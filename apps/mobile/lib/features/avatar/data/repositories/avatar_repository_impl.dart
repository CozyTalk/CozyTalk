import '../../domain/entities/avatar_decoration.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../datasources/avatar_datasource.dart';
import '../models/avatar_decoration_model.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  final AvatarDatasource _datasource;
  AvatarRepositoryImpl(this._datasource);

  @override
  Future<AvatarDecoration?> getDecoration(String uid) async {
    final model = await _datasource.getDecoration(uid);
    return model?.toEntity();
  }

  @override
  Future<void> updateHat(String uid, String? hatKey) =>
      _datasource.updateHat(uid, hatKey);

  @override
  Future<void> updateMood(String uid, String? moodKey) =>
      _datasource.updateMood(uid, moodKey);
}
