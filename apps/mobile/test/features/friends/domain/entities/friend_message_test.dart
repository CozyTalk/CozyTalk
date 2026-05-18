import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_message.dart';

void main() {
  group('FriendMessage', () {
    test('constructs with all required fields', () {
      final msg = FriendMessage(
        id: 'msg-1',
        senderId: 'uid-1',
        senderDisplayName: 'Alice',
        text: 'Hello!',
        timestamp: DateTime.fromMillisecondsSinceEpoch(5000),
      );
      expect(msg.id, 'msg-1');
      expect(msg.senderId, 'uid-1');
      expect(msg.senderDisplayName, 'Alice');
      expect(msg.text, 'Hello!');
      expect(msg.timestamp.millisecondsSinceEpoch, 5000);
    });

    test('preserves empty text', () {
      final msg = FriendMessage(
        id: 'msg-2',
        senderId: 'uid-2',
        senderDisplayName: 'Bob',
        text: '',
        timestamp: DateTime(2024),
      );
      expect(msg.text, '');
    });

    test('preserves multiline text', () {
      const multiline = 'Line one\nLine two\nLine three';
      final msg = FriendMessage(
        id: 'msg-3',
        senderId: 'uid-3',
        senderDisplayName: 'Carol',
        text: multiline,
        timestamp: DateTime(2024),
      );
      expect(msg.text, multiline);
    });

    test('preserves exact timestamp', () {
      final dt = DateTime(2024, 12, 31, 23, 59, 59);
      final msg = FriendMessage(
        id: 'msg-4',
        senderId: 'uid-4',
        senderDisplayName: 'Dan',
        text: 'Happy new year!',
        timestamp: dt,
      );
      expect(msg.timestamp, dt);
    });
  });
}
