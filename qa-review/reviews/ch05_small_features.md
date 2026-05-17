# Chapter 5 — Profile, Avatar, Home, Hello Features QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase2
> Date: 2026-05-17

## Summary

Reviewed all layers of `features/profile/`, `features/avatar/`, `features/home/`, and `features/hello/` — entities, use cases, datasources, repositories, providers, screens, and tests. One HIGH finding requiring an immediate code fix: `AvatarPickerScreen` uses `FirebaseAuth.instance` directly in `initState()` and `_save()`, bypassing Riverpod and blocking widget tests. Two LOW findings: `HomeScreen`'s "Start Chatting" button is an empty stub, and `ProfileScreen` has no server-side field-length validation. Everything else — Clean Architecture compliance, sentinel pattern, test coverage — passes. **Fix for F-001 applied.**

**Findings by severity:** HIGH 1 · MEDIUM 0 · LOW 2 · INFO 1

---

## Findings

### F-001 — `AvatarPickerScreen` bypasses Riverpod with direct `FirebaseAuth.instance` calls
- **Severity:** HIGH
- **File:** `apps/mobile/lib/features/avatar/presentation/screens/avatar_picker_screen.dart` lines 48, 57
- **Category:** CA-Violation / Bug
- **Description:** `initState()` calls `FirebaseAuth.instance.currentUser?.uid` directly (line 48) and `_save()` calls it again (line 57). This hard-couples the screen to the Firebase SDK, bypasses the `authNotifierProvider` that owns auth state, and makes the screen impossible to test in widget tests without a live Firebase connection. CLAUDE.md explicitly notes this issue and defers screen tests pending a fix.
- **Evidence:**
  ```dart
  // line 48
  final uid = FirebaseAuth.instance.currentUser?.uid;
  // line 57
  final uid = FirebaseAuth.instance.currentUser?.uid;
  ```
- **Recommendation:** Replace both occurrences with `ref.read(authNotifierProvider).user?.uid` (requires adding the `auth_provider.dart` import). **Fix applied.**

---

### F-002 — `HomeScreen` "Start Chatting" button has empty `onPressed`
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/home/presentation/screens/home_screen.dart`
- **Category:** Bug / Missing Feature
- **Description:** The "Start Chatting" `ElevatedButton` has `onPressed: () {}` — a silent no-op. `HomeScreen` is only active when `_useMainUI = true`, which is the planned production mode. If `_useMainUI` is ever flipped to `true` to ship the production UI, this button will do nothing. There is no TODO comment.
- **Evidence:** `onPressed: () {}` in `HomeScreen`.
- **Recommendation:** Wire `onPressed` to navigate to the matchmaking flow (e.g., `Navigator.pushNamed(context, AppRoutes.findingRoom)` or equivalent), or add a `// TODO` comment so the gap is visible before `_useMainUI` is set to `true`.

---

### F-003 — `ProfileScreen` length constraints are client-only; no Firestore rule enforcement
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` / `firestore.rules`
- **Category:** Security
- **Description:** `ProfileScreen` validates username ≤ 20 chars, interest ≤ 200 chars, and thoughts ≤ 50 chars before calling the notifier. The Firestore `users` update rule allows `displayName`, `interest`, and `thoughts` via `affectedKeys().hasOnly(...)` but imposes no length constraints on those fields. A user who bypasses the Flutter app (e.g., via REST API) can write arbitrarily long values. For the current threat model (authenticated users only), this is low risk — but could cause UI rendering issues.
- **Evidence:** Firestore `users` update rule — no `.val().size()` checks on `displayName`, `interest`, `thoughts`.
- **Recommendation:** Add length validators to the Firestore update rule for the three profile fields (e.g., `displayName.size() <= 20`, `interest.size() <= 200`, `thoughts.size() <= 50`).

---

### F-004 — `HelloScreen` dev buttons are correct staging scaffolding
- **Severity:** INFO
- **File:** `apps/mobile/lib/features/hello/presentation/screens/hello_screen.dart`
- **Category:** Style
- **Description:** `HelloScreen` contains three dev-only buttons: "Test Matchmaking" → `MatchmakingTestScreen`, "Edit profile" → `ProfileScreen`, "Test avatar picker" → `AvatarPickerScreen`. These are appropriate for the current `_useMainUI = false` staging mode. When `_useMainUI` is flipped to `true`, `HelloScreen` is no longer the default route and these buttons become unreachable from the production flow.
- **Evidence:** Three `ElevatedButton` widgets in `HelloScreen`.
- **Recommendation:** None — this is correct for the current dev staging mode.

---

## Clean Architecture Compliance

### Profile Feature

| Layer | Imports | Violations |
|-------|---------|------------|
| `domain/entities/` | Pure Dart | None |
| `domain/repositories/` | Domain only | None |
| `domain/usecases/` | Domain only | None |
| `data/models/` | `freezed_annotation`, `json_annotation`, domain | None |
| `data/datasources/` | `cloud_firestore`, `firebase_auth` | None |
| `data/repositories/` | Domain + data | None |
| `presentation/providers/` | Riverpod, `cloud_firestore`, `firebase_auth` | None |
| `presentation/screens/` | Flutter, Riverpod, domain | None |

### Avatar Feature

| Layer | Imports | Violations |
|-------|---------|------------|
| `domain/entities/` | Pure Dart | None |
| `domain/repositories/` | Domain only | None |
| `domain/usecases/` | Domain only | None |
| `data/models/` | `freezed_annotation`, `json_annotation`, domain | None |
| `data/datasources/` | `cloud_firestore`, `firebase_auth` | None |
| `data/repositories/` | Domain + data | None |
| `presentation/providers/` | Riverpod, domain | None |
| `presentation/screens/` | Flutter, Riverpod, domain, `firebase_auth` | **VIOLATION (F-001 — fixed)**: `firebase_auth` imported directly in screen |

### Home Feature

| Layer | Imports | Violations |
|-------|---------|------------|
| `presentation/screens/` | Flutter only | None — thin hub, no data layer needed |

### Hello Feature

| Layer | Imports | Violations |
|-------|---------|------------|
| `presentation/screens/` | Flutter, Riverpod, other feature screens | None — dev staging hub |

---

## Test Coverage Assessment

### Profile

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `ProfileUser` entity | ✅ | N/A | None |
| `GetProfile` use case | ✅ | N/A | None |
| `UpdateDisplayName` use case | ✅ | N/A | None |
| `UpdateInterest` use case | ✅ | N/A | None |
| `UpdateThoughts` use case | ✅ | N/A | None |
| `ProfileRepositoryImpl` | ✅ | N/A | None |
| `ProfileState.copyWith` | ✅ | ✅ (profile, error, successField null-clear) | None |
| `ProfileNotifier` | ✅ | ✅ | None |
| `ProfileScreen` | ✅ | N/A | None |

### Avatar

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `AvatarDecoration` entity | ✅ | N/A | None |
| `GetAvatarDecoration` use case | ✅ | N/A | None |
| `UpdateHat` use case | ✅ | N/A | None |
| `UpdateMood` use case | ✅ | N/A | None |
| `UpdateDecoration` use case | ✅ | N/A | None |
| `AvatarRepositoryImpl` | ✅ | N/A | None |
| `AvatarDecorationState.copyWith` | ✅ | ✅ (decoration, error null-clear) | None |
| `AvatarDecorationNotifier` | ✅ | ✅ | None |
| `AvatarPickerScreen` | ⬜ deferred | N/A | Deferred pending F-001 fix; now unblocked |

### Home

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `HomeScreen` | ✅ | N/A | None (thin widget, no state) |

### Hello

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `HelloScreen` | ✅ | N/A | None |

---

## What Is Working Well

- `ProfileScreen` uses `ref.listen` for post-save controller prefill — correct Riverpod pattern ✅
- `ProfileState.copyWith` sentinel pattern applied to `profile?`, `error?`, `successField?` ✅
- `AvatarDatasourceImpl` uses `FieldValue.delete()` for null hat/mood keys — removes field cleanly ✅
- `AvatarDecorationNotifier._syncToSharedProvider()` propagates decoration to shared `avatarProvider` ✅
- `AvatarDecorationStatus` enum has 4 values; test uses `containsAll` + length ✅
- `_PickerRow` uses `ListView.builder` for the horizontal item list — no unbounded children ✅
- `ProfileScreen` length validation gates submit before calling notifier (client-side) ✅
- `HelloScreen` correctly uses `Navigator.push` (not named routes) to reach feature screens ✅
- No Firebase SDK in any test file across all four features ✅
