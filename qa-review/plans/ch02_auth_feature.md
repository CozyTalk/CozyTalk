# Chapter 2 Plan — Auth Feature

## Scope

```
apps/mobile/lib/features/auth/
├── data/
│   ├── datasources/auth_datasource.dart
│   ├── models/auth_user_model.dart (.freezed.dart, .g.dart)
│   └── repositories/auth_repository_impl.dart
├── domain/
│   ├── entities/auth_user.dart
│   ├── repositories/auth_repository.dart
│   └── usecases/ (sign_in, sign_up, sign_out, sign_in_anonymously, sign_in_with_google)
└── presentation/
    ├── providers/auth_provider.dart
    └── screens/ (login_screen.dart, signup_screen.dart)

apps/mobile/test/features/auth/ (all test files)
```

---

## Checks to Perform

### 2.1 Domain Layer Purity
- [ ] `auth_user.dart` — no Flutter or Firebase imports.
- [ ] `auth_repository.dart` — abstract interface only, no concrete types.
- [ ] Each use case — imports only domain entities and repository interface.
- [ ] `AuthUser` entity has no `toJson`/`fromJson` (that belongs in the model).

### 2.2 AuthStatus Enum Completeness
- [ ] Four values exist: `idle | loading | authenticated | unauthenticated`.
- [ ] Every switch on `AuthStatus` in presentation/providers is exhaustive.
- [ ] `_AuthRouter` handles all four states (see Ch01 cross-check).

### 2.3 Auth Datasource (`auth_datasource.dart`)
- [ ] `signUp` — writes Firestore user doc with all required fields (`uid`, `email`, `role`, `createdAt`, `lastSeen`, `displayName`, `interest`, `hatKey`, `moodKey`, `thoughts`).
- [ ] `signInAnonymously` — also writes Firestore user doc.
- [ ] `signInWithGoogle` — writes doc only when `additionalUserInfo.isNewUser == true`.
- [ ] Google sign-in platform split: `kIsWeb` → `signInWithPopup`; native → `GoogleSignIn.instance.authenticate()`.
- [ ] `_anonymousName(uid, {})` is called correctly — djb2 hash producing adjective+animal.
- [ ] All Firestore writes use `set(merge: true)` for profile updates.
- [ ] `watchAuthState()` wraps `FirebaseAuth.authStateChanges()` — no extra filtering logic that could drop events.
- [ ] No raw exceptions swallowed — all Firebase exceptions propagate or are mapped to typed errors.
- [ ] `Map` from Firebase normalized via `Map<String, dynamic>.from(data as Map)` before use.

### 2.4 AuthUserModel (Freezed)
- [ ] `@freezed` annotation present; `_$AuthUserModel` mixin used.
- [ ] `fromJson` factory delegates to generated `_$AuthUserModelFromJson`.
- [ ] `toEntity()` extension maps all fields correctly to `AuthUser`.
- [ ] Nullable fields in model match nullable fields in entity.
- [ ] No hand-rolled JSON serialization.

### 2.5 AuthRepositoryImpl
- [ ] Implements all methods declared in `AuthRepository` interface.
- [ ] Converts model → entity before returning to callers.
- [ ] Doesn't catch exceptions from datasource unless re-throwing typed exceptions.
- [ ] `watchAuthState()` stream: model→entity conversion applied in-stream.

### 2.6 Use Cases
- [ ] Each use case has a single `call()` / `execute()` method.
- [ ] Arguments forwarded exactly — no accidental mutation or default substitution.
- [ ] Result returned — not swallowed.
- [ ] Exception from repository propagates unchanged.
- [ ] No business logic (branching, validation) in use cases that belongs in datasource or presenter.

### 2.7 AuthState & AuthNotifier (`auth_provider.dart`)
- [ ] `AuthState` fields: `status`, `user?`, `error?`.
- [ ] `copyWith` uses sentinel pattern for both nullable fields (`user`, `error`).
- [ ] `AuthNotifier.build()` subscribes to `watchAuthState()` stream.
- [ ] Stream listener skips state updates while `status == loading` (documented behavior).
- [ ] Loading guard at top of each submit action (`isLoading` check).
- [ ] Errors set `status = unauthenticated`, not `idle`.
- [ ] `signOut` action transitions through `loading` then `unauthenticated` — not direct.
- [ ] DI chain: `_datasourceProvider` → `_repositoryProvider` → `_usecaseProvider` — correct order, no circular refs.

### 2.8 Login Screen
- [ ] Validates email format and non-empty password before calling notifier.
- [ ] Loading guard: submit button disabled while `isLoading`.
- [ ] Error displayed from `state.error` — not a hardcoded string.
- [ ] "Continue as Guest" calls `signInAnonymously` use case.
- [ ] Google sign-in button calls `signInWithGoogle` use case.
- [ ] Navigation to sign-up screen works.
- [ ] No `print()` calls.
- [ ] No Firebase SDK imports.

### 2.9 Sign-Up Screen
- [ ] Validates: email format, password length, password match (if confirm field exists).
- [ ] Loading guard present.
- [ ] Error displayed from `state.error`.
- [ ] On success, navigation handled by `_AuthRouter` (not imperative navigation from screen).
- [ ] No `print()` calls.

### 2.10 Test Coverage
- [ ] `auth_user_test.dart` — construction, optional fields default null.
- [ ] `auth_user_model_test.dart` — fromJson all fields, with nulls, extra keys; toEntity() correct.
- [ ] `auth_repository_impl_test.dart` — call counts, arg forwarding, model→entity, exception propagation.
- [ ] Each use case test — args forwarded, result returned, exception propagates.
- [ ] `auth_state_test.dart` — copyWith preserves fields, sets nullables, **clears nullables with explicit null** (sentinel guard).
- [ ] `login_screen_test.dart` — renders key widgets, validation errors, valid submit calls notifier, error/loading states.
- [ ] `signup_screen_test.dart` — same coverage.
- [ ] `shared_fakes.dart` — `FakeAuthRepository` covers all interface methods.
- [ ] No Firebase SDK in any test file.
- [ ] No mockito.
- [ ] Fresh fake in each `setUp`.

---

## Cross-Feature Dependencies to Check
- `auth_datasource.dart` contains `_anonymousName` function — check if `chat_datasource.dart` has a duplicate (CLAUDE.md says yes — flag as tech debt).
- `_AuthRouter` in `main.dart` watches `authNotifierProvider` — verify the provider name matches.

---

## Files to Read in Full

1. `apps/mobile/lib/features/auth/domain/entities/auth_user.dart`
2. `apps/mobile/lib/features/auth/domain/repositories/auth_repository.dart`
3. `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart`
4. `apps/mobile/lib/features/auth/data/models/auth_user_model.dart`
5. `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart`
6. `apps/mobile/lib/features/auth/presentation/providers/auth_provider.dart`
7. `apps/mobile/lib/features/auth/presentation/screens/login_screen.dart`
8. `apps/mobile/lib/features/auth/presentation/screens/signup_screen.dart`
9. All test files in `apps/mobile/test/features/auth/`

---

## Expected Findings Categories

- `_anonymousName` duplication between auth and chat datasource (MEDIUM — tech debt)
- Missing sentinel test for `AuthState.copyWith(user: null)` (HIGH per test rules)
- Firebase SDK leaked into domain layer (CRITICAL if found)
- Google sign-in platform split missing `kIsWeb` guard (HIGH if found)
- Firestore doc creation missing required fields (HIGH)
- Screen `print()` calls (LOW)

---

## Output

Write findings to `reviews/ch02_auth_feature.md`.
