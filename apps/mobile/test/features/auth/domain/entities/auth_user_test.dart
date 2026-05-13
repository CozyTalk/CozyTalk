import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';

void main() {
  group('AuthUser', () {
    test('constructs with required uid', () {
      const user = AuthUser(uid: 'abc');
      expect(user.uid, 'abc');
    });

    test('email and displayName default to null', () {
      const user = AuthUser(uid: 'uid-1');
      expect(user.email, isNull);
      expect(user.displayName, isNull);
    });

    test('accepts all optional fields', () {
      const user = AuthUser(
        uid: 'uid-2',
        email: 'test@example.com',
        displayName: 'Alice',
      );
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Alice');
    });
  });
}
