# Chapter 1 Plan — Flutter Core & Entrypoint

## Scope

| File | Why |
|------|-----|
| `apps/mobile/lib/main.dart` | Entrypoint, Firebase init, routing, dual-mode toggle |
| `apps/mobile/lib/theme/app_colors.dart` | Color palette — accessibility contrast ratios |
| `apps/mobile/lib/theme/app_theme.dart` | Material theme — typography, component defaults |
| `apps/mobile/lib/theme/app_routes.dart` | Named route definitions — completeness, dead routes |
| `apps/mobile/.env` / `.env.example` | Environment config — secrets, USE_EMULATOR default |
| `apps/mobile/pubspec.yaml` | Dependency versions — outdated, conflicts |
| `apps/mobile/analysis_options.yaml` | Linter config — missing rules, disabled checks |
| `apps/mobile/firebase_options.dart` | Generated Firebase config — prod vs emulator misuse |

---

## Checks to Perform

### 1.1 Firebase Initialization
- [ ] `Firebase.initializeApp()` is called exactly once before any Firebase access.
- [ ] `DefaultFirebaseOptions.currentPlatform` is used (not hardcoded options).
- [ ] Emulator connection code is gated on `USE_EMULATOR` compile-time constant, not runtime.
- [ ] All four emulator services (Auth, Functions, Firestore, RTDB) are connected before widgets render.
- [ ] Emulator connection is NOT attempted in production builds (`--dart-define=USE_EMULATOR=false`).

### 1.2 Dual-Mode Toggle (`_useMainUI`)
- [ ] `_useMainUI` is a hardcoded `const` — confirm it cannot be flipped by user input.
- [ ] Both branches compile and produce coherent routes — no missing route references.
- [ ] `_useMainUI = true` (legacy UI) doesn't accidentally import Firebase-free screens that depend on Firebase.
- [ ] `_useMainUI = false` (production mode) — `_AuthRouter` is the only routing logic, no duplication.
- [ ] `_useMainUI` is documented in CLAUDE.md with accurate description of each mode.

### 1.3 Auth Router (`_AuthRouter`)
- [ ] Covers all four `AuthStatus` values: `idle`, `loading`, `authenticated`, `unauthenticated`.
- [ ] `idle` shows a loading spinner — not `LoginScreen` (would cause flash).
- [ ] `authenticated` → `HelloScreen` is correct for current dev mode; check production path.
- [ ] Transitions are not animated in a way that leaks screen state.
- [ ] No Firebase calls made inside `_AuthRouter` directly — it only watches the provider.

### 1.4 Route Definitions
- [ ] All routes referenced in `MaterialApp.routes` or `GoRouter` are defined.
- [ ] No dead routes (defined but never navigated to).
- [ ] Routes that require auth are protected — unauthenticated users can't deep-link to chat screens.
- [ ] `AppRoutes` constants match actual route strings.

### 1.5 Theme
- [ ] `AppTheme.theme` vs inline `ThemeData` — confirm only one is used per UI mode.
- [ ] Color contrast ratios checked for primary text / background combos (WCAG AA = 4.5:1 minimum).
- [ ] `TextTheme` sizes use `sp`-style relative sizing or Material defaults — no hardcoded pixel sizes.
- [ ] Dark mode: is it supported? If not, is that intentional and documented?

### 1.6 Dependencies (pubspec.yaml)
- [ ] All packages are at non-pre-release versions (no `rc`, `alpha`, `beta` in production deps).
- [ ] Firebase suite versions are all from the same compatible generation (check firebase_core vs firebase_auth vs cloud_firestore compatibility matrix).
- [ ] `flutter_riverpod` and `riverpod_annotation`/`riverpod_generator` are version-compatible.
- [ ] `freezed` and `freezed_annotation` are version-compatible.
- [ ] `json_serializable` and `json_annotation` are version-compatible.
- [ ] No unused dependencies in pubspec.yaml.
- [ ] `flutter_secure_storage` — confirm it's actually used (search for imports).
- [ ] `image_picker` — confirm it's actually used (search for imports).
- [ ] `go_router` — confirm it's used and not shadowed by `MaterialApp.routes`.

### 1.7 Linter Config (analysis_options.yaml)
- [ ] `flutter_lints` is included.
- [ ] No rules are explicitly disabled that should be active.
- [ ] `avoid_print` is active.
- [ ] `curly_braces_in_flow_control_structures` is active.
- [ ] No unnecessary `// ignore:` directives in main.dart or theme files.

### 1.8 Environment / Secrets
- [ ] `.env.example` has no real secret values.
- [ ] `.env` is in `.gitignore`.
- [ ] `firebase_options.dart` does not contain API keys that should be secret (Firebase web API keys are public by design — confirm this is understood and security is via rules, not key secrecy).
- [ ] `--dart-define` pattern is documented for production builds.

---

## Files to Read in Full

1. `apps/mobile/lib/main.dart`
2. `apps/mobile/lib/theme/app_theme.dart`
3. `apps/mobile/lib/theme/app_routes.dart`
4. `apps/mobile/pubspec.yaml`
5. `apps/mobile/analysis_options.yaml`
6. `apps/mobile/.env.example`

---

## Expected Findings Categories

- Route-auth protection gaps (HIGH if chat screens reachable without auth)
- Missing `AuthStatus.loading` handling in router (MEDIUM)
- Outdated dependency versions (LOW-MEDIUM)
- Unused pubspec dependencies (LOW)
- Color contrast failures (MEDIUM per WCAG requirement)
- `_useMainUI` toggle documentation drift (LOW)

---

## Output

Write findings to `reviews/ch01_flutter_core.md` using the standard review format defined in `MASTER_QA_PLAN.md`.
