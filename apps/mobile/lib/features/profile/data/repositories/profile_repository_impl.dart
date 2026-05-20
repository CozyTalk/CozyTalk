import '../../domain/entities/profile_user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_cache_datasource.dart';
import '../datasources/profile_datasource.dart';
import '../models/profile_user_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileDatasource _datasource;
  final ProfileCacheDatasource _cache;

  ProfileRepositoryImpl(this._datasource, this._cache);

  @override
  Future<ProfileUser> getProfile(String uid) async {
    try {
      final model = await _datasource.getProfile(uid);
      try {
        await _cache.write(uid, model);
      } catch (_) {}
      return model.toEntity();
    } catch (e) {
      final cached = await _cache.read(uid);
      if (cached != null) return cached.toEntity();
      rethrow;
    }
  }

  @override
  Future<ProfileUser?> getCachedProfile(String uid) async {
    final model = await _cache.read(uid);
    return model?.toEntity();
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) =>
      _datasource.updateDisplayName(uid, displayName);

  @override
  Future<void> updateInterest(String uid, String interest) =>
      _datasource.updateInterest(uid, interest);

  @override
  Future<void> updateThoughts(String uid, String thoughts) =>
      _datasource.updateThoughts(uid, thoughts);
}
