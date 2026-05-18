import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/data/models/app_user_model.dart';

void main() {
  group('AppUserModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = AppUserModel.fromJson({
          'uid': 'uid-1',
          'displayName': 'Alice',
        });
        expect(model.uid, 'uid-1');
        expect(model.displayName, 'Alice');
      });

      test('constructs with empty displayName', () {
        final model = AppUserModel.fromJson({
          'uid': 'uid-2',
          'displayName': '',
        });
        expect(model.displayName, '');
      });
    });

    group('toEntity', () {
      test('maps uid and displayName to AppUser', () {
        const model = AppUserModel(uid: 'uid-3', displayName: 'Bob');
        final entity = model.toEntity();
        expect(entity.uid, 'uid-3');
        expect(entity.displayName, 'Bob');
      });

      test('preserves empty displayName in entity', () {
        const model = AppUserModel(uid: 'uid-4', displayName: '');
        final entity = model.toEntity();
        expect(entity.displayName, '');
      });
    });
  });
}
