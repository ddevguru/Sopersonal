// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Contest _$ContestFromJson(Map<String, dynamic> json) => Contest(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: json['type'] as String,
  entryFee: (json['entry_fee'] as num).toDouble(),
  prizePool: (json['prize_pool'] as num?)?.toDouble() ?? 0.0,
  numPlayers: (json['num_players'] as num?)?.toInt() ?? 0,
  numQuestions: (json['num_questions'] as num?)?.toInt() ?? 0,
  startDateTime: json['start_datetime'] == null
      ? null
      : DateTime.parse(json['start_datetime'] as String),
  rankings: (json['rankings'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
  totalWinningAmount: Contest._parseTotalWinningAmountFromJson(
    json['total_winning_amount'],
  ),
);

Map<String, dynamic> _$ContestToJson(Contest instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'entry_fee': instance.entryFee,
  'prize_pool': instance.prizePool,
  'num_players': instance.numPlayers,
  'num_questions': instance.numQuestions,
  'start_datetime': instance.startDateTime?.toIso8601String(),
  'rankings': instance.rankings,
  'total_winning_amount': instance.totalWinningAmount,
};
