import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/data/models/avatar_decoration_model.dart';

void main() {
  group('AvatarDecorationModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = AvatarDecorationModel.fromJson({
          'hatKey': 'Crown',
          'moodKey': 'Happy',
        });
        expect(model.hatKey, 'Crown');
        expect(model.moodKey, 'Happy');
      });

      test('handles null optional fields', () {
        final model = AvatarDecorationModel.fromJson({});
        expect(model.hatKey, isNull);
        expect(model.moodKey, isNull);
      });

      test('ignores unknown extra keys', () {
        final model = AvatarDecorationModel.fromJson({
          'hatKey': 'Cap',
          'uid': 'u1',
          'role': 'user',
        });
        expect(model.hatKey, 'Cap');
      });
    });

    group('toEntity', () {
      test('maps both fields to AvatarDecoration', () {
        const model = AvatarDecorationModel(hatKey: 'Beanie', moodKey: 'Sad');
        final entity = model.toEntity();
        expect(entity.hatKey, 'Beanie');
        expect(entity.moodKey, 'Sad');
      });

      test('preserves null optional fields', () {
        const model = AvatarDecorationModel();
        final entity = model.toEntity();
        expect(entity.hatKey, isNull);
        expect(entity.moodKey, isNull);
      });
    });
  });
}
