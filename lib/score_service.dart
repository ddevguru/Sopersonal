
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class ScoreService {
//   Future<Map<String, dynamic>> submitScore(
//     int contestId,
//     int score, {
//     required String matchId,
//     required String sessionToken,
//     required String contestType,
//   }) async {
//     try {
//       final response = await http.post(
//         Uri.parse('https://sopersonal.in/score_manager.php'),
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//         body: {
//           'action': 'submit_score',
//           'session_token': sessionToken,
//           'contest_id': contestId.toString(),
//           'score': score.toString(),
//           'contest_type': contestType,
//           'match_id': matchId,
//         },
//       ).timeout(const Duration(seconds: 10));

//       print('Score Submission Response: Status=${response.statusCode}, Body=${response.body}');

//       if (response.statusCode == 200) {
//         try {
//           final data = jsonDecode(response.body);
//           return data;
//         } catch (e) {
//           print('JSON decode error: $e, Response Body: ${response.body}');
//           return {
//             'success': false,
//             'message': 'Error submitting score: $e',
//           };
//         }
//       } else {
//         return {
//           'success': false,
//           'message': 'Error submitting score: HTTP ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       print('Error submitting score: $e');
//       return {
//         'success': false,
//         'message': 'Error submitting score: $e',
//       };
//     }
//   }
// }



import 'dart:convert';
import 'package:http/http.dart' as http;

class ScoreService {
  Future<Map<String, dynamic>> submitScore(
    int contestId,
    int score, {
    required String matchId,
    required String sessionToken,
    required String contestType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://sopersonal.in/score_manager.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'action': 'submit_score',
          'session_token': sessionToken,
          'contest_id': contestId.toString(),
          'score': score.toString(),
          'contest_type': contestType,
          'match_id': matchId,
        },
      ).timeout(const Duration(seconds: 10));

      print('Score Submission Response: Status=${response.statusCode}, Body=${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return data;
        } catch (e) {
          print('JSON decode error: $e, Response Body: ${response.body}');
          return {
            'success': false,
            'message': 'Error submitting score: $e',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Error submitting score: HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error submitting score: $e');
      return {
        'success': false,
        'message': 'Error submitting score: $e',
      };
    }
  }
}
