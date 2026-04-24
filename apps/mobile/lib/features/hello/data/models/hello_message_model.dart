import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/hello_message.dart';

part 'hello_message_model.freezed.dart';
part 'hello_message_model.g.dart';

@freezed
abstract class HelloMessageModel with _$HelloMessageModel {
  const factory HelloMessageModel({
    required String message,
  }) = _HelloMessageModel;

  factory HelloMessageModel.fromJson(Map<String, dynamic> json) =>
      _$HelloMessageModelFromJson(json);
}

extension HelloMessageModelX on HelloMessageModel {
  HelloMessage toEntity() => HelloMessage(message: message);
}
