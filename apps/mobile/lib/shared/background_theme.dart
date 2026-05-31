const _themeAssets = <String, String>{
  'kao_tapu': 'assets/images/backgrounds/kao_tapu.png',
  'red_lotus_lake': 'assets/images/backgrounds/red_lotus_lake.png',
  'sea_of_cloud': 'assets/images/backgrounds/sea_of_cloud.png',
  'lumphini_park': 'assets/images/backgrounds/lumphini_park.png',
};

/// Returns the asset path for a background theme ID, or null if unknown.
String? backgroundThemeAsset(String? themeId) =>
    themeId != null ? _themeAssets[themeId] : null;
