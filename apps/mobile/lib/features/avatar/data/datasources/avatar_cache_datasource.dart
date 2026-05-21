import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/cache_keys.dart';
import '../models/avatar_decoration_model.dart';

abstract class AvatarCacheDatasource {
  Future<AvatarDecorationModel?> read(String uid);
  Future<void> write(String uid, AvatarDecorationModel model);
  Future<void> clear(String uid);
}

class AvatarCacheDatasourceImpl implements AvatarCacheDatasource {
  final SharedPreferences _prefs;

  AvatarCacheDatasourceImpl(this._prefs);

  @override
  Future<AvatarDecorationModel?> read(String uid) async {
    final raw = _prefs.getString(CacheKeys.avatar(uid));
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return AvatarDecorationModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String uid, AvatarDecorationModel model) async {
    await _prefs.setString(CacheKeys.avatar(uid), jsonEncode(model.toJson()));
  }

  @override
  Future<void> clear(String uid) async {
    await _prefs.remove(CacheKeys.avatar(uid));
  }
}
