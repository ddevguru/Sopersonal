// import 'package:json_annotation/json_annotation.dart';

// part 'contest.g.dart';

// @JsonSerializable()
// class Contest {
//   @JsonKey(name: 'id', includeIfNull: false)
//   final int id;
//   final String name;
//   final String type;
//   @JsonKey(name: 'entry_fee')
//   final double entryFee;
//   @JsonKey(name: 'prize_pool', defaultValue: 0.0)
//   final double prizePool; // Used for Mini Contests
//   @JsonKey(name: 'num_players', defaultValue: 0)
//   final int numPlayers; // Used for Mega Contests
//   @JsonKey(name: 'num_questions', defaultValue: 0)
//   final int numQuestions; // Used for Mega Contests
//   @JsonKey(name: 'start_datetime')
//   final DateTime? startDateTime; // Used for Mega Contests
//   final List<Map<String, dynamic>>? rankings; // Used for Mega Contests

//   Contest({
//     required this.id,
//     required this.name,
//     required this.type,
//     required this.entryFee,
//     this.prizePool = 0.0,
//     this.numPlayers = 0,
//     this.numQuestions = 0,
//     this.startDateTime,
//     this.rankings,
//   });

//   factory Contest.fromJson(Map<String, dynamic> json) {
//     return Contest(
//       id: _parseInt(json['id'] ?? json['contest_id']),
//       name: json['name'] as String? ?? 'Unknown Contest',
//       type: json['type'] as String? ?? 'unknown',
//       entryFee: _parseDouble(json['entry_fee']?.toString() ?? '0.0'),
//       prizePool: _parseDouble(json['prize_pool']?.toString() ?? '0.0'),
//       numPlayers: _parseInt(json['num_players']?.toString() ?? '0'),
//       numQuestions: _parseInt(json['num_questions']?.toString() ?? '0'),
//       startDateTime: json['start_datetime'] != null
//           ? _parseDateTime(json['start_datetime'] as String?)
//           : null,
//       rankings: json['rankings'] != null
//           ? (json['rankings'] as List<dynamic>?)?.cast<Map<String, dynamic>>()
//           : null,
//     );
//   }

//   static int _parseInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is String) {
//       try {
//         return int.parse(value);
//       } catch (e) {
//         print('Error parsing int: $e, value: $value');
//         return 0;
//       }
//     }
//     return 0;
//   }

//   static double _parseDouble(String? value) {
//     if (value == null) return 0.0;
//     try {
//       return double.parse(value);
//     } catch (e) {
//       print('Error parsing double: $e, value: $value');
//       return 0.0;
//     }
//   }

//   static DateTime? _parseDateTime(String? value) {
//     if (value == null) return null;
//     try {
//       return DateTime.parse(value);
//     } catch (e) {
//       print('Error parsing DateTime: $e, value: $value');
//       return null;
//     }
//   }

//   Map<String, dynamic> toJson() => _$ContestToJson(this);
// }



import 'package:json_annotation/json_annotation.dart';

part 'contest.g.dart';

@JsonSerializable()
class Contest {
  @JsonKey(name: 'id', includeIfNull: false)
  final int id;
  final String name;
  final String type;
  @JsonKey(name: 'entry_fee')
  final double entryFee;
  @JsonKey(name: 'prize_pool', defaultValue: 0.0)
  final double prizePool; // Used for Mini Contests
  @JsonKey(name: 'num_players', defaultValue: 0)
  final int numPlayers; // Used for Mega Contests
  @JsonKey(name: 'num_questions', defaultValue: 0)
  final int numQuestions; // Used for Mega Contests
  @JsonKey(name: 'start_datetime')
  final DateTime? startDateTime; // Used for Mega Contests
  final List<Map<String, dynamic>>? rankings; // Used for Mega Contests
  @JsonKey(name: 'total_winning_amount', fromJson: _parseTotalWinningAmountFromJson)
  final double? totalWinningAmount; // New field for mega contests


  Contest({
    required this.id,
    required this.name,
    required this.type,
    required this.entryFee,
    this.prizePool = 0.0,
    this.numPlayers = 0,
    this.numQuestions = 0,
    this.startDateTime,
    this.rankings,
    this.totalWinningAmount,
  });

  factory Contest.fromJson(Map<String, dynamic> json) {
    return Contest(
      id: _parseInt(json['id'] ?? json['contest_id']),
      name: json['name'] as String? ?? 'Unknown Contest',
      type: json['type'] as String? ?? 'unknown',
      entryFee: _parseDouble(json['entry_fee']?.toString() ?? '0.0'),
      prizePool: _parseDouble(json['prize_pool']?.toString() ?? '0.0'),
      numPlayers: _parseInt(json['num_players']?.toString() ?? '0'),
      numQuestions: _parseInt(json['num_questions']?.toString() ?? '0'),
      startDateTime: json['start_datetime'] != null
          ? _parseDateTime(json['start_datetime'] as String?)
          : null,
      rankings: json['rankings'] != null
          ? (json['rankings'] as List<dynamic>?)?.cast<Map<String, dynamic>>()
          : null,
      totalWinningAmount: _parseTotalWinningAmount(json['total_winning_amount']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print('Error parsing int: $e, value: $value');
        return 0;
      }
    }
    return 0;
  }

  static double _parseDouble(String? value) {
    if (value == null) return 0.0;
    try {
      return double.parse(value);
    } catch (e) {
      print('Error parsing double: $e, value: $value');
      return 0.0;
    }
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value);
    } catch (e) {
      print('Error parsing DateTime: $e, value: $value');
      return null;
    }
  }

  static double? _parseTotalWinningAmountFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print('Error parsing total_winning_amount: $e, value: $value');
        return null;
      }
    }
    return null;
  }

  static double? _parseTotalWinningAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print('Error parsing total_winning_amount: $e, value: $value');
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => _$ContestToJson(this);
}

