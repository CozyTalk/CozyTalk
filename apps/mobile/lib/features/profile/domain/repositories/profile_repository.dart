import '../entities/profile_user.dart';

abstract class ProfileRepository {
  Future<ProfileUser> getProfile(String uid);
  Future<void> updateDisplayName(String uid, String displayName);
  Future<void> updateInterest(String uid, String interest);
  Future<void> updateThoughts(String uid, String thoughts);
}
