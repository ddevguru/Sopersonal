// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mega_contest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MegaContest _$MegaContestFromJson(Map<String, dynamic> json) => MegaContest(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: json['type'] as String,
  startDateTime: json['start_datetime'] == null
      ? null
      : DateTime.parse(json['start_datetime'] as String),
  numPlayers: (json['num_players'] as num?)?.toInt() ?? 0,
  numQuestions: (json['num_questions'] as num?)?.toInt() ?? 0,
  entryFee: (json['entry_fee'] as num).toDouble(),
  totalWinningAmount: MegaContest._parseTotalWinningAmountFromJson(
    json['total_winning_amount'],
  ),
  status: json['status'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MegaContestToJson(MegaContest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'start_datetime': instance.startDateTime?.toIso8601String(),
      'num_players': instance.numPlayers,
      'num_questions': instance.numQuestions,
      'entry_fee': instance.entryFee,
      'total_winning_amount': instance.totalWinningAmount,
      'status': instance.status,
      'created_at': instance.createdAt?.toIso8601String(),
    };
