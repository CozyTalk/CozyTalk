# Feature: profile

Read and update user profile fields: display name, interest, thoughts.

## File Map

```
features/profile/
├── domain/
│   ├── entities/profile_user.dart                ProfileUser (uid, displayName?, interest?, thoughts?)
│   ├── repositories/profile_repository.dart       abstract ProfileRepository
│   └── usecases/
│       ├── get_profile.dart                       GetProfile
│       ├── update_display_name.dart               UpdateDisplayName
│       ├── update_interest.dart                   UpdateInterest
│       └── update_thoughts.dart                   UpdateThoughts
├── data/
│   ├── datasources/profile_datasource.dart        ProfileDatasourceImpl (Firestore users/{uid})
│   ├── models/profile_user_model.dart             @freezed ProfileUserModel + toEntity()
│   └── repositories/profile_repository_impl.dart
└── presentation/
    ├── providers/profile_provider.dart            profileNotifierProvider, ProfileNotifier, ProfileState
    └── screens/profile_screen.dart                ProfileScreen (ConsumerStatefulWidget) — dev path
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `profileNotifierProvider` | `NotifierProvider<ProfileNotifier, ProfileState>` | profile CRUD state |

## State

`ProfileState` — `user` (ProfileUser?), `isLoading` (bool), `successField` (String?), `error` (String?)

`successField` values: `'username' | 'interest' | 'thoughts'`

## Key Behavior

- Client-side validation in the CA dev screen (`features/profile/`): username ≤ 20 chars, interest ≤ 200, thoughts ≤ 50
- Screen pre-fills text controllers on mount and on each successful save via `ref.listen`
- Firestore: `set(merge: true)` on `users/{uid}` — never overwrites unrelated fields
- Production screen `screens/profile_edit_screen.dart`: interest capped at 100 chars (not 200), no thoughts field, does not call `profileNotifierProvider` — not yet integrated
- `screens/profile_screen.dart` — read-only profile view screen (uses `shared/user_profile_provider`, not `profileNotifierProvider`)

## Offline Behavior (added PR 8)

- `load(uid)`: on successful Firestore read, writes to `ProfileCacheDatasource` (SharedPreferences, key `profile_cache_{uid}`). On Firestore exception, reads the cache — if a cached `ProfileUser` exists, sets it in state with no error; only sets `state.error` on double-miss (both Firestore and cache fail).
- Write methods (`updateDisplayName`, `updateInterest`, `updateThoughts`): call `networkInfoProvider.isConnected` before touching Firestore. If offline, set `state.error = "You're offline. Changes require a connection."` and return — repository is not called.
- Cache cleared on `signOut()` via `auth_provider.dart` to prevent cross-user data exposure on shared devices.

| New file | Description |
|---|---|
| `data/datasources/profile_cache_datasource.dart` | Abstract `ProfileCacheDatasource` + `ProfileCacheDatasourceImpl(SharedPreferences)` — `read/write/clear` keyed by uid |
| `domain/usecases/get_cached_profile.dart` | `GetCachedProfile` — reads from cache only, returns `null` on miss |
| `profileRepositoryProvider` (now public) | Previously `_profileRepositoryProvider`; made non-private so tests can override it |
