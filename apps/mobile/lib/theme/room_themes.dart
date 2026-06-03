class RoomTheme {
  final String title;
  final String thumbnail;
  const RoomTheme({required this.title, required this.thumbnail});
}

const _kThemes = <String, RoomTheme>{
  'kao_tapu': RoomTheme(
    title: 'Kao Tapu',
    thumbnail: 'assets/images/backgrounds/kao_tapu.png',
  ),
  'red_lotus_lake': RoomTheme(
    title: 'Red Lotus Lake',
    thumbnail: 'assets/images/backgrounds/red_lotus_lake.png',
  ),
  'sea_of_cloud': RoomTheme(
    title: 'The Sea of Cloud',
    thumbnail: 'assets/images/backgrounds/sea_of_cloud.png',
  ),
  'lumphini_park': RoomTheme(
    title: 'Lumphini Park',
    thumbnail: 'assets/images/backgrounds/lumphini_park.png',
  ),
};

RoomTheme resolveRoomTheme(String? themeId, {required String mode}) {
  final t = themeId == null ? null : _kThemes[themeId];
  if (t != null) return t;
  return RoomTheme(
    title: mode == '1v1' ? '1v1 Room' : 'Group Room',
    thumbnail: mode == '1v1'
        ? 'assets/images/1on1_doodle.png'
        : 'assets/images/group_doodle.png',
  );
}

/// Picks a random theme from the available set.
/// Used when a room has no backgroundTheme (e.g. both users pressed Random).
RoomTheme resolveRandomRoomTheme(String roomId) {
  final themes = _kThemes.values.toList();
  final seed = roomId.codeUnits.fold(0, (a, b) => a + b);
  return themes[seed % themes.length];
}
