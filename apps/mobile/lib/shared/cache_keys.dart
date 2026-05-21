class CacheKeys {
  CacheKeys._();

  static String profile(String uid) => 'profile_cache_$uid';
  static String avatar(String uid) => 'avatar_cache_$uid';
}
