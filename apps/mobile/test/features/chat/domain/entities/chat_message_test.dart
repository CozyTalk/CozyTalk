import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';

void main() {
  group('ChatMessage', () {
    final ts = DateTime(2024, 1, 15, 12, 0, 0);

    test('constructs with all required fields', () {
      final msg = ChatMessage(
        id: 'msg-1',
        senderId: 'user-1',
        displayName: 'Alice',
        text: 'hello',
        timestamp: ts,
      );
      expect(msg.id, 'msg-1');
      expect(msg.senderId, 'user-1');
      expect(msg.displayName, 'Alice');
      expect(msg.text, 'hello');
      expect(msg.timestamp, ts);
    });

    test('preserves empty text', () {
      final msg = ChatMessage(
        id: 'msg-2',
        senderId: 'user-1',
        displayName: 'Bob',
        text: '',
        timestamp: ts,
      );
      expect(msg.text, '');
    });
  });
}
