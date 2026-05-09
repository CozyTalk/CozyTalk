# Code Review — PR #14

**Title:** feat: add missing screens, dialogs, assets and unify UI button style  
**Author:** pwithrae08 (Natthanicha Buasamlee)  
**Additions:** +2972 / Deletions: -82

---

## Overview

This PR delivers a significant visual layer: new screens (chat, group chat, select background, join by Room ID), five dialogs (leave room, song queue, 3-step report, user profile, members list), seven background/doodle image assets, four new named routes, and a sweeping `withOpacity → withValues(alpha:)` / `WillPopScope → PopScope` deprecation sweep. The choose-room-type screen replaces its "coming soon" placeholder with real UI.

---

## Critical Issues

### 1. Clean Architecture is not followed anywhere in this PR

Every new file is dropped under `lib/screens/` or `lib/dialogs/`. Per `CLAUDE.md` all features must live under `features/<feature>/domain|data|presentation`. This PR has:

- No domain entities, repositories, or use cases for chat
- No Riverpod providers or notifiers — all state is plain `setState`
- No datasource layer — all data is hardcoded mock values in widget state

This is the second PR in a row that builds pure-presentation screens without wiring them into the architecture. The longer this continues, the harder it becomes to retrofit. The new screens should at minimum be under `features/chat/presentation/screens/` even if the domain/data layers are stubbed.

### 2. `USE_EMULATOR` default changed from `true` to `false` (`main.dart:9`)

The CLAUDE.md explicitly says developers should set `USE_EMULATOR=true` to point at the local emulator, implying the safe default for development **is** the emulator. Flipping the default to `false` means every developer who runs `flutter run` without explicit `--dart-define` will hit the **production** Firebase project. This must be reverted.

### 3. `pubspec.lock` has transitive dependency downgrades

Three packages were downgraded (not upgraded):

| Package | Before | After |
|---|---|---|
| `characters` | 1.4.1 | 1.4.0 |
| `matcher` | 0.12.19 | 0.12.17 |
| `material_color_utilities` | 0.13.0 | 0.11.1 |

`material_color_utilities` going from 0.13 → 0.11 is a significant regression. This looks like the PR was authored against an older Flutter SDK. Run `flutter pub upgrade` to align, or pin the versions intentionally in `pubspec.yaml` if there's a reason.

### 4. `ReportDialog` is completely non-functional as a moderation tool

The Submit button in step 2 only transitions to a "Thank you" step — no HTTP call, no Firebase write. Per the core privacy requirement in CLAUDE.md:

> "if a report is filed, the Cloud Function retains the chat log for moderation review before destroying it."

Showing users a "Thank you for your report, we'll review within 24h" screen when nothing has been sent is misleading and breaks a hard product requirement. This dialog must either:
- Be clearly labelled as a UI mock/placeholder (not surfaced to users), or  
- Wire up the actual report Cloud Function call before merge

Additional issues inside the dialog:
- No validation: "Next" in step 1 advances even when zero options are selected
- The `TextField` in step 2 ("Additional Context") has no `TextEditingController`, so the text is unreadable on submit
- "Attach images" has no `onTap` handler — it is permanently static UI

### 5. Type-safety issue in `GroupChatScreen` — messages as `List<Map<String, dynamic>>`

`ChatScreen` uses a proper typed `ChatMessage` class. `GroupChatScreen` uses raw `List<Map<String, dynamic>>` maps. This is inconsistent and unsafe. Accessing `msg['time']` on warning/system messages (which have no `'time'` key) in `_buildChatBubble` will produce a null cast error at runtime.

### 6. Force-unwrap crash risk in `ChatScreen` (`chat_screen.dart:1319`)

```dart
if (msg.type == 'me') {
  return _buildBubble(msg.text, msg.time!, true);   // ← force-unwrap
}
```

`ChatMessage.time` is nullable. If a `'me'` message is ever constructed without a time (as happens silently if a caller forgets), this throws at runtime. Use a fallback: `msg.time ?? ''`.

---

## Significant Issues

### 7. Business logic in screens

`_sendMessage`, `_shuffleTopic`, `_scrollToBottom`, `_onJoinPressed` are all implemented directly in `State` subclasses. Per CLAUDE.md: *"Never put business logic inside a Screen or Notifier — that belongs in a UseCase."* For now they're mock-only, but this pattern will require a full rewrite when real Firebase integration is added.

### 8. Hardcoded Room ID in `ChatScreen` header

```dart
const Text('Room ID: AWD3V', ...)
```

Even as a mock, a literal `'AWD3V'` in the header is confusing to anyone testing the app. Should be a passed argument or a generated placeholder.

### 9. `SelectBackgroundScreen` header reads "Select room type" not "Select background"

`apps/mobile/lib/screens/select_background_screen.dart:3357`

Copy/paste error. The title label says "Select room type" when the screen is for selecting a background image.

### 10. `ChooseRoomTypeScreen` back button clears the entire navigation stack

```dart
onTap: () => Navigator.pushNamedAndRemoveUntil(
    context, AppRoutes.home, (route) => false),
```

A back button should `Navigator.pop(context)`. Clearing the entire stack means pressing back from Choose Room Type prevents the user from returning to whatever context sent them there.

### 11. `SongDialog` send button is a `Container`, not interactive

The send icon in `song_dialog.dart` is a bare `Container` with no `GestureDetector` and no `onTap`. The queue remove buttons also have no handlers. This screen is entirely static.

### 12. No tests added

Per CLAUDE.md Definition of Done: *"Widget tests for all screens."* This PR adds four screens and five dialogs with zero widget tests. At minimum, smoke-tests that each screen renders without throwing should be present.

---

## Minor Issues

### 13. Comments added to `friend.dart` explain what the code already says

```dart
String name;           // editable note/nickname you set for this friend
final String username; // their actual account username
```

Per CLAUDE.md: *"No comments explaining what code does."* These fields are self-explanatory from their names. Remove the comments.

### 14. Inline dialog in `ChooseRoomTypeScreen._showJoinGroupDialog`

The join-group dialog is built inline via an anonymous builder. All other dialogs in this PR are proper widget classes (`LeaveRoomDialog`, `ReportDialog`, etc.). Extract `_showJoinGroupDialog`'s content into a `JoinGroupDialog` widget class for consistency.

### 15. `JoinRoomIdScreen` doesn't auto-focus the first PIN field on load

Users must tap to start entering the room code. Add `autofocus: true` to the first `TextField` in the list.

### 16. Thai-language comments left in `home_screen.dart`

```dart
// ลบ border ออก และใส่เฉพาะเงา
// ปรับเงาให้ชัดขึ้นเล็กน้อยเพื่อความสวยงาม
```

These are pre-existing but this PR touches those lines. Project convention is English-only (and comments only for non-obvious WHY, not UI rationale).

### 17. `MembersListDialog` has hardcoded member list

```dart
final List<String> members = ['Somtum', 'Kaitom', 'Somjeed'];
```

This is mock data that looks real to users. Annotate it clearly as placeholder or accept a `List<String>` parameter.

### 18. `UserProfileDialog` hardcodes interest text

```dart
const Text('I love TikTok very much.\nTikTok is the best\napplication in the world.')
```

This is rendered in the profile dialog as if it were real user data. Should be either a constructor parameter or visibly marked as a placeholder.

---

## Positive Changes

- `withOpacity → withValues(alpha:)` sweep across all files is correct and complete; eliminates deprecation warnings project-wide.
- `WillPopScope → PopScope` with `onPopInvokedWithResult` is implemented correctly in `ChatScreen` — this is the right API for Flutter 3.x.
- `ColorScheme.background → surface` in `app_theme.dart` is the correct deprecation fix.
- All `StatefulWidget` subclasses properly `dispose()` their controllers, scroll controllers, and focus nodes.
- `ListView.builder` is used in both chat screens — no unbounded `children: [...]` lists.
- Asset registrations in `pubspec.yaml` are complete and match the added image files.
- `unreadCount = 0` default in `Friend` model is a reasonable ergonomic improvement.
- `notification_screen.dart`: Moving `accepted = false` to field initializer is cleaner Dart.

---

## Summary

The UI work is visually polished and demonstrates solid Flutter widget composition skills. However, this PR has three blockers that must be fixed before merge:

1. **Revert `USE_EMULATOR` default to `true`** — production safety.
2. **`ReportDialog` must not deceive users** — either remove it from navigation or wire the actual Cloud Function.
3. **Fix the `pubspec.lock` dependency downgrades** — rebuild the lock file against the correct Flutter SDK.

The architecture violations (no Clean Architecture layers, no Riverpod) are the long-term structural concern. They don't block this PR outright if the screens are understood to be pure UI mocks, but a follow-up plan for migrating them into the feature structure should be agreed upon before more screens are added in this pattern.
