import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/banned_word.dart';

part 'banned_word_model.freezed.dart';
part 'banned_word_model.g.dart';

@freezed
abstract class BannedWordModel with _$BannedWordModel {
  const factory BannedWordModel({
    required String word,
    required String language,
  }) = _BannedWordModel;

  factory BannedWordModel.fromJson(Map<String, dynamic> json) =>
      _$BannedWordModelFromJson(json);
}

extension BannedWordModelX on BannedWordModel {
  BannedWord toEntity() => BannedWord(word: word, language: language);
}
