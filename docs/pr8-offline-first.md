# PR 8 — Offline-First Support

## Context

Users should navigate CozyTalk freely while offline. Only actions that touch the Privacy-by-Design boundary (matchmaking, chat) require connectivity. Profile and avatar data are cached in SharedPreferences so the app looks normal offline. Screens that truly can't function show a styled card that matches the app's visual language — no red errors, no crashes.

**Privacy-by-Design hard boundary:** Room state, chat messages, matchmaking status are never cached. Only `users/{uid}` profile fields (displayName, interest, thoughts, hatKey, moodKey) are stored locally — no encryption keys, no session data.

**Decisions:**
- Cache: `SharedPreferences` (already in pubspec). No Hive.
- New package: `connectivity_plus` only.
- Mood/DressUp: allow navigation (screens are local-only), fail with SnackBar on return if save fails.
- FriendsScreen: add OfflineCard for future-proofing.

---

## All Files

### New lib files (10)

| Path | Purpose |
|---|---|
| `lib/shared/network_info.dart` | Abstract `NetworkInfo` + `NetworkInfoImpl` wrapping `connectivity_plus`. Abstraction is mandatory so tests never import the plugin. |
| `lib/shared/connectivity_provider.dart` | `networkInfoProvider` (Provider) + `isOnlineProvider` (StreamProvider\<bool\>). |
| `lib/shared/prefs_provider.dart` | `sharedPreferencesProvider = Provider<SharedPreferences>` — throws if not overridden. Overridden in `main.dart` and in every test that exercises cache code. |
| `lib/shared/cache_keys.dart` | `CacheKeys.profile(uid)` → `'profile_cache_$uid'` · `CacheKeys.avatar(uid)` → `'avatar_cache_$uid'`. |
| `lib/shared/offline_chip.dart` | Small white pill with wifi-off icon + "Offline" text. `SizedBox.shrink()` when online. |
| `lib/shared/offline_card.dart` | Full content-area white card, wifi-off icon, "You're offline" heading + subtitle. App card style. |
| `lib/features/profile/data/datasources/profile_cache_datasource.dart` | Abstract + SharedPreferences impl. `read/write/clear` keyed by uid. |
| `lib/features/avatar/data/datasources/avatar_cache_datasource.dart` | Same pattern for avatar. |
| `lib/features/profile/domain/usecases/get_cached_profile.dart` | Delegates to `repo.getCachedProfile(uid)`. |
| `lib/features/avatar/domain/usecases/get_cached_decoration.dart` | Delegates to `repo.getCachedDecoration(uid)`. |

### Modified lib files (14)

| Path | Change |
|---|---|
| `apps/mobile/pubspec.yaml` | Add `connectivity_plus: ^6.x`. |
| `lib/main.dart` | `await SharedPreferences.getInstance()` before `runApp`; add `sharedPreferencesProvider` override to `ProviderScope`. |
| `lib/features/profile/domain/repositories/profile_repository.dart` | Add `Future<ProfileUser?> getCachedProfile(String uid);` |
| `lib/features/profile/data/repositories/profile_repository_impl.dart` | Inject `ProfileCacheDatasource _cache` (2nd arg). Write-through on success. Fallback to cache on Firestore throw. Rethrow on double-miss. |
| `lib/features/avatar/domain/repositories/avatar_repository.dart` | Add `Future<AvatarDecoration?> getCachedDecoration(String uid);` |
| `lib/features/avatar/data/repositories/avatar_repository_impl.dart` | Inject `AvatarCacheDatasource _cache`. Write-through on success. Return null on double-miss (avatar null is valid). |
| `lib/features/profile/presentation/providers/profile_provider.dart` | Wire cache datasource + use case. `load()` falls back to cache on throw. Write methods blocked offline with error message. |
| `lib/features/avatar/presentation/providers/avatar_decoration_provider.dart` | Same pattern. Repository handles fallback transparently. Write methods blocked offline. |
| `lib/features/auth/presentation/providers/auth_provider.dart` | `signOut()`: capture uid, clear profile + avatar cache keys from SharedPreferences before delegating. |
| `lib/screens/home_screen.dart` | Add `OfflineChip` between `_TopBar` and `Expanded`. Add `ref.listen` for avatar error SnackBar. |
| `lib/screens/profile_screen.dart` | Add `OfflineChip` below custom app bar. |
| `lib/screens/profile_edit_screen.dart` | Add `OfflineChip`. Gray Save button offline. SnackBar on tap when offline. |
| `lib/screens/finding_room_screen.dart` | Show `OfflineCard` instead of tuk-tuk animation when offline. Cancel button stays visible. |
| `lib/screens/friends_screen.dart` | Convert to `ConsumerStatefulWidget`. Show `OfflineCard` when offline. |

---

## Build Wave Ordering

```
Wave 1  pubspec.yaml + network_info.dart + prefs_provider.dart + cache_keys.dart + connectivity_provider.dart
Wave 2  profile_cache_datasource.dart + avatar_cache_datasource.dart
Wave 3  ProfileRepository + AvatarRepository (add new abstract methods)
Wave 4  ProfileRepositoryImpl + AvatarRepositoryImpl (inject cache, fallback logic)
Wave 5  get_cached_profile.dart + get_cached_decoration.dart
Wave 6  main.dart (SharedPreferences init + ProviderScope override)
Wave 7  profile_provider.dart + avatar_decoration_provider.dart (wire cache + online guard)
Wave 8  auth_provider.dart (signout cache clear)
Wave 9  offline_chip.dart + offline_card.dart
Wave 10 home_screen + profile_screen + profile_edit_screen + finding_room_screen + friends_screen
Wave 11 All tests
```

---

## Key Implementation Details

### `NetworkInfo` abstraction
```dart
abstract class NetworkInfo {
  Stream<bool> get onConnectivityChanged;
  Future<bool> get isConnected;
}
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;
  NetworkInfoImpl(this._connectivity);
  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged
          .map((r) => r.any((c) => c != ConnectivityResult.none));
  @override
  Future<bool> get isConnected async {
    final r = await _connectivity.checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }
}
```

### `isOnlineProvider` — fail-open rule
All call sites: `.valueOrNull ?? true`. Means:
- App startup (stream not yet emitted) → treated as online → no chip flash.
- Write guards see `null` → treat as online → allow the write attempt.
- Exception path in `load()` handles captive portal / false-positive online.

### `sharedPreferencesProvider` override pattern
```dart
// main.dart
final prefs = await SharedPreferences.getInstance();
runApp(ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: const MyApp(),
));

// In any test that exercises cache
SharedPreferences.setMockInitialValues({});
final prefs = await SharedPreferences.getInstance();
final container = ProviderContainer(overrides: [
  sharedPreferencesProvider.overrideWithValue(prefs),
  networkInfoProvider.overrideWithValue(_FakeNetworkInfo(isOnline: false)),
]);
```

### `ProfileRepositoryImpl.getProfile` — write-through + fallback
```dart
Future<ProfileUser> getProfile(String uid) async {
  try {
    final model = await _datasource.getProfile(uid);
    try { await _cache.write(uid, model); } catch (_) {}
    return model.toEntity();
  } catch (e) {
    final cached = await _cache.read(uid);
    if (cached != null) return cached.toEntity();
    rethrow;
  }
}
```

### Avatar `getDecoration` — silent null-on-miss (not rethrow)
```dart
Future<AvatarDecoration?> getDecoration(String uid) async {
  try {
    final model = await _datasource.getDecoration(uid);
    if (model != null) try { await _cache.write(uid, model); } catch (_) {}
    return model?.toEntity();
  } catch (_) {
    return (await _cache.read(uid))?.toEntity();
  }
}
```

### `ProfileNotifier.load` — offline fallback
```dart
Future<void> load(String uid) async {
  if (state.isLoading) return;
  state = state.copyWith(isLoading: true, error: null, successField: null);
  try {
    final profile = await ref.read(_getProfileProvider)(uid);
    state = state.copyWith(isLoading: false, profile: profile);
  } catch (e) {
    try {
      final cached = await ref.read(_getCachedProfileProvider)(uid);
      if (cached != null) {
        state = state.copyWith(isLoading: false, profile: cached);
        return;
      }
    } catch (_) {}
    state = state.copyWith(isLoading: false, error: e.toString());
  }
}
```

### Write guard (both notifiers)
```dart
if (!(ref.read(isOnlineProvider).valueOrNull ?? true)) {
  state = state.copyWith(error: "You're offline. Changes require a connection.");
  return;
}
```

### Auth `signOut` cache clear
```dart
Future<void> signOut() async {
  final uid = state.user?.uid;
  if (uid != null) {
    final prefs = ref.read(sharedPreferencesProvider);
    await Future.wait([
      prefs.remove(CacheKeys.profile(uid)),
      prefs.remove(CacheKeys.avatar(uid)),
    ]);
  }
  await ref.read(_signOutProvider)();
  state = state.copyWith(status: AuthStatus.unauthenticated, user: null, error: null);
}
```

---

## Tests — Complete List (70 tests)

### New test files (9) + Updated test files (7)

**Fake class conventions:** `_FakeXxx` (private, in same file) for datasources and notifiers; `FakeXxx` (public, in `shared_fakes.dart`) for repositories. `_FakeNetworkInfo` appears in every offline test file.

---

#### `test/features/profile/data/datasources/profile_cache_datasource_test.dart` (NEW)
`setUp`: `SharedPreferences.setMockInitialValues({})`, construct impl.

1. read returns null when key missing
2. write then read returns correct model — assert uid/displayName/interest/thoughts
3. write then clear makes read return null
4. uid isolation: write uid-A, read uid-B returns null
5. read handles malformed JSON without throwing → returns null

#### `test/features/avatar/data/datasources/avatar_cache_datasource_test.dart` (NEW)

6. read returns null when key missing
7. write then read returns correct model — assert hatKey + moodKey
8. write then clear makes read return null
9. uid isolation: write uid-A, read uid-B returns null

#### `test/features/profile/data/repositories/profile_repository_impl_test.dart` (UPDATE)
Add `_FakeProfileCacheDatasource`. Update `setUp` to `ProfileRepositoryImpl(datasource, cacheDs)`.

10. getProfile success: writes to cache (writeCount == 1)
11. getProfile success: returns entity from datasource model
12. getProfile success: cache write error is swallowed — does not throw
13. getProfile datasource throws, cache hit: returns cached entity, no rethrow
14. getProfile datasource throws, cache miss: rethrows original exception
15. getCachedProfile returns entity when cache has data
16. getCachedProfile returns null when cache empty
17. updateDisplayName does NOT call cache (writeCount stays 0)
18. updateInterest does NOT call cache
19. updateThoughts does NOT call cache
20. Existing tests — unchanged, constructor call updated only

#### `test/features/avatar/data/repositories/avatar_repository_impl_test.dart` (UPDATE)
Add `_FakeAvatarCacheDatasource`. Update `setUp`.

21. getDecoration success with non-null model: writes to cache
22. getDecoration success with null model: does NOT write to cache
23. getDecoration datasource throws, cache hit: returns cached entity
24. getDecoration datasource throws, cache miss: returns null (not rethrow)
25. getCachedDecoration returns entity when cache has data
26. getCachedDecoration returns null when cache empty
27. updateHat does NOT call cache
28. updateMood does NOT call cache
29. updateDecoration does NOT call cache

#### `test/features/profile/domain/usecases/get_cached_profile_test.dart` (NEW)

30. forwards uid to repository — getCachedProfileCount == 1, lastUid == 'u1'
31. returns user from repository
32. returns null when repository returns null

#### `test/features/avatar/domain/usecases/get_cached_decoration_test.dart` (NEW)

33. forwards uid to repository
34. returns decoration from repository
35. returns null on cache miss

#### `test/features/profile/domain/shared_fakes.dart` (UPDATE)
Add: `returnCachedProfile`, `getCachedProfileCount`, `getCachedProfile(uid)`.

#### `test/features/avatar/domain/shared_fakes.dart` (UPDATE)
Add: `returnCachedDecoration`, `getCachedDecorationCount`, `getCachedDecoration(uid)`.

#### `test/features/profile/presentation/providers/profile_notifier_offline_test.dart` (NEW)
Uses `ProviderContainer` + `_FakeNetworkInfo` + `SharedPreferences.setMockInitialValues({})`.

36. load() online success: profile set, no error
37. load() Firestore throws, cache hit: profile set to cached, no error in state
38. load() Firestore throws, cache miss: error set in state
39. updateDisplayName offline: state.error contains "offline", repo.updateDisplayNameCount == 0
40. updateInterest offline: repo.updateInterestCount == 0
41. updateThoughts offline: repo.updateThoughtsCount == 0
42. updateDisplayName online: repo.updateDisplayNameCount == 1

#### `test/features/avatar/presentation/providers/avatar_decoration_notifier_offline_test.dart` (NEW)

43. load() success: decoration set, status idle
44. load() Firestore throws, cache returns decoration: status idle with cached decoration
45. load() double miss: status idle with null decoration (avatar null is valid, not error)
46. updateHat offline: status=error, offline message, repo NOT called
47. updateMood offline: same
48. updateDecoration offline: same
49. updateHat online: repo called

#### `test/shared/connectivity_provider_test.dart` (NEW)

50. AsyncLoading before stream emits
51. emits true when stream emits true
52. emits false when stream emits false
53. transitions: true then false → final value false

#### `test/screens/home_screen_test.dart` (UPDATE)
Add `networkInfoProvider` override to `_buildScreen` helper.

54. OfflineChip visible when offline — find.text('Offline') → findsOneWidget
55. OfflineChip not visible when online — find.text('Offline') → findsNothing
56. avatar error SnackBar shown when avatarDecorationState.error is set

#### `test/screens/profile_screen_test.dart` (UPDATE)

57. OfflineChip visible when offline
58. OfflineChip not visible when online

#### `test/screens/profile_edit_screen_test.dart` (NEW)

59. Save button shows green when online
60. Save button shows grey when offline
61. Tapping Save offline shows SnackBar, does not call notifier (updateDisplayNameCount == 0)
62. Tapping Save online calls notifier (updateDisplayNameCount == 1)
63. OfflineChip visible when offline

#### `test/screens/finding_room_screen_test.dart` (NEW)

64. OfflineCard visible when offline — find.byType(OfflineCard) → findsOneWidget
65. OfflineCard not visible when online
66. Tuk-tuk Image.asset absent when offline

#### `test/screens/friends_screen_test.dart` (NEW)

67. Renders without crash when online
68. OfflineCard visible when offline
69. OfflineCard not visible when online
70. Mock friend entries visible when online

---

## "What Could Break" Mitigations

| Risk | Mitigation |
|---|---|
| `connectivity_plus` `MissingPluginException` in tests | `NetworkInfo` abstraction — plugin never imported in any test file |
| `isOnlineProvider` `AsyncLoading` → chip flashes on startup | `.valueOrNull ?? true` everywhere — fail-open |
| Captive portal / false-positive online | `load()` catches all exceptions, not just when stream says offline |
| `SharedPreferences` `Map<dynamic,dynamic>` | `Map<String,dynamic>.from(jsonDecode(...))` before `fromJson` in every cache read |
| Cache write fails mid-flight | Inner try/catch swallows write errors — read path unaffected |
| User A's cache bleeds to User B | `signOut()` clears both cache keys before Firebase signout |
| `ProfileRepositoryImpl` constructor change breaks existing tests | `setUp` updated: `ProfileRepositoryImpl(datasource, cacheDs)` |
| `AvatarRepositoryImpl` same | Same fix in avatar repository test |
| Avatar null-on-double-miss absorbed silently | Test 45 explicitly asserts this is expected, code comment documents it |

---

## IRL Testing Guide

After implementation, test these scenarios manually on a device or emulator. Disable network by toggling airplane mode or disabling the emulator network adapter.

---

### Before going offline (first-time setup)

1. Sign in with any method
2. Navigate to **Profile** → your name/interest should load
3. Navigate to **HomeScreen** → avatar should be visible
4. Go back online — these steps seed the cache for offline tests

---

### Screen-by-screen offline tests

#### HomeScreen
**How to test:** Sign in online, navigate to HomeScreen, then toggle airplane mode.

**Expect:**
- A small white pill labeled **"Offline"** appears below the top bar
- Your username, avatar, and thought bubble are still visible (from cache)
- All navigation buttons (Find Room, Friends, Profile icons) are still tappable
- The bell notification badge may disappear (friends data not cached — expected)

**Chip disappears when:** You re-enable network and the stream emits `true` (may take 1–2 seconds)

---

#### ProfileScreen
**How to test:** From HomeScreen tap the profile icon while offline.

**Expect:**
- **"Offline"** chip below the "Profile" header
- Your cached displayName and interest are visible
- "Blocked" and "Contact us" cards render normally
- Log out button still works (cache is cleared on signout)

---

#### ProfileEditScreen
**How to test:** From ProfileScreen tap the edit icon while offline.

**Expect:**
- **"Offline"** chip below the "Edit Profile" header
- Username and interest fields are pre-filled from cached data
- Save button is **grayed out** (light gray background, gray text)
- Tapping Save shows a SnackBar: **"You're offline — changes can't be saved"**
- The notifier is NOT called — no loading spinner appears
- Going back online: button turns green again, save works normally

---

#### MoodScreen
**How to test:** From HomeScreen tap the mood button (avatar area) while offline.

**Expect:**
- Screen opens normally — you can browse and select a mood
- No offline indicator on this screen (it's purely local)
- Tapping a mood and returning to HomeScreen triggers the save attempt

**After returning to HomeScreen (offline):**
- A floating SnackBar appears: **"You're offline. Changes require a connection."**
- Your avatar mood does NOT change (save was blocked)
- Going back online and selecting a mood again saves successfully

---

#### DressUpScreen
**How to test:** Same as MoodScreen — tap the hat/accessory button while offline.

**Expect:** Same behavior as MoodScreen — screen opens freely, hat selection fails on return with SnackBar.

---

#### ChooseRoomTypeScreen
**How to test:** Tap "Find a Room" from HomeScreen while offline.

**Expect:**
- Screen opens normally — you can see 1v1, Group, Create options
- No offline indicator on this screen (navigation only)
- Tapping "Join" or "Start" navigates forward to SelectBackgroundScreen

---

#### SelectBackgroundScreen
**How to test:** Tap through ChooseRoomTypeScreen → SelectBackground while offline.

**Expect:**
- Background images load normally (local assets)
- No offline indicator
- Tapping "Continue" navigates to FindingRoomScreen

---

#### FindingRoomScreen
**How to test:** Continue through SelectBackground → FindingRoomScreen while offline.

**Expect:**
- **No tuk-tuk animation** — replaced by a centered white card
- Card shows: wifi-off icon + **"You're offline"** (bold) + **"This feature requires a connection."**
- The Cancel button at the bottom is still visible and works (navigates back)
- No crash, no red error, no spinner

**Going back online mid-screen:** The OfflineCard disappears and the tuk-tuk animation resumes. Matching also resumes if the matchmaking notifier retries.

---

#### JoinRoomIdScreen
**How to test:** ChooseRoomTypeScreen → Join by ID while offline.

**Expect:**
- Can type a room code normally (keyboard input is local)
- Tapping "Join" navigates to FindingRoomScreen
- FindingRoomScreen then shows the OfflineCard (block happens there, not here)

---

#### BlockedScreen
**How to test:** Profile → Blocked while offline.

**Expect:**
- Works completely normally — uses mock data, no network calls
- No offline indicator needed or shown

---

#### FriendsScreen
**How to test:** Bottom nav / notification icon → Friends while offline.

**Expect:**
- **No friend list** — replaced by the same centered white card
- Card shows: wifi-off icon + **"You're offline"** + subtitle
- Works consistently with FindingRoomScreen

---

#### ChatScreen / GroupChatScreen
**How to test:** Start a chat while online, then toggle airplane mode mid-conversation.

**Expect:**
- App does NOT crash
- Firebase RTDB and Firestore handle their own reconnection internally
- Typing indicator and message delivery may freeze briefly
- When network returns, messages sync automatically
- **No offline card is shown** — this is intentional (don't interfere with Firebase reconnect)

---

#### LoginScreen / SignupScreen
**How to test:** Sign out, then attempt login while offline.

**Expect:**
- Form renders normally
- Tapping Sign In / Sign Up attempts Firebase Auth
- Firebase Auth returns an error ("Authentication failed. Please try again.")
- Error is shown in the existing red error text below the form
- This is existing behavior — no change in this PR

---

### Sign-out / sign-in isolation test

**How to test:**
1. Sign in as User A (online), let profile load
2. Sign out
3. Immediately toggle airplane mode
4. Sign in as User B (on same device)
5. Navigate to Profile and HomeScreen while offline

**Expect:**
- User B sees **no data** (or their own cached data if they've signed in before)
- User A's name/avatar/interest are NOT visible
- OfflineChip shows because Firestore fetch failed and no cache exists for User B yet

---

### Reconnect flow

**How to test:** Go offline, browse around, re-enable network.

**Expect:**
- OfflineChip disappears within 1–2 seconds of reconnection
- Navigating to ProfileScreen or HomeScreen and triggering a load refreshes from Firestore
- Avatar and profile update to latest server values
- Save buttons go green again

---

## Automated Verification

```bash
cd apps/mobile

# Full test suite (all existing + new)
flutter test

# Targeted new test areas
flutter test test/shared/
flutter test test/features/profile/data/datasources/
flutter test test/features/avatar/data/datasources/
flutter test test/features/profile/presentation/providers/profile_notifier_offline_test.dart
flutter test test/features/avatar/presentation/providers/avatar_decoration_notifier_offline_test.dart
flutter test test/screens/finding_room_screen_test.dart
flutter test test/screens/friends_screen_test.dart
flutter test test/screens/profile_edit_screen_test.dart

# Static analysis
flutter analyze
```
