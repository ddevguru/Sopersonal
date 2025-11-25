import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:play_smart/Auth/login_screen.dart';
import 'package:play_smart/Models/contest.dart';
import 'package:play_smart/controller/mega-contest-controller.dart';
import 'package:play_smart/controller/mini-contest-controller.dart';
import 'package:play_smart/profile_Screen.dart';
import 'package:play_smart/splash_screen.dart';
import 'package:play_smart/widgets/scratch_card_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'quiz_screen.dart';
import 'mega_quiz_screen.dart';
import 'mega_result_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingIconsController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  double userBalance = 0.0;
  List<Contest> miniContests = [];
  List<Contest> megaContests = [];
  final ContestController _miniContestController = ContestController();
  final MegaContestController _megaContestController = MegaContestController();
  Timer? _refreshTimer;
  Map<int, Map<String, dynamic>> _megaContestStatus = {};

  final List<List<Color>> cardGradients = [
    [Color(0xFFFF6F00), Color(0xFFFFB300)], // Amber gradient
    [Color(0xFF00C853), Color(0xFF4CAF50)], // Green gradient
    [Color(0xFF0288D1), Color(0xFF03A9F4)], // Blue gradient
    [Color(0xFFAD1457), Color(0xFFF06292)], // Pink gradient
    [Color(0xFF6D4C41), Color(0xFF8D6E63)], // Brown gradient
    [Color(0xFF7B1FA2), Color(0xFFAB47BC)], // Purple gradient (complementary)
  ];

  Map<int, List<Map<String, dynamic>>> _contestRankings = {};
  Map<int, bool> _scratchCardScratched = {}; // Track which cards have been scratched
  bool _canScratchToday = true; // Whether user can scratch a card today
  Map<String, dynamic> _weeklyProgress = {
    'scratched_days': [],
    'total_scratched': 0,
    'total_amount': 0.0,
    'current_day': 1,
  }; // Weekly scratch card progress

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchUserBalance();
    fetchContests();
    _startRefreshTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMiniContestPopup();
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _floatingIconsController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 8000),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingIconsController.dispose();
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showMiniContestPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF9575CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Information',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'English: If you exit a Mini Contest after joining, you must wait 2 minutes to play the next Mini Contest.',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFD1C4E9),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Hindi: यदि आप मिनी कॉन्टेस्ट में शामिल होने के बाद बाहर निकलते हैं, तो आपको अगला मिनी कॉन्टेस्ट खेलने के लिए 2 मिनट इंतजार करना होगा।',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFD1C4E9),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Marathi: जर तुम्ही मिनी कॉन्टेस्टमध्ये सामील झाल्यावर बाहेर पडलात, तर पुढील मिनी कॉन्टेस्ट खेळण्यासाठी तुम्हाला 2 मिनट थांबावे लागेल.',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFD1C4E9),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFCE93D8),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF6A1B9A),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Confirm Logout',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A1B9A),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6A1B9A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _redirectToLogin() async {
    print('Redirecting to login...');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('token');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SplashScreen()),
      );
    }
  }

  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      print('Error: No token found for updating last activity');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://sopersonal.in/update_last_activity.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'session_token': token},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!data['success']) {
          print('Failed to update last activity: ${data['message']}');
        }
      } else {
        print('Failed to update last activity: HTTP ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error updating last activity: $e');
    }
  }

  Future<void> fetchUserBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() {
        userBalance = 0.0;
      });
      return;
    }
    try {
      await updateLastActivity();
      final response = await http.get(
        Uri.parse('https://sopersonal.in/fetch_user_balance.php?session_token=$token'),
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            userBalance = data['data']['wallet_balance'] is double
                ? data['data']['wallet_balance']
                : double.parse(data['data']['wallet_balance'].toString());
          });
        } else {
          setState(() {
            userBalance = 0.0;
          });
        }
      } else {
        setState(() {
          userBalance = 0.0;
        });
      }
    } catch (e) {
      setState(() {
        userBalance = 0.0;
      });
    }
  }

  Future<Map<String, dynamic>> fetchScratchCardInfo(int contestId, String contestType) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }
    try {
      await updateLastActivity();
      final response = await http.get(
        Uri.parse('https://sopersonal.in/fetch_scratch_card_amount.php?session_token=$token&contest_id=$contestId&contest_type=$contestType'),
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final amount = data['amount'] is double
              ? data['amount']
              : double.parse(data['amount'].toString());
          final canScratch = data['can_scratch_today'] ?? true;
          final weeklyProgress = data['weekly_progress'] ?? {};
          setState(() {
            _canScratchToday = canScratch;
            _weeklyProgress = {
              'scratched_days': List<int>.from(weeklyProgress['scratched_days'] ?? []),
              'total_scratched': weeklyProgress['total_scratched'] ?? 0,
              'total_amount': weeklyProgress['total_amount'] is double
                  ? weeklyProgress['total_amount']
                  : double.parse((weeklyProgress['total_amount'] ?? 0).toString()),
              'current_day': weeklyProgress['current_day'] ?? 1,
              'week_start_date': weeklyProgress['week_start_date'] ?? '',
            };
          });
          return {
            'amount': amount,
            'can_scratch_today': canScratch,
            'weekly_progress': weeklyProgress,
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch scratch card amount');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching scratch card amount: $e');
      throw e;
    }
  }

  Future<double> fetchScratchCardAmount(int contestId, String contestType) async {
    final info = await fetchScratchCardInfo(contestId, contestType);
    return info['amount'] as double;
  }

  Future<void> updateWalletFromScratchCard(int contestId, String contestType, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }
    try {
      await updateLastActivity();
      final response = await http.post(
        Uri.parse('https://sopersonal.in/update_wallet_from_scratch_card.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'contest_id': contestId.toString(),
          'contest_type': contestType,
          'amount': amount.toString(),
        },
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // Update local balance
          final weeklyProgress = data['weekly_progress'] ?? {};
          setState(() {
            userBalance += amount;
            _scratchCardScratched[contestId] = true;
            _weeklyProgress = {
              'scratched_days': List<int>.from(weeklyProgress['scratched_days'] ?? []),
              'total_scratched': weeklyProgress['total_scratched'] ?? 0,
              'total_amount': weeklyProgress['total_amount'] is double
                  ? weeklyProgress['total_amount']
                  : double.parse((weeklyProgress['total_amount'] ?? 0).toString()),
              'current_day': weeklyProgress['current_day'] ?? 1,
              'week_start_date': weeklyProgress['week_start_date'] ?? '',
            };
          });
          // Refresh balance from server
          await fetchUserBalance();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${amount.toStringAsFixed(2)} added to your wallet!'),
                        Text(
                          'Week Progress: ${weeklyProgress['total_scratched'] ?? 0}/7 days',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to update wallet');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating wallet from scratch card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Error updating wallet: $e'),
            ],
          ),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      rethrow;
    }
  }

 Future<void> fetchContests() async {
  try {
    await updateLastActivity();
    print('DEBUG: Starting fetchContests');
    final miniContestsData = await _miniContestController.fetchContests();
    print('DEBUG: Mini Contests fetched: ${miniContestsData.length} items');

    List<Contest> megaContestsData = [];
    try {
      megaContestsData = await _megaContestController.fetchMegaContests();
      print('DEBUG: Mega Contests fetched: ${megaContestsData.length} items');
    } catch (e) {
      print('WARNING: Failed to fetch mega contests, proceeding with mini contests only: $e');
    }

    Map<int, Map<String, dynamic>> newMegaContestStatus = {};
    for (var contest in megaContestsData) {
      try {
        await updateLastActivity();
        final status = await _megaContestController.fetchMegaContestStatus(contest.id);
        print('DEBUG: Fetched status for Contest ID: ${contest.id}, Status: $status');
        final startDateTime = DateTime.tryParse(status['start_datetime'] ?? '') ?? contest.startDateTime ?? DateTime.now();

        final hasSubmitted = status['has_submitted'] ?? false;
        final hasViewedResults = status['has_viewed_results'] ?? false;

        final existingStatus = _megaContestStatus[contest.id];
        newMegaContestStatus[contest.id] = {
          'is_joinable': status['is_joinable'] ?? false,
          'has_joined': status['has_joined'] ?? false,
          'is_active': status['is_active'] ?? false,
          'has_submitted': hasSubmitted,
          'has_viewed_results': hasViewedResults,
          'start_datetime': startDateTime.toIso8601String(),
          'isWinner': existingStatus?['isWinner'] ?? false,
          'isTie': existingStatus?['isTie'] ?? false,
          'opponentName': existingStatus?['opponentName'],
          'opponentScore': existingStatus?['opponentScore'],
          'matchCompleted': existingStatus?['matchCompleted'] ?? false,
        };
      } catch (e) {
        print('ERROR: Failed to fetch status for contest ${contest.id}: $e');
        if (_megaContestStatus.containsKey(contest.id)) {
          newMegaContestStatus[contest.id] = _megaContestStatus[contest.id]!;
          print('DEBUG: Preserving old status for contest ${contest.id} due to error.');
        } else {
          print('DEBUG: Contest ${contest.id} has no prior status and fetch failed. It will be filtered out.');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      miniContests = miniContestsData;
      _megaContestStatus = newMegaContestStatus;
      megaContests = megaContestsData.where((contest) {
        final status = _megaContestStatus[contest.id];
        if (status == null) {
          print('DEBUG: Contest ID: ${contest.id} has no status data. Using fallback logic.');
          final startDateTime = contest.startDateTime ?? DateTime.now();
          final now = DateTime.now();
          final minutesUntilStart = startDateTime.difference(now).inMinutes;
          final shouldBeVisible = (minutesUntilStart >= -120 && minutesUntilStart <= 1440);
          print('DEBUG: Fallback filtering for Contest ID: ${contest.id}, minutesUntilStart: $minutesUntilStart, shouldBeVisible: $shouldBeVisible');
          return shouldBeVisible;
        }
        final hasJoined = status['has_joined'] ?? false;
        final hasSubmitted = status['has_submitted'] ?? false;
        final hasViewedResults = status['has_viewed_results'] ?? false;
        final isJoinable = status['is_joinable'] ?? false;

        final startDateTime = DateTime.tryParse(status['start_datetime'] ?? '') ?? contest.startDateTime ?? DateTime.now();
        final now = DateTime.now();
        final minutesUntilStart = startDateTime.difference(now).inMinutes;

        final shouldBeVisible = isJoinable ||
                               hasJoined ||
                               hasSubmitted ||
                               (minutesUntilStart >= -120 && minutesUntilStart <= 1440);

        print('DEBUG: Filtering Contest ID: ${contest.id}, Name: ${contest.name}, shouldBeVisible: $shouldBeVisible');
        return shouldBeVisible;
      }).toList();
    });
  } catch (e, stackTrace) {
    print('Error loading contests: $e\nStack Trace: $stackTrace');
  }
}

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 60), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      print('DEBUG: Refresh timer triggered. Fetching user balance and contests...');
      await fetchUserBalance();
      await fetchContests();
    });
  }

  Future<String?> getMatchId(int contestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;
    try {
      await updateLastActivity();
      final response = await http.get(
        Uri.parse('https://sopersonal.in/mega/get_match_id.php?session_token=$token&contest_id=$contestId&contest_type=mega'),
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final matchId = data['match_id']?.toString();
          if (matchId != null && matchId.isNotEmpty) {
            print('DEBUG: Fetched match ID: $matchId for contest $contestId');
            return matchId;
          } else {
            print('ERROR: Match ID not provided by server for contest $contestId');
            return null;
          }
        } else {
          print('ERROR: Failed to fetch match ID for contest $contestId: ${data['message']}');
          return null;
        }
      } else {
        print('ERROR: Failed to fetch match ID for contest $contestId: HTTP ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('ERROR: Error fetching match ID for contest $contestId: $e');
      return null;
    }
  }

  Future<void> _showRankingsPopup(Contest contest) async {
    try {
      final rankings = await _megaContestController.fetchContestRankings(contest.id);
      _contestRankings[contest.id] = rankings;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFD1C4E9).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Color(0xFF6A1B9A),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Contest Rankings',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  Text(
                    contest.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rankings.length,
                      itemBuilder: (context, index) {
                        final ranking = rankings[index];
                        return Card(
                          color: Color(0xFFD1C4E9).withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRankColor(ranking['rank_start']),
                              child: Text(
                                '${ranking['rank_start']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              'Rank ${ranking['rank_start']} - ${ranking['rank_end']}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                            trailing: Text(
                              '₹${ranking['prize_amount']}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCE93D8),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  joinContest(contest);
                },
                child: Text(
                  'Join Now',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6A1B9A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error fetching rankings: $e');
      joinContest(contest);
    }
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Color(0xFFFFD700);
    if (rank == 2) return Color(0xFFC0C0C0);
    if (rank == 3) return Color(0xFFCD7F32);
    return Color(0xFF9575CD);
  }

  Future<void> joinContest(Contest contest) async {
    if (userBalance < contest.entryFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Insufficient balance to join contest'),
            ],
          ),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    try {
      await updateLastActivity();
      final joinData = contest.type == 'mega'
          ? await _megaContestController.joinMegaContest(contest.id, contest.entryFee)
          : await _miniContestController.joinContest(contest.id, contest.entryFee, contest.type);
      
      final String? matchId = joinData['match_id']?.toString();
      if (matchId == null || matchId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Error: Match ID not received from server'),
              ],
            ),
            backgroundColor: Colors.red[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      setState(() {
        userBalance -= contest.entryFee;
        if (contest.type == 'mega') {
          _megaContestStatus[contest.id] = {
            'is_joinable': false,
            'has_joined': true,
            'is_active': false,
            'has_submitted': false,
            'has_viewed_results': false,
            'start_datetime': contest.startDateTime?.toIso8601String() ?? _megaContestStatus[contest.id]?['start_datetime'] ?? DateTime.now().toIso8601String(),
            'isWinner': false,
            'isTie': false,
            'opponentName': null,
            'opponentScore': null,
            'matchCompleted': false,
          };
        }
      });
      
      if (contest.type == 'mega') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Successfully joined Mega Contest. Wait for the start time.'),
              ],
            ),
            backgroundColor: Color(0xFF9575CD),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        fetchContests();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              contestId: contest.id,
              contestName: contest.name,
              contestType: contest.type,
              entryFee: contest.entryFee,
              prizePool: contest.prizePool,
              matchId: matchId,
              initialIsBotOpponent: joinData['is_bot'] ?? false,
              initialOpponentName: joinData['opponent_name'],
              initialAllPlayersJoined: joinData['all_players_joined'] ?? false,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Error joining contest: $e'),
            ],
          ),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> startMegaContest(Contest contest) async {
    await updateLastActivity();
    final matchId = await getMatchId(contest.id);
    if (matchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Error: Match ID not found'),
            ],
          ),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    try {
      final result = await _megaContestController.startMegaContest(contest.id, matchId);
      if (result['success']) {
        setState(() {
          _megaContestStatus[contest.id]!['is_active'] = true;
        });
        
        final quizResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MegaQuizScreen(
              contestId: contest.id,
              contestName: contest.name,
              contestType: contest.type,
              entryFee: contest.entryFee,
              numQuestions: contest.numQuestions,
              matchId: matchId,
            ),
          ),
        );
        
        if (quizResult != null && quizResult is Map<String, dynamic> && quizResult['success'] == true) {
          setState(() {
            _megaContestStatus[contest.id]!['has_submitted'] = quizResult['hasSubmitted'] ?? true;
            _megaContestStatus[contest.id]!['has_viewed_results'] = quizResult['hasViewedResults'] ?? false;
            _megaContestStatus[contest.id]!['is_active'] = false;
            _megaContestStatus[contest.id]!['isWinner'] = quizResult['isWinner'] ?? false;
            _megaContestStatus[contest.id]!['isTie'] = quizResult['isTie'] ?? false;
            _megaContestStatus[contest.id]!['opponentName'] = quizResult['opponentName'];
            _megaContestStatus[contest.id]!['opponentScore'] = quizResult['opponentScore'];
            _megaContestStatus[contest.id]!['matchCompleted'] = quizResult['matchCompleted'] ?? false;
            print('DEBUG: Updated _megaContestStatus after quiz submission for contest ${contest.id}:');
            print('    has_submitted: ${_megaContestStatus[contest.id]!['has_submitted']}');
            print('    has_viewed_results: ${_megaContestStatus[contest.id]!['has_viewed_results']}');
          });
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              fetchContests();
            }
          });
        } else {
          setState(() {
            _megaContestStatus[contest.id]!['is_active'] = false;
          });
          fetchContests();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Error starting contest: ${result['message']}'),
              ],
            ),
            backgroundColor: Colors.red[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Error starting contest: $e'),
            ],
          ),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> viewMegaResults(Contest contest) async {
    try {
      await updateLastActivity();
      final matchId = await getMatchId(contest.id);
      if (matchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Error: Match ID not found'),
              ],
            ),
            backgroundColor: Colors.red[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Error: No token found'),
              ],
            ),
            backgroundColor: Colors.red[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      final response = await http.get(
        Uri.parse('https://sopersonal.in/mega/fetch_results.php?session_token=$token&contest_id=${contest.id}&match_id=$matchId'),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Error fetching results: HTTP ${response.statusCode}'),
              ],
            ),
            backgroundColor: Colors.red[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      final resultData = jsonDecode(response.body);
      if (!resultData['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Error fetching results: ${resultData['message']}'),
              ],
            ),
            backgroundColor: Colors.red[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      double? parseToDouble(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }
      
      final resultViewed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MegaResultScreen(
            contestId: contest.id,
            contestName: contest.name,
            numQuestions: contest.numQuestions,
            matchId: matchId,
            userScore: parseToDouble(resultData['user_score']),
            prizeWon: parseToDouble(resultData['prize_won']),
            isWinner: resultData['is_winner'] ?? false,
            isTie: resultData['is_tie'] ?? false,
            opponentName: resultData['opponent_name'],
            opponentScore: parseToDouble(resultData['opponent_score']),
          ),
        ),
      );
      
      if (resultViewed == true) {
        setState(() {
          _megaContestStatus[contest.id]!['has_viewed_results'] = true;
          _megaContestStatus[contest.id]!['isWinner'] = resultData['is_winner'] ?? false;
          _megaContestStatus[contest.id]!['isTie'] = resultData['is_tie'] ?? false;
          _megaContestStatus[contest.id]!['opponentName'] = resultData['opponent_name'];
          _megaContestStatus[contest.id]!['opponentScore'] = parseToDouble(resultData['opponent_score']);
          print('DEBUG: Set has_viewed_results to true for contest ${contest.id}');
        });
        
        print('DEBUG: Results viewed for contest ${contest.id}');
      }
      
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          fetchContests();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('ERROR: Failed to view results for contest ${contest.id}: $e'),
            ],
          ),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFloatingIcon(int index) {
    final icons = [
      Icons.lightbulb_outline,
      Icons.emoji_events,
      Icons.school,
      Icons.psychology,
      Icons.extension,
      Icons.star,
      Icons.auto_awesome,
      Icons.emoji_objects,
    ];
    final sizes = [30.0, 40.0, 25.0, 35.0, 45.0];
    return Icon(
      icons[index % icons.length],
      color: Color(0xFFD1C4E9),
      size: sizes[index % sizes.length],
    );
  }

  Widget _buildAnimatedIconButton({required IconData icon, required VoidCallback onPressed}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFFD1C4E9).withOpacity(0.3),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF6A1B9A).withOpacity(0.2 + (_pulseController.value * 0.1)),
                blurRadius: 10 + (_pulseController.value * 5),
                spreadRadius: 1 + (_pulseController.value * 1),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 24),
            onPressed: onPressed,
            splashColor: Color(0xFFCE93D8).withOpacity(0.3),
            highlightColor: Color(0xFFCE93D8).withOpacity(0.2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedMiniContests = miniContests.toList()
      ..sort((a, b) => a.entryFee.compareTo(b.entryFee));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF9575CD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -screenWidth * 0.2,
            left: -screenWidth * 0.2,
            child: Container(
              height: screenWidth * 0.5,
              width: screenWidth * 0.5,
              decoration: BoxDecoration(
                color: Color(0xFF9575CD).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -screenWidth * 0.3,
            right: -screenWidth * 0.3,
            child: Container(
              height: screenWidth * 0.6,
              width: screenWidth * 0.6,
              decoration: BoxDecoration(
                color: Color(0xFF9575CD).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ...List.generate(10, (index) {
            return Positioned(
              top: 100 + (index * 70),
              left: (index % 2 == 0) ? -20 : null,
              right: (index % 2 == 1) ? -20 : null,
              child: AnimatedBuilder(
                animation: _floatingIconsController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      math.sin((_floatingIconsController.value * 2 * math.pi) + index) * 30,
                      math.cos((_floatingIconsController.value * 2 * math.pi) + index + 1) * 20,
                    ),
                    child: Opacity(
                      opacity: 0.15,
                      child: _buildFloatingIcon(index),
                    ),
                  );
                },
              ),
            );
          }),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildAnimatedIconButton(
                          icon: Icons.logout,
                          onPressed: () {
                            _showLogoutConfirmationDialog();
                          },
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFD1C4E9).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(0xFFCE93D8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '₹${userBalance.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            _buildAnimatedIconButton(
                              icon: Icons.refresh,
                              onPressed: fetchUserBalance,
                            ),
                          ],
                        ),
                      ),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildAnimatedIconButton(
                          icon: Icons.person,
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            String? token = prefs.getString('token');
                            print('Token for profile: $token');
                            if (token != null) {
                              await updateLastActivity();
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(token: token),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    var begin = Offset(1.0, 0.0);
                                    var end = Offset.zero;
                                    var curve = Curves.easeOutQuint;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    return SlideTransition(position: animation.drive(tween), child: child);
                                  },
                                  transitionDuration: Duration(milliseconds: 500),
                                ),
                              ).then((_) {
                                fetchUserBalance();
                              });
                            } else {
                              await _redirectToLogin();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.05),
                                child: Text(
                                  'Sopersonal',
                                  style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: Offset(0, 3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          Text(
                            'Test your knowledge & win big!',
                            style: GoogleFonts.poppins(
                              color: Color(0xFFD1C4E9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Expanded(
                    child: ListView(
                      physics: BouncingScrollPhysics(),
                      children: [
                        if (megaContests.isNotEmpty) ...[
                          _buildSectionTitle('Bg Win Contests'),
                          SizedBox(height: 10),
                          ...megaContests.asMap().entries.map((entry) {
                            final index = entry.key;
                            final contest = entry.value;
                            return _buildContestCard(contest, index, isMega: true);
                          }),
                        ],
                        if (sortedMiniContests.isNotEmpty) ...[
                          SizedBox(height: 20),
                          _buildSectionTitle('Mini Contests'),
                          SizedBox(height: 10),
                          ...sortedMiniContests.asMap().entries.map((entry) {
                            final index = entry.key;
                            final contest = entry.value;
                            return _buildContestCard(contest, index, isMega: false);
                          }),
                        ],
                        if (megaContests.isEmpty && sortedMiniContests.isEmpty)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Color(0xFFCE93D8)),
                                SizedBox(height: 20),
                                Text(
                                  'Loading Contests...',
                                  style: GoogleFonts.poppins(
                                    color: Color(0xFFD1C4E9),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 5),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: Color(0xFFCE93D8),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildContestCard(Contest contest, int index, {required bool isMega}) {
    final status = _megaContestStatus[contest.id] ?? {};
    final isJoinable = status['is_joinable'] ?? false;
    final hasJoined = status['has_joined'] ?? false;
    final isActive = status['is_active'] ?? false;
    final hasSubmitted = status['has_submitted'] ?? false;
    final hasViewedResults = status['has_viewed_results'] ?? false;
    final startDateTime = DateTime.tryParse(status['start_datetime'] ?? '') ?? contest.startDateTime ?? DateTime.now();
    final isStartTimeReached = DateTime.now().difference(startDateTime).inSeconds >= 0;
    final minutesUntilStart = startDateTime.difference(DateTime.now()).inMinutes;
    
    final bool isStartWindowOpen = isActive && !hasSubmitted;
    final bool canJoinMega = isMega && isJoinable && !hasJoined && minutesUntilStart > 1;
    final bool canStartMega = isMega && hasJoined && isStartTimeReached && !hasSubmitted;
    final bool canViewResultsMega = isMega && hasSubmitted && !hasViewedResults;
    
    final gradient = cardGradients[index % cardGradients.length];
    
    print('DEBUG: Building Card for Contest ID: ${contest.id}, Name: ${contest.name}');
    print('    isJoinable: $isJoinable, hasJoined: $hasJoined, isActive: $isActive, hasSubmitted: $hasSubmitted, hasViewedResults: $hasViewedResults');
    print('    startDateTime: $startDateTime, isStartTimeReached: $isStartTimeReached, minutesUntilStart: $minutesUntilStart');
    print('    isStartWindowOpen: $isStartWindowOpen');
    print('    canJoinMega: $canJoinMega, canStartMega: $canStartMega, canViewResultsMega: $canViewResultsMega');

    String buttonText;
    Color buttonColor;
    bool buttonEnabled;

    if (isMega) {
      final hasStatusData = _megaContestStatus.containsKey(contest.id);
      
      if (!hasStatusData) {
        if (minutesUntilStart > 1 && minutesUntilStart <= 30) {
          buttonText = 'Join Now';
          buttonColor = Color(0xFFCE93D8);
          buttonEnabled = true;
        } else if (minutesUntilStart <= 1 && minutesUntilStart > -120) {
          buttonText = 'Joining Closed';
          buttonColor = Colors.grey.withOpacity(0.5);
          buttonEnabled = false;
        } else if (minutesUntilStart <= 0 && minutesUntilStart > -120) {
          buttonText = 'Start Now';
          buttonColor = Color(0xFFCE93D8);
          buttonEnabled = true;
        } else {
          buttonText = 'Joining Closed';
          buttonColor = Colors.grey.withOpacity(0.5);
          buttonEnabled = false;
        }
      } else if (canViewResultsMega) {
        buttonText = 'View Result';
        buttonColor = Color(0xFF9575CD);
        buttonEnabled = true;
      } else if (canStartMega) {
        buttonText = 'Start Now';
        buttonColor = Color(0xFFCE93D8);
        buttonEnabled = true;
      } else if (hasJoined && !hasSubmitted) {
        if (minutesUntilStart > 0) {
          buttonText = 'Waiting to Start (${minutesUntilStart}m)';
          buttonColor = Colors.orange;
          buttonEnabled = false;
        } else if (isStartTimeReached) {
          buttonText = 'Start Now';
          buttonColor = Color(0xFFCE93D8);
          buttonEnabled = true;
        } else {
          buttonText = 'Waiting to Start';
          buttonColor = Colors.orange;
          buttonEnabled = false;
        }
      } else if (canJoinMega) {
        buttonText = 'Join Now';
        buttonColor = Color(0xFFCE93D8);
        buttonEnabled = true;
      } else if (hasSubmitted && hasViewedResults) {
        buttonText = 'View Result Again';
        buttonColor = Color(0xFF9575CD);
        buttonEnabled = true;
      } else if (isMega && !hasJoined && minutesUntilStart <= 1 && minutesUntilStart > -120) {
        buttonText = 'Joining Closed';
        buttonColor = Colors.grey.withOpacity(0.5);
        buttonEnabled = false;
      } else if (isMega && !hasJoined && minutesUntilStart > 1 && minutesUntilStart <= 30) {
        buttonText = 'Joining Soon (${minutesUntilStart}m)';
        buttonColor = Colors.grey.withOpacity(0.5);
        buttonEnabled = false;
      } else {
        buttonText = 'Joining Closed';
        buttonColor = Colors.grey.withOpacity(0.5);
        buttonEnabled = false;
      }
    } else {
      buttonText = 'Join Now';
      buttonColor = Color(0xFFCE93D8);
      buttonEnabled = true;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: buttonEnabled
              ? () {
                  if (isMega) {
                    final hasStatusData = _megaContestStatus.containsKey(contest.id);
                    
                    if (!hasStatusData) {
                      if (minutesUntilStart > 1 && minutesUntilStart <= 30) {
                        _showRankingsPopup(contest);
                      } else if (minutesUntilStart <= 0 && minutesUntilStart > -120) {
                        startMegaContest(contest);
                      }
                    } else if (canViewResultsMega || (hasSubmitted && hasViewedResults)) {
                      viewMegaResults(contest);
                    } else if (canStartMega) {
                      startMegaContest(contest);
                    } else if (canJoinMega) {
                      _showRankingsPopup(contest);
                    }
                  } else {
                    joinContest(contest);
                  }
                }
              : null,
          child: Container(
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Opacity(
                    opacity: 0.2,
                    child: Icon(
                      Icons.star,
                      size: 100,
                      color: Color(0xFFD1C4E9),
                    ),
                  ),
                ),
                // Scratch Card Overlay
                if (!(_scratchCardScratched[contest.id] ?? false))
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: IgnorePointer(
                        ignoring: _scratchCardScratched[contest.id] ?? false,
                        child: ScratchCardWidget(
                          contestId: contest.id,
                          contestType: contest.type,
                          canScratchToday: _canScratchToday && !_scratchCardScratched.values.any((scratched) => scratched),
                          weeklyProgress: _weeklyProgress,
                          fetchScratchAmount: () => fetchScratchCardAmount(contest.id, contest.type),
                          onScratched: (amount) {
                            updateWalletFromScratchCard(contest.id, contest.type, amount);
                          },
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Color(0xFFD1C4E9).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              contest.type.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.1),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFD1C4E9).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.monetization_on,
                                        color: Color(0xFFCE93D8),
                                        size: 16,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '₹${contest.entryFee.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        contest.name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      if (isMega) ...[
                        _buildContestDetail(
                          icon: Icons.schedule,
                          text: 'Start: ${startDateTime.toLocal().toString().split('.')[0]}',
                        ),
                        _buildContestDetail(
                          icon: Icons.group,
                          text: 'Players: ${contest.numPlayers}',
                        ),
                        _buildContestDetail(
                          icon: Icons.question_answer,
                          text: 'Questions: ${contest.numQuestions}',
                        ),
                        if (contest.totalWinningAmount != null)
                          _buildContestDetail(
                            icon: Icons.monetization_on,
                            text: 'Total Winning Amount: ₹${contest.totalWinningAmount!.toStringAsFixed(2)}',
                          ),
                      ] else ...[
                        _buildContestDetail(
                          icon: Icons.account_balance_wallet,
                          text: 'Prize Pool: ₹${contest.prizePool.toStringAsFixed(2)}',
                        ),
                      ],
                      SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: buttonEnabled
                              ? () {
                                  if (isMega) {
                                    if (canViewResultsMega) {
                                      viewMegaResults(contest);
                                    } else if (canStartMega) {
                                      startMegaContest(contest);
                                    } else if (canJoinMega) {
                                      _showRankingsPopup(contest);
                                    }
                                  } else {
                                    joinContest(contest);
                                  }
                                }
                              : null,
                          child: Text(
                            buttonText,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContestDetail({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xFFD1C4E9),
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Color(0xFFD1C4E9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}