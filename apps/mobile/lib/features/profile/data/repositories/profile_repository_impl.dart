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
  Future<void> updateDisplayName(String uid, String displayName) async {
    await _datasource.updateDisplayName(uid, displayName);
    try {
      final cached = await _cache.read(uid);
      if (cached != null) {
        await _cache.write(uid, cached.copyWith(displayName: displayName));
      }
    } catch (_) {}
  }

  @override
  Future<void> updateInterest(String uid, String interest) async {
    await _datasource.updateInterest(uid, interest);
    try {
      final cached = await _cache.read(uid);
      if (cached != null) {
        await _cache.write(uid, cached.copyWith(interest: interest));
      }
    } catch (_) {}
  }

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {
    await _datasource.updateThoughts(uid, thoughts);
    try {
      final cached = await _cache.read(uid);
      if (cached != null) {
        await _cache.write(uid, cached.copyWith(thoughts: thoughts));
      }
    } catch (_) {}
  }
}
