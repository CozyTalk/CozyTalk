# Production Screens

All screens in `apps/mobile/lib/screens/`. These are the production frontend — wired to CA `features/` via Riverpod providers.

## Main Screens

| Class | File | Route | Extends | Integration |
|---|---|---|---|---|
| `HomeScreen` | `screens/home_screen.dart` | `/` | ConsumerStatefulWidget | ✅ integrated |
| `ChatScreen` | `screens/chat_screen.dart` | `/chat` | ConsumerStatefulWidget | ⚠️ partial — uses `shared/` providers only, not wired to `chatNotifierProvider` |
| `GroupChatScreen` | `screens/group_chat_screen.dart` | `/group-chat` | ConsumerStatefulWidget | ⚠️ partial — uses `shared/` providers only, not wired to `chatNotifierProvider` |
| `FindingRoomScreen` | `screens/finding_room_screen.dart` | `/finding-room` | ConsumerStatefulWidget | ✅ integrated — calls `join1v1Pool()` / `joinGroupRoom()` / `createCustomRoom()` based on `roomType` arg; navigates to `chatScreen` (1v1) or `groupChatScreen` (group/create) on `matched`; `cancelSearch()` on Cancel or dispose |
| `ChooseRoomTypeScreen` | `screens/choose_room_type_screen.dart` | `/choose-room-type` | StatefulWidget | ✅ integrated — back button uses `popUntil(isFirst)` to return home |
| `JoinRoomIdScreen` | `screens/join_room_id_screen.dart` | `/join-room` | StatefulWidget | ⬜ pending |
| `ProfileScreen` | `screens/profile_screen.dart` | `/profile` | ConsumerStatefulWidget | ⚠️ partial — uses `shared/user_profile_provider`, not `profileNotifierProvider` |
| `ProfileEditScreen` | `screens/profile_edit_screen.dart` | `/profile/edit` | ConsumerStatefulWidget | ⚠️ partial — uses `avatarProvider` only; not wired to `profileNotifierProvider`; not in any named-route table (navigated directly) |
| `DressUpScreen` | `screens/dress_up_screen.dart` | `/dressup` | ConsumerStatefulWidget | ⚠️ partial — uses shared `avatarProvider` (`StateProvider`), not `avatarDecorationNotifierProvider` |
| `MoodScreen` | `screens/mood_screen.dart` | `/mood` | ConsumerStatefulWidget | ⚠️ partial — uses shared `avatarProvider` (`StateProvider`), not `avatarDecorationNotifierProvider` |
| `FriendsScreen` | `screens/friends_screen.dart` | `/friends` | StatefulWidget | ⬜ pending |
| `FriendChatScreen` | `screens/friend_chat_screen.dart` | `/friends/chat` | StatefulWidget | ⬜ pending |
| `BlockedScreen` | `screens/blocked_screen.dart` | `/blocked` | StatefulWidget | ⬜ pending |
| `NotificationScreen` | `screens/notification_screen.dart` | `/notification` | StatefulWidget | ⬜ pending |
| `SelectBackgroundScreen` | `screens/select_background_screen.dart` | `/select-background` | StatefulWidget | ✅ integrated — no Riverpod needed; passes `{ roomType, roomName, bgImage, isGroup }` to `findingRoom` route; back button pops to `chooseRoomType` |
| `LoginScreen` | `screens/login_screen.dart` | — | ConsumerStatefulWidget | ⬜ design preview — never imported in `main.dart`; CA version (`features/auth/`) is used |
| `SignupScreen` | `screens/signup_screen.dart` | — | ConsumerStatefulWidget | ⬜ design preview — never imported in `main.dart`; CA version (`features/auth/`) is used |

## Admin Screens (admin role only)

| Class | File | Notes |
|---|---|---|
| `AdminConsoleScreen` | `screens/admin_console_screen.dart` | tabs: users, reports, banned |
| `AdminProfileScreen` | `screens/admin_profile_screen.dart` | user detail view |
| `AdminReportDetailScreen` | `screens/admin_report_detail_screen.dart` | report review + action |
| `AdminBanDetailScreen` | `screens/admin_ban_detail_screen.dart` | ban detail |
| `AdminUsersTab` | `screens/admin_users_tab.dart` | tab widget |
| `AdminReportsTab` | `screens/admin_reports_tab.dart` | tab widget |
| `AdminBannedTab` | `screens/admin_banned_tab.dart` | tab widget |

## Dialogs / Shared

| Class | File | Notes |
|---|---|---|
| `ThoughtBubbleDialog` | `screens/thought_bubble_dialog.dart` | |
| `FriendProfileDialog` | `screens/friend_profile_dialog.dart` | private class |
| `RemoveFriendDialog` | `screens/remove_friend_dialog.dart` | private class |
| block dialogs | `screens/block_dialogs.dart` | |
| shared widgets | `screens/widgets.dart` | |
| admin shared | `screens/admin_shared.dart` | |

## App Routes

Defined in `apps/mobile/lib/theme/app_routes.dart` as `AppRoutes` constants.
Registered in `main.dart` under `MaterialApp.routes` (production mode only, `_useMainUI = true`).

## Dev Mode Screens (features/ path)

When `_useMainUI = false`, the app uses `_AuthRouter` → `features/auth/presentation/screens/login_screen.dart` → `features/hello/presentation/screens/hello_screen.dart`.

## Integration Rules (summary)

Convert `StatefulWidget` → `ConsumerStatefulWidget`. Wire `ref.watch/read`. Never change widget tree or visual design. One screen per PR. See CLAUDE.md §9.
