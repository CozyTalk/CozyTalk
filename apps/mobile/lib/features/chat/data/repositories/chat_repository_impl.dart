import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/typing_user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_datasource.dart';
import '../models/chat_message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatDatasource _datasource;

  ChatRepositoryImpl(this._datasource);

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) async* {
    final keyHex = await _datasource.fetchSessionKey(sessionId);
    final keyBytes = _hexToBytes(keyHex);

    await for (final models in _datasource.watchRawMessages(sessionId)) {
      yield await Future.wait(models.map((m) => _decrypt(m, keyBytes)));
    }
  }

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) =>
      _datasource.watchTypingUsers(sessionId);

  @override
  Future<void> sendMessage({required String sessionId, required String text}) =>
      _datasource.sendMessage(sessionId: sessionId, text: text);

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  }) => _datasource.setTyping(
    sessionId: sessionId,
    isTyping: isTyping,
    currentUid: currentUid,
    displayName: displayName,
  );

  @override
  Future<void> endSession({required String sessionId}) =>
      _datasource.endSession(sessionId: sessionId);

  Future<ChatMessage> _decrypt(
    ChatMessageModel model,
    List<int> keyBytes,
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(
      base64.decode(model.encryptedText),
      nonce: base64.decode(model.iv),
      mac: Mac(base64.decode(model.authTag)),
    );
    final plainBytes = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return ChatMessage(
      id: model.id,
      senderId: model.senderId,
      displayName: model.displayName,
      text: utf8.decode(plainBytes),
      timestamp: DateTime.fromMillisecondsSinceEpoch(model.timestamp),
    );
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
