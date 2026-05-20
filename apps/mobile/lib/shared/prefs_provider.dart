import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden — '
    'call SharedPreferences.getInstance() in main.dart and pass the result '
    'as an override to ProviderScope.',
  ),
);
