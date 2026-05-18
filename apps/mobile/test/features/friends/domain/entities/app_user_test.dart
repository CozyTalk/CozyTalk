import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';

void main() {
  group('AppUser', () {
    test('constructs with required fields', () {
      const user = AppUser(uid: 'uid-1', displayName: 'Alice');
      expect(user.uid, 'uid-1');
      expect(user.displayName, 'Alice');
    });

    test('preserves empty displayName', () {
      const user = AppUser(uid: 'uid-2', displayName: '');
      expect(user.displayName, '');
    });

    test('preserves whitespace in displayName', () {
      const user = AppUser(uid: 'uid-3', displayName: '  Alice  ');
      expect(user.displayName, '  Alice  ');
    });

    test('preserves uid exactly', () {
      const uid = 'abc123-xyz-789';
      const user = AppUser(uid: uid, displayName: 'Bob');
      expect(user.uid, uid);
    });
  });
}
