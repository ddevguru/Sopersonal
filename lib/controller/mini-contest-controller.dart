
import 'package:http/http.dart' as http;
import 'package:play_smart/Models/contest.dart';
import 'package:play_smart/Models/question.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ContestController {
  static const String baseUrl = 'https://sopersonal.in';

  Future<List<Contest>> fetchContests() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    final error = 'No token found';
    print('Error: $error');
    throw Exception(error);
  }

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/fetch_contests.php?session_token=$token'),
    ).timeout(const Duration(seconds: 10));

    print('DEBUG: fetchContests Response - Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        return (data['data'] as List).map((e) => Contest.fromJson(e)).toList();
      } else {
        final error = 'Failed to fetch contests: ${data['message']}';
        print('Error: $error');
        throw Exception(error);
      }
    } else {
      final error = 'Failed to fetch contests: HTTP ${response.statusCode}, Body: ${response.body}';
      print('Error: $error');
      throw Exception(error);
    }
  } catch (e) {
    final error = 'Error fetching contests: $e';
    print('Error: $error');
    throw Exception(error);
  }
}




  Future<Map<String, dynamic>> joinContest(int contestId, double entryFee, String contestType) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      final error = 'No token found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      print('Attempting to join contest $contestId with entry fee $entryFee');
      
      final response = await http.post(
        Uri.parse('$baseUrl/join_contest.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'contest_id': contestId.toString(),
          'entry_fee': entryFee.toStringAsFixed(2),
          'contest_type': contestType,
        },
      ).timeout(const Duration(seconds: 15));

      print('Join contest response: Status=${response.statusCode}, Body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print('Joined contest successfully: Contest ID: $contestId, Match ID: ${data['match_id']}');
          return data;
        } else {
          final error = 'Failed to join contest: ${data['message']}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to join contest: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error joining contest: $e';
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
        Uri.parse('$baseUrl/fetch_questions.php?session_token=$token&match_id=$matchId'),
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

  Future<Map<String, dynamic>> convertToBotMatch(String matchId, String botName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      final error = 'Session token not found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/convert_to_bot_match.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'match_id': matchId,
          'bot_name': botName,
        },
      ).timeout(const Duration(seconds: 10));

      print('convertToBotMatch Response: Status=${response.statusCode}, Body=${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            print('Successfully converted match $matchId to bot match with bot_name: $botName');
            return {
              'success': true,
              'message': data['message'] ?? 'Match converted to bot match',
              'is_bot': true,
              'opponent_name': botName,
            };
          } else {
            final error = 'Failed to convert to bot match: ${data['message'] ?? 'Unknown error'}';
            print('Error: $error');
            throw Exception(error);
          }
        } catch (e) {
          final error = 'JSON decode error: $e, Response Body: ${response.body}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to convert to bot match: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error converting to bot match: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }

  // Method to abandon waiting matches
  Future<Map<String, dynamic>> abandonMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      final error = 'Session token not found';
      print('Error: $error');
      throw Exception(error);
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/abandon_match.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'match_id': matchId,
        },
      ).timeout(const Duration(seconds: 10));

      print('abandonMatch Response: Status=${response.statusCode}, Body=${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            print('Successfully abandoned match $matchId');
            return {
              'success': true,
              'message': data['message'] ?? 'Match abandoned successfully',
              'refunded_amount': data['refunded_amount'] ?? 0,
            };
          } else {
            final error = 'Failed to abandon match: ${data['message'] ?? 'Unknown error'}';
            print('Error: $error');
            throw Exception(error);
          }
        } catch (e) {
          final error = 'JSON decode error: $e, Response Body: ${response.body}';
          print('Error: $error');
          throw Exception(error);
        }
      } else {
        final error = 'Failed to abandon match: HTTP ${response.statusCode}, Body: ${response.body}';
        print('Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      final error = 'Error abandoning match: $e';
      print('Error: $error');
      throw Exception(error);
    }
  }
}
