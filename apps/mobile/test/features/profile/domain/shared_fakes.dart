import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/domain/repositories/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  ProfileUser? returnProfile;
  ProfileUser? returnCachedProfile;
  Exception? error;

  int getProfileCount = 0;
  int getCachedProfileCount = 0;
  int updateDisplayNameCount = 0;
  int updateInterestCount = 0;
  int updateThoughtsCount = 0;

  String? lastUid;
  String? lastDisplayName;
  String? lastInterest;
  String? lastThoughts;

  @override
  Future<ProfileUser> getProfile(String uid) async {
    getProfileCount++;
    lastUid = uid;
    if (error != null) throw error!;
    return returnProfile!;
  }

  @override
  Future<ProfileUser?> getCachedProfile(String uid) async {
    getCachedProfileCount++;
    lastUid = uid;
    return returnCachedProfile;
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    updateDisplayNameCount++;
    lastUid = uid;
    lastDisplayName = displayName;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateInterest(String uid, String interest) async {
    updateInterestCount++;
    lastUid = uid;
    lastInterest = interest;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {
    updateThoughtsCount++;
    lastUid = uid;
    lastThoughts = thoughts;
    if (error != null) throw error!;
  }
}
