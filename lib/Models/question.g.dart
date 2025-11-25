// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Question _$QuestionFromJson(Map<String, dynamic> json) => Question(
  id: (json['id'] as num).toInt(),
  questionText: json['questionText'] as String,
  optionA: json['optionA'] as String,
  optionB: json['optionB'] as String,
  optionC: json['optionC'] as String,
  optionD: json['optionD'] as String,
  correctOption: json['correctOption'] as String,
);

Map<String, dynamic> _$QuestionToJson(Question instance) => <String, dynamic>{
  'id': instance.id,
  'questionText': instance.questionText,
  'optionA': instance.optionA,
  'optionB': instance.optionB,
  'optionC': instance.optionC,
  'optionD': instance.optionD,
  'correctOption': instance.correctOption,
};
