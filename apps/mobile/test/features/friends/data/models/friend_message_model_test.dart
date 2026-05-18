import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/data/models/friend_message_model.dart';

void main() {
  group('FriendMessageModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = FriendMessageModel.fromJson({
          'id': 'msg-1',
          'senderId': 'uid-1',
          'senderDisplayName': 'Alice',
          'text': 'Hello!',
          'timestamp': 7000,
        });
        expect(model.id, 'msg-1');
        expect(model.senderId, 'uid-1');
        expect(model.senderDisplayName, 'Alice');
        expect(model.text, 'Hello!');
        expect(model.timestamp, 7000);
      });

      test('handles empty text', () {
        final model = FriendMessageModel.fromJson({
          'id': 'msg-2',
          'senderId': 'uid-2',
          'senderDisplayName': 'Bob',
          'text': '',
          'timestamp': 0,
        });
        expect(model.text, '');
      });

      test('handles timestamp of zero (pending server write)', () {
        final model = FriendMessageModel.fromJson({
          'id': 'msg-3',
          'senderId': 'uid-3',
          'senderDisplayName': 'Carol',
          'text': 'hi',
          'timestamp': 0,
        });
        expect(model.timestamp, 0);
      });
    });

    group('toEntity', () {
      test('maps all fields to FriendMessage', () {
        const model = FriendMessageModel(
          id: 'msg-4',
          senderId: 'uid-4',
          senderDisplayName: 'Dan',
          text: 'How are you?',
          timestamp: 9000,
        );
        final entity = model.toEntity();
        expect(entity.id, 'msg-4');
        expect(entity.senderId, 'uid-4');
        expect(entity.senderDisplayName, 'Dan');
        expect(entity.text, 'How are you?');
        expect(entity.timestamp, DateTime.fromMillisecondsSinceEpoch(9000));
      });

      test('converts timestamp 0 to epoch DateTime', () {
        const model = FriendMessageModel(
          id: 'msg-5',
          senderId: 'uid-5',
          senderDisplayName: 'Eve',
          text: 'test',
          timestamp: 0,
        );
        final entity = model.toEntity();
        expect(entity.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
      });
    });
  });
}
