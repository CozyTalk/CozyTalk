# Chapter 6 Plan — Legacy UI Screens & Shared Widgets

## Scope

```
apps/mobile/lib/screens/          (all legacy UI screens)
apps/mobile/lib/dialogs/          (all dialog files)
apps/mobile/lib/shared/           (all shared widgets)
apps/mobile/lib/models/           (friend.dart — shared model)
```

---

## Context

These screens are **design-preview implementations** — not yet wired to Clean Architecture features. Per CLAUDE.md: "When integrating, route legacy screens to the features/ providers rather than reimplementing logic."

The QA goal here is NOT to fully test these screens as production code. Instead:
1. Catalog what exists, what is complete, and what is a stub.
2. Find any patterns that would create obstacles when integrating with Clean Architecture.
3. Find security or data-handling issues that could be imported into the production layer.
4. Identify dead code that should be removed.

---

## Checks to Perform

### 6.1 Screen Inventory & Status

For each screen, determine:
- [ ] Is it a stub (empty/placeholder) or has real UI?
- [ ] Does it import Firebase SDK directly? (This is acceptable in legacy screens but must be flagged for future integration.)
- [ ] Does it contain business logic that belongs in use cases?
- [ ] Does it use hardcoded strings instead of state from providers?
- [ ] Does it have `print()` calls?

Screens to catalog:
- `home_screen.dart` — navigation hub
- `profile_screen.dart` — profile viewer/editor (legacy version)
- `profile_edit_screen.dart` — profile edit (legacy)
- `notification_screen.dart` — notifications
- `blocked_screen.dart` — blocked users list
- `friends_screen.dart` — friends list
- `friend_chat_screen.dart` — DM/friend chat
- `friend_profile_dialog.dart` — friend profile popup
- `dress_up_screen.dart` — avatar customization (legacy)
- `mood_screen.dart` — mood selection (legacy)
- `chat_screen.dart` — 1v1 chat (legacy UI version)
- `group_chat_screen.dart` — group chat
- `choose_room_type_screen.dart` — room type selection
- `select_background_screen.dart` — background selection
- `join_room_id_screen.dart` — custom room join
- `finding_room_screen.dart` — matchmaking spinner
- `block_dialogs.dart` — block confirmation
- `remove_friend_dialog.dart` — remove friend confirmation
- `thought_bubble_dialog.dart` — thought bubble display
- `admin_console_screen.dart` — admin dashboard
- `admin_profile_screen.dart` — admin user profile
- `admin_users_tab.dart` — admin user list
- `admin_reports_tab.dart` — admin reports list
- `admin_report_detail_screen.dart` — admin report detail
- `admin_banned_tab.dart` — admin bans list
- `admin_ban_detail_screen.dart` — admin ban detail
- `admin_shared.dart` — shared admin utilities
- `widgets.dart` — misc widgets

### 6.2 Admin Screens (Security-Critical)
- [ ] `admin_console_screen.dart` — does it enforce `role == 'admin'` check before displaying?
- [ ] Admin screens: is the route protected from non-admin users (both in routing and in Firestore reads)?
- [ ] Admin actions (ban, unban, delete user): are they calling Cloud Functions or writing Firestore directly? Direct Firestore writes from client for admin actions are acceptable only if Firestore rules enforce admin role.
- [ ] `admin_reports_tab.dart` — reads from `reports/{reportId}` — confirm security rules enforce admin-only.
- [ ] No hardcoded UIDs or admin credentials.

### 6.3 Chat Screens (Data Handling)
- [ ] `chat_screen.dart` (legacy) — does it share message data format with `features/chat/`?
- [ ] `group_chat_screen.dart` — group message format — does it match `chat_rooms/` collection schema?
- [ ] Message lists: uses `ListView.builder` not `ListView(children: [...])`?
- [ ] Messages encrypted in transit (legacy screen may be unencrypted — flag if so).
- [ ] `finding_room_screen.dart` — cancels pool join correctly?

### 6.4 Shared Widgets

For each shared widget:
- [ ] `layered_avatar.dart` — reads from `avatarProvider`; renders hat + mood overlays; pure UI (no Firebase).
- [ ] `avatar_overlay.dart` — sub-widget; pure UI.
- [ ] `pill_button.dart` — reusable button; no state.
- [ ] `press_bounce_btn.dart` — interactive button with animation; no external state.
- [ ] `friend_message_popup.dart` — reads from which provider? Firebase directly?
- [ ] `user_profile.dart` — reads from which provider? Firebase directly?

### 6.5 `models/friend.dart`
- [ ] Pure Dart model? Or has Firebase/Freezed?
- [ ] If it has `fromJson`/`toJson`, is it hand-rolled (violation) or generated?
- [ ] Is this model used in a legacy screen only, or also in features/?

### 6.6 Route Registration
- [ ] All routes referenced in `app_routes.dart` have corresponding screen classes.
- [ ] All routes used in `MaterialApp.routes` (`main.dart`) are defined in `app_routes.dart`.
- [ ] No routes that exist in `app_routes.dart` but are never navigated to in either UI mode.

### 6.7 Unbounded ListView Check
- [ ] Search all `screens/` and `dialogs/` files for `ListView(children:` pattern.
- [ ] Flag every occurrence as HIGH performance violation.

### 6.8 `print()` Usage
- [ ] Search all `screens/` and `dialogs/` files for `print(` calls.
- [ ] Each is a LOW-severity finding (linter should catch, but legacy code may pre-date linter enforcement).

---

## Files to Read

Read each screen file at least superficially (first 50 lines) to determine status (stub vs real). Read in full:
- Admin screens (security-critical)
- `chat_screen.dart` and `group_chat_screen.dart` (data handling)
- `finding_room_screen.dart` (matchmaking integration point)
- `shared/` directory (all files — they're used across the app)
- `models/friend.dart`

---

## Deliverable: Screen Inventory Table

The review file must include a table:

| Screen | Status | Firebase Direct | Business Logic in Screen | print() | ListView Violation | Notes |
|--------|--------|-----------------|--------------------------|---------|---------------------|-------|
| ... | Stub / Real UI | Yes / No | Yes / No | Yes / No | Yes / No | ... |

---

## Expected Findings Categories

- Admin routes unprotected (CRITICAL if any non-admin can reach them)
- Unencrypted messages in legacy chat screen (HIGH)
- `ListView(children: [...])` for messages (HIGH)
- Business logic in legacy screens (MEDIUM — tech debt for integration)
- `print()` calls throughout (LOW)
- Dead routes (LOW — cleanup)
- `friend.dart` with hand-rolled JSON (MEDIUM if found)

---

## Output

Write findings to `reviews/ch06_legacy_ui.md`.
