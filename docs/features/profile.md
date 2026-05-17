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
