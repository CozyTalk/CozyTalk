# Chapter 7 Plan — Cloud Functions: Matchmaking Backend

## Scope

```
functions/src/matchmaking/
├── join1v1Pool.ts
├── cancel1v1Pool.ts
├── match1v1Users.ts
├── joinGroupRoom.ts
├── createCustomRoom.ts
├── joinRoomById.ts
├── leaveRoom.ts
├── setRoomLock.ts
├── expireRooms.ts
├── cleanupMember.ts
├── cleanupPoolMember.ts
├── embeddingService.ts
└── _utils.ts

functions/src/index.ts  (exports check)
```

---

## Checks to Perform

### 7.1 Function Exports (`index.ts`)
- [ ] Exactly 11 matchmaking functions exported (per CLAUDE.md):
  `joinGroupRoom`, `createCustomRoom`, `joinRoomById`, `leaveRoom`, `join1v1Pool`, `cancel1v1Pool`, `setRoomLock`, `expireRooms`, `match1v1Users`, `cleanupMember`, `cleanupPoolMember`.
- [ ] `embeddingService.ts` and `_utils.ts` are NOT exported (internal helpers only).
- [ ] All chat functions also exported: `sendMessage`, `endSession`, `reportSession`.
- [ ] No function exported from the wrong region — RTDB triggers (`cleanupMember`, `cleanupPoolMember`) must be `asia-southeast1`.
- [ ] Scheduled function `expireRooms` has correct cron schedule `*/2 * * * *`.

### 7.2 JSDoc Coverage
- [ ] Every `function` declaration (including `_`-prefixed helpers) in all matchmaking files has a JSDoc block with `@param` and `@return`.
- [ ] `const` arrow functions are exempt — verify none are flagged by ESLint.

### 7.3 `join1v1Pool.ts`
- [ ] Authentication check: rejects unauthenticated callers.
- [ ] Validates `interestText` length if provided (prevent unbounded string sent to Vertex AI).
- [ ] Calls `embedText()` if `interestText` provided; handles null return (embed failure → graceful FIFO fallback).
- [ ] Writes to `waiting_pool/{uid}`: `createdAt`, `status: 'waiting'`, `updatedAt`, `mode: '1v1'`, `interestText?`, `interestVector?`.
- [ ] If user is already in pool: returns error or idempotent success? Document the behavior.
- [ ] No match logic here — matching is in `match1v1Users.ts` (Firestore trigger).
- [ ] TTL cleanup of own stale pool entry before joining (to handle crash recovery).

### 7.4 `cancel1v1Pool.ts`
- [ ] Auth check.
- [ ] Deletes `waiting_pool/{uid}`.
- [ ] Handles case where user was already matched (pool entry may already be deleted).
- [ ] Returns success even if doc didn't exist (idempotent).
- [ ] Does NOT delete the room if already matched — that's the user's choice.

### 7.5 `match1v1Users.ts` (Firestore Trigger)
- [ ] Triggered on `waiting_pool/{uid}` create/update.
- [ ] **Race condition handling:** uses Firestore transaction to atomically:
  - Read both candidates from pool.
  - Verify both still have `status: 'waiting'`.
  - Atomically update both to `status: 'matched'`.
  - Create `rooms/{roomId}` doc.
- [ ] **ID collision:** 5-char alphanumeric roomId generation retries on collision (atomic `create()`).
- [ ] Cosine similarity threshold: `0.65` — if both have vectors AND similarity < 0.65, falls back to another candidate.
- [ ] FIFO fallback: when no vector match found, picks oldest waiting entry.
- [ ] Does NOT match a user with themselves (uid check).
- [ ] Does NOT match users already in a room.
- [ ] Writes `rooms/{roomId}` with: `status`, `users: [uid1, uid2]`, `roomType: '1v1'`, `createdAt`, `expiresAt`, `memberCount`, `encryptionKey` (AES key), `isLocked: false`.
- [ ] Updates both `waiting_pool/{uid}` entries: `status: 'matched'`, `roomId`.
- [ ] Encryption key generation: cryptographically random (not Math.random).

### 7.6 `joinGroupRoom.ts`
- [ ] Auth check.
- [ ] Finds a group room with available slots (Firestore query on `rooms` where `roomType == 'group'` and `memberCount < maxSize` and `status == 'open'`).
- [ ] Slot reservation uses Firestore transaction (not optimistic write).
- [ ] Writes `waiting_pool` entry similarly to 1v1 with `mode: 'group'`.
- [ ] Returns roomId on success.
- [ ] If no group room available, creates one.

### 7.7 `createCustomRoom.ts`
- [ ] Auth check.
- [ ] Generates 5-char roomId atomically.
- [ ] Sets `isLocked: false` initially (owner can lock via `setRoomLock`).
- [ ] Sets `createdAt`, `expiresAt` (TTL), `users`, `memberCount`.
- [ ] Returns roomId to caller.

### 7.8 `joinRoomById.ts`
- [ ] Auth check.
- [ ] Validates roomId format (5-char alphanumeric).
- [ ] Reads `rooms/{roomId}` — returns error if not found.
- [ ] Returns error if `status != 'open'` (expired, full, or locked).
- [ ] Returns error if `isLocked == true`.
- [ ] Adds user to `rooms/{roomId}.users` atomically.
- [ ] Increments `memberCount` atomically.

### 7.9 `leaveRoom.ts`
- [ ] Auth check.
- [ ] Removes user from `rooms/{roomId}.users`.
- [ ] Decrements `memberCount`.
- [ ] If `memberCount == 0`: marks room as expired (not immediately deleted — `expireRooms` handles deletion).
- [ ] RTDB presence entry for user deleted.
- [ ] Is this idempotent? (Called twice should not error.)

### 7.10 `setRoomLock.ts`
- [ ] Auth check.
- [ ] Verifies caller is in `rooms/{roomId}.users`.
- [ ] Verifies `roomType == 'custom'` — only custom rooms can be locked.
- [ ] Writes `isLocked: <bool>` to `rooms/{roomId}`.
- [ ] No other fields modified.

### 7.11 `expireRooms.ts` (Scheduled, every 2 min)
- [ ] Queries `rooms` where `expiresAt < now`.
- [ ] For each expired room: re-checks `memberCount == 0` before deleting (CLAUDE.md specifies this check).
- [ ] Deletes `rooms/{roomId}` doc.
- [ ] Does NOT delete RTDB data (that's `cleanupMember`/`cleanupPoolMember`).
- [ ] Handles large batch sizes (what if 1000+ rooms expire simultaneously?).
- [ ] Logs count of deleted rooms.

### 7.12 `cleanupMember.ts` (RTDB Trigger, asia-southeast1)
- [ ] Triggered on `rooms/{roomId}/members/{uid}` delete (user goes offline).
- [ ] Calls `leaveRoom` logic or calls the CF directly?
- [ ] Updates Firestore `rooms/{roomId}.memberCount`.
- [ ] Region: explicitly `asia-southeast1` (matches RTDB URL region).

### 7.13 `cleanupPoolMember.ts` (RTDB Trigger, asia-southeast1)
- [ ] Triggered on `pool_presence/{uid}` delete.
- [ ] Deletes `waiting_pool/{uid}` from Firestore.
- [ ] Region: explicitly `asia-southeast1`.

### 7.14 `embeddingService.ts`
- [ ] `embedText(text: string): Promise<number[] | null>` — returns null on failure.
- [ ] Model: `text-multilingual-embedding-002`, 256 dimensions.
- [ ] Vertex AI project/location configured correctly (reads from env or Firebase config).
- [ ] `cosineSimilarity(a: number[], b: number[]): number` — handles zero-magnitude vectors (div-by-zero guard).
- [ ] `meanVector(vectors: number[][]): number[]` — handles empty array.
- [ ] All three functions have JSDoc with `@param` and `@return`.

### 7.15 `_utils.ts`
- [ ] `generateRoomId()` — 5-char alphanumeric, cryptographically random.
- [ ] TTL cleanup helper — removes stale data correctly.
- [ ] JSDoc on all exported/internal functions.

### 7.16 TypeScript/ESLint Compliance
- [ ] No implicit `any`.
- [ ] No `// @ts-ignore` or `// eslint-disable` comments.
- [ ] Double quotes, 2-space indent, trailing commas, semicolons.
- [ ] Prettier formatting applied.
- [ ] `npm run lint` passes clean.
- [ ] `npm run build` produces no TypeScript errors.

### 7.17 Error Handling
- [ ] All callable CFs return structured errors via `functions.https.HttpsError` (not plain `throw new Error`).
- [ ] Error codes are appropriate: `unauthenticated`, `invalid-argument`, `not-found`, `already-exists`, `permission-denied`.
- [ ] RTDB trigger failures logged but don't crash the trigger.
- [ ] Firestore transaction retry logic present for high-contention operations (match1v1Users).

---

## Files to Read in Full

1. `functions/src/index.ts`
2. `functions/src/matchmaking/join1v1Pool.ts`
3. `functions/src/matchmaking/cancel1v1Pool.ts`
4. `functions/src/matchmaking/match1v1Users.ts`
5. `functions/src/matchmaking/joinGroupRoom.ts`
6. `functions/src/matchmaking/createCustomRoom.ts`
7. `functions/src/matchmaking/joinRoomById.ts`
8. `functions/src/matchmaking/leaveRoom.ts`
9. `functions/src/matchmaking/setRoomLock.ts`
10. `functions/src/matchmaking/expireRooms.ts`
11. `functions/src/matchmaking/cleanupMember.ts`
12. `functions/src/matchmaking/cleanupPoolMember.ts`
13. `functions/src/matchmaking/embeddingService.ts`
14. `functions/src/matchmaking/_utils.ts`

---

## Expected Findings Categories

- Missing Firestore transaction in match1v1Users (CRITICAL — race condition)
- `Math.random()` used for roomId or encryption key (CRITICAL)
- Missing auth check in any CF (CRITICAL)
- Wrong region for RTDB triggers (HIGH)
- Cosine similarity div-by-zero (HIGH)
- Missing `memberCount == 0` check in expireRooms (HIGH)
- Incomplete JSDoc (LOW per style rules)
- `HttpsError` not used for errors (MEDIUM)
- ESLint/TypeScript violations (LOW-MEDIUM)

---

## Output

Write findings to `reviews/ch07_cf_matchmaking.md`.
