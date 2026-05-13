import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';

void main() {
  group('TypingUser', () {
    test('constructs with uid and displayName', () {
      const user = TypingUser(uid: 'u1', displayName: 'Carol');
      expect(user.uid, 'u1');
      expect(user.displayName, 'Carol');
    });

    test('preserves anonymous display name', () {
      const user = TypingUser(uid: 'anon', displayName: 'Anonymous');
      expect(user.displayName, 'Anonymous');
    });
  });
}
