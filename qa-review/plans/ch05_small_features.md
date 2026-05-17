# Chapter 5 Plan — Profile, Avatar, Home, Hello Features

## Scope

```
apps/mobile/lib/features/profile/   (all layers)
apps/mobile/lib/features/avatar/    (all layers)
apps/mobile/lib/features/home/      (presentation only — no domain/data)
apps/mobile/lib/features/hello/     (all layers — reference implementation)

apps/mobile/test/features/profile/
apps/mobile/test/features/avatar/
apps/mobile/test/features/home/
apps/mobile/test/features/hello/
```

---

## Checks to Perform

### 5.1 Profile Feature

#### 5.1.1 Domain
- [ ] `profile_user.dart` entity: `uid` (required), `displayName?`, `interest?`, `thoughts?` — matches CLAUDE.md spec.
- [ ] No Flutter/Firebase imports.
- [ ] `profile_repository.dart` — abstract interface; 4 methods: `getProfile`, `updateDisplayName`, `updateInterest`, `updateThoughts`.

#### 5.1.2 Data
- [ ] `profile_datasource.dart` reads from `users/{uid}`.
- [ ] All writes use `set(merge: true)` — handles legacy accounts.
- [ ] Individual field updates: only the target field is written (not the whole doc).
- [ ] Map normalization applied on reads.

#### 5.1.3 Presentation
- [ ] `ProfileState` fields: `profile?`, `isLoading`, `error?`, `successField?` — all match CLAUDE.md.
- [ ] Sentinel pattern for `profile`, `error`, `successField` (all nullable).
- [ ] `ProfileScreen` pre-fills controllers from cached state on mount.
- [ ] `ref.listen` used for post-save controller updates (not `ref.watch` side effects).
- [ ] Client-side length validation BEFORE calling notifier:
  - username ≤ 20 chars
  - interest ≤ 200 chars
  - thoughts ≤ 50 chars
- [ ] Save buttons show loading state while `isLoading`.
- [ ] No Firebase SDK in screen.

#### 5.1.4 Tests
- [ ] `profile_user_test.dart` — construction, optional fields null.
- [ ] `profile_user_model_test.dart` — fromJson all/null/extra; toEntity correct.
- [ ] `profile_repository_impl_test.dart` — 4 methods, call counts, arg forwarding, exception propagation.
- [ ] All 4 use case tests.
- [ ] `profile_state_test.dart` — sentinel for profile, error, successField with explicit null.
- [ ] `profile_screen_test.dart` — renders, validation error shown, valid submit calls notifier, loading state.
- [ ] `shared_fakes.dart` — covers all 4 repository methods.
- [ ] No Firebase SDK in tests.

---

### 5.2 Avatar Feature

#### 5.2.1 Domain
- [ ] `avatar_decoration.dart` entity: `hatKey?`, `moodKey?` — both nullable; null = no selection.
- [ ] No Flutter/Firebase imports.
- [ ] `avatar_repository.dart` — abstract; 4 methods: `getAvatarDecoration`, `updateHat`, `updateMood`, `updateDecoration`.

#### 5.2.2 Data
- [ ] `avatar_datasource.dart` reads/writes `users/{uid}.hatKey` and `users/{uid}.moodKey`.
- [ ] Uses `FieldValue.delete()` for null hat/mood (removes field from Firestore doc).
- [ ] Creates user doc with minimal required fields if it doesn't exist (first-time avatar set).
- [ ] `updateDecoration` — two writes (hat + mood) are atomic? Or two separate writes? Race condition risk.

#### 5.2.3 Presentation
- [ ] `AvatarDecorationStatus` enum: `idle | loading | saving | error` — all four values.
- [ ] `AvatarDecorationState` fields: `status`, `decoration?`, `error?` — sentinel for nullable fields.
- [ ] `AvatarDecorationNotifier` calls `_syncToSharedProvider()` after successful load.
- [ ] `avatarProvider` shared in-memory provider — confirm it's a global `StateProvider` or similar.
- [ ] **KNOWN ISSUE (from CLAUDE.md):** `AvatarPickerScreen.initState` calls `FirebaseAuth.instance.currentUser?.uid` directly — this bypasses Riverpod and blocks widget testing. Flag as HIGH and document the fix pattern.
- [ ] 6 hat options displayed: Cap, Beanie, Witch, Glasses, Cat Headband, Crown.
- [ ] 6 mood options: Happy, Thrilled, Sad, Lonely, Silly, Grumpy.
- [ ] Selection is staged locally before save.
- [ ] Single save call applies both hat and mood changes.

#### 5.2.4 Tests
- [ ] `avatar_decoration_test.dart` — construction, both nulls default null.
- [ ] `avatar_decoration_model_test.dart` — fromJson/toEntity.
- [ ] `avatar_repository_impl_test.dart` — all 4 methods.
- [ ] All 4 use case tests.
- [ ] `avatar_decoration_state_test.dart` — sentinel for decoration, error.
- [ ] **Screen test deferred** (documented in CLAUDE.md — confirm this is still the case).
- [ ] `shared_fakes.dart` — covers all 4 repository methods.
- [ ] Flag if test exists for `AvatarPickerScreen` — it shouldn't yet (or if it exists without proper mocking, flag as CRITICAL).

---

### 5.3 Home Feature

#### 5.3.1 Presentation Only
- [ ] `HomeScreen` — `StatelessWidget` (no state).
- [ ] Has AppBar and "Start Chatting" button.
- [ ] Only active when `_useMainUI = true` — confirm this is not navigated to in production mode.
- [ ] "Start Chatting" routes to correct matchmaking flow (or is it still a stub?).
- [ ] No Firebase imports, no Riverpod imports (it's a StatelessWidget).

#### 5.3.2 Tests
- [ ] `home_screen_test.dart` — renders AppBar, renders "Start Chatting" button.
- [ ] Test uses `ProviderScope` if any providers are watched (even indirectly).

---

### 5.4 Hello Feature (Reference Implementation)

#### 5.4.1 Domain
- [ ] `hello_message.dart` entity — pure Dart.
- [ ] `hello_repository.dart` — abstract interface.
- [ ] `call_hello.dart` use case — single `call()` method.

#### 5.4.2 Data
- [ ] `hello_datasource.dart` — calls `hello` Cloud Function.
- [ ] `hello_message_model.dart` — `@freezed`, `fromJson`, `toEntity()`.
- [ ] `hello_repository_impl.dart` — model→entity conversion.

#### 5.4.3 Presentation
- [ ] `hello_provider.dart` — DI wiring + state/notifier.
- [ ] `HelloState` — has `isLoading`, `result?`, `error?` (or similar); sentinel pattern for nullable fields.
- [ ] `HelloScreen` — currently the dev hub; has "Test Matchmaking" button and "Edit Profile" button.
- [ ] Buttons route correctly to `MatchmakingTestScreen` and `ProfileScreen`.

#### 5.4.4 Tests
- [ ] `hello_message_test.dart` — construction.
- [ ] `hello_message_model_test.dart` — fromJson/toEntity.
- [ ] `hello_repository_impl_test.dart` — call count, arg forwarding.
- [ ] `call_hello_test.dart` — arg forwarding, exception propagation.
- [ ] `hello_state_test.dart` — sentinel tests.
- [ ] `hello_screen_test.dart` — renders, button actions.

---

## Cross-Feature Checks

- [ ] `layered_avatar.dart` (shared/) uses `avatarProvider` — confirm it reads from the shared in-memory provider synced by `AvatarDecorationNotifier`.
- [ ] `avatar_overlay.dart` — is it a sub-widget of `layered_avatar.dart` or standalone?
- [ ] Profile and Avatar are accessed from `HelloScreen` in dev mode — confirm routes are registered.
- [ ] `AppRoutes.profile` route is defined and navigates to `ProfileScreen`.

---

## Files to Read in Full

1. `apps/mobile/lib/features/profile/` — all source files
2. `apps/mobile/lib/features/avatar/` — all source files
3. `apps/mobile/lib/features/home/presentation/screens/home_screen.dart`
4. `apps/mobile/lib/features/hello/` — all source files
5. `apps/mobile/lib/shared/layered_avatar.dart`
6. All test files for all four features

---

## Expected Findings Categories

- `AvatarPickerScreen` FirebaseAuth direct call (HIGH — known, document fix pattern)
- Screen test for avatar deferred — confirm it's correctly deferred not accidentally missing (INFO)
- `updateDecoration` two-write race condition (MEDIUM)
- `FieldValue.delete()` for null avatar fields — confirm behavior in Firestore rules (MEDIUM)
- HelloScreen navigation routing gaps (LOW)
- Missing sentinel tests for any nullable state field (HIGH per standard)

---

## Output

Write findings to `reviews/ch05_small_features.md`.
