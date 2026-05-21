# Feature: auth

Sign up, sign in (email/password + Google + anonymous), sign out, auth state stream.

## File Map

```
features/auth/
├── domain/
│   ├── entities/auth_user.dart                  AuthUser (id, email, displayName?, photoUrl?)
│   ├── repositories/auth_repository.dart         abstract AuthRepository
│   └── usecases/
│       ├── sign_in.dart                           SignIn
│       ├── sign_in_anonymously.dart               SignInAnonymously
│       ├── sign_in_with_google.dart               SignInWithGoogle
│       ├── sign_out.dart                          SignOut
│       └── sign_up.dart                           SignUp
├── data/
│   ├── datasources/auth_datasource.dart           AuthDatasourceImpl (FirebaseAuth + Firestore)
│   ├── models/auth_user_model.dart                @freezed AuthUserModel + toEntity()
│   └── repositories/auth_repository_impl.dart
└── presentation/
    ├── providers/auth_provider.dart               authNotifierProvider, AuthNotifier, AuthState
    └── screens/
        ├── login_screen.dart                      LoginScreen (ConsumerStatefulWidget) — dev path
        └── signup_screen.dart                     SignupScreen (ConsumerStatefulWidget) — dev path
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `authNotifierProvider` | `NotifierProvider<AuthNotifier, AuthState>` | global auth state |

## State

`AuthState` — `status` (AuthStatus), `user` (AuthUser?)

`AuthStatus` enum: `idle | loading | authenticated | unauthenticated`

## Key Behavior

- `AuthNotifier.build()` subscribes to `watchAuthState()` stream; skips stream updates while `status == loading`
- Google auth: web → `signInWithPopup`; native → `GoogleSignIn.instance.authenticate()`
- Firestore user doc written only on account creation / first sign-in: `signUp`, `signInAnonymously` (new user), `signInWithGoogle` (new user — `additionalUserInfo.isNewUser == true`). Returning `signIn` (email+password for existing users) does **not** write or overwrite the doc. Profile updates use `set(merge: true)`.
- Anonymous display name: `_anonymousName(uid)` in `auth_datasource.dart` — djb2 hash of UID → adjective+animal (225 combos). Also duplicated in `chat_datasource.dart` — extract if a third caller appears.
- `signOut()`: before delegating to the `SignOut` use case, captures the current uid and calls `prefs.remove(CacheKeys.profile(uid))` + `prefs.remove(CacheKeys.avatar(uid))` in parallel. Prevents the previous user's cached profile/avatar from appearing to the next user on the same device.

## Notes

- `screens/login_screen.dart` IS imported in `main.dart` as `ui.LoginScreen()` — used in production mode (`_useMainUI = true`) by `_MainUIAuthRouter`. It is fully wired to `authNotifierProvider` and includes offline handling (OfflineChip + all sign-in actions blocked when offline).
- `screens/signup_screen.dart` is a design-preview file not currently used in navigation.
- Production app routes (`_useMainUI = true`) do not include `/login` or `/signup` in the named routes — auth is handled by `_AuthRouter` widget
- `ref impl #2` — used as second canonical CA example after hello
