import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/cache_keys.dart';
import '../models/profile_user_model.dart';

abstract class ProfileCacheDatasource {
  Future<ProfileUserModel?> read(String uid);
  Future<void> write(String uid, ProfileUserModel model);
  Future<void> clear(String uid);
}

class ProfileCacheDatasourceImpl implements ProfileCacheDatasource {
  final SharedPreferences _prefs;

  ProfileCacheDatasourceImpl(this._prefs);

  @override
  Future<ProfileUserModel?> read(String uid) async {
    final raw = _prefs.getString(CacheKeys.profile(uid));
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return ProfileUserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String uid, ProfileUserModel model) async {
    await _prefs.setString(CacheKeys.profile(uid), jsonEncode(model.toJson()));
  }

  @override
  Future<void> clear(String uid) async {
    await _prefs.remove(CacheKeys.profile(uid));
  }
}
