import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/models/auth_user_model.dart';

void main() {
  group('AuthUserModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = AuthUserModel.fromJson({
          'uid': 'uid-1',
          'email': 'user@example.com',
          'displayName': 'Alice',
        });
        expect(model.uid, 'uid-1');
        expect(model.email, 'user@example.com');
        expect(model.displayName, 'Alice');
      });

      test('handles null optional fields', () {
        final model = AuthUserModel.fromJson({'uid': 'uid-2'});
        expect(model.uid, 'uid-2');
        expect(model.email, isNull);
        expect(model.displayName, isNull);
      });
    });

    group('toEntity', () {
      test('maps all fields to AuthUser', () {
        const model = AuthUserModel(
          uid: 'uid-3',
          email: 'test@test.com',
          displayName: 'Bob',
        );
        final entity = model.toEntity();
        expect(entity.uid, 'uid-3');
        expect(entity.email, 'test@test.com');
        expect(entity.displayName, 'Bob');
      });

      test('preserves null optional fields', () {
        const model = AuthUserModel(uid: 'uid-4');
        final entity = model.toEntity();
        expect(entity.email, isNull);
        expect(entity.displayName, isNull);
      });
    });
  });
}
