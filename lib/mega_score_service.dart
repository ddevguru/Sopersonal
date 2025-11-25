import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MegaScoreService {
  static const String baseUrl = 'https://sopersonal.in';

  Future<Map<String, dynamic>> submitMegaScore(int contestId, int score, String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Session token not found');
    }

    final response = await http.post(
              Uri.parse('$baseUrl/mega_score_manager.php'),
      body: {
        'session_token': token,
        'contest_id': contestId.toString(),
        'score': score.toString(),
        'match_id': matchId,
      },
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        return data;
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Failed to submit mega score: ${response.statusCode}');
    }
  }
}
