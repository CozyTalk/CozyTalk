import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/datasources/chat_datasource.dart';
import 'package:mobile/features/chat/data/models/chat_message_model.dart';
import 'package:mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';

class _FakeChatDatasource implements ChatDatasource {
  final String keyHex;
  final List<ChatMessageModel> messages;
  final List<TypingUser> typingUsers;

  int sendMessageCount = 0;
  int endSessionCount = 0;
  int setTypingCount = 0;
  bool? lastIsTyping;

  _FakeChatDatasource({
    required this.keyHex,
    this.messages = const [],
    this.typingUsers = const [],
  });

  @override
  Future<String> fetchSessionKey(String sessionId) async => keyHex;

  @override
  Stream<List<ChatMessageModel>> watchRawMessages(String sessionId) =>
      Stream.value(messages);

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) =>
      Stream.value(typingUsers);

  @override
  Future<void> sendMessage({required String sessionId, required String text}) async =>
      sendMessageCount++;

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  }) async {
    setTypingCount++;
    lastIsTyping = isTyping;
  }

  @override
  Future<void> endSession({required String sessionId}) async => endSessionCount++;

  @override
  Future<String> joinProtoSession({
    required String sessionId,
    required String uid,
  }) async =>
      'Test User';
}

Future<ChatMessageModel> _encryptModel({
  required String id,
  required String senderId,
  required String displayName,
  required String plainText,
  required List<int> keyBytes,
  required int timestamp,
}) async {
  final algorithm = AesGcm.with256bits();
  final secretKey = SecretKey(keyBytes);
  final secretBox = await algorithm.encrypt(
    utf8.encode(plainText),
    secretKey: secretKey,
  );
  return ChatMessageModel(
    id: id,
    senderId: senderId,
    displayName: displayName,
    encryptedText: base64Encode(secretBox.cipherText),
    iv: base64Encode(secretBox.nonce),
    authTag: base64Encode(secretBox.mac.bytes),
    timestamp: timestamp,
  );
}

// 32 zero bytes as a 64-char hex string.
const _testKeyHex = '0000000000000000000000000000000000000000000000000000000000000000';
final _testKeyBytes = List<int>.filled(32, 0);

void main() {
  group('ChatRepositoryImpl', () {
    group('watchMessages', () {
      test('decrypts a single message correctly', () async {
        final model = await _encryptModel(
          id: 'msg-1',
          senderId: 'user-1',
          displayName: 'Alice',
          plainText: 'hello world',
          keyBytes: _testKeyBytes,
          timestamp: 1700000000000,
        );
        final datasource = _FakeChatDatasource(
          keyHex: _testKeyHex,
          messages: [model],
        );
        final repo = ChatRepositoryImpl(datasource);

        final messages = await repo.watchMessages('session-1').first;

        expect(messages, hasLength(1));
        expect(messages[0].id, 'msg-1');
        expect(messages[0].senderId, 'user-1');
        expect(messages[0].displayName, 'Alice');
        expect(messages[0].text, 'hello world');
        expect(
          messages[0].timestamp,
          DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );
      });

      test('decrypts multiple messages in order', () async {
        final m1 = await _encryptModel(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          plainText: 'first',
          keyBytes: _testKeyBytes,
          timestamp: 1000,
        );
        final m2 = await _encryptModel(
          id: 'm2',
          senderId: 'u2',
          displayName: 'Bob',
          plainText: 'second',
          keyBytes: _testKeyBytes,
          timestamp: 2000,
        );
        final datasource = _FakeChatDatasource(
          keyHex: _testKeyHex,
          messages: [m1, m2],
        );
        final repo = ChatRepositoryImpl(datasource);

        final messages = await repo.watchMessages('session-1').first;

        expect(messages.length, 2);
        expect(messages[0].text, 'first');
        expect(messages[1].text, 'second');
      });

      test('returns empty list when no messages', () async {
        final datasource = _FakeChatDatasource(keyHex: _testKeyHex);
        final repo = ChatRepositoryImpl(datasource);

        final messages = await repo.watchMessages('session-1').first;
        expect(messages, isEmpty);
      });

      test('decrypts unicode text correctly', () async {
        final model = await _encryptModel(
          id: 'u-1',
          senderId: 'u1',
          displayName: 'User',
          plainText: '🐨 こんにちは',
          keyBytes: _testKeyBytes,
          timestamp: 0,
        );
        final datasource =
            _FakeChatDatasource(keyHex: _testKeyHex, messages: [model]);
        final repo = ChatRepositoryImpl(datasource);

        final messages = await repo.watchMessages('s').first;
        expect(messages[0].text, '🐨 こんにちは');
      });
    });

    group('watchTypingUsers', () {
      test('delegates to datasource', () async {
        const users = [TypingUser(uid: 'u1', displayName: 'Alice')];
        final datasource =
            _FakeChatDatasource(keyHex: _testKeyHex, typingUsers: users);
        final repo = ChatRepositoryImpl(datasource);

        final result = await repo.watchTypingUsers('session-1').first;
        expect(result.length, 1);
        expect(result[0].uid, 'u1');
      });
    });

    group('sendMessage', () {
      test('delegates to datasource', () async {
        final datasource = _FakeChatDatasource(keyHex: _testKeyHex);
        final repo = ChatRepositoryImpl(datasource);

        await repo.sendMessage(sessionId: 'room-1', text: 'hi');
        expect(datasource.sendMessageCount, 1);
      });
    });

    group('setTyping', () {
      test('delegates to datasource with correct parameters', () async {
        final datasource = _FakeChatDatasource(keyHex: _testKeyHex);
        final repo = ChatRepositoryImpl(datasource);

        await repo.setTyping(
          sessionId: 'room-1',
          isTyping: true,
          currentUid: 'user-1',
          displayName: 'Alice',
        );
        expect(datasource.setTypingCount, 1);
        expect(datasource.lastIsTyping, isTrue);
      });
    });

    group('endSession', () {
      test('delegates to datasource', () async {
        final datasource = _FakeChatDatasource(keyHex: _testKeyHex);
        final repo = ChatRepositoryImpl(datasource);

        await repo.endSession(sessionId: 'room-1');
        expect(datasource.endSessionCount, 1);
      });
    });
  });
}
