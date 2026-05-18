# Cloud Functions

16 exported functions total. All in `functions/src/`. Deployed via Firebase CLI.

Firebase project: `cozytalk-5d984`
Default region: `us-central1` (unless noted)

---

## Chat (3 functions)

### `sendMessage`
`functions/src/chat/sendMessage.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ sessionId: string, text: string }`
- **Process:** Looks up room in `rooms/{sessionId}` then `active_sessions/{sessionId}`. Verifies caller is participant. Encrypts text with AES-256-GCM (random 12-byte IV). Writes to `chat_rooms/{sessionId}/messages`.
- **Output:** void (throws HttpsError on failure)

### `endSession`
`functions/src/chat/endSession.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ sessionId: string }`
- **Process:** Looks up `rooms/{sessionId}` then `active_sessions/{sessionId}`. Verifies caller is participant. Archives key to `session_keys/{sessionId}`. Tombstones room (`status: expired`). Deletes RTDB presence/typing for room. Deletes `chat_rooms/{sessionId}/messages`.
- **Output:** void

### `reportSession`
`functions/src/chat/reportSession.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ sessionId, reportedUserId, reportType, reason, contextText?, contextImageUrls? }`
- **Process:** Validates all inputs (`reason` ≤500 chars, `contextText` optional ≤2000 chars, `reportType` one of `spam|harassment|inappropriate_content|other`, `contextImageUrls` ≤5 Firebase Storage URLs (`https://firebasestorage.googleapis.com/` prefix required), no self-reporting). Verifies both `reporterId` **and** `reportedUserId` are actual session participants. Looks up `encryptionKey` from `rooms/{sessionId}` (falls back to `active_sessions`, then `session_keys`). Upserts `session_keys/{sessionId}` with `flagged: true, expiresAt: null`. Decrypts all messages (AES-256-GCM), sorts by timestamp, saves plaintext to `reports/{reportId}/chat_log.json` in Cloud Storage (non-fatal if Storage write fails). Batch-updates `chat_rooms/{sessionId}/messages` with `{flagged: true, expiresAt: null}`. Creates `reports/{auto-id}` in Firestore (no `encryptionKey` in the doc — key remains in `session_keys/` only). Room is NOT ended — caller should call `endSession` after.
- **Output:** `{ reportId: string }`

---

## Matchmaking (11 functions)

### `join1v1Pool`
`functions/src/matchmaking/join1v1Pool.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ interestText?: string }`
- **Process:** Adds user to `waiting_pool/{uid}` with `status: waiting`. If `interestText` provided, generates embedding via Vertex AI and stores 256-dim vector. Sets `pool_presence/{uid}` in RTDB.
- **Output:** void

### `cancel1v1Pool`
`functions/src/matchmaking/cancel1v1Pool.ts`
- **Trigger:** callable (authenticated)
- **Input:** none
- **Process:** Removes user from `waiting_pool`. Clears `pool_presence` RTDB node.
- **Output:** `{ success: true }` or `{ success: false, reason: "matching_in_progress" }` if already matching

### `match1v1Users`
`functions/src/matchmaking/match1v1Users.ts`
- **Trigger:** Firestore `onDocumentCreated` — `waiting_pool/{uid}` — **region: `asia-southeast1`**
- **Process:** 2-phase atomic Firestore transaction. Finds best candidate by cosine similarity of interest vectors (threshold 0.65). Creates `rooms/{roomId}` with `mode: 1v1`, `status: active`. Removes both users from pool. Writes match result to RTDB.
- **Output:** void (trigger)

### `joinGroupRoom`
`functions/src/matchmaking/joinGroupRoom.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ interestText?: string }`
- **Process:** 3-phase match: find candidate group rooms → compute cosine similarity → join best match or create new group room. Room capacity 2–5 users.
- **Output:** `{ roomId: string, mode: string, roomType: string }`

### `createCustomRoom`
`functions/src/matchmaking/createCustomRoom.ts`
- **Trigger:** callable (authenticated)
- **Input:** none (or optional config TBD)
- **Process:** Generates 5-char crypto-random room ID. Creates `rooms/{roomId}` with `mode: group`, `roomType: custom`, `status: active`. Adds creator to `rooms/{roomId}/members` in RTDB.
- **Output:** `{ roomId: string }`

### `joinRoomById`
`functions/src/matchmaking/joinRoomById.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ roomId: string }`
- **Process:** Validates room exists, is not expired/padding, not locked, not full. Adds caller to `rooms/{roomId}.users` and RTDB members. Returns room info.
- **Output:** `{ roomId: string, mode: string, roomType: string }`

### `leaveRoom`
`functions/src/matchmaking/leaveRoom.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ roomId: string }`
- **Process:** Removes caller from `rooms/{roomId}.users`. If room empty, tombstones it. Clears RTDB member node.
- **Output:** void

### `setRoomLock`
`functions/src/matchmaking/setRoomLock.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ roomId: string, isLocked: boolean }`
- **Process:** Verifies caller is room participant. Sets `rooms/{roomId}.isLocked`.
- **Output:** void

### `expireRooms`
`functions/src/matchmaking/expireRooms.ts`
- **Trigger:** scheduled — every 2 minutes
- **Process:** Three operations: (1) expire padding rooms past `paddingUntil`, (2) reset stale `matching_in_progress` docs, (3) heal ghost rooms (RTDB members but Firestore room missing). Re-checks RTDB membership before expiring (crash-safe).
- **Output:** void (cron)

### `cleanupMember`
`functions/src/matchmaking/cleanupMember.ts`
- **Trigger:** RTDB `onValueDeleted` — `rooms/{roomId}/members/{uid}` — **region: `asia-southeast1`**
- **Process:** When a member's RTDB presence node is deleted (disconnect), triggers room cleanup. If room now empty, tombstones Firestore room.
- **Output:** void (trigger)

### `cleanupPoolMember`
`functions/src/matchmaking/cleanupPoolMember.ts`
- **Trigger:** RTDB `onValueDeleted` — `pool_presence/{uid}` — **region: `asia-southeast1`**
- **Process:** When pool presence deleted (disconnect), removes user from `waiting_pool/{uid}`.
- **Output:** void (trigger)

---

## Friends (1 function)

### `onFriendshipDeleted`
`functions/src/friends/removeFriendship.ts`
- **Trigger:** Firestore `onDocumentDeleted` — `friendships/{friendshipId}`
- **Process:** When a `friendships` doc is deleted, deletes the entire `friend_messages/{friendshipId}/messages` subcollection to prevent orphaned data consuming storage indefinitely.
- **Output:** void (trigger)

---

## Utility (1 function)

### `helloWorld`
`functions/src/index.ts`
- **Trigger:** callable (authenticated), public CORS
- **Input:** `{ message: string }`
- **Process:** Echoes the message back. Validates non-empty string. Used by `hello` feature for CF smoke testing.
- **Output:** `{ message: string }`

---

## Dead Code

- `functions/src/chat/onProtoPresenceDeleted.ts` — disabled stub (`export {}`). RTDB trigger for proto-session presence cleanup. Re-enable after full matchmaking integration.

---

## Shared Utilities

`functions/src/matchmaking/_utils.ts`
- `generateRoomId()` — 5-char crypto-random ID from `[A-Z0-9a-z]`
- `generateKey()` — `crypto.randomBytes(32)` hex string for AES-256
- `cosineSimilarity(a, b)` — dot product / magnitudes; returns 0 for zero vectors
- `RoomData` interface — Firestore room document shape
