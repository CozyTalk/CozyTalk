# PR #13 Review — Feature/home

## Overview

This PR introduces a complete home screen UI layer: `HomeScreen`, `NotificationScreen`, `ProfileScreen`, `BlockedScreen`, `DressUpScreen`, `MoodScreen`, `FriendsScreen`, and `FriendChatScreen`, plus a theme system (`AppColors`/`AppTheme`/`AppRoutes`), a `Friend` model, 27 PNG assets, and iOS CocoaPods wiring. +3742 / -188 lines.

---

## Critical Issues

**1. Auth completely bypassed**
`main.dart` removes `_AuthRouter` and routes directly to `HomeScreen`. The entire auth flow (login, anonymous, Google) is now unreachable. This needs to be restored — the home screen should be gated behind `AuthStatus.authenticated`.

**2. Violates Clean Architecture**
All new screens live in `lib/screens/` (flat), not under `features/<feature>/domain/data/presentation`. This bypasses the project's established architecture. New screens need to either follow the feature structure or there needs to be an explicit architectural decision documented.

**3. Unbounded `ListView` with `children` in `friend_chat_screen.dart`**
```dart
// line 1192-1200
ListView(
  children: [
    ...
    ..._messages.map(_buildMessageBubble),  // CLAUDE.md forbids this
  ],
)
```
Must use `ListView.builder` with `itemCount`.

**4. `Friend` model is mutable — breaks Riverpod state guarantees**
```dart
// friends_screen.dart
_friends[index].unreadCount = 0;   // direct mutation
_friends[index].name = newNote;    // direct mutation
```
All data models must use `@freezed` with `copyWith`. `Friend` appears to be a plain mutable class.

**5. `go_router` added but not used**
The pubspec adds `go_router` but navigation uses `Navigator.pushNamed`. Either use `go_router` for type-safe routing or remove the dependency.

**6. `profileEdit` route declared but never registered**
`AppRoutes.profileEdit = '/profile/edit'` is in `app_routes.dart` but not in `main.dart`'s routes map.

---

## Moderate Issues

**7. Mock data embedded directly in screen files**
`_mockFriends`, `_mockConversations`, hardcoded blocked users, and notification items (including Thai names) live as top-level globals in screen files. This data belongs in a test fixture or at minimum a separate `mock_data.dart` file, not entangled with the view layer.

**8. `_buildCustomAppBar` duplicated across 6+ screens**
`BlockedScreen`, `DressUpScreen`, `MoodScreen`, `NotificationScreen`, `ProfileScreen`, `FriendsScreen` all copy-paste the same ~60-line `_buildCustomAppBar`. Extract to a shared widget in `widgets.dart`.

**9. Duplicate `PillButton`**
`widgets.dart` exports a public `PillButton`; `friend_profile_dialog.dart` defines a private `_PillButton` with identical logic. Use the shared one.

**10. Mixed deprecated API usage**
Some files use `withOpacity()` (deprecated), others use `withValues(alpha:)` (current). Should be consistent throughout — use `withValues`.

**11. Hardcoded email in `profile_screen.dart`**
```dart
Text('Sekloso@gmail.com')   // should be auth state
```
Should read from `authNotifierProvider`.

---

## Style / Convention

**12. Thai-language comments**
Multiple files contain Thai comments (e.g., `// พื้นหลังสีครีม`, `// แสดงจำนวนผู้ที่ถูกบล็อก`). CLAUDE.md says comments should only explain non-obvious WHY. All of these explain WHAT and should be removed.

**13. Files missing trailing newline**
`blocked_screen.dart`, `dress_up_screen.dart`, `mood_screen.dart`, `profile_screen.dart` all end without a final newline.

**14. `Color(0xFF695959)` hardcoded in multiple screens**
This is `AppColors.brownDeep`. Should reference the constant everywhere.

**15. `_NotifItem` should use `@freezed`**
Plain mutable class with `bool accepted; bool declined;` fields. Should follow the Freezed pattern.

---

## Security

**16. Report button is non-functional (`friend_chat_screen.dart`)**
The red flag icon in the chat header has no `onTap` handler — it can't be pressed. For a safety-critical feature, this needs to be either wired up or explicitly noted as a tracked TODO.

---

## Tests

**17. Zero test coverage**
8+ new screens, a theme system, and a model were added with no widget tests. CLAUDE.md defines _Definition of Done_ as requiring widget tests for all screens.

---

## Summary

| Severity | Count |
|---|---|
| Critical (blocks merge) | 6 |
| Moderate | 5 |
| Style / Convention | 4 |
| Security | 1 |
| Missing tests | 1 |

The UI work itself looks solid and the design system (`AppColors`, `AppTheme`, `AppRoutes`) is a clean addition. The main blockers are: auth bypass, architecture placement, the unbounded `ListView`, and mutable `Friend` model.
