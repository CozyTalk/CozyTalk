# Chapter 2 — Auth Feature QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase2
> Date: 2026-05-17

## Summary

Reviewed all layers of `features/auth/` — domain entities, repository interface, use cases, data models, `AuthDatasourceImpl`, `AuthRepositoryImpl`, `AuthNotifier`/`AuthState`, `LoginScreen`, `SignUpScreen`, and all auth test files. One HIGH security-rule bug discovered: the Firestore users create rule's `hasOnly()` allowlist does not include `interest`, which the datasource writes at signup, meaning all client-side user document creation will be rejected by Firestore rules in production. One MEDIUM tech-debt finding: `_anonymousName()` is duplicated. Everything else passes: sentinel pattern, loading guard, platform split for Google Sign-In, stream subscription lifecycle, and test coverage.

**Findings by severity:** HIGH 1 · MEDIUM 1 · LOW 1 · INFO 1

---

## Findings

### F-001 — Firestore create rule rejects datasource-written `interest` field
- **Severity:** HIGH
- **File:** `firestore.rules` line 46–49 / `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart` lines 47–55, 86–97, 120–130
- **Category:** Bug / Security
- **Description:** `AuthDatasourceImpl` writes `'interest': ''` in the initial `users/{uid}` document for all three sign-in flows (anonymous, Google new user, email sign-up). The Firestore security rule for `users` document creation uses `hasOnly(['uid', 'email', 'role', 'createdAt', 'lastSeen', 'displayName', 'photoUrl', 'hatKey', 'moodKey'])`. The `interest` field is NOT in this list. Firestore's `hasOnly()` rejects the write if the document contains any key outside the list. All three creation paths will fail with `permission-denied` in production (rules are enforced on the client SDK). The emulator may not surface this if emulator rules are out of sync with production rules.
- **Evidence:**
  ```dart
  // auth_datasource.dart line ~47 (signInAnonymously)
  await _firestore.collection('users').doc(user.uid).set({
    'uid': user.uid,
    'role': 'user',
    'displayName': displayName,
    'interest': '',        // ← not in create hasOnly list
    'hatKey': null,
    'moodKey': null,
    'createdAt': FieldValue.serverTimestamp(),
    'lastSeen': FieldValue.serverTimestamp(),
  });
  ```
  ```
  // firestore.rules line 46
  && request.resource.data.keys().hasOnly([
      'uid', 'email', 'role', 'createdAt', 'lastSeen',
      'displayName', 'photoUrl', 'hatKey', 'moodKey'  // 'interest' missing
  ]);
  ```
- **Recommendation:** Add `'interest'` to the `hasOnly()` allowlist in the `users` create rule. Also verify whether `'thoughts'` should be creatable (it is not written at creation time, so omitting it is correct). **Fix applied to `firestore.rules`.**

---

### F-002 — `_anonymousName()` duplicated in auth and chat datasources
- **Severity:** MEDIUM
- **File:** `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart` line 167 / `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart` (same function)
- **Category:** Style / Tech-Debt
- **Description:** The `_anonymousName(String uid, Set<String> taken)` function — 45 lines including the word lists — is copy-pasted verbatim in both datasource files. CLAUDE.md documents this and states it should be extracted to a shared utility when a third caller appears. As of this review there are two callers.
- **Evidence:** Identical function bodies in both files; `CLAUDE.md` footnote: "Duplicated from `chat_datasource.dart` — extract to a shared utility if a third caller appears."
- **Recommendation:** No immediate action required (CLAUDE.md is tracking this). Extract to `apps/mobile/lib/shared/anonymous_name.dart` when the avatar or profile feature needs it.

---

### F-003 — `signInAnonymously` omits `email` field; inconsistency with other paths
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart` lines 47–55
- **Category:** Style
- **Description:** `signInAnonymously` does not write an `email` field (correct — anonymous users have no email). `signUp` and `signInWithGoogle` (new user) do write `email`. The users collection schema in `CLAUDE.md` lists `email` as a field, but the create rule allows it optionally. This is functionally correct; the minor inconsistency is that Firestore docs for anonymous users will simply lack the `email` key, which is fine as long as all readers handle the absent field.
- **Evidence:** `auth_datasource.dart:47–55` — no `email` key in the anonymous set.
- **Recommendation:** No change required. Confirm all readers of `users/{uid}.email` null-check or use `?.` access.

---

### F-004 — `AuthNotifier.build()` stream skip-while-loading is correct but undocumented inline
- **Severity:** INFO
- **File:** `apps/mobile/lib/features/auth/presentation/providers/auth_provider.dart` line 79
- **Category:** Style
- **Description:** The `watchAuthState` listener checks `if (state.status == AuthStatus.loading) return;` to avoid a race between the stream's async emission and an in-flight sign-in action. This is correct and documented in CLAUDE.md, but the in-file comment explaining why the guard exists is missing.
- **Evidence:** `auth_provider.dart:79` — guard present without a WHY comment.
- **Recommendation:** Add a one-line comment: `// Skip stream updates while a sign-in action is in-flight to avoid races.`

---

## Clean Architecture Compliance

| Layer | Imports | Violations |
|-------|---------|------------|
| `domain/entities/` | Pure Dart | None |
| `domain/repositories/` | Pure Dart | None |
| `domain/usecases/` | Domain only | None |
| `data/models/` | `json_annotation`, domain | None |
| `data/datasources/` | `firebase_auth`, `cloud_firestore`, `google_sign_in` | None — correct layer for SDK calls |
| `data/repositories/` | Domain + data | None |
| `presentation/providers/` | Riverpod, Firebase SDK (for DI wiring only) | None |
| `presentation/screens/` | Flutter, Riverpod, domain entities | None |

---

## Test Coverage Assessment

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `AuthUser` entity | ✅ | N/A | None |
| `AuthUserModel` | ✅ | N/A | None |
| `SignUp` use case | ✅ | N/A | None |
| `SignIn` use case | ✅ | N/A | None |
| `SignOut` use case | ✅ | N/A | None |
| `SignInAnonymously` use case | ✅ | N/A | None |
| `SignInWithGoogle` use case | ✅ | N/A | None |
| `AuthRepositoryImpl` | ✅ | N/A | None |
| `AuthState.copyWith` | ✅ | ✅ (user/error null-clear) | None |
| `AuthNotifier` | ✅ | ✅ | None |
| `LoginScreen` | ✅ | N/A | None |
| `SignUpScreen` | ✅ | N/A | None |

---

## What Is Working Well

- Sentinel pattern correctly applied to `user?` and `error?` in `AuthState.copyWith`
- Loading guard in stream listener prevents sign-in race conditions
- Platform split (`kIsWeb`) for `signInWithGoogle` — web uses popup, native uses `GoogleSignIn.instance.authenticate()`
- `additionalUserInfo?.isNewUser == true` guards prevent overwriting existing user docs on returning Google users
- `_authErrorMessage()` centralizes Firebase error code mapping — no raw codes exposed to UI
- `ref.onDispose(() => _sub?.cancel())` correctly handles stream lifecycle
- All test fakes are hand-written with no Firebase SDK imports
- `callCount` tracked in notifier fakes so tests assert behavior, not just rendered UI
