import '../../domain/entities/avatar_decoration.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../datasources/avatar_cache_datasource.dart';
import '../datasources/avatar_datasource.dart';
import '../models/avatar_decoration_model.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  final AvatarDatasource _datasource;
  final AvatarCacheDatasource _cache;

  AvatarRepositoryImpl(this._datasource, this._cache);

  @override
  Future<AvatarDecoration?> getDecoration(String uid) async {
    try {
      final model = await _datasource.getDecoration(uid);
      if (model != null) {
        try {
          await _cache.write(uid, model);
        } catch (_) {}
      }
      return model?.toEntity();
    } catch (_) {
      // Avatar null is a valid "no decoration" state — return null rather than
      // rethrow so the notifier never shows an error just because the cache missed.
      return (await _cache.read(uid))?.toEntity();
    }
  }

  @override
  Future<AvatarDecoration?> getCachedDecoration(String uid) async {
    final model = await _cache.read(uid);
    return model?.toEntity();
  }

  @override
  Future<void> updateHat(String uid, String? hatKey) =>
      _datasource.updateHat(uid, hatKey);

  @override
  Future<void> updateMood(String uid, String? moodKey) =>
      _datasource.updateMood(uid, moodKey);

  @override
  Future<void> updateDecoration(String uid, String? hatKey, String? moodKey) =>
      _datasource.updateDecoration(uid, hatKey, moodKey);
}
