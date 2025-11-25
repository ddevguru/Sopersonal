import 'package:json_annotation/json_annotation.dart';

part 'question.g.dart';

@JsonSerializable()
class Question {
  final int id;
  final String questionText; // Changed to match PHP
  final String optionA;     // Changed to match PHP
  final String optionB;     // Changed to match PHP
  final String optionC;     // Changed to match PHP
  final String optionD;     // Changed to match PHP
  final String correctOption; // Changed to match PHP

  Question({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
  });

  factory Question.fromJson(Map<String, dynamic> json) => _$QuestionFromJson(json);
  Map<String, dynamic> toJson() => _$QuestionToJson(this);
}



