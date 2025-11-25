import 'package:http/http.dart' as http;
import 'package:play_smart/Models/contest.dart';
import 'package:play_smart/Models/question.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MegaContestController {
  static const String baseUrl = 'https://sopersonal.in';

  Future<List<Contest>> fetchMegaContests() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      final error = 'No token found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mega/fetch_mega_contest.php?session_token=$token'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return (data['data'] as List).map((e) => Contest.fromJson(e)).toList();
        } else {
          final error = 'Failed to fetch mega contests: ${data['message']}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to fetch mega contests: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error fetching mega contests: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> joinMegaContest(int contestId, double entryFee) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      final error = 'No token found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mega/join_mega_contest.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'contest_id': contestId.toString(),
          'entry_fee': entryFee.toStringAsFixed(2),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final String? matchId = data['match_id']?.toString();
          if (matchId == null || matchId.isEmpty) {
            throw Exception('Match ID not received from server after joining contest.');
          }
          print('Joined mega contest successfully: Contest ID: $contestId, Match ID: $matchId');
          return {
            'success': true,
            'message': data['message'],
            'match_id': matchId,
            'is_bot': data['is_bot'] ?? false,
            'all_players_joined': data['all_players_joined'] ?? false,
          };
        } else {
          final error = 'Failed to join mega contest: ${data['message']}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to join mega contest: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error joining mega contest: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> fetchMegaContestStatus(int contestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mega/get_mega_contest_status.php?session_token=$token&contest_id=$contestId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            final startDateTime = DateTime.tryParse(data['start_datetime'] ?? '') ?? DateTime.now();
            return {
              'is_joinable': data['is_joinable'] ?? false,
              'has_joined': data['has_joined'] ?? false,
              'is_active': data['is_active'] ?? false,
              'has_submitted': data['has_submitted'] ?? false,
              'has_viewed_results': data['has_viewed_results'] ?? false,
              'start_datetime': startDateTime.toIso8601String(),
            };
          } else {
            throw Exception('Failed to fetch contest status: ${data['message']}');
          }
        } catch (e) {
          print('ERROR: Failed to parse JSON response: ${response.body}');
          
          final body = response.body;
          final jsonStart = body.indexOf('{');
          final jsonEnd = body.lastIndexOf('}');
          
          if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
            try {
              final jsonString = body.substring(jsonStart, jsonEnd + 1);
              final data = jsonDecode(jsonString);
              if (data['success']) {
                return data;
              } else {
                throw Exception('Server error: ${data['message']}');
              }
            } catch (jsonError) {
              throw Exception('Invalid JSON response: ${response.body}');
            }
          } else {
            throw Exception('Invalid JSON response: ${response.body}');
          }
        }
      } else {
        print('ERROR: HTTP ${response.statusCode}: ${response.body}');
        throw Exception('Failed to fetch contest status: HTTP ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching contest status: $e');
    }
  }

  Future<Map<String, dynamic>> startMegaContest(int contestId, String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      final error = 'No token found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mega/start_mega_contest.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'contest_id': contestId.toString(),
          'match_id': matchId,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print('Started mega contest successfully: Contest ID: $contestId, Match ID: $matchId');
          return data;
        } else {
          final error = 'Failed to start mega contest: ${data['message']}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to start mega contest: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error starting mega contest: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }

  Future<List<Question>> fetchQuestions(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      final error = 'No token found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mega/fetch_questions.php?session_token=$token&match_id=$matchId'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic> || !(data['success'] ?? false)) {
          final error = 'Invalid response format: ${response.body}';
          print('Error: $error');
          throw Exception(error);
        }

        final questionsData = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (questionsData.isEmpty) {
          final error = 'No questions available for match ID: $matchId';
          print('Error: $error');
          throw Exception(error);
        }

        return questionsData.map((e) {
          try {
            return Question.fromJson(e);
          } catch (parseError) {
            print('Error parsing question: $parseError, Data: $e');
            return Question(
              id: (e['id'] as num?)?.toInt() ?? 0,
              questionText: e['question_text'] as String? ?? 'No question',
              optionA: e['option_a'] as String? ?? 'No option',
              optionB: e['option_b'] as String? ?? 'No option',
              optionC: e['option_c'] as String? ?? 'No option',
              optionD: e['option_d'] as String? ?? 'No option',
              correctOption: e['correct_option'] as String? ?? '',
            );
          }
        }).toList();
      } else {
        final error = 'Failed to fetch questions: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error fetching questions: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> submitMegaScore(int contestId, int score, String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Session token not found');
    }

    print('DEBUG: Submitting score to server - Contest: $contestId, Score: $score, Match: $matchId');

    final response = await http.post(
      Uri.parse('$baseUrl/mega/mega_score_manager.php'),
      body: {
        'session_token': token,
        'contest_id': contestId.toString(),
        'score': score.toString(),
        'match_id': matchId,
      },
    ).timeout(Duration(seconds: 15));

    print('DEBUG: Score submission response - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        // Convert string values to proper types
        final responseData = Map<String, dynamic>.from(data);
        
        // Parse numeric string values
        if (responseData['prize_won'] is String) {
          responseData['prize_won'] = double.tryParse(responseData['prize_won']) ?? 0.0;
        }
        if (responseData['opponent_score'] is String) {
          responseData['opponent_score'] = double.tryParse(responseData['opponent_score']) ?? 0.0;
        }
        
        return responseData;
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Failed to submit mega score: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> viewMegaResults(int contestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      final error = 'No token found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mega/view_mega_results.php?session_token=$token&contest_id=$contestId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print('Fetched mega contest results successfully: Contest ID: $contestId');
          return data;
        } else {
          final error = 'Failed to fetch mega contest results: ${data['message']}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to fetch mega contest results: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error fetching mega contest results: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchContestRankings(int contestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mega/fetch_contest_rankings.php?session_token=$token&contest_id=$contestId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return (data['rankings'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Failed to fetch contest rankings: ${data['message']}');
        }
      } else {
        throw Exception('Failed to fetch contest rankings: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching contest rankings: $e');
    }
  }

  Future<Map<String, dynamic>> checkAutoSubmitStatus(int contestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mega/check_auto_submit_status.php?session_token=$token&contest_id=$contestId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            return data;
          } else {
            throw Exception('Failed to check auto-submit status: ${data['message']}');
          }
        } catch (e) {
          print('ERROR: Failed to parse JSON response: ${response.body}');
          throw Exception('Invalid JSON response: ${response.body}');
        }
      } else {
        print('ERROR: HTTP ${response.statusCode}: ${response.body}');
        throw Exception('Failed to check auto-submit status: HTTP ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking auto-submit status: $e');
    }
  }
}

double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
