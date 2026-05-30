# Matchmaking — Context-Aware Interest Matching Reference

Full system reference for the embedding-based interest matchmaking feature. Covers Cloud Functions, Flutter, data model, test suites, and known pitfalls. Read this before modifying anything in `functions/src/matchmaking/` or `apps/mobile/lib/features/matchmaking/`.

---

## Overview

Users optionally type a phrase ("I like football") before joining. The system generates a 256-dimensional embedding vector from Vertex AI and uses cosine similarity to prefer interest-compatible pairings. Users with no interest phrase fall back to the existing random/FIFO algorithm — never an error.

**Similarity threshold:** `INTEREST_SIMILARITY_THRESHOLD = 0.65` (constant in `embeddingService.ts`)

**Embedding model:** `text-multilingual-embedding-002`, 256 dims, `SEMANTIC_SIMILARITY` task type, via Vertex AI `us-central1`

---

## File Map

```
functions/src/matchmaking/
├── embeddingService.ts          ← core embedding + math utilities
├── _utils.ts                    ← room creation, ID generation, RoomData interface
├── join1v1Pool.ts               ← callable CF: join 1v1 queue with optional interest
├── match1v1Users.ts             ← Firestore trigger: match two pool users
├── joinGroupRoom.ts             ← callable CF: join/create group room with optional interest
├── leaveRoom.ts                 ← callable CF: leave room, recompute interest vectors
├── cleanupMember.ts             ← RTDB trigger: member disconnect, recompute interest vectors
├── cleanupPoolMember.ts         ← RTDB trigger: pool disconnect cleanup
├── cancel1v1Pool.ts             ← callable CF: cancel pool entry
├── createCustomRoom.ts          ← callable CF: create a custom (invite-only) room
├── joinRoomById.ts              ← callable CF: join by explicit 5-char ID
├── setRoomLock.ts               ← callable CF: lock/unlock custom rooms
├── expireRooms.ts               ← scheduled CF: expire padding rooms, heal ghost rooms
└── __tests__/
    ├── embeddingService.test.ts ← unit tests for embedding math (no emulator)
    ├── matchmaking.test.ts      ← integration tests (requires emulators)
    ├── testEmbeddingLive.ts     ← manual live test against real Vertex AI
    └── helpers.ts               ← test utilities (signInAnon, callFn, adminFirestoreSet, ...)

apps/mobile/lib/features/matchmaking/
├── domain/
│   ├── entities/room.dart             ← Room entity (has roomInterestVector: List<double>?)
│   ├── entities/matchmaking_status.dart
│   ├── repositories/matchmaking_repository.dart  ← abstract interface
│   └── usecases/
│       ├── join_1v1_pool.dart         ← takes optional interestText
│       └── join_group_room.dart       ← takes optional interestText
├── data/
│   ├── models/room_model.dart         ← Freezed DTO (has roomInterestVector: List<double>?)
│   ├── datasources/matchmaking_datasource.dart  ← passes interestText to CFs
│   └── repositories/matchmaking_repository_impl.dart
└── presentation/
    ├── providers/matchmaking_provider.dart  ← state has interestText: String
    └── screens/matchmaking_test_screen.dart  ← TextField wired to setInterestText()

apps/mobile/test/features/matchmaking/
├── domain/shared_fakes.dart     ← FakeMatchmakingRepository (tracks interestText args)
├── domain/usecases/join_1v1_pool_test.dart
├── domain/usecases/join_group_room_test.dart
├── data/models/room_model_test.dart
├── presentation/providers/matchmaking_state_test.dart
└── presentation/screens/matchmaking_test_screen_test.dart
```

---

## Data Model

### `waiting_pool/{uid}` — added interest fields

| Field | Type | Written by | Notes |
|---|---|---|---|
| `interestText` | `string \| null` | `join1v1Pool` CF | raw phrase typed by user |
| `interestVector` | `number[] \| null` | `join1v1Pool` CF | 256-dim Vertex embedding; null = no interest |
| `status` | `"waiting" \| "matching" \| "matched"` | various CFs | `matching` = claimed by match1v1Users |
| `mode` | `"1v1"` | `join1v1Pool` CF | always 1v1 for pool docs |
| `createdAt`, `updatedAt` | `Timestamp` | CF | server timestamps |
| `roomId` | `string \| null` | `match1v1Users` | set when matched |

### `rooms/{roomId}` — added interest fields

| Field | Type | Written by | Notes |
|---|---|---|---|
| `roomInterestVector` | `number[] \| null` | join/leave CFs | mean of all `memberInterests` vectors |
| `memberInterests` | `{[uid]: number[]} \| null` | join/leave CFs | per-member vectors; needed to recompute mean on leave |

Storage: 256 dims × 5 members ≈ 10 KB max per room doc. Well within Firestore's 1 MB limit.

**Why store `memberInterests` (per-member) instead of just `roomInterestVector` (aggregate)?**
When a member leaves, you can only recompute the correct mean if you know each remaining member's vector. Storing only the aggregate makes leave-recomputation impossible.

---

## embeddingService.ts — API Reference

```typescript
// Calls Vertex AI. Returns null on ANY failure — never throws.
// Requires GCLOUD_PROJECT env var (auto-set in Firebase Functions runtime).
// Input truncated to 500 chars before sending.
// Singleton client lazily initialized per function instance.
export async function embedText(text: string): Promise<number[] | null>

// Cosine similarity in [-1, 1]. Returns 0 for zero vectors, empty arrays, or
// mismatched lengths. Safe to call with any input.
export function cosineSimilarity(a: number[], b: number[]): number

// Element-wise mean of equal-length vectors. Returns [] for empty input.
export function meanVector(vectors: number[][]): number[]

// The threshold constant used everywhere.
export const INTEREST_SIMILARITY_THRESHOLD = 0.65
```

**Vertex AI response shape** (what the code navigates):
```typescript
response.predictions[0]
  .structValue.fields["embeddings"]
  .structValue.fields["values"]
  .listValue.values
  .map(v => v.numberValue ?? 0)
```

---

## Cloud Function Logic

### join1v1Pool.ts

1. Reads optional `data.interestText: string`
2. Calls `embedText(rawInterest)` → `interestVector` (null if no text or embedding fails)
3. Deletes stale pool entry (idempotent)
4. Writes new pool doc with `{ interestText, interestVector, status: "waiting", mode: "1v1", ... }`
5. Client watches this doc for `status == "matched"` to get `roomId`

### match1v1Users.ts (Firestore trigger)

Fires on `waiting_pool/{uid}` creation, region `asia-southeast1`, `minInstances: 1`.

```
1. Validate: mode == "1v1" && status == "waiting"
2. Read trigger user's interestVector from event data
3. Query up to 20 candidates (was 6 before interest matching)
4. If trigger user has a vector: sort candidates
     → interest-matching first (cosine >= 0.65), shuffled for fairness
     → FIFO remainder
5. For each candidate:
   a. Phase 1 — atomically claim: tx set candidate.status = "matching"
   b. Phase 2 — create room via createRoomWithRetry()
      - Room includes memberInterests + roomInterestVector when BOTH users have vectors
   c. Phase 3 — finalize: tx set both users status = "matched", roomId = <new>
      - On failure: tombstone room (status: "expired"), undo claim
6. Write RTDB members for both users (3 retries, exponential backoff)
```

**Concurrency safety:**
- `status: "matching"` claim in a transaction prevents two triggers from picking the same candidate
- Finalizing both users in a second transaction handles the case where the trigger user was already matched

### joinGroupRoom.ts (callable CF)

```
Priority order (highest to lowest):
  Phase 0 — Interest: user has vector → filter all candidates by cosine >= 0.65
  Phase 1 — Priority: join lone-user room (memberCount == 1)
  Phase 2 — Random: join any 2-4 member room
  Phase 3 — Create: no room available → create new

Phase 1 + Phase 2 candidate queries run in PARALLEL before the interest filter.

Join transaction:
  - Rejects: expired, padding, locked, full, already-member
  - Adds: users += uid, memberCount++, status = active, paddingUntil = null
  - If user has vector: memberInterests[uid] = vector, roomInterestVector = mean(all)

Post-creation race mitigation:
  - After Phase 3, re-query for other 1-member rooms (limit 5)
  - Iterate all candidates; for each, check RTDB rooms/{id}/members — skip if empty (stale disconnected room whose cleanupMember hasn't run)
  - On first live candidate, attempt merge transaction: discard own room, update RTDB
  - Falls back to own room if all candidates are stale or merge fails
```

### leaveRoom.ts + cleanupMember.ts

Both share the same interest vector cleanup logic for group rooms:

```
On group member leave:
  - remaining = memberInterests without leaving uid
  - if remaining has entries: update memberInterests, recompute roomInterestVector = mean(values)
  - if remaining is empty: set memberInterests = null, roomInterestVector = null

On 1v1 leave/disconnect:
  - Room → 30-second padding
  - Remaining user re-queued (delete + set waiting_pool doc to trigger match1v1Users)
  - RTDB cleared for both users

On empty group room:
  - Room → 5-minute padding (PADDING_MINUTES = 5)
```

`cleanupMember` has one extra guard: does NOT overwrite a shorter `paddingUntil` already set by `leaveRoom`.

### expireRooms.ts (scheduled `*/2 * * * *`, us-central1)

Three sub-routines run in parallel:

| Sub-routine | What it does |
|---|---|
| `_expirePaddingRooms` | Finds padding rooms with `paddingUntil <= now`. If `memberCount > 0`, checks RTDB first — skips only if real RTDB members exist. Tombstones as `expired`, cleans RTDB + chat subcollection. |
| `_resetStaleMatchingDocs` | Resets `waiting_pool` docs stuck in `matching` for > 60s back to `waiting`. |
| `_healGhostRooms` | Active rooms with `memberCount > 0` but no RTDB members → force 1-minute padding. |

**Critical bug fix context (2026-05-16):** Before the fix, `_expirePaddingRooms` skipped rooms where `memberCount > 0` without checking RTDB. If `cleanupMember` crashed or didn't fire, rooms with `memberCount=1` and empty RTDB were permanently stuck in padding. Now it always checks RTDB before skipping.

---

## Flutter Feature

### Domain

```dart
// Room entity — lib/features/matchmaking/domain/entities/room.dart
class Room {
  final String roomId;
  final RoomType roomType;        // public | custom
  final RoomMode mode;            // oneToOne | group
  final RoomStatus status;        // active | padding | expired
  final int maxUsers;
  final int memberCount;
  final List<String> users;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime? paddingUntil;
  final List<double>? roomInterestVector;  // ← interest field
}

// Repository interface
abstract class MatchmakingRepository {
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({String? interestText});
  Future<void> join1v1Pool({String? interestText});
  // ... other methods
}

// Use cases (domain layer — no Firebase imports)
class Join1v1Pool {
  Future<void> call({String? interestText}) => _repo.join1v1Pool(interestText: interestText);
}
class JoinGroupRoom {
  Future<({String roomId, bool isNewRoom})> call({String? interestText}) =>
      _repo.joinGroupRoom(interestText: interestText);
}
```

### Data Layer

```dart
// RoomModel — lib/features/matchmaking/data/models/room_model.dart
@freezed
abstract class RoomModel with _$RoomModel {
  const factory RoomModel({
    // ... other fields ...
    @JsonKey(name: 'roomInterestVector') List<double>? roomInterestVector,
  }) = _RoomModel;
  factory RoomModel.fromJson(Map<String, dynamic> json) => _$RoomModelFromJson(json);
}

extension RoomModelX on RoomModel {
  Room toEntity() => Room(
    // ...
    roomInterestVector: roomInterestVector,
  );
}
```

Datasource calls the CF with the interest text:
```dart
// In MatchmakingDatasourceImpl
Future<({String roomId, bool isNewRoom})> joinGroupRoom({String? interestText}) async {
  final result = await _functions.httpsCallable('joinGroupRoom').call({
    if (interestText != null) 'interestText': interestText,
  });
  // ...
}
```

### Presentation Layer

```dart
// MatchmakingState has interestText field
class MatchmakingState {
  final String interestText;  // default ''
  // ... other fields + sentinel-pattern copyWith
}

// Notifier methods
void setInterestText(String text);  // updates state + persists to SharedPreferences
void loadSavedInterestText();        // call on screen init (loads SharedPreferences)
// join1v1Pool() and joinGroupRoom() forward state.interestText automatically
```

Interest text is persisted device-locally via `shared_preferences`, pre-filling on next session including for anonymous users.

---

## Test Suites

### embeddingService.test.ts (unit — no emulator)

Run: `cd functions && npm test -- --testPathPattern embeddingService`

**4 describe groups, ~21 tests total:**

#### `cosineSimilarity` (7 tests)
| Input | Expected |
|---|---|
| identical vectors | `≈ 1.0` |
| opposite vectors | `≈ -1.0` |
| orthogonal vectors | `≈ 0.0` |
| zero vector | `0` |
| empty arrays | `0` |
| mismatched lengths | `0` |
| scaled parallel | `≈ 1.0` |

#### `meanVector` (4 tests)
| Input | Expected |
|---|---|
| single vector | identity |
| two vectors | element-wise average |
| three vectors | element-wise average |
| empty input | `[]` |

#### `embedText — graceful degradation` (2 tests, no mock)
- Returns null when `GCLOUD_PROJECT` not set (never throws)
- Returns null when Vertex AI client throws (never throws)

#### `embedText — mocked Vertex AI client` (8 tests)

**Mock setup pattern** (critical — singleton must be reset per test):
```typescript
beforeEach(() => {
  mockPredict = jest.fn();
  jest.resetModules();  // ← resets singleton _client
  jest.doMock("@google-cloud/aiplatform", () => ({
    v1: { PredictionServiceClient: jest.fn(() => ({predict: mockPredict})) },
    helpers: { toValue: (obj: unknown) => obj },  // pass-through
  }));
});

afterEach(() => {
  jest.resetModules();  // ← essential
});

// Inside each test — must require() AFTER doMock() to get fresh module:
const {embedText} = require("../embeddingService");
```

**Vertex AI mock response shape** (what `makeResponse(values)` builds):
```typescript
[{
  predictions: [{
    structValue: {
      fields: {
        embeddings: {
          structValue: {
            fields: {
              values: {
                listValue: {
                  values: values.map(n => ({numberValue: n}))
                }
              }
            }
          }
        }
      }
    }
  }]
}]
```

Tests verify:
- Returns 256-dim array on valid response
- Trims text and sends `task_type: "SEMANTIC_SIMILARITY"`
- Truncates input to 500 chars
- Sends `outputDimensionality: 256`
- Returns null for empty predictions, missing fields, empty values list, client rejection

---

### matchmaking.test.ts (integration — requires emulators)

Run: `cd functions && npm test` (after `./dev.sh --emulator-only` in another terminal)

**60 tests across 14 describe groups:**

| Group | Tests | What it covers |
|---|---|---|
| `priority` | 7 | Group room: 1-member rooms chosen over larger; random spread |
| `secondary randomness` | 4 | Random selection across 2-4 member rooms |
| `padding` | 4 | Padding state: not joinable, 1v1 rooms excluded from group |
| `RTDB and edge cases` | 4 | Membership, typing/presence paths, lock, deduplication |
| `1v1 pool and match` | 6 | Pool entry fields, matching trigger, scale (10 users → 5 pairs) |
| `1v1 leave and requeue` | 4 | 30s padding, requeue, RTDB cleanup |
| `flows` | 9 | Complete lifecycle (1v1, group, mixed, load test) |
| `regression: expireRooms` | 3 | Ghost rooms, stale memberCount, paddingUntil future |
| `1v1 interest matching: room interest vectors` | 2 | Fields set on matched rooms |
| `group room: roomInterestVector maintained on leave` | 2 | Vector recomputed/nulled on leave |
| `1v1 interest matching: prefers similar-interest candidate` | 2 | Interest sort over FIFO |
| `join1v1Pool: interest text and embedding` | 3 | Pool doc written with `interestText` + `interestVector` when text provided; null vector when no text; text truncated at 500 chars |
| `joinGroupRoom: interest text seeded into room` | 3 | Room doc gets `memberInterests` + `roomInterestVector` on join; recomputed on leave; null when last member leaves |
| `group interest matching: Phase 0 routing` | 7 | Interest-filtered candidate selection; falls back to Phase 1 when no interest match; lone-user room with matching vector found via Phase 0 |

#### Interest-specific test helpers (defined inline in test file)

```typescript
// 256-dim unit vector along dimension d — used for deterministic cosine math
const unitVec = (d: number): number[] =>
  Array.from({length: 256}, (_, i) => (i === d ? 1 : 0));

// cosine(unitVec(0), unitVec(0)) = 1.0  → matched
// cosine(unitVec(0), unitVec(1)) = 0.0  → not matched

// Directly deletes RTDB member to trigger cleanupMember CF
const rtdbDeleteMember = (roomId: string, uid: string): Promise<Response> =>
  fetch(`http://127.0.0.1:9000/rooms/${roomId}/members/${uid}.json?ns=cozytalk-5d984-default-rtdb&auth=owner`,
    {method: "DELETE"});
```

#### Interest test staging trick

Tests bypass Vertex AI by writing pool docs directly with `adminFirestoreSet`. The `status: "matching"` trick pre-populates candidates without triggering `match1v1Users`:

```typescript
// Stage uidC FIRST (older createdAt), no interest vector.
await adminFirestoreSet(`waiting_pool/${uidC}`, {
  createdAt: new Date(), updatedAt: new Date(),
  status: "matching",  // ← CF fires on CREATE but returns early (status != "waiting")
  mode: "1v1", roomId: null,
});

// Stage uidB with matching interest vector.
await adminFirestoreSet(`waiting_pool/${uidB}`, {
  status: "matching", interestVector: unitVec(0), ...
});

// Flip both to "waiting" — no new trigger fires (UPDATE, not CREATE).
await adminFirestoreUpdate(`waiting_pool/${uidC}`, {status: "waiting"});
await adminFirestoreUpdate(`waiting_pool/${uidB}`, {status: "waiting"});

// uidA arrives last — CF fires. Interest sort puts uidB first despite uidC being FIFO-oldest.
await adminFirestoreSet(`waiting_pool/${uidA}`, {
  status: "waiting", interestVector: unitVec(0), ...  // cosine(unitVec(0), unitVec(0)) = 1.0
});
```

#### Key interest test assertions

**1v1 — room has interest vectors when both users matched with them:**
```typescript
const room = await adminFirestoreDoc(`rooms/${roomId}`);
const interests = room!["memberInterests"] as Record<string, unknown>;
expect(Object.keys(interests)).toContain(uidA);
expect(Object.keys(interests)).toContain(uidB);
const rv = room!["roomInterestVector"] as number[];
expect(rv.length).toBe(256);
```

**1v1 — null when neither user has vector:**
```typescript
expect(room!["memberInterests"] ?? null).toBeNull();
expect(room!["roomInterestVector"] ?? null).toBeNull();
```

**Group — vector recomputed on leave (via cleanupMember):**
```typescript
// Write vectors directly to room
await adminFirestoreUpdate(`rooms/${roomId}`, {
  memberInterests: {[uidA]: unitVec(0), [uidB]: unitVec(1)},
  roomInterestVector: [0.5, 0.5, ...new Array(254).fill(0)],
});

// Trigger cleanupMember by deleting RTDB member
await rtdbDeleteMember(roomId, uidA);

// Wait for Firestore update
const updated = await waitUntilAdminDocMatches(`rooms/${roomId}`, (d) => {
  const mi = d?.["memberInterests"];
  return mi !== null && !Object.keys(mi ?? {}).includes(uidA);
});

// roomInterestVector should now equal uidB's unitVec(1)
expect(updated!["roomInterestVector"][1]).toBe(1);
expect(updated!["roomInterestVector"][0]).toBe(0);
```

**Group — null when last member with interest leaves:**
```typescript
// cleanupMember fires with newCount = 0 → both fields set to null
expect(updated!["roomInterestVector"] ?? null).toBeNull();
expect(updated!["memberInterests"] ?? null).toBeNull();
```

---

### testEmbeddingLive.ts (manual, not CI)

```bash
cd functions
npx ts-node -P tsconfig.test.json src/matchmaking/__tests__/testEmbeddingLive.ts
```

Requires: `gcloud auth application-default login`, `GCLOUD_PROJECT=cozytalk-5d984`, Vertex AI API enabled.

Tests 4 semantic pairs against 0.65 threshold:
- "I love football" ↔ "soccer is my favourite sport" → should match
- "I love cooking pasta" ↔ "baking bread is my hobby" → should match
- "I love football" ↔ "I enjoy baking cakes" → should NOT match
- "music and concerts" ↔ "playing guitar" → should match

---

### Flutter Tests

#### FakeMatchmakingRepository (shared_fakes.dart)

```dart
class FakeMatchmakingRepository implements MatchmakingRepository {
  // Configurable return values
  ({String roomId, bool isNewRoom}) joinGroupRoomResult = (roomId: 'Ab3Kz', isNewRoom: false);
  Exception? error;

  // Call tracking — assert these in tests
  int join1v1PoolCalls = 0;
  int joinGroupRoomCalls = 0;
  String? lastJoin1v1PoolInterest;   // ← interest tracking
  String? lastJoinGroupRoomInterest; // ← interest tracking

  @override
  Future<void> join1v1Pool({String? interestText}) async {
    join1v1PoolCalls++;
    lastJoin1v1PoolInterest = interestText;
    if (error != null) throw error!;
  }
  // ...
}

Room makeRoom({String roomId = 'Ab3Kz', ...}) { ... }  // test fixture factory
```

**Never share mutable fakes across tests** — always `setUp(() { repo = FakeMatchmakingRepository(); })`.

#### What each Flutter test file covers

| File | What it tests |
|---|---|
| `join_1v1_pool_test.dart` | `interestText` forwarded to repo; null when not provided; call count; exception propagates |
| `join_group_room_test.dart` | Same pattern for joinGroupRoom |
| `room_model_test.dart` | `fromJson` with `roomInterestVector` present/null; `toEntity()` maps the field |
| `matchmaking_state_test.dart` | `copyWith` preserves existing fields, sets `interestText` |
| `matchmaking_test_screen_test.dart` | Interest `TextField` renders; typing calls `setInterestText()` |

---

## Known Pitfalls & Gotchas

### 1. No Vertex AI emulator
`embedText` returns `null` in local emulator environments. All interest-based matching degrades to random/FIFO. To test actual embedding behavior locally you need real GCP credentials: `gcloud auth application-default login`. The `dev.sh` / `dev.ps1` scripts show a warning at startup if ADC credentials are missing.

### 2. Module singleton in tests
`embeddingService.ts` holds a module-level `_client` singleton (`let _client: PredictionServiceClient | null = null`). Tests that mock `@google-cloud/aiplatform` MUST call `jest.resetModules()` in both `beforeEach` and `afterEach`, and load the module via `require()` inside each test body (not at the top of the file). Importing at the top means the singleton is set once with the real module before any mock applies.

### 3. `status: "matching"` staging trick
`match1v1Users` is an `onDocumentCreated` trigger — it fires only on CREATE, not UPDATE. To pre-populate candidates with specific `interestVector` values in tests without triggering the CF:
1. Write with `status: "matching"` — CF fires on create but returns immediately
2. Update to `status: "waiting"` — no trigger fires
3. Write the actual trigger user with `status: "waiting"` — CF fires with staged candidates ready

### 4. Region split in emulator
`match1v1Users` and `cleanupMember` are deployed to `asia-southeast1`. The local emulator runs all functions in `us-central1`. In some emulator configurations, `cleanupMember` may not fire. The regression tests in `matchmaking.test.ts` cover this path by corrupting the Firestore doc directly and running `expireRooms` to clean it up.

### 5. RTDB trigger vs. leaveRoom for interest tests
`cleanupMember` (RTDB trigger) handles interest vector recomputation, same as `leaveRoom` (callable CF). Tests that target `cleanupMember` specifically use `rtdbDeleteMember()` to delete the RTDB path directly, not `callFn("leaveRoom")` — because `leaveRoom` already updates the Firestore doc before cleanupMember fires, which would make the test order-dependent.

### 6. Interest matching does NOT affect group Phase 1 priority
Phase 0 (interest) has higher priority than Phase 1 (lone-user), but Phase 0 draws from the combined Phase 1 + Phase 2 candidate pool. A lone-user room with a matching interest vector is found in Phase 0, not Phase 1. A lone-user room with no matching vector falls back to Phase 1 (regular priority behavior).

### 7. `waitingPool` field interestVector is written by CF, not Flutter
Flutter passes `interestText` as a string to the CF. The CF calls `embedText()` and stores both `interestText` and `interestVector` in the pool doc. The Flutter app never handles raw float vectors.

---

## Setup Checklist (from scratch)

1. **Enable Vertex AI API** in GCP Console for project `cozytalk-5d984`
2. **Local credentials** for embedding: `gcloud auth application-default login`
3. **Install CF dependencies**: `cd functions && npm install` (adds `@google-cloud/aiplatform`)
4. **Flutter**: `cd apps/mobile && flutter pub get && dart run build_runner build`
5. **Run emulators**: `./dev.sh --emulator-only`
6. **Run CF tests**: `cd functions && npm test`
7. **Run Flutter tests**: `cd apps/mobile && flutter test`

Without step 2, embedding returns null and matching falls back to random — no crash, but interest features won't work locally.

---

## Firestore Indexes Required

The `joinGroupRoom` queries use composite indexes. Ensure these exist in `firestore.indexes.json`:

- `rooms`: `mode ASC, status ASC, isLocked ASC, memberCount ASC` (for Phase 1 + Phase 2 queries)
- `waiting_pool`: `mode ASC, status ASC, createdAt ASC` (for match1v1Users candidate query)
- `waiting_pool`: `status ASC, createdAt ASC` (for expireRooms stale-matching reset)

---

## Quick Reference: Similarity Math

```typescript
// cosine similarity: 1.0 = identical direction, 0.65 = threshold, 0.0 = orthogonal, -1.0 = opposite
cosineSimilarity(unitVec(0), unitVec(0)) === 1.0   // same interest → matched
cosineSimilarity(unitVec(0), unitVec(1)) === 0.0   // orthogonal → not matched
cosineSimilarity(unitVec(0), unitVec(0).map(x => -x)) === -1.0  // opposite

// mean of two unit vectors along different dimensions
meanVector([unitVec(0), unitVec(1)]) // → [0.5, 0.5, 0, 0, ...]

// practical note: real Vertex AI embeddings are dense (not unit) — all 256 dims have values
// unitVec() is only used in tests for deterministic math
```
