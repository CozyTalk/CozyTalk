import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/models/profile_user_model.dart';

void main() {
  group('ProfileUserModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = ProfileUserModel.fromJson({
          'uid': 'uid-1',
          'displayName': 'Alice',
          'interest': 'coding',
          'thoughts': 'feeling good',
        });
        expect(model.uid, 'uid-1');
        expect(model.displayName, 'Alice');
        expect(model.interest, 'coding');
        expect(model.thoughts, 'feeling good');
      });

      test('handles null optional fields', () {
        final model = ProfileUserModel.fromJson({'uid': 'uid-2'});
        expect(model.uid, 'uid-2');
        expect(model.displayName, isNull);
        expect(model.interest, isNull);
        expect(model.thoughts, isNull);
      });

      test('ignores unknown extra keys', () {
        final model = ProfileUserModel.fromJson({
          'uid': 'uid-3',
          'role': 'user',
          'email': 'a@b.com',
          'createdAt': 'timestamp',
        });
        expect(model.uid, 'uid-3');
      });
    });

    group('toEntity', () {
      test('maps all fields to ProfileUser', () {
        const model = ProfileUserModel(
          uid: 'uid-4',
          displayName: 'Bob',
          interest: 'music',
          thoughts: 'inspired',
        );
        final entity = model.toEntity();
        expect(entity.uid, 'uid-4');
        expect(entity.displayName, 'Bob');
        expect(entity.interest, 'music');
        expect(entity.thoughts, 'inspired');
      });

      test('preserves null optional fields', () {
        const model = ProfileUserModel(uid: 'uid-5');
        final entity = model.toEntity();
        expect(entity.displayName, isNull);
        expect(entity.interest, isNull);
        expect(entity.thoughts, isNull);
      });
    });
  });
}
