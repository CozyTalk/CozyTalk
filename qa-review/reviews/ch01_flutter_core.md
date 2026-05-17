# Chapter 1 — Flutter Core & Entrypoint QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase2
> Date: 2026-05-17

## Summary

Reviewed `apps/mobile/lib/main.dart`, `apps/mobile/lib/theme/app_routes.dart`, `apps/mobile/lib/theme/app_theme.dart`, and the dual-mode architecture. The entrypoint is structurally sound — Firebase initialisation, emulator wiring, and `_AuthRouter` all behave correctly. Four low-severity findings: a file-level lint suppression masking conditional imports, a hardcoded dev-mode toggle, a dead route constant, and a minor `_AuthRouter` readability issue. No bugs, no CA violations, no security issues.

**Findings by severity:** HIGH 0 · MEDIUM 0 · LOW 3 · INFO 1

---

## Findings

### F-001 — `// ignore_for_file: unused_import` suppresses legitimate lint
- **Severity:** LOW
- **File:** `apps/mobile/lib/main.dart` line 1
- **Category:** Style
- **Description:** The file-level suppression exists because legacy screen imports (`screens/home_screen.dart`, `screens/notification_screen.dart`, etc.) are conditionally compiled via `_useMainUI`. When `_useMainUI = false` (the default), all legacy screen imports are unused. Rather than a file-level suppress, each screen import could be co-located with the `_useMainUI` branch — but Dart doesn't support conditional imports of that form, so this workaround is pragmatically acceptable.
- **Evidence:** `// ignore_for_file: unused_import` at line 1; 13 legacy screen imports that are unreachable when `_useMainUI = false`.
- **Recommendation:** Leave as-is unless the dual-mode toggle is removed. If `_useMainUI` is hardwired permanently to `true` or `false`, delete the dead branch and its imports.

---

### F-002 — `_useMainUI` is a hardcoded source constant with no `--dart-define` escape hatch
- **Severity:** LOW
- **File:** `apps/mobile/lib/main.dart` line 35
- **Category:** Style
- **Description:** `const _useMainUI = false` is a source-level toggle for legacy UI vs. backend mode. Unlike `_useEmulator`, which reads from `bool.fromEnvironment('USE_EMULATOR')`, `_useMainUI` cannot be flipped at build time without editing the file. Shipping a production build with the wrong value requires a code change, not just a build flag.
- **Evidence:** `const _useMainUI = false;` — no `fromEnvironment` wrapper.
- **Recommendation:** When the production UI is ready to ship, wire this via `bool.fromEnvironment('USE_MAIN_UI', defaultValue: false)` so CI and release builds can control it without source edits.

---

### F-003 — `AppRoutes.profileEdit` defined but never registered as a route
- **Severity:** LOW
- **File:** `apps/mobile/lib/theme/app_routes.dart` line 7
- **Category:** Style
- **Description:** `AppRoutes.profileEdit = '/profile/edit'` exists as a constant but is registered in neither the legacy-mode route map nor the backend-mode route map in `main.dart`. Navigation to `AppRoutes.profileEdit` will throw a `RouteNotFoundException`. The Profile feature exists as a full Clean Architecture implementation but is accessed via `Navigator.push` from `HelloScreen`, not via this named route.
- **Evidence:** `app_routes.dart:7`; neither route map in `main.dart` contains `AppRoutes.profileEdit`.
- **Recommendation:** Either remove the constant and navigate to `ProfileScreen` via `Navigator.push` everywhere, or register the route in the appropriate map. Do not leave a navigable constant that has no handler.

---

### F-004 — `_AuthRouter` catch-all `_` is technically correct but not explicit
- **Severity:** INFO
- **File:** `apps/mobile/lib/main.dart` line 122
- **Category:** Style
- **Description:** The switch returns `LoginScreen()` for any state other than `authenticated` and `idle`. Since `AuthStatus` has exactly four values (`idle`, `loading`, `authenticated`, `unauthenticated`), the catch-all effectively handles `loading` and `unauthenticated` together. `loading` shows the spinner (handled by `idle` case), so in practice `_` only catches `unauthenticated`. The code is functionally correct.
- **Evidence:**
  ```dart
  return switch (status) {
    AuthStatus.authenticated => const HelloScreen(),
    AuthStatus.idle => const Scaffold(body: Center(child: CircularProgressIndicator())),
    _ => const LoginScreen(),
  };
  ```
- **Recommendation:** Consider adding `AuthStatus.loading` explicitly alongside `unauthenticated` for readability, matching the pattern the `AuthStatus.loading` enum value implies. This documents intent rather than relying on the catch-all.

---

## Clean Architecture Compliance

| Layer | Imports | Violations |
|-------|---------|------------|
| `main.dart` (wiring) | Firebase SDK, Riverpod, feature providers | None — wiring is correct; Firebase SDK is used directly only for emulator setup |
| `app_routes.dart` | None | None — pure constants |
| `app_theme.dart` | Flutter only | None |

---

## What Is Working Well

- `USE_EMULATOR` correctly uses `bool.fromEnvironment` — compile-time constant, safe for production builds
- All four Firebase emulators wired to correct ports (Auth 9099, Functions 5001, Firestore 8080, RTDB 9000)
- `ProviderScope` wraps `MyApp` at the correct level
- `_AuthRouter` correctly uses `.select()` to narrow the subscription to `status` only, avoiding unnecessary rebuilds
- `AppRoutes.findingRoom` is registered in the backend-mode route map
- Legacy route imports are all real screen files that exist under `apps/mobile/lib/screens/`
