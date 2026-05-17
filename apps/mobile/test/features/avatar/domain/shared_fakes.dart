import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';
import 'package:mobile/features/avatar/domain/repositories/avatar_repository.dart';

class FakeAvatarRepository implements AvatarRepository {
  AvatarDecoration? returnDecoration;
  Exception? error;

  int getDecorationCount = 0;
  int updateHatCount = 0;
  int updateMoodCount = 0;
  int updateDecorationCount = 0;

  String? lastUid;
  String? lastHatKey;
  String? lastMoodKey;

  @override
  Future<AvatarDecoration?> getDecoration(String uid) async {
    getDecorationCount++;
    lastUid = uid;
    if (error != null) throw error!;
    return returnDecoration;
  }

  @override
  Future<void> updateHat(String uid, String? hatKey) async {
    updateHatCount++;
    lastUid = uid;
    lastHatKey = hatKey;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateMood(String uid, String? moodKey) async {
    updateMoodCount++;
    lastUid = uid;
    lastMoodKey = moodKey;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateDecoration(
    String uid,
    String? hatKey,
    String? moodKey,
  ) async {
    updateDecorationCount++;
    lastUid = uid;
    lastHatKey = hatKey;
    lastMoodKey = moodKey;
    if (error != null) throw error!;
  }
}
