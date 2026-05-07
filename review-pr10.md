# PR #10 Review — PWfrontend1

## Overview

This PR resolves merge conflicts from `PWfrontend1` into `main` and introduces: a placeholder `HomeScreen` at the correct architecture path, a `background→surface` fix in `AppTheme`, a `unreadCount` default on `Friend`, and macOS CocoaPods scaffolding. It also commits several files that must not be in source control. +2246 / -22 lines, though the majority is generated/lock files.

---

## Critical Issues

**1. `notification_screen.dart` introduces a compile error**

The PR moves defaults to field-level and removes them from the constructor:

```dart
// after this PR
bool accepted = false;
bool declined = false;

_NotifItem({
  ...
  this.isFriendRequest = false,
  // ← this.accepted and this.declined removed
});
```

But later in the same file the constructor is called with `declined: true`:

```dart
_NotifItem(
  ...
  declined: true,   // ← not a constructor param → compile error
),
```

**Fix:** restore `this.accepted = false` and `this.declined = false` as constructor parameters (revert the constructor half of this change). The field-level defaults are redundant once the constructor params are back.

---

**2. `.dart_tool/` and `.flutter-plugins-dependencies` committed — both are in `.gitignore`**

The root `.gitignore` explicitly ignores:
```
.dart_tool/
.flutter-plugins-dependencies
```

Yet this PR adds:
- `.dart_tool/package_config.json`
- `.dart_tool/package_graph.json`
- `.dart_tool/version`
- `.flutter-plugins-dependencies`

These are machine-generated build artifacts containing absolute paths to `preawa`'s local `~/.pub-cache`. They will break every other contributor's build. Remove from the PR and add a commit that ensures `.gitignore` is respected.

---

**3. Phantom root-level `pubspec.yaml` / `pubspec.lock` / `pubspec.lock.bak`**

A bare Flutter project was accidentally initialised at the **repo root** instead of `apps/mobile/`:

```yaml
# /pubspec.yaml  (root of the monorepo — wrong)
name: cozytalk
environment:
  sdk: '>=3.3.0 <4.0.0'   # ← older SDK constraint than apps/mobile (^3.8.1)
dependencies:
  shared_preferences: ^2.2.2  # ← missing Firebase, Riverpod, go_router, etc.
```

The asset paths (`assets/images/HomeBg.png`) are relative to the repo root where those files don't exist. This file will confuse tooling and CI. Delete it along with the accompanying `pubspec.lock` and `pubspec.lock.bak`.

---

**4. `pubspec.lock.bak` committed**

Backup files belong in `.gitignore`, not VCS. Delete it.

---

**5. `pubspec.lock` transitive dep downgrades**

`apps/mobile/pubspec.lock` downgrades three transitive packages relative to `main`:

| Package | main | this PR |
|---|---|---|
| `characters` | 1.4.1 | 1.4.0 |
| `matcher` | 0.12.19 | 0.12.17 |
| `material_color_utilities` | 0.13.0 | 0.11.1 |

These appear to be a developer-machine artifact from running `flutter pub get` on a different Flutter SDK version. Run `flutter pub upgrade` against the pinned SDK (`^3.8.1`) to bring the lockfile back in sync with `main`.

---

## Moderate Issues

**6. `friend.dart` adds WHAT-comments**

```dart
String name;           // editable note/nickname you set for this friend
final String username; // their actual account username
```

CLAUDE.md: *"Never comment what the code does."* The field names already communicate this. Remove both comments.

---

**7. macOS Podfile adds an undeclared platform target**

`CLAUDE.md` states the project targets **Android and Web**. Adding `apps/mobile/macos/Podfile` implicitly extends scope to macOS without an architectural decision recorded anywhere. If macOS support is intentional, it needs to be documented. If it's a side-effect of running `pod install` locally, revert it.

---

**8. `HomeScreen` placeholder has a dead button**

```dart
ElevatedButton(
  onPressed: () {},   // ← no-op
  child: const Text('Start Chatting'),
)
```

The button should either navigate to the waiting/search flow or be replaced with a `TODO` comment that tracks the outstanding work. A silently-dead primary CTA in a committed screen is confusing.

---

## Persisting from PR #13 (unresolved in touched files)

The following issues from the PR #13 review are not addressed by this PR and remain open in the files it modifies:

**[#1] Auth completely bypassed**
The placeholder `HomeScreen` added here is not gated behind `AuthStatus.authenticated`. `_AuthRouter` in `main.dart` still routes directly to `HomeScreen` regardless of auth state.

**[#4] `Friend` model is mutable — breaks Riverpod state guarantees**
`friend.dart` still uses a plain mutable class with `String name` and `int unreadCount` as `var` fields. Must be converted to `@freezed` with `copyWith`.

**[#15] `_NotifItem` should use `@freezed`**
`notification_screen.dart` still uses a mutable plain class. The `bool accepted`/`bool declined` fields mutated via `setState` should be modelled as immutable state with `@freezed`.

**[#12] WHAT-comments throughout the codebase**
Multiple files from the previous merge still contain Thai-language and English WHAT-comments. This PR adds two more English WHAT-comments to `friend.dart` (see Issue #6 above).

**[#17] Zero test coverage**
The new `HomeScreen` widget has no widget test. The `Definition of Done` in `CLAUDE.md` requires widget tests for all screens.

---

## What This PR Gets Right

- `app_theme.dart`: `background` → `surface` is the correct Material 3 fix (`ColorScheme.background` is deprecated).
- `unreadCount = 0` default on `Friend` is the correct ergonomic choice.
- `home_screen.dart` is placed at `features/home/presentation/screens/` — the correct Clean Architecture path.

---

## Summary

| Severity | Count |
|---|---|
| Critical (blocks merge) | 5 |
| Moderate | 3 |
| Persisting from PR #13 | 5 |

The core fixes (`surface`, `unreadCount`) are good. The blockers are: the compile error in `notification_screen.dart`, the committed machine-generated files, and the phantom root `pubspec.yaml`. Those three must be fixed before this can land.
