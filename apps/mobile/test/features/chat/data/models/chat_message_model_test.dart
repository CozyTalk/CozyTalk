import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/models/chat_message_model.dart';

void main() {
  group('ChatMessageModel', () {
    group('fromJson', () {
      test('constructs from valid json', () {
        final model = ChatMessageModel.fromJson({
          'id': 'msg-1',
          'senderId': 'user-1',
          'displayName': 'Alice',
          'encryptedText': 'abc==',
          'iv': 'nonce==',
          'authTag': 'tag==',
          'timestamp': 1700000000000,
        });
        expect(model.id, 'msg-1');
        expect(model.senderId, 'user-1');
        expect(model.displayName, 'Alice');
        expect(model.encryptedText, 'abc==');
        expect(model.iv, 'nonce==');
        expect(model.authTag, 'tag==');
        expect(model.timestamp, 1700000000000);
      });

      test('ignores unknown fields from Firestore snapshot', () {
        final model = ChatMessageModel.fromJson({
          'id': 'msg-2',
          'senderId': 'user-2',
          'displayName': 'Bob',
          'encryptedText': 'x',
          'iv': 'y',
          'authTag': 'z',
          'timestamp': 0,
          'expiresAt': 9999,
          'flagged': false,
        });
        expect(model.id, 'msg-2');
      });
    });

    group('construction', () {
      test('stores all fields', () {
        const model = ChatMessageModel(
          id: 'id-1',
          senderId: 'sender-1',
          displayName: 'Carol',
          encryptedText: 'ctext',
          iv: 'ivbytes',
          authTag: 'tag',
          timestamp: 42,
        );
        expect(model.id, 'id-1');
        expect(model.timestamp, 42);
      });
    });
  });
}
