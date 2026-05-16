import '../entities/avatar_decoration.dart';

abstract class AvatarRepository {
  Future<AvatarDecoration?> getDecoration(String uid);
  Future<void> updateHat(String uid, String? hatKey);
  Future<void> updateMood(String uid, String? moodKey);
  Future<void> updateDecoration(String uid, String? hatKey, String? moodKey);
}
