import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/icebreaker_question.dart';

part 'icebreaker_question_model.freezed.dart';
part 'icebreaker_question_model.g.dart';

@freezed
abstract class IcebreakerQuestionModel with _$IcebreakerQuestionModel {
  const factory IcebreakerQuestionModel({
    required String id,
    required String text,
    required String category,
    required String depth,
    required List<String> tags,
  }) = _IcebreakerQuestionModel;

  factory IcebreakerQuestionModel.fromJson(Map<String, dynamic> json) =>
      _$IcebreakerQuestionModelFromJson(json);
}

extension IcebreakerQuestionModelX on IcebreakerQuestionModel {
  IcebreakerQuestion toEntity() => IcebreakerQuestion(
    id: id,
    text: text,
    category: category,
    depth: depth,
    tags: List<String>.unmodifiable(tags),
  );
}
