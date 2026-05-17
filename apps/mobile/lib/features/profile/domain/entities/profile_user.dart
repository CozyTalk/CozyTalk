class ProfileUser {
  final String uid;
  final String? displayName;
  final String? interest;
  final String? thoughts;

  const ProfileUser({
    required this.uid,
    this.displayName,
    this.interest,
    this.thoughts,
  });
}
