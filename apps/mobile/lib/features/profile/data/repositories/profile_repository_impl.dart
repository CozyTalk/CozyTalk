import '../../domain/entities/profile_user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';
import '../models/profile_user_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileDatasource _datasource;

  ProfileRepositoryImpl(this._datasource);

  @override
  Future<ProfileUser> getProfile(String uid) async {
    final model = await _datasource.getProfile(uid);
    return model.toEntity();
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
