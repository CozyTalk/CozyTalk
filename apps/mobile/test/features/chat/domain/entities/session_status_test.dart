import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/session_status.dart';

void main() {
  group('SessionStatus', () {
    test('defines idle', () => expect(SessionStatus.idle, isNotNull));
    test('defines searching', () => expect(SessionStatus.searching, isNotNull));
    test('defines chatting', () => expect(SessionStatus.chatting, isNotNull));
    test('defines disconnected', () => expect(SessionStatus.disconnected, isNotNull));

    test('has exactly four states', () {
      expect(SessionStatus.values.length, 4);
    });
  });
}
