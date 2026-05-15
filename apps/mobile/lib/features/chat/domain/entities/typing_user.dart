class TypingUser {
  final String uid;
  final String displayName;
  final String? photoUrl;

  const TypingUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });
}
