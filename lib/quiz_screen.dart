
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:play_smart/controller/mini-contest-controller.dart';
import 'package:play_smart/logger.dart';
import 'package:play_smart/score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:play_smart/Models/question.dart';
import 'package:play_smart/Auth/login_screen.dart';
import 'main_screen.dart';

class QuizScreen extends StatefulWidget {
  final int contestId;
  final String contestName;
  final String contestType;
  final double entryFee;
  final double prizePool;
  final String matchId;
  final bool initialIsBotOpponent;
  final String? initialOpponentName;
  final bool initialAllPlayersJoined;

  const QuizScreen({
    Key? key,
    required this.contestId,
    required this.contestName,
    required this.contestType,
    required this.entryFee,
    required this.prizePool,
    required this.matchId,
    this.initialIsBotOpponent = false,
    this.initialOpponentName,
    this.initialAllPlayersJoined = false,
  }) : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final ContestController _contestController = ContestController();
  List<Question> questions = [];
  Map<int, String> userAnswers = {};
  int currentQuestionIndex = 0;
  int userScore = 0;
  int opponentScore = 0;
  double winningAmount = 0.0;
  bool isLoading = true;
  bool isWaiting = true;
  bool isWaitingForOpponentScore = false;
  bool isTestCompleted = false;
  bool isSubmittingScore = false;
  bool isAiOpponent = false;
  bool isTie = false;
  bool isWinner = false;
  String? opponentName;
  String waitingMessage = 'Finding opponent...';
  String? resultMessage;
  String? resultSubMessage;
  String errorMessage = '';
  int questionTimeRemaining = 30;
  int totalTimeInSeconds = 0;
  int remainingTimeInSeconds = 0;
  int waitTimeRemaining = 30;
  bool isTimerRunning = false;
  Timer? matchStatusTimer;
  Timer? questionTimer;
  Timer? scoreStatusTimer;
  Timer? inGameStatusTimer;
  String? matchId;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _timerController;
  late AnimationController _questionTransitionController;
  late AnimationController _confettiController;
  late AnimationController _waitingTimerController; // New controller for circular timer
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _waitingTimerAnimation; // Animation for circular timer

  final List<String> randomNames = [
    'Alex', 'Sam', 'Jordan', 'Casey', 'Taylor', 'Morgan', 'Riley', 'Avery',
    'Quinn', 'Blake', 'Sage', 'River', 'Skylar', 'Phoenix', 'Rowan', 'Cameron',
    'Drew', 'Emery', 'Finley', 'Harper', 'Hayden', 'Jamie', 'Kendall', 'Logan'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    matchId = widget.matchId;
    isAiOpponent = widget.initialIsBotOpponent;
    opponentName = widget.initialOpponentName ?? randomNames[Random().nextInt(randomNames.length)];
    isWaiting = !widget.initialAllPlayersJoined;
    print('QuizScreen initialized: matchId=$matchId, allPlayersJoined=${widget.initialAllPlayersJoined}, isAiOpponent=$isAiOpponent, opponentName=$opponentName');

    if (widget.initialAllPlayersJoined) {
      print('All players joined, starting quiz immediately');
      _fetchQuestions();
    } else {
      print('Not all players joined, starting match status polling');
      _startMatchStatusPolling();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _timerController = AnimationController(vsync: this, duration: Duration(seconds: totalTimeInSeconds));
    _questionTransitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _waitingTimerController = AnimationController(vsync: this, duration: const Duration(seconds: 30)); // Initialize circular timer

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );
    _waitingTimerAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _waitingTimerController, curve: Curves.linear),
    ); // Animation for circular timer

    _timerController.addListener(() {
      if (_timerController.isAnimating && mounted) {
        setState(() {
          remainingTimeInSeconds = totalTimeInSeconds - (totalTimeInSeconds * _timerController.value).floor();
        });
        if (remainingTimeInSeconds <= 0 && !isTestCompleted) {
          _endTest();
        }
      }
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    matchStatusTimer?.cancel();
    questionTimer?.cancel();
    scoreStatusTimer?.cancel();
    inGameStatusTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    _timerController.dispose();
    _questionTransitionController.dispose();
    _confettiController.dispose();
    _waitingTimerController.dispose(); // Dispose circular timer controller
    super.dispose();
  }

  Future<void> _startMatchStatusPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() {
        errorMessage = 'Session expired. Please log in again.';
        isWaiting = false;
        isLoading = false;
      });
      _handleTokenError();
      return;
    }

    setState(() {
      isWaiting = true;
      isLoading = false;
      waitTimeRemaining = 30;
      waitingMessage = 'Finding opponent... ($waitTimeRemaining seconds)';
    });

    print('Starting match status polling for matchId: $matchId - 30 SECOND REAL PLAYER SEARCH');
    _waitingTimerController.forward(from: 0.0); // Start circular timer
    matchStatusTimer?.cancel();
    matchStatusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted) {
        timer.cancel();
        _waitingTimerController.stop();
        return;
      }

      if (timer.tick % 2 == 0) {
        setState(() {
          if (waitTimeRemaining > 0) {
            waitTimeRemaining = math.max(0, waitTimeRemaining - 1);
            waitingMessage = 'Finding opponent... ($waitTimeRemaining seconds)';
          }
        });
      }

      try {
        print('Polling match status for matchId: $matchId, waitTime: $waitTimeRemaining, tick: ${timer.tick}');
        final response = await http.post(
          Uri.parse('https://sopersonal.in/check_match_status.php'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'session_token': token,
            'match_id': matchId!,
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Match status response: $data');
          if (data['success']) {
            final bool matchReady = data['match_ready'] == true;
            final bool isBot = data['is_bot'] == true;
            final bool waitingForOpponent = data['waiting_for_opponent'] == true;
            final String? fetchedOpponentName = data['opponent_name'];

            if (!waitingForOpponent && !isBot && fetchedOpponentName != null && fetchedOpponentName.isNotEmpty) {
              timer.cancel();
              _waitingTimerController.stop();
              setState(() {
                isAiOpponent = false;
                opponentName = fetchedOpponentName;
                isWaiting = false;
                waitingMessage = 'Matched with player: $opponentName!';
              });
              print('🎉 REAL PLAYER MATCH FOUND! Opponent: $opponentName');
              await Logger.logToFile('REAL PLAYER MATCH: Opponent=$opponentName');
              await _fetchQuestions();
              return;
            } else if (waitingForOpponent) {
              // Continue waiting
            }

            if (waitTimeRemaining <= 0 && isWaiting) {
              timer.cancel();
              _waitingTimerController.stop();
              setState(() {
                isWaiting = false;
                isAiOpponent = true;
                opponentName = randomNames[Random().nextInt(randomNames.length)];
                waitingMessage = 'Matching with AI: $opponentName...';
              });
              print('⏰ CLIENT TIMEOUT - Converting to AI opponent: $opponentName');
              await Logger.logToFile('CLIENT TIMEOUT - Converting to AI opponent: $opponentName');

              try {
                final botResult = await _contestController.convertToBotMatch(matchId!, opponentName!);
                if (botResult['success']) {
                  setState(() {
                    isAiOpponent = botResult['is_bot'] ?? true;
                    opponentName = botResult['opponent_name'] ?? opponentName;
                    waitingMessage = 'Matched with AI: $opponentName!';
                  });
                  print('Successfully converted to bot match: $opponentName');
                  await _fetchQuestions();
                } else {
                  setState(() {
                    errorMessage = botResult['message'] ?? 'Failed to match with AI opponent';
                    isLoading = false;
                    isWaiting = false;
                  });
                }
              } catch (e) {
                setState(() {
                  errorMessage = 'Error matching with AI: $e';
                  isLoading = false;
                  isWaiting = false;
                });
                print('Error converting to bot match: $e');
                await Logger.logToFile('Error converting to bot match: $e');
              }
            }
          } else {
            print('Server error in _startMatchStatusPolling: ${data['message']}');
            await Logger.logToFile('Server error in _startMatchStatusPolling: ${data['message']}');
            if (data['message'] == 'Invalid token') {
              timer.cancel();
              _waitingTimerController.stop();
              _handleTokenError();
              return;
            }
            setState(() {
              errorMessage = data['message'] ?? 'An unknown error occurred.';
              isLoading = false;
              isWaiting = false;
            });
            timer.cancel();
            _waitingTimerController.stop();
          }
        } else {
          print('HTTP error in _startMatchStatusPolling: ${response.statusCode}, Body: ${response.body}');
          await Logger.logToFile('HTTP error in _startMatchStatusPolling: ${response.statusCode}, Body: ${response.body}');
          setState(() {
            errorMessage = 'Network error: ${response.statusCode}';
            isLoading = false;
            isWaiting = false;
          });
          timer.cancel();
          _waitingTimerController.stop();
        }
      } catch (e) {
        print('Polling error in _startMatchStatusPolling: $e');
        await Logger.logToFile('Polling error in _startMatchStatusPolling: $e');
        setState(() {
          errorMessage = 'Connection error: $e';
          isLoading = false;
          isWaiting = false;
        });
        timer.cancel();
        _waitingTimerController.stop();
      }
    });
  }

  Future<void> _startScoreStatusPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      print('Token not found during score status polling');
      _handleTokenError();
      return;
    }

    print('Starting score status polling for matchId: $matchId');
    scoreStatusTimer?.cancel();
    scoreStatusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted || isTestCompleted) {
        timer.cancel();
        return;
      }
      try {
        final response = await http.post(
          Uri.parse('https://sopersonal.in/check_score_status.php'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'session_token': token,
            'match_id': matchId!,
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Score status response: $data');
          if (data['success']) {
            final bool matchCompleted = data['match_completed'] == true;
            final bool isBot = data['is_bot'] == true;
            final bool isTie = data['is_tie'] == true;
            final bool isWinner = data['is_winner'] == true;

            if (matchCompleted) {
              timer.cancel();
              setState(() {
                isLoading = false;
                isSubmittingScore = false;
                isTestCompleted = true;
                isWaitingForOpponentScore = false;
                opponentScore = int.tryParse(data['opponent_score'].toString()) ?? 0;
                this.isAiOpponent = isBot;
                this.opponentName = data['opponent_name'] ?? opponentName;
                this.isTie = isTie;
                this.isWinner = isWinner;
                winningAmount = double.tryParse(data['winning_amount'].toString()) ?? 0.0;
                errorMessage = '';
                resultMessage = this.isTie
                    ? "It's a Tie!"
                    : this.isWinner
                        ? "Congratulations!"
                        : "Better Luck Next Time!";
                resultSubMessage = this.isTie
                    ? "Both players scored equally! Entry fee returned."
                    : this.isWinner
                        ? "You won the match against ${this.opponentName}!"
                        : "You lost the match against ${this.opponentName}!";
                if (this.isWinner) {
                  _confettiController.forward();
                }
              });
              await _fetchBalance(token);
              await Logger.logToFile(
                  'Match completed via polling - User: $userScore, Opponent: $opponentScore (${this.opponentName}), IsAI: ${this.isAiOpponent}, WinningAmount: $winningAmount');
            }
            if (data['user_score'] != null && data['user_score'] != userScore) {
              setState(() {
                userScore = int.tryParse(data['user_score'].toString()) ?? userScore;
              });
            }
          } else {
            print('Server error in _startScoreStatusPolling: ${data['message']}');
            await Logger.logToFile('Server error in _startScoreStatusPolling: ${data['message']}');
            if (data['message'] == 'Invalid token') {
              _handleTokenError();
            } else {
              setState(() {
                errorMessage = data['message'] ?? 'An unknown error occurred.';
                isWaitingForOpponentScore = false;
                isTestCompleted = true;
              });
            }
          }
        } else {
          print('HTTP error in _startScoreStatusPolling: ${response.statusCode}, Body: ${response.body}');
          await Logger.logToFile('HTTP error in _startScoreStatusPolling: ${response.statusCode}, Body: ${response.body}');
          setState(() {
            errorMessage = 'Network error: ${response.statusCode}';
            isWaitingForOpponentScore = false;
            isTestCompleted = true;
          });
        }
      } catch (e) {
        print('Score polling error: $e');
        await Logger.logToFile('Score polling error: $e');
        setState(() {
          errorMessage = 'Connection error: $e';
          isWaitingForOpponentScore = false;
          isTestCompleted = true;
        });
      }
    });
  }

  Future<void> _startInGameMatchStatusPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _handleTokenError();
      return;
    }

    print('Starting in-game match status polling for matchId: $matchId');
    inGameStatusTimer?.cancel();
    inGameStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || isTestCompleted || isSubmittingScore || isWaitingForOpponentScore) {
        timer.cancel();
        return;
      }
      try {
        final response = await http.post(
          Uri.parse('https://sopersonal.in/check_in_game_match_status.php'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'session_token': token,
            'match_id': matchId!,
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('In-game match status response: $data');
          if (data['success'] && data['match_completed'] == true) {
            timer.cancel();
            questionTimer?.cancel();
            _timerController.stop();
            setState(() {
              isLoading = false;
              isSubmittingScore = false;
              isTestCompleted = true;
              isWaitingForOpponentScore = false;
              userScore = int.tryParse(data['user_score'].toString()) ?? userScore;
              opponentScore = int.tryParse(data['opponent_score'].toString()) ?? 0;
              isAiOpponent = data['is_bot'] == true;
              opponentName = data['opponent_name'] ?? opponentName;
              isTie = data['is_tie'] == true;
              isWinner = data['is_winner'] == true;
              winningAmount = double.tryParse(data['winning_amount'].toString()) ?? 0.0;
              errorMessage = '';
              resultMessage = isTie
                  ? "It's a Tie!"
                  : isWinner
                      ? "Congratulations!"
                      : "Better Luck Next Time!";
              resultSubMessage = isTie
                  ? "Both players scored equally! Entry fee returned."
                  : isWinner
                      ? "You won the match against ${opponentName}!"
                      : "You lost the match against ${opponentName}!";
              if (isWinner) {
                _confettiController.forward();
              }
            });
            await _fetchBalance(token);
            await Logger.logToFile(
                'Match completed via in-game polling - User: $userScore, Opponent: $opponentScore ($opponentName), IsAI: $isAiOpponent, WinningAmount: $winningAmount');
          } else if (!data['success'] && data['message'] == 'Invalid token') {
            timer.cancel();
            _handleTokenError();
          }
        } else {
          print('HTTP error in _startInGameMatchStatusPolling: ${response.statusCode}, Body: ${response.body}');
          await Logger.logToFile('HTTP error in _startInGameMatchStatusPolling: ${response.statusCode}, Body: ${response.body}');
        }
      } catch (e) {
        print('In-game polling error: $e');
        await Logger.logToFile('In-game polling error: $e');
      }
    });
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      isWaiting = false;
    });
    try {
      print('Fetching questions for matchId: $matchId');
      final fetchedQuestions = await _contestController.fetchQuestions(matchId!);
      setState(() {
        questions = fetchedQuestions.map((q) => Question(
              id: q.id,
              questionText: q.questionText,
              optionA: q.optionA,
              optionB: q.optionB,
              optionC: q.optionC,
              optionD: q.optionD,
              correctOption: q.correctOption,
            )).toList();
        questions.shuffle(Random());
        if (questions.isEmpty) {
          errorMessage = 'No questions available in the database';
          isLoading = false;
          return;
        }
        totalTimeInSeconds = questions.length * 30;
        remainingTimeInSeconds = totalTimeInSeconds;
        currentQuestionIndex = 0;
        userScore = 0;
        userAnswers = {};
        isLoading = false;
        isTimerRunning = true;
      });
      print('Questions loaded: ${questions.length} questions, opponent: $opponentName');
      _startQuestionTimer();
      _timerController.duration = Duration(seconds: totalTimeInSeconds);
      _timerController.forward(from: 0.0);
      _questionTransitionController.forward();
      _startInGameMatchStatusPolling();
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching questions: $e';
        isLoading = false;
      });
      print('Error fetching questions: $e');
      await Logger.logToFile('Error fetching questions: $e');
    }
  }

  void _startQuestionTimer() {
    questionTimer?.cancel();
    questionTimeRemaining = 30;
    setState(() {});
    questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (remainingTimeInSeconds <= 0) {
        timer.cancel();
        _endTest();
        return;
      }
      setState(() {
        questionTimeRemaining--;
        remainingTimeInSeconds--;
      });
      if (questionTimeRemaining <= 0) {
        timer.cancel();
        _goToNextQuestion();
      }
    });
  }

  Future<void> _fetchBalance(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://sopersonal.in/fetch_user_balance.php?session_token=$token'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('wallet_balance', double.tryParse(data['data']['wallet_balance'].toString()) ?? 0.0);
        } else {
          print('Server error fetching balance: ${data['message']}');
          await Logger.logToFile('Server error fetching balance: ${data['message']}');
          if (data['message'] == 'Invalid token') {
            _handleTokenError();
          }
        }
      }
    } catch (e) {
      print('Error fetching balance: $e');
      await Logger.logToFile('Error fetching balance: $e');
    }
  }

  Future<void> calculateScore() async {
    setState(() {
      isSubmittingScore = true;
      isLoading = true;
      isWaitingForOpponentScore = false;
      errorMessage = '';
    });
    questionTimer?.cancel();
    inGameStatusTimer?.cancel();
    _timerController.stop();
    isTimerRunning = false;
    questionTimeRemaining = 0;

    int tempScore = 0;
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final userAnswer = userAnswers[i];
      if (userAnswer != null && question.correctOption.isNotEmpty && userAnswer == question.correctOption) {
        tempScore += 1;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: Token not found';
          isSubmittingScore = false;
          isTestCompleted = true;
          isWaitingForOpponentScore = false;
        });
        print('Token not found during score calculation');
        await Logger.logToFile('Token not found during score calculation');
        _handleTokenError();
        return;
      }

      setState(() {
        userScore = tempScore;
      });

      final scoreService = ScoreService();
      final result = await scoreService.submitScore(
        widget.contestId,
        tempScore,
        contestType: widget.contestType,
        matchId: widget.matchId,
        sessionToken: token,
      );

      print('Score Submission Result: $result');
      await Logger.logToFile('Score Submission Result: $result, isAiOpponent: $isAiOpponent, userScore: $tempScore');

      if (result['success'] == true) {
        final bool matchCompleted = result['match_completed'] == true;
        final bool isBot = result['is_bot'] == true;
        final bool isTie = result['is_tie'] == true;
        final bool isWinner = result['is_winner'] == true;

        if (matchCompleted) {
          setState(() {
            isLoading = false;
            isSubmittingScore = false;
            isTestCompleted = true;
            isWaitingForOpponentScore = false;
            opponentScore = int.tryParse(result['opponent_score'].toString()) ?? 0;
            this.isAiOpponent = isBot;
            this.opponentName = result['opponent_name'] ?? opponentName ?? '';
            this.isTie = isTie;
            this.isWinner = isWinner;
            winningAmount = double.tryParse(result['winning_amount'].toString()) ?? 0.0;
            errorMessage = '';
            resultMessage = this.isTie
                ? "It's a Tie!"
                : this.isWinner
                    ? "Congratulations!"
                    : "Better Luck Next Time!";
            resultSubMessage = this.isTie
                ? "Both players scored equally! Entry fee returned."
                : this.isWinner
                    ? "You won the match against ${this.opponentName}!"
                    : "You lost the match against ${this.opponentName}!";
            if (this.isWinner) {
              _confettiController.forward();
            }
          });
          await _fetchBalance(token);
          await Logger.logToFile(
              'Match completed immediately (from score_manager) - User: $userScore, Opponent: $opponentScore (${this.opponentName}), IsAI: ${this.isAiOpponent}, WinningAmount: $winningAmount');
        } else {
          setState(() {
            isLoading = false;
            isSubmittingScore = false;
            isTestCompleted = false;
            isWaitingForOpponentScore = true;
            errorMessage = '';
          });
          _startScoreStatusPolling();
        }
      } else {
        setState(() {
          isLoading = false;
          isSubmittingScore = false;
          isWaitingForOpponentScore = false;
          errorMessage = result['message'] ?? 'Failed to submit score';
          isTestCompleted = true;
        });
        print('Score submission failed: ${result['message']}');
        await Logger.logToFile('Score submission failed: ${result['message']}');
        if (result['message'] == 'Invalid token') {
          _handleTokenError();
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isSubmittingScore = false;
        isWaitingForOpponentScore = false;
        errorMessage = 'Error submitting score: $e';
        isTestCompleted = true;
      });
      print('Error submitting score: $e');
      await Logger.logToFile('Error submitting score: $e');
    }
  }

  void _goToNextQuestion() {
    if (remainingTimeInSeconds <= 0) {
      questionTimer?.cancel();
      calculateScore();
      return;
    }
    questionTimer?.cancel();
    if (currentQuestionIndex < questions.length - 1) {
      _questionTransitionController.reverse().then((_) {
        setState(() {
          currentQuestionIndex++;
        });
        _startQuestionTimer();
        _questionTransitionController.forward();
      });
    } else {
      _showSubmitButton();
    }
  }

  void _endTest() {
    _timerController.stop();
    isTimerRunning = false;
    questionTimer?.cancel();
    inGameStatusTimer?.cancel();
    calculateScore();
  }

  void _showSubmitButton() async {
    setState(() {
      isSubmittingScore = true;
    });
    await calculateScore();
  }


  // Future<void> _abandonMatchAndNavigate() async {
  //   matchStatusTimer?.cancel();
  //   questionTimer?.cancel();
  //   scoreStatusTimer?.cancel();
  //   inGameStatusTimer?.cancel();
  //   setState(() {
  //     isLoading = true;
  //     errorMessage = '';
  //   });

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     String? token = prefs.getString('token');
  //     if (token == null) {
  //       _handleTokenError();
  //       return;
  //     }

  //     print('Attempting to abandon match $matchId for user $token with score $userScore');
  //     final response = await http.post(
  //       Uri.parse('https://sopersonal.in/score_manager.php'),
  //       headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  //       body: {
  //         'action': 'abandon_match',
  //         'session_token': token,
  //         'contest_id': widget.contestId.toString(),
  //         'match_id': matchId!,
  //         'score': userScore.toString(),
  //         'contest_type': widget.contestType,
  //       },
  //     ).timeout(const Duration(seconds: 10));

  //     final data = jsonDecode(response.body);
  //     print('Abandon match response: $data');
  //     await Logger.logToFile('Abandon match response: $data');

  //     if (data['success']) {
  //       print('Successfully abandoned match. Navigating to MainScreen.');
  //     } else {
  //       print('Failed to abandon match: ${data['message']}');
  //       _showCustomSnackBar(data['message'] ?? 'Failed to abandon match.', isError: true);
  //     }
  //   } catch (e) {
  //     print('Error abandoning match: $e');
  //     await Logger.logToFile('Error abandoning match: $e');
  //     _showCustomSnackBar('Error abandoning match: $e', isError: true);
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => MainScreen()),
  //       );
  //     }
  //   }
  // }




  Future<void> _abandonMatchAndNavigate() async {
  matchStatusTimer?.cancel();
  questionTimer?.cancel();
  scoreStatusTimer?.cancel();
  inGameStatusTimer?.cancel();
  _waitingTimerController.stop();
  
  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) {
      _handleTokenError();
      return;
    }

    print('Attempting to abandon match $matchId for user $token with score $userScore');
    final response = await http.post(
      Uri.parse('https://sopersonal.in/score_manager.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'action': 'abandon_match',
        'session_token': token,
        'contest_id': widget.contestId.toString(),
        'match_id': matchId!,
        'score': userScore.toString(),
        'contest_type': widget.contestType,
      },
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    print('Abandon match response: $data');
    await Logger.logToFile('Abandon match response: $data');

    if (data['success']) {
      print('Successfully abandoned match. Navigating to MainScreen.');
    } else {
      print('Failed to abandon match: ${data['message']}');
      _showCustomSnackBar(data['message'] ?? 'Failed to abandon match.', isError: true);
    }
  } catch (e) {
    print('Error abandoning match: $e');
    await Logger.logToFile('Error abandoning match: $e');
    _showCustomSnackBar('Error abandoning match: $e', isError: true);
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    }
  }
}

// Add this new method specifically for abandoning during waiting period
Future<void> _abandonWaitingMatch() async {
  matchStatusTimer?.cancel();
  _waitingTimerController.stop();
  
  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  try {
    print('Attempting to abandon waiting match $matchId');
    
    // Use the new abandon method from ContestController for waiting period
    final result = await _contestController.abandonMatch(matchId!);
    
    if (result['success']) {
      print('Successfully abandoned waiting match. ${result['message']}');
      
      // Show success message if entry fee was refunded
      if (result['refunded_amount'] != null && result['refunded_amount'] > 0) {
        _showCustomSnackBar(
          'Match cancelled. Entry fee ₹${result['refunded_amount']} refunded.',
          isError: false
        );
      } else {
        _showCustomSnackBar(result['message'] ?? 'Match cancelled successfully.', isError: false);
      }
    } else {
      print('Failed to abandon waiting match: ${result['message']}');
      _showCustomSnackBar(result['message'] ?? 'Failed to cancel match.', isError: true);
    }
  } catch (e) {
    print('Error abandoning waiting match: $e');
    _showCustomSnackBar('Error cancelling match: $e', isError: true);
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
      
      // Wait a moment for the snackbar to show, then navigate
      await Future.delayed(const Duration(seconds: 1));
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    }
  }
}

// Update the WillPopScope onWillPop method to use appropriate abandon method
Future<bool> _onWillPop() async {
  // If user is in waiting period
  if (isWaiting) {
    final exit = await _showExitDialog(context);
    if (exit == true) {
      await _abandonWaitingMatch(); // Use waiting-specific abandon method
    }
    return false;
  }
  
  // If user is in active game with answers
  if (!isTestCompleted && userAnswers.isNotEmpty) {
    final exit = await _showExitDialog(context);
    if (exit == true) {
      await _abandonMatchAndNavigate(); // Use existing method for active games
    }
    return false;
  }
  
  // Normal exit - just cleanup and navigate
  matchStatusTimer?.cancel();
  questionTimer?.cancel();
  scoreStatusTimer?.cancel();
  inGameStatusTimer?.cancel();
  _waitingTimerController.stop();
  
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => MainScreen()),
  );
  return false;
}

  void _handleTokenError() {
    matchStatusTimer?.cancel();
    questionTimer?.cancel();
    scoreStatusTimer?.cancel();
    inGameStatusTimer?.cancel();
    _waitingTimerController.stop(); // Stop circular timer
    setState(() {
      errorMessage = 'Session expired. Please log in again.';
      isWaiting = false;
      isLoading = false;
      isTestCompleted = true;
      isWaitingForOpponentScore = false;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
      }
    });
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red[700] : Colors.green[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  Future<void> _checkAndCleanStaleMatch() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || matchId == null) return;

  try {
    print('Checking if match $matchId is stale...');

    final response = await http.post(
      Uri.parse('https://sopersonal.in/check_match_validity.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'session_token': token,
        'match_id': matchId!,
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Match validity response: $data');

      if (data['success'] == false && data['message'] == 'Match not found') {
        // Match was cleaned up, show message and allow rejoin
        setState(() {
          isWaiting = false;
          isLoading = false;
          errorMessage = '';
        });

        _showMatchCleanedDialog();
      }
    }
  } catch (e) {
    print('Error checking match validity: $e');
  }
}

void _showMatchCleanedDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 10),
          Text('Match Timeout', style: GoogleFonts.poppins(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your waiting match has been automatically cancelled due to timeout.',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your entry fee has been refunded to your wallet.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
            );
          },
          child: Text('Back to Contests', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            _rejoinContest(); // Try to join again
          },
          child: Text('Join Again', style: GoogleFonts.poppins()),
        ),
      ],
    ),
  );
}

Future<void> _rejoinContest() async {
  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  try {
    final result = await _contestController.joinContest(
      widget.contestId,
      widget.entryFee.toDouble(),
      widget.contestType,
    );

    if (result['success']) {
      setState(() {
        matchId = result['match_id'];
        isAiOpponent = result['is_bot'] ?? false;
        opponentName = result['opponent_name'] ?? '';
        isWaiting = !result['all_players_joined'];
        isLoading = false;
      });

      if (result['all_players_joined']) {
        _fetchQuestions();
      } else {
        _startMatchStatusPolling();
      }
    }
  } catch (e) {
    setState(() {
      isLoading = false;
      errorMessage = 'Failed to rejoin contest: $e';
    });
  }
}

  Future<bool?> _showExitDialog(BuildContext context) {
  String message;
  if (isWaiting) {
    message = 'Are you sure you want to cancel? Your entry fee will be refunded.';
  } else {
    message = 'Are you sure you want to exit? Your progress will be lost and you will forfeit the match.';
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isWaiting ? 'Cancel Match?' : 'Exit Quiz?', style: GoogleFonts.poppins()),
      content: Text(message, style: GoogleFonts.poppins()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Stay', style: GoogleFonts.poppins()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(isWaiting ? 'Cancel' : 'Exit', style: GoogleFonts.poppins(color: Colors.red)),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!isTestCompleted && userAnswers.isNotEmpty) {
          final exit = await _showExitDialog(context);
          if (exit == true) {
            await _abandonMatchAndNavigate();
          }
          return false;
        }
        matchStatusTimer?.cancel();
        questionTimer?.cancel();
        scoreStatusTimer?.cancel();
        inGameStatusTimer?.cancel();
        _waitingTimerController.stop(); // Stop circular timer
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildMainContent()),
                  ],
                ),
              ),
            ),
            if (isTestCompleted && !isTie && isWinner) _buildConfetti(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
         FadeTransition(
        opacity: _fadeAnimation,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () async {
            HapticFeedback.lightImpact();
            
            // If in waiting period
            if (isWaiting) {
              final exit = await _showExitDialog(context);
              if (exit == true) {
                await _abandonWaitingMatch();
              }
            }
            // If in active game
            else if (!isTestCompleted && userAnswers.isNotEmpty) {
              final exit = await _showExitDialog(context);
              if (exit == true) {
                await _abandonMatchAndNavigate();
              }
            } 
            // Normal navigation
            else {
              matchStatusTimer?.cancel();
              questionTimer?.cancel();
              scoreStatusTimer?.cancel();
              inGameStatusTimer?.cancel();
              _waitingTimerController.stop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainScreen()),
              );
            }
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
                '${(remainingTimeInSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingTimeInSeconds % 60).toString().padLeft(2, '0')}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    print('MainContent: isTestCompleted=$isTestCompleted, isLoading=$isLoading, errorMessage=$errorMessage, isWaiting=$isWaiting, isWaitingForOpponentScore=$isWaitingForOpponentScore');
    if (isTestCompleted) {
      return _buildResultScreen();
    } else if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (errorMessage.isNotEmpty) {
      return Center(
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
              errorMessage,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainScreen()),
              ),
              child: Text('Back to Main', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    } else if (isWaiting) {
      return _buildWaitingScreen();
    } else if (isWaitingForOpponentScore) {
      return _buildPostSubmissionWaitingScreen();
    } else if (questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No valid questions available',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainScreen()),
              ),
              child: Text('Back to Main', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    } else {
      return _buildQuestionScreen();
    }
  }




  

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular countdown timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: AnimatedBuilder(
                  animation: _waitingTimerAnimation,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _waitingTimerAnimation.value, // Animates from 1.0 to 0.0
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                    );
                  },
                ),
              ),
              Text(
                '$waitTimeRemaining',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            waitingMessage,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              '🔍 Searching for players...',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (waitTimeRemaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Text(
                ' match after $waitTimeRemaining seconds',
                style: GoogleFonts.poppins(
                  color: Colors.orange[200],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }




  Widget _buildPostSubmissionWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 6,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green[300],
                  size: 48,
                ),
                const SizedBox(height: 15),
                Text(
                  'Score Submitted Successfully!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your score: $userScore/${questions.length}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⏳ Waiting for results...',
                    style: GoogleFonts.poppins(
                      color: Colors.blue[200],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final question = questions[currentQuestionIndex];
    final selectedAnswer = userAnswers[currentQuestionIndex];
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (opponentName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.yellowAccent, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      color: Colors.yellowAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'VS $opponentName',
                      style: GoogleFonts.poppins(
                        color: Colors.yellowAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                question.questionText,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: ['A', 'B', 'C', 'D'].map((option) {
                    final isSelected = userAnswers[currentQuestionIndex] == option;
                    final displayOption = option == 'A'
                        ? question.optionA
                        : option == 'B'
                            ? question.optionB
                            : option == 'C'
                                ? question.optionC
                                : question.optionD;
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
                          onTap: isSubmittingScore
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    userAnswers[currentQuestionIndex] = option;
                                  });
                                },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (currentQuestionIndex < questions.length - 1)
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: isSubmittingScore || userAnswers[currentQuestionIndex] == null
                      ? null
                      : () => _goToNextQuestion(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Next', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            if (currentQuestionIndex == questions.length - 1)
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: isSubmittingScore || userAnswers[currentQuestionIndex] == null
                      ? null
                      : () => _showSubmitButton(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Submit', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6A5ACD),
            const Color(0xFF483D8B),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTie
                          ? Colors.orange.withOpacity(0.2)
                          : isWinner
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                    ),
                    child: Icon(
                      isTie
                          ? Icons.handshake
                          : isWinner
                              ? Icons.emoji_events
                              : Icons.sentiment_dissatisfied,
                      size: 60,
                      color: isTie
                          ? Colors.orange
                          : isWinner
                              ? Colors.amber
                              : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    resultMessage ?? (isWinner ? "Congratulations!" : isTie ? "It's a Tie!" : "Better Luck Next Time!"),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    resultSubMessage ?? (isWinner ? "You won the match against $opponentName!" : isTie ? "Both players scored equally! Entry fee returned." : "You lost the match against $opponentName!"),
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isWinner
                    ? Colors.green.withOpacity(0.1)
                    : isTie
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isWinner
                      ? Colors.green.withOpacity(0.3)
                      : isTie
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Match Results',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your Score: $userScore/${questions.length}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Opponent: $opponentName - $opponentScore/${questions.length}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              'Prize Won: ₹${winningAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(Icons.analytics, color: Colors.blue, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              'Accuracy: ${((userScore / questions.length) * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen()),
                  );
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
      ),
    );
  }

  Widget _buildConfetti() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          return CustomPaint(
            painter: ConfettiPainter(_confettiController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double animationValue;
  ConfettiPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue == 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = (random.nextDouble() * size.height * 2) - (size.height * (1 - animationValue));
      paint.color = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
      ][i % 6];
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}