import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';

void main() {
  group('AvatarDecoration', () {
    test(
      'constructs with required fields only — both nullable fields default to null',
      () {
        const decoration = AvatarDecoration();
        expect(decoration.hatKey, isNull);
        expect(decoration.moodKey, isNull);
      },
    );

    test('constructs with hatKey only', () {
      const decoration = AvatarDecoration(hatKey: 'Cap');
      expect(decoration.hatKey, 'Cap');
      expect(decoration.moodKey, isNull);
    });

    test('constructs with moodKey only', () {
      const decoration = AvatarDecoration(moodKey: 'Happy');
      expect(decoration.hatKey, isNull);
      expect(decoration.moodKey, 'Happy');
    });

    test('constructs with both fields', () {
      const decoration = AvatarDecoration(hatKey: 'Crown', moodKey: 'Grumpy');
      expect(decoration.hatKey, 'Crown');
      expect(decoration.moodKey, 'Grumpy');
    });
  });
}
