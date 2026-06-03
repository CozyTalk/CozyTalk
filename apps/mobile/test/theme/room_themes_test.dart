import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme/room_themes.dart';

void main() {
  group('resolveRoomTheme', () {
    test('returns Kao Tapu theme for kao_tapu id', () {
      final t = resolveRoomTheme('kao_tapu', mode: 'group');
      expect(t.title, 'Kao Tapu');
      expect(t.thumbnail, 'assets/images/backgrounds/kao_tapu.png');
    });

    test('returns Red Lotus Lake theme for red_lotus_lake id', () {
      final t = resolveRoomTheme('red_lotus_lake', mode: 'group');
      expect(t.title, 'Red Lotus Lake');
      expect(t.thumbnail, 'assets/images/backgrounds/red_lotus_lake.png');
    });

    test('returns The Sea of Cloud theme for sea_of_cloud id', () {
      final t = resolveRoomTheme('sea_of_cloud', mode: 'group');
      expect(t.title, 'The Sea of Cloud');
      expect(t.thumbnail, 'assets/images/backgrounds/sea_of_cloud.png');
    });

    test('returns Lumphini Park theme for lumphini_park id', () {
      final t = resolveRoomTheme('lumphini_park', mode: 'group');
      expect(t.title, 'Lumphini Park');
      expect(t.thumbnail, 'assets/images/backgrounds/lumphini_park.png');
    });

    test('falls back to Group Room when id is null and mode is group', () {
      final t = resolveRoomTheme(null, mode: 'group');
      expect(t.title, 'Group Room');
      expect(t.thumbnail, 'assets/images/group_doodle.png');
    });

    test('falls back to 1v1 Room when id is null and mode is 1v1', () {
      final t = resolveRoomTheme(null, mode: '1v1');
      expect(t.title, '1v1 Room');
      expect(t.thumbnail, 'assets/images/1on1_doodle.png');
    });

    test('falls back to default when id is unknown', () {
      final t = resolveRoomTheme('does_not_exist', mode: 'group');
      expect(t.title, 'Group Room');
      expect(t.thumbnail, 'assets/images/group_doodle.png');
    });
  });

  group('resolveRandomRoomTheme', () {
    const knownTitles = [
      'Kao Tapu',
      'Red Lotus Lake',
      'The Sea of Cloud',
      'Lumphini Park',
    ];

    test('is deterministic — same roomId always returns the same theme', () {
      final t1 = resolveRandomRoomTheme('room-xyz-001');
      final t2 = resolveRandomRoomTheme('room-xyz-001');
      expect(t1.title, t2.title);
      expect(t1.thumbnail, t2.thumbnail);
    });

    test('returns a known scenic theme, not a doodle fallback', () {
      final t = resolveRandomRoomTheme('room-xyz-001');
      expect(knownTitles, contains(t.title));
    });

    test('does not crash when roomId is empty', () {
      final t = resolveRandomRoomTheme('');
      expect(knownTitles, contains(t.title));
    });

    test('roomIds with different code-unit sums return different themes', () {
      // '' sums to 0 → index 0; 'a' sums to 97 → index 1 (97 % 4 = 1)
      expect(
        resolveRandomRoomTheme('').title,
        isNot(resolveRandomRoomTheme('a').title),
      );
    });
  });
}
