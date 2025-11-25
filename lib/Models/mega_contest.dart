import 'package:json_annotation/json_annotation.dart';

part 'mega_contest.g.dart';

@JsonSerializable()
class MegaContest {
  @JsonKey(name: 'id', includeIfNull: false)
  final int id;
  final String name;
  final String type;
  @JsonKey(name: 'start_datetime')
  final DateTime? startDateTime;
  @JsonKey(name: 'num_players', defaultValue: 0)
  final int numPlayers;
  @JsonKey(name: 'num_questions', defaultValue: 0)
  final int numQuestions;
  @JsonKey(name: 'entry_fee')
  final double entryFee;
  @JsonKey(name: 'total_winning_amount', fromJson: _parseTotalWinningAmountFromJson)
  final double? totalWinningAmount;
  final String status;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  MegaContest({
    required this.id,
    required this.name,
    required this.type,
    this.startDateTime,
    this.numPlayers = 0,
    this.numQuestions = 0,
    required this.entryFee,
    this.totalWinningAmount,
    required this.status,
    this.createdAt,
  });

  factory MegaContest.fromJson(Map<String, dynamic> json) {
    return MegaContest(
      id: _parseInt(json['id'] ?? json['contest_id']),
      name: json['name'] as String? ?? 'Unknown Mega Contest',
      type: json['type'] as String? ?? 'mega',
      startDateTime: json['start_datetime'] != null
          ? _parseDateTime(json['start_datetime'] as String?)
          : null,
      numPlayers: _parseInt(json['num_players']?.toString() ?? '0'),
      numQuestions: _parseInt(json['num_questions']?.toString() ?? '0'),
      entryFee: _parseDouble(json['entry_fee']?.toString() ?? '0.0'),
      totalWinningAmount: _parseTotalWinningAmount(json['total_winning_amount']),
      status: json['status'] as String? ?? 'unknown',
      createdAt: json['created_at'] != null
          ? _parseDateTime(json['created_at'] as String?)
          : null,
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

  Map<String, dynamic> toJson() => _$MegaContestToJson(this);
}