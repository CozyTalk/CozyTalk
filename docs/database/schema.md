# Database Schema

Full reference: `PROJECT_CONTEXT.md` (Firestore rules) and `MATCHMAKING_CONTEXT_AWARE.md` (interest matching).

---

## Firestore Collections

### `users/{uid}`

| Field | Type | Notes |
|---|---|---|
| `uid` | string | same as document ID |
| `email` | string | |
| `role` | string | `'user'` or `'admin'` — immutable after creation |
| `createdAt` | timestamp | |
| `lastSeen` | timestamp | |
| `displayName` | string? | |
| `photoUrl` | string? | |
| `hatKey` | string? | avatar hat |
| `moodKey` | string? | avatar mood |
| `interest` | string? | free-text interest for matching |
| `thoughts` | string? | |

Rules: create allowed for authenticated users (must include uid, email, role, createdAt, lastSeen). Update allowed for own doc; `role` field immutable.

### `waiting_pool/{uid}`

| Field | Type | Notes |
|---|---|---|
| `status` | string | `'waiting'` → `'matching'` → `'matched'` (CF-managed) |
| `mode` | string | `'1v1'` or `'group'` |
| `createdAt` | timestamp | server timestamp, must equal `request.time` (rules-enforced) |
| `updatedAt` | timestamp | client-updatable only |
| `interestText` | string? | raw interest text |
| `interestVector` | array? | 256-dim Vertex AI embedding |
| `roomId` | string? | set by `match1v1Users` CF when matched (1v1 only); `null` initially |

Rules: update restricted to `updatedAt` field only (prevents client status manipulation).

### `rooms/{roomId}`

5-char alphanumeric room ID.

| Field | Type | Notes |
|---|---|---|
| `roomId` | string | document ID |
| `mode` | string | `'1v1'` or `'group'` |
| `roomType` | string | `'public'` (pool-matched) or `'custom'` (created with ID) |
| `status` | string | `'active'`, `'padding'`, `'expired'` |
| `users` | string[] | UIDs of participants |
| `memberCount` | number | |
| `maxUsers` | number | 2 for 1v1, up to 5 for group |
| `encryptionKey` | string | hex AES-256 key — readable by room members (used for client-side decryption) |
| `isLocked` | boolean | |
| `paddingUntil` | timestamp? | set when status transitions to `padding` |
| `createdAt` | timestamp | |

Rules: `users` membership checked for read/write access.

### `active_sessions/{id}`

Legacy proto-sessions only. New code uses `rooms/`. Not actively written to by current CFs.

### `chat_rooms/{sessionId}/messages/{messageId}`

| Field | Type | Notes |
|---|---|---|
| `senderId` | string | always set server-side from `request.auth.uid` |
| `displayName` | string | always sourced from Firestore users doc, never client payload |
| `encryptedText` | string | base64 AES-256-GCM ciphertext |
| `iv` | string | base64 12-byte random IV |
| `authTag` | string | base64 GCM auth tag |
| `timestamp` | timestamp | |
| `expiresAt` | timestamp | 3-day TTL (Firestore TTL policy) |
| `flagged` | boolean | `false` at creation; set to `true` by `reportSession` CF to preserve message for moderation |

Rules: create validates `senderId == request.auth.uid`. No client reads after session end.

### `session_keys/{sessionId}`

Archived encryption keys after session ends.

| Field | Type | Notes |
|---|---|---|
| `sessionId` | string | matches document ID |
| `encryptionKey` | string | hex AES-256 key |
| `users` | string[] | UIDs of room participants |
| `createdAt` | timestamp | original session creation time |
| `expiresAt` | timestamp | TTL — auto-deleted after retention window; cleared to `null` when flagged |
| `flagged` | boolean | set to `true` by `reportSession` to prevent premature TTL deletion |

Rules: deny all client access — admin SDK only.

### `reports/{id}`

| Field | Type | Notes |
|---|---|---|
| `reporterId` | string | set from `request.auth.uid` by CF |
| `reportedUserId` | string | |
| `sessionId` | string | |
| `reason` | string | |
| `description` | string | |
| `createdAt` | timestamp | |
| `status` | string | |
| `encryptionKey` | string | hex AES-256 key stored for moderator decryption — CF-written via admin SDK, not in client `hasOnly()` list |

Rules: any authenticated user may create (restricted: `reporterId == uid`, `status == 'pending'`, required fields only). Read, update, delete are admin-only.

---

## RTDB Paths

RTDB instance: `cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

| Path | Read rule | Write rule | Purpose |
|---|---|---|---|
| `rooms/{roomId}/members/{uid}` | room members | room members | presence for room occupants |
| `typing/{roomId}/{uid}` | room members | own UID | typing indicator |
| `presence/{roomId}/{uid}` | room members | own UID | online presence (onDisconnect removes) |
| `nameQueue/{roomId}` | room members | room members | anonymous name assignment |
| `pool_presence/{uid}` | own UID | own UID | pool presence (removed on disconnect) |

Note: `cleanupMember` CF triggers on `rooms/{roomId}/members/{uid}` deletion. `cleanupPoolMember` triggers on `pool_presence/{uid}` deletion.

---

## Firestore Indexes

`firestore.indexes.json` — 6 composite indexes deployed:

| Collection | Fields | Purpose |
|---|---|---|
| `waiting_pool` | `status ASC, createdAt ASC` | Legacy: oldest waiting user (no mode filter) |
| `waiting_pool` | `mode ASC, status ASC, createdAt ASC` | Matchmaking: oldest waiting user by mode |
| `waiting_pool` | `mode ASC, status ASC, updatedAt ASC` | Matchmaking: most-recently-updated waiting user by mode |
| `reports` | `status ASC, createdAt DESC` | Admin dashboard: pending reports by time |
| `rooms` | `mode ASC, status ASC, isLocked ASC, memberCount ASC` | Group room picker: available unlocked rooms by fill level |
| `rooms` | `status ASC, paddingUntil ASC` | `expireRooms` cron: find rooms past their padding window |

TTL field policies (live in prod): `chat_rooms/{id}/messages.expiresAt` and `session_keys.expiresAt`.

---

## Security Rule Files

- `firestore.rules` — Firestore security rules
- `database.rules.json` — RTDB security rules
