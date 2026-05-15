import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/avatar_decoration.dart';

part 'avatar_decoration_model.freezed.dart';
part 'avatar_decoration_model.g.dart';

@freezed
abstract class AvatarDecorationModel with _$AvatarDecorationModel {
  const factory AvatarDecorationModel({
    String? hatKey,
    String? moodKey,
  }) = _AvatarDecorationModel;

  factory AvatarDecorationModel.fromJson(Map<String, dynamic> json) =>
      _$AvatarDecorationModelFromJson(json);
}

extension AvatarDecorationModelX on AvatarDecorationModel {
  AvatarDecoration toEntity() =>
      AvatarDecoration(hatKey: hatKey, moodKey: moodKey);
}
