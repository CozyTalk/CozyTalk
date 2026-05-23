# QA Follow-up Items

Found during full QA scan (2026-05-24) after PR #71 + fix/post-pr71-followups.

---

## High Priority — Real Bugs

### A. Missing `backgroundTheme` in `cleanupMember` re-queue
**File:** `functions/src/matchmaking/cleanupMember.ts` ~line 95  
**Problem:** When a 1v1 partner disconnects via network drop, `cleanupMember` re-queues the remaining user WITHOUT their `backgroundTheme`. The explicit `leaveRoom.ts` path preserves it. So if your partner drops instead of leaving cleanly, your background theme preference is lost.  
**Fix:** Add `backgroundTheme: data.backgroundTheme ?? null` to the re-queue payload in `cleanupMember.ts`, mirroring what `leaveRoom.ts` already does.

---

### B. Firestore TTL policy not version-controlled
**File:** `functions/src/chat/sendMessage.ts` line 123 sets `expiresAt` 3 days out, but no Firestore TTL policy is committed anywhere in the repo.  
**Problem:** If the TTL policy is not deployed in Firebase Console, messages from crashed/orphaned sessions (app killed mid-session, network drop before `endSession` CF fires) persist in Firestore forever — violating the core privacy guarantee.  
**Action:** Verify the TTL policy exists in Firebase Console for `chat_rooms/{id}/messages` on the `expiresAt` field. If not, deploy it. Consider adding it to `firebase.json` or a separate IaC file so it's version-controlled and can't silently disappear.

---

## Medium Priority — Pre-existing Issues

### C. Proto-session cleanup disabled
**File:** `functions/src/chat/onProtoPresenceDeleted.ts`  
**Problem:** File exports only `{}` — the cleanup handler that runs when the last user leaves a proto-session is completely disabled. Proto-session messages can persist indefinitely.  
**Action:** Either re-enable the handler or remove the entire proto-session code path (`proto-*` room IDs) from `chat_datasource.dart` once all users are confirmed to be on real rooms.

### D. `join1v1Pool` embedding failure blocks the entire join
**File:** `functions/src/matchmaking/join1v1Pool.ts` line 33  
**Problem:** `await embedText(rawInterest)` throws if Vertex AI is down or rate-limited → the whole pool join fails and the user sees an error.  
**Fix:**
```typescript
const interestVector = rawInterest
  ? await embedText(rawInterest).catch(() => null)
  : null;
```
Degrades gracefully to random matching instead of blocking the user entirely.

### E. Optimistic send "clear all" on first confirmation
**Files:** `apps/mobile/lib/screens/chat_screen.dart`, `apps/mobile/lib/screens/group_chat_screen.dart`  
**Problem:** `_optimisticMessages` is cleared entirely when the first backend confirmation arrives. If the user sends two messages very quickly, the second optimistic entry briefly disappears before its own backend confirmation arrives. Not a data loss — the message still shows up via the stream — but causes a visible flicker for fast typists.  
**Fix (future):** Assign a local `sendId` (e.g. `DateTime.now().microsecondsSinceEpoch`) to each optimistic entry, pass it through `sendMessage`, and only remove the matching entry on confirmation. Defer until this becomes user-reported.

---

## Low Priority — Pre-existing Code Quality

### F. `match1v1Users` error recovery swallows failures silently
**File:** `functions/src/matchmaking/match1v1Users.ts` lines 141–188  
**Problem:** When room creation fails, the cleanup handlers use `.catch(err => logger.error(...))` — swallowing the error. If the undo also fails, the candidate is stuck in `"matching"` status forever and can never match again.  
**Fix:** Throw after logging so the Cloud Function trigger retries, or implement a timeout/reset in `expireRooms`.

### G. Expired rooms readable by any signed-in user
**File:** `firestore.rules` lines 87–92  
**Problem:** `allow read: if isSignedIn() && (resource.data.status == 'expired' || ...)` lets any signed-in user read any expired room document, including its metadata (mode, background, member list at expiry time).  
**Context:** This was intentional — clients need to detect "room expired" state. Low sensitivity since the data isn't private, but worth tightening to members-only in a future rules pass.

---

## Already Fixed (in `fix/cf-reliability-a-b-d-f`)

| Issue | Fix |
|---|---|
| A. Missing `backgroundTheme` in `cleanupMember` re-queue | Added `requeueBackgroundTheme` capture + field in `set()` payload |
| B. Firestore TTL policy not version-controlled | Added `tools/setup-firestore-ttl.sh` — run once to deploy; idempotent |
| D. `join1v1Pool` embedding failure blocks join | Added `.catch(() => null)` to `embedText` call |
| F. `match1v1Users` cleanup swallows errors silently | Phase 2 & 3 cleanup failures now rethrow so the CF can retry |

---

## Already Fixed (in `fix/post-pr71-followups`)

| Issue | Fix |
|---|---|
| `hatKey: null` on signup breaks `updateMood` (Firestore type check) | Removed from all 3 sign-up paths in `auth_datasource.dart` |
| Existing accounts with stored `hatKey: null` still denied | Firestore rule updated: `null \|\| string` both allowed |
| `gif_other` avatar not tappable (no friend profile dialog) | `GestureDetector` + `UserProfileDialog` added to gif bubble in `chat_screen.dart` |
| First message send latency (backend round-trip) | Optimistic rendering added to both chat screens |
| `ChatMessage.type` comment missing `'gif_other'` | Updated |
