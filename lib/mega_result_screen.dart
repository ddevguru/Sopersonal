import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';

class MegaResultScreen extends StatefulWidget {
  final int contestId;
  final String contestName;
  final int numQuestions;
  final String matchId;
  final double? userScore;
  final double? prizeWon;
  final bool isWinner;
  final bool isTie;
  final String? opponentName;
  final double? opponentScore;

  const MegaResultScreen({
    Key? key,
    required this.contestId,
    required this.contestName,
    required this.numQuestions,
    required this.matchId,
    this.userScore,
    this.prizeWon,
    required this.isWinner,
    required this.isTie,
    this.opponentName,
    this.opponentScore,
  }) : super(key: key);

  @override
  _MegaResultScreenState createState() => _MegaResultScreenState();
}

class _MegaResultScreenState extends State<MegaResultScreen> {
  double? userScore;
  double? prizeWon;
  String? opponentName;
  double? opponentScore;
  bool isWinner;
  bool isTie;
  bool isLoading = true;
  String? errorMessage;
  bool matchCompletedOnServer = false;
  Timer? _pollingTimer;
  
  // New variables for leaderboard
  List<Map<String, dynamic>> allParticipants = [];
  int userRank = 0;
  int totalParticipants = 0;

  _MegaResultScreenState()
      : userScore = null,
        prizeWon = null,
        opponentName = null,
        opponentScore = null,
        isWinner = false,
        isTie = false;

  @override
  void initState() {
    super.initState();
    // Initialize with widget values if provided
    userScore = widget.userScore;
    prizeWon = widget.prizeWon;
    opponentName = widget.opponentName;
    opponentScore = widget.opponentScore;
    isWinner = widget.isWinner;
    isTie = widget.isTie;
    // Start fetching results and polling
    _startResultPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startResultPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await fetchResults();
      if (matchCompletedOnServer) {
        timer.cancel();
      }
    });
  }

  Future<void> fetchResults() async {
    if (!isLoading && matchCompletedOnServer) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() {
          errorMessage = 'No token found. Please log in again.';
          isLoading = false;
        });
        _pollingTimer?.cancel();
        return;
      }

      final response = await http.get(
        Uri.parse('https://sopersonal.in/mega/view_mega_results.php?session_token=$token&contest_id=${widget.contestId}&match_id=${widget.matchId}'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            userScore = _parseToDouble(data['user_score']) ?? 0.0;
            prizeWon = _parseToDouble(data['prize_won']) ?? 0.0;
            opponentName = data['opponent_name'] ?? 'Unknown';
            opponentScore = _parseToDouble(data['opponent_score']) ?? 0.0;
            isWinner = data['is_winner'] ?? false;
            isTie = data['is_tie'] ?? false;
            matchCompletedOnServer = data['match_completed'] == true;
            
            // New leaderboard data
            userRank = data['user_rank'] ?? 0;
            totalParticipants = data['total_participants'] ?? 0;
            
            // Parse all participants data
            if (data['all_participants'] != null) {
              allParticipants = List<Map<String, dynamic>>.from(data['all_participants']);
            }
            
            isLoading = false;
          });

          print('DEBUG: Fetched results for contest ${widget.contestId}:');
          print('    User Score: $userScore, Prize Won: $prizeWon, User Rank: $userRank');
          print('    Total Participants: $totalParticipants');
          print('    All Participants: $allParticipants');
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Failed to fetch results';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: HTTP ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching results: $e';
        isLoading = false;
      });
      print('ERROR: Failed to fetch results for contest ${widget.contestId}: $e');
    }
  }

  double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Handle empty strings
      if (value.isEmpty) return null;
      return double.tryParse(value);
    }
    return null;
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey[400]!; // Silver
      case 3:
        return Colors.brown; // Bronze
      default:
        return Colors.blue[300]!;
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events; // Trophy
      case 2:
        return Icons.military_tech; // Medal
      case 3:
        return Icons.workspace_premium; // Badge
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _pollingTimer?.cancel();
        Navigator.pop(context, true);
        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[300],
                              size: 64,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              errorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                _startResultPolling();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'Retry',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildResultContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildResultContent() {
    String resultMessage = isTie
        ? "It's a Tie!"
        : isWinner
            ? "Congratulations!"
            : "Better Luck Next Time!";

    String resultSubMessage = isTie
        ? "Multiple players scored equally!"
        : isWinner
            ? "You won the contest!"
            : "Keep practicing for better results!";

    Color resultColor = isTie
        ? Colors.orange
        : isWinner
            ? Colors.green
            : Colors.red;

    IconData resultIcon = isTie
        ? Icons.handshake
        : isWinner
            ? Icons.emoji_events
            : Icons.sentiment_dissatisfied;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header with Contest Name
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.contestName,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Result Card
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resultColor.withOpacity(0.2),
                    border: Border.all(color: resultColor, width: 2),
                  ),
                  child: Icon(
                    resultIcon,
                    size: 50,
                    color: resultColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  resultMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  resultSubMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                if (!matchCompletedOnServer)
                  Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 15),
                      Text(
                        'Waiting for all players to submit scores...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // User's Performance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Performance',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricColumn(
                        icon: Icons.emoji_events,
                        label: 'Your Rank',
                        value: '#$userRank',
                        iconColor: _getRankColor(userRank),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMetricColumn(
                        icon: Icons.quiz,
                        label: 'Your Score',
                        value: '${userScore?.toStringAsFixed(0) ?? '0'}/${widget.numQuestions}',
                        iconColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricColumn(
                        icon: Icons.monetization_on,
                        label: 'Prize Won',
                        value: '₹${prizeWon?.toStringAsFixed(2) ?? '0.00'}',
                        iconColor: Colors.yellowAccent,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMetricColumn(
                        icon: Icons.analytics,
                        label: 'Accuracy',
                        value: '${((userScore ?? 0) / widget.numQuestions * 100).toStringAsFixed(1)}%',
                        iconColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Leaderboard Card
          if (allParticipants.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.leaderboard, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Leaderboard',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...allParticipants.asMap().entries.map((entry) {
                    final index = entry.key;
                    final participant = entry.value;
                    final rank = participant['rank'] ?? (index + 1);
                    final username = participant['username'] ?? 'Unknown';
                    final score = participant['score'] ?? 0;
                    final prize = participant['prize_won'] ?? 0.0;
                    final isCurrentUser = participant['user_id'].toString() == 
                        participant['current_user_id']?.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isCurrentUser 
                            ? Colors.amber.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrentUser 
                              ? Colors.amber.withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                          width: isCurrentUser ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Rank with icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getRankColor(rank).withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _getRankColor(rank),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: rank <= 3
                                  ? Icon(
                                      _getRankIcon(rank),
                                      color: _getRankColor(rank),
                                      size: 20,
                                    )
                                  : Text(
                                      '$rank',
                                      style: GoogleFonts.poppins(
                                        color: _getRankColor(rank),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          
                          // Username and score
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      username,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: GoogleFonts.poppins(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  'Score: $score/${widget.numQuestions}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Prize
                          if (prize > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '₹${prize.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          const SizedBox(height: 30),

          // Back to Contests Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _pollingTimer?.cancel();
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: Text(
                'Back to Contests',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Colors.white, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
