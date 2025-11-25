import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:play_smart/Models/question.dart';
import 'package:play_smart/Auth/login_screen.dart';
import 'package:play_smart/controller/mega-contest-controller.dart';
import 'package:play_smart/mega_score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import 'mega_result_screen.dart';

class MegaQuizScreen extends StatefulWidget {
  final int contestId;
  final String contestName;
  final String contestType;
  final double entryFee;
  final int numQuestions;
  final String matchId;

  const MegaQuizScreen({
    Key? key,
    required this.contestId,
    required this.contestName,
    required this.contestType,
    required this.entryFee,
    required this.numQuestions,
    required this.matchId,
  }) : super(key: key);

  @override
  _MegaQuizScreenState createState() => _MegaQuizScreenState();
}

class _MegaQuizScreenState extends State<MegaQuizScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _timerController;
  late AnimationController _questionTransitionController;
  late AnimationController _confettiController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Question> questions = [];
  Map<int, String> userAnswers = {};
  int currentQuestionIndex = 0;
  int userScore = 0;
  bool isLoading = true;
  bool hasSubmitted = false;
  bool isSubmitting = false;
  String? sessionToken;
  final MegaContestController _contestController = MegaContestController();
  final MegaScoreService _scoreService = MegaScoreService();
  Timer? questionTimer;
  Timer? autoSubmitCheckTimer;
  int questionTimeRemaining = 30;
  int totalTimeInSeconds = 0;
  int remainingTimeInSeconds = 0;
  bool isTimerRunning = false;
  String errorMessage = '';
  bool isWaitingForAutoSubmit = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchSessionToken();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _questionTransitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _timerController.dispose();
    _questionTransitionController.dispose();
    _confettiController.dispose();
    questionTimer?.cancel();
    autoSubmitCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAutoSubmitStatus() async {
    if (hasSubmitted || !mounted) return;
    
    try {
      final status = await _contestController.checkAutoSubmitStatus(widget.contestId);
      
      if (status['auto_submit_triggered'] == true) {
        if (mounted) {
          setState(() {
            isWaitingForAutoSubmit = false;
          });
          _endTest();
        }
      } else if (status['has_any_submitted'] == true && !status['all_submitted']) {
        if (mounted) {
          setState(() {
            isWaitingForAutoSubmit = true;
          });
        }
      }
    } catch (e) {
      print('Error checking auto-submit status: $e');
    }
  }

  void _startAutoSubmitCheckTimer() {
    autoSubmitCheckTimer?.cancel();
    autoSubmitCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (hasSubmitted || !mounted) {
        timer.cancel();
        return;
      }
      _checkAutoSubmitStatus();
    });
  }

  Future<void> _fetchSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    sessionToken = prefs.getString('token');
    if (sessionToken == null) {
      _redirectToLogin();
      return;
    }
    await _loadQuestions();
  }

  Future<void> _redirectToLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('token');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
      final questionsData = await _contestController.fetchQuestions(widget.matchId);
      
      if (questionsData.isEmpty) {
        setState(() {
          errorMessage = 'No questions available for this contest.';
          isLoading = false;
        });
        return;
      }
      setState(() {
        questions = questionsData;
        isLoading = false;
        totalTimeInSeconds = questions.length * 30;
        remainingTimeInSeconds = totalTimeInSeconds;
      });
      _initializeTimer();
      _startQuestionTimer();
      _startAutoSubmitCheckTimer();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load questions: $e';
        isLoading = false;
      });
    }
  }

  void _initializeTimer() {
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: totalTimeInSeconds),
    );
    _timerController.addListener(() {
      if (_timerController.isAnimating && mounted) {
        setState(() {
          remainingTimeInSeconds = totalTimeInSeconds - (totalTimeInSeconds * _timerController.value).floor();
        });
        if (remainingTimeInSeconds <= 0 && !hasSubmitted) {
          _endTest();
        }
      }
    });
    _timerController.forward();
  }

  void _startQuestionTimer() {
    questionTimer?.cancel();
    questionTimeRemaining = 30;
    isTimerRunning = true;
    questionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          questionTimeRemaining--;
        });
        if (questionTimeRemaining <= 0) {
          timer.cancel();
          _nextQuestion();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      _questionTransitionController.reverse().then((_) {
        setState(() {
          currentQuestionIndex++;
          questionTimeRemaining = 30;
        });
        _startQuestionTimer();
        _questionTransitionController.forward();
      });
    } else {
      _endTest();
    }
  }

  void _selectAnswer(String option) {
    if (hasSubmitted || isSubmitting) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      userAnswers[currentQuestionIndex] = option;
    });
  }

  Future<void> _endTest() async {
    if (hasSubmitted || isSubmitting) return;
    
    setState(() {
      hasSubmitted = true;
      isSubmitting = true;
    });
    
    questionTimer?.cancel();
    autoSubmitCheckTimer?.cancel();
    _timerController.stop();
    
    // Calculate score
    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final userAnswer = userAnswers[i];
      if (userAnswer == question.correctOption) {
        score++;
      }
    }
    
    setState(() {
      userScore = score;
    });

    print('DEBUG: Submitting score - User Score: $score, Total Questions: ${questions.length}');
    print('DEBUG: User Answers: $userAnswers');

    try {
      // Submit score to server
      final result = await _contestController.submitMegaScore(
        widget.contestId,
        score,
        widget.matchId,
      );
      
      print('DEBUG: Score submission result: $result');
      
      if (result['success']) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Score submitted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // Wait a moment to show the success message
        await Future.delayed(Duration(seconds: 1));
        
        // Return to main screen with result data
        if (mounted) {
          Navigator.pop(context, {
            'success': true,
            'hasSubmitted': true,
            'hasViewedResults': false,
            'isWinner': result['is_winner'] ?? false,
            'isTie': result['is_tie'] ?? false,
            'opponentName': result['opponent_name'],
            'opponentScore': result['opponent_score']?.toDouble(),
            'matchCompleted': result['rank'] != null,
            'userScore': score.toDouble(),
            'prizeWon': result['prize_won']?.toDouble(),
          });
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to submit score');
      }
    } catch (e) {
      print('ERROR: Score submission failed: $e');
      setState(() {
        errorMessage = 'Failed to submit score: $e';
        isSubmitting = false;
        hasSubmitted = false;
      });
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Submission Error'),
            content: Text('Failed to submit your score. Please try again.\n\nError: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _endTest();
                },
                child: Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Loading Questions...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (errorMessage.isNotEmpty && !isSubmitting) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.white, size: 64),
                SizedBox(height: 20),
                Text(
                  errorMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              'No questions available',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
    }

    if (isSubmitting) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Submitting your score...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please wait',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                            onPressed: hasSubmitted ? null : () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Exit Quiz?', style: GoogleFonts.poppins()),
                                  content: Text('Are you sure you want to exit? Your progress will be lost.', style: GoogleFonts.poppins()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel', style: GoogleFonts.poppins()),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      },
                                      child: Text('Exit', style: GoogleFonts.poppins(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: 1.0 + (_pulseController.value * 0.03),
                                    child: Text(
                                      widget.contestName,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        if (isTimerRunning)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                _formatTime(remainingTimeInSeconds),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Question info
                    Text(
                      'Question ${currentQuestionIndex + 1}/${questions.length}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Time left: $questionTimeRemaining s',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isWaitingForAutoSubmit) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.5)),
                        ),
                        child: Text(
                          'Waiting for others...',
                          style: GoogleFonts.poppins(
                            color: Colors.orange[200],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Question container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        currentQuestion.questionText,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    // Options
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: ['A', 'B', 'C', 'D'].map((option) {
                            final isSelected = userAnswers[currentQuestionIndex] == option;
                            final displayOption = option == 'A'
                                ? currentQuestion.optionA
                                : option == 'B'
                                    ? currentQuestion.optionB
                                    : option == 'C'
                                        ? currentQuestion.optionC
                                        : currentQuestion.optionD;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.yellow[700] : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? Colors.yellow[900] : Colors.grey[300],
                                    child: Text(
                                      option,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: isSelected ? Colors.black : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    displayOption,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.black,
                                      height: 1.3,
                                    ),
                                  ),
                                  onTap: isSubmitting
                                      ? null
                                      : () => _selectAnswer(option),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Next or Submit button
                    if (currentQuestionIndex < questions.length - 1)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: isSubmitting || userAnswers[currentQuestionIndex] == null
                              ? null
                              : () => _nextQuestion(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Next',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    if (currentQuestionIndex == questions.length - 1)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: isSubmitting || userAnswers[currentQuestionIndex] == null
                              ? null
                              : () => _endTest(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Submit',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}