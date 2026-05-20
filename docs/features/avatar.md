# Feature: avatar

Hat and mood decoration for the user's avatar. Syncs to a shared provider for use across screens.

## File Map

```
features/avatar/
├── domain/
│   ├── entities/avatar_decoration.dart              AvatarDecoration (hatKey?, moodKey?)
│   ├── repositories/avatar_repository.dart           abstract AvatarRepository
│   └── usecases/
│       ├── get_avatar_decoration.dart                GetAvatarDecoration
│       ├── update_decoration.dart                    UpdateDecoration
│       ├── update_hat.dart                           UpdateHat
│       └── update_mood.dart                          UpdateMood
├── data/
│   ├── datasources/avatar_datasource.dart            AvatarDatasourceImpl (Firestore users/{uid})
│   ├── models/avatar_decoration_model.dart           @freezed AvatarDecorationModel + toEntity()
│   └── repositories/avatar_repository_impl.dart
└── presentation/
    ├── providers/avatar_decoration_provider.dart     avatarDecorationNotifierProvider
    └── screens/avatar_picker_screen.dart             AvatarPickerScreen (ConsumerStatefulWidget)
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `avatarDecorationNotifierProvider` | `NotifierProvider<AvatarDecorationNotifier, AvatarDecorationState>` | load/save decoration |
| `avatarProvider` | `NotifierProvider<AvatarNotifier, AvatarState>` | shared snapshot for other screens — defined in `shared/avatar_overlay.dart` |

## State

`AvatarDecorationState` — `decoration` (AvatarDecoration?), `status` (AvatarDecorationStatus)

`AvatarDecorationStatus` enum: `idle | loading | saving | error`

## Key Behavior

- Null fields use `FieldValue.delete()` to remove Firestore keys (not write `null`)
- After save, notifier calls `_syncToSharedProvider()` to push new values into `avatarProvider`
- Auth UID sourced from `ref.read(authNotifierProvider).user?.uid` — never `FirebaseAuth.instance.currentUser`
- `avatarProvider` (`NotifierProvider<AvatarNotifier, AvatarState>`) lives in `apps/mobile/lib/shared/avatar_overlay.dart` — shared across screens. The avatar feature syncs into it via `_syncToSharedProvider()` after save.
- Production screen is `screens/dress_up_screen.dart` + `screens/mood_screen.dart` (not yet fully integrated)

## Offline Behavior (added PR 8)

- `load(uid)`: on successful Firestore read, writes to `AvatarCacheDatasource` (SharedPreferences, key `avatar_cache_{uid}`). On Firestore exception, returns the cached decoration — or `null` if also missing (avatar null is a valid "no decoration" state; never surfaces as an error).
- Write methods (`updateHat`, `updateMood`, `updateDecoration`): call `_resetErrorIfAny()` first (clears any lingering error so `HomeScreen`'s `ref.listen` re-fires on every repeated offline attempt), then check `networkInfoProvider.isConnected`. If offline, set `state.status = AvatarDecorationStatus.error` with the offline message — repository not called.
- Cache cleared on `signOut()` via `auth_provider.dart`.

| New file | Description |
|---|---|
| `data/datasources/avatar_cache_datasource.dart` | Abstract `AvatarCacheDatasource` + `AvatarCacheDatasourceImpl(SharedPreferences)` |
| `domain/usecases/get_cached_decoration.dart` | `GetCachedDecoration` — reads from cache only, returns `null` on miss |
| `avatarRepositoryProvider` (now public) | Previously `_avatarRepositoryProvider`; made non-private for test overriding |
