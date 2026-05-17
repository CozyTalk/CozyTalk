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

## Notes

- `screens/login_screen.dart` and `screens/signup_screen.dart` are design-preview files. `main.dart` imports the `features/auth/presentation/screens/` versions. The production `screens/` versions are never used in navigation.
- Production app routes (`_useMainUI = true`) do not include `/login` or `/signup` in the named routes — auth is handled by `_AuthRouter` widget
- `ref impl #2` — used as second canonical CA example after hello
