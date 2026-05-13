import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/session_status.dart';

void main() {
  group('SessionStatus', () {
    test('has the four expected states', () {
      expect(
        SessionStatus.values,
        containsAll([
          SessionStatus.idle,
          SessionStatus.searching,
          SessionStatus.chatting,
          SessionStatus.disconnected,
        ]),
      );
      expect(SessionStatus.values.length, 4);
    });
  });
}
