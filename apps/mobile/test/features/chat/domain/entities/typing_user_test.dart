import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';

void main() {
  group('TypingUser', () {
    test('constructs with uid and displayName', () {
      const user = TypingUser(uid: 'u1', displayName: 'Carol');
      expect(user.uid, 'u1');
      expect(user.displayName, 'Carol');
      expect(user.photoUrl, isNull);
    });

    test('preserves anonymous display name', () {
      const user = TypingUser(uid: 'anon', displayName: 'Anonymous');
      expect(user.displayName, 'Anonymous');
    });

    test('stores optional photoUrl', () {
      const user = TypingUser(
        uid: 'u1',
        displayName: 'Carol',
        photoUrl: 'https://example.com/photo.jpg',
      );
      expect(user.photoUrl, 'https://example.com/photo.jpg');
    });

    test('photoUrl defaults to null when not provided', () {
      const user = TypingUser(uid: 'u2', displayName: 'Dave');
      expect(user.photoUrl, isNull);
    });
  });
}
