## Summary

`ReportDialog` was a UI-only stub that advanced directly to the success step without calling any backend. This PR wires it to `reportNotifierProvider` and threads `sessionId` / `reportedUserId` through every screen and dialog that exposes a report button (`ChatScreen`, `GroupChatScreen`, `FriendChatScreen`, `UserProfileDialog`, `MembersPanelBody`). It also fixes a group-chat race condition where hop-in system messages showed the raw Firebase Auth display name (Gmail address) instead of the Firestore profile username.

## Type of Change

- [x] Bug fix (non-breaking change that fixes an issue)
- [x] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Refactor (no behavior change, improves structure or readability)
- [ ] Chore (dependency update, config, CI, tooling)
- [ ] Docs

## Related Issues

N/A

## Changes

- **`dialogs/report_dialog.dart`**: Converted from `StatefulWidget` to `ConsumerStatefulWidget`; added required `sessionId` and `reportedUserId` params; Submit calls `reportNotifierProvider` (selectType, setReason, setContextText, addImage, submit); step 2 shows `reportState.error` and `isSubmitting` spinner; step 3 only entered on `state.isSuccess`.
- **`data/datasources/report_datasource.dart`**: Added `HttpsCallableOptions(timeout: Duration(seconds: 30))` to the `reportSession` CF call to prevent an indefinite loading spinner.
- **`dialogs/user_profile_dialog.dart`**: Added optional `sessionId` and `reportedUserId` fields; report button saves `Navigator.of(context)` before `pop()` and uses `nav.context` for the subsequent `showDialog`.
- **`dialogs/members_list_dialog.dart`** (`MembersPanelBody`): Added optional `sessionId` field; report button wires to `ReportDialog` with the member UID.
- **`screens/chat_screen.dart`**: Passes `sessionId: roomId` and `reportedUserId: partner?.uid` to `UserProfileDialog`.
- **`screens/group_chat_screen.dart`**: Threads `roomId` through extracted build methods; passes `sessionId` / `reportedUserId` to `UserProfileDialog` and `MembersPanelBody`; fixes race condition by guarding `_memberNameCache` writes and `_pendingJoinUids` flushes behind `_memberInterestCache.containsKey(uid)` in all three listeners.
- **`screens/friend_chat_screen.dart`**: Threads `reportedUserId` through `_buildHeader`; passes `sessionId: _friend.chatRoomId` to `ReportDialog`.

## Testing

**Manual steps to verify:**

1. In a 1v1 chat, tap partner avatar, open profile card, tap report icon, complete 3-step ReportDialog — doc created in Firestore `reports/` and dialog reaches step 3.
2. In a group chat, tap member avatar in banner or bubble — same flow.
3. Open members panel, tap report on any member — same flow.
4. In a friend chat, tap header report icon — same flow.
5. Confirm Submit spinner clears on success or error (no infinite spinner).
6. In a group chat with two users, hop-in messages show profile username, not Gmail address.

**Test coverage:**

- [ ] Unit tests added / updated
- [ ] Widget tests added / updated
- [x] Tested on Android
- [ ] Tested on Web

## Security & Privacy Checklist

- [x] No secrets or API keys added to tracked files
- [ ] Firestore / RTDB security rules updated (if applicable)
- [x] Chat messages are not persisted beyond session end (Privacy by Design)
- [x] No Firebase SDK calls outside `datasources/`

## Clean Architecture Checklist

- [x] Domain layer has zero Flutter / Firebase imports
- [x] Business logic lives in UseCases, not Notifiers or Screens
- [x] New `@freezed` models ran through `build_runner` (no hand-rolled `fromJson`)
- [x] No unbounded `ListView` with `children: [...]` for dynamic data

## Screenshots / Recordings

N/A — no visual changes; existing ReportDialog design preserved.

## Notes for Reviewers

- 30-second CF timeout: `reportSession` uploads images to Storage before writing Firestore, so it can be slow on poor connections. This is the minimum safe value.
- `nav.context` pattern (save `Navigator.of(context)` before `pop()`, then pass `nav.context` to `showDialog`) is the canonical Flutter approach to avoid a deactivated-context crash after navigating away.
- Group-chat race condition: `_memberInterestCache` is populated only by `_loadMemberProfiles` (Firestore fetch). Gating hop-in emission behind that map guarantees display names are always the profile username, never the ephemeral Firebase Auth `displayName`.
