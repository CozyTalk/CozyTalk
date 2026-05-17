import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';

void main() {
  group('ProfileUser', () {
    test('constructs with required uid', () {
      const user = ProfileUser(uid: 'abc');
      expect(user.uid, 'abc');
    });

    test('optional fields default to null', () {
      const user = ProfileUser(uid: 'uid-1');
      expect(user.displayName, isNull);
      expect(user.interest, isNull);
      expect(user.thoughts, isNull);
    });

    test('accepts all optional fields', () {
      const user = ProfileUser(
        uid: 'uid-2',
        displayName: 'Alice',
        interest: 'coding',
        thoughts: 'feeling good',
      );
      expect(user.displayName, 'Alice');
      expect(user.interest, 'coding');
      expect(user.thoughts, 'feeling good');
    });
  });
}
