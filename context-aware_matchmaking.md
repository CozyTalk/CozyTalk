# Context-Aware Interest Matchmaking — Decision Log

> **Authoritative reference:** [`MATCHMAKING_CONTEXT_AWARE.md`](MATCHMAKING_CONTEXT_AWARE.md) — full implementation details, file map, CF logic, test suites, and known pitfalls. This document is a decision log only; it records *what* was decided and *why*, not how to use it.

Text-embedding-based interest matching for CozyTalk's 1v1 and group room flows. Users optionally type a phrase ("I like football") before joining; the system generates a 256-dimensional embedding vector and uses cosine similarity to prefer interest-compatible pairings. Users with no interest typed fall back to the existing algorithm unchanged.

---

## Decisions

| Decision | Value |
|---|---|
| Embedding provider | Vertex AI `text-multilingual-embedding-002` (multilingual, 768 dims max) via ADC |
| Output dimensions | 256 (compact storage, 95%+ quality vs full 768) |
| Interest persistence | Device-local via `shared_preferences` — pre-fills on next session for all users including anonymous |
| Similarity threshold | `0.65` cosine similarity (`INTEREST_SIMILARITY_THRESHOLD` constant) |
| UI scope | `matchmaking_test_screen.dart` only — production UI later |
| Per-member vector storage | `memberInterests: {uid: vector}` map on room doc, enables accurate recompute on leave |

---

## Data Model Changes

### `waiting_pool/{uid}` — 2 new nullable fields
```
interestText: string | null      // raw phrase the user typed
interestVector: number[] | null  // 256-dim Vertex embedding; null if no interest
```
Written by `join1v1Pool` CF via admin SDK (bypasses Firestore rules).

### `rooms/{roomId}` — 2 new nullable fields
```
roomInterestVector: number[] | null          // mean of all member interestVectors
memberInterests: { [uid: string]: number[] } | null  // per-member vectors for recomputation
```
Written by `joinGroupRoom`, `match1v1Users`, `leaveRoom`, `cleanupMember` CFs via admin SDK.

**Storage**: 256 dims × 5 members ≈ 10 KB max per room doc. Well within Firestore's 1 MB limit.

---

## New File: `functions/src/matchmaking/embeddingService.ts`

- `embedText(text)` — calls Vertex AI, returns `number[] | null` (never throws)
- `cosineSimilarity(a, b)` — returns similarity in [-1, 1]; 0 for zero-length vectors
- `meanVector(vectors)` — element-wise mean of same-length vectors
- `INTEREST_SIMILARITY_THRESHOLD = 0.65` — configurable constant

**Package**: `@google-cloud/aiplatform` added to `functions/package.json`.

**API**:
```typescript
import {v1, helpers} from "@google-cloud/aiplatform";

const client = new v1.PredictionServiceClient({
  apiEndpoint: "us-central1-aiplatform.googleapis.com",
});

const [response] = await client.predict({
  endpoint: `projects/${project}/locations/us-central1/publishers/google/models/text-multilingual-embedding-002`,
  instances: [helpers.toValue({content: text, task_type: "SEMANTIC_SIMILARITY"})!],
  parameters: helpers.toValue({outputDimensionality: 256}),
});

// Response navigation:
const vector = response.predictions![0]
  .structValue?.fields?.["embeddings"]
  ?.structValue?.fields?.["values"]
  ?.listValue?.values
  ?.map((v) => v.numberValue ?? 0) ?? [];
```

**Auth**: ADC — automatic in production (service account), requires `gcloud auth application-default login` for local emulator. `GCLOUD_PROJECT` env var is set automatically in both environments.

**Emulator compatibility**: `embedText` wraps in try/catch — returns `null` on any failure and matching degrades gracefully to existing random algorithm. No emulator for Vertex AI; developers need real GCP credentials locally.

---

## Cloud Function Changes

### `join1v1Pool.ts`
- Accepts optional `data.interestText: string`
- Embeds via `embedText()`, stores `interestText` + `interestVector` in pool doc

### `match1v1Users.ts`
- Candidate query expanded from 6 → 20 for better interest coverage
- Reads triggering user's `interestVector` from event doc
- Partitions candidates: interest-matching first (similarity ≥ threshold, shuffled), FIFO remainder
- Room creation includes `memberInterests` + `roomInterestVector` when both users have vectors

### `joinGroupRoom.ts`
- Accepts optional `data.interestText: string`
- Phase 1 + Phase 2 queries run in parallel upfront
- **Phase 0** (new, only when user has interest): filters combined candidates by similarity ≥ threshold, tries those first
- Priority: Phase 0 (interest match) → Phase 1 (lone-user) → Phase 2 (2-4 member) → Phase 3 (create new)
- Room join transaction: adds `memberInterests[uid]`, recomputes `roomInterestVector = mean(all vectors)`
- New room creation: seeds `memberInterests` + `roomInterestVector` if user has interest

### `leaveRoom.ts` + `cleanupMember.ts`
- When a group member leaves: removes `memberInterests[uid]`, recomputes `roomInterestVector`
- If no members with interest remain: sets both fields to `null`

### `_utils.ts`
- `RoomData` interface extended with optional `roomInterestVector` + `memberInterests`

---

## Flutter Changes

### Domain
- `Room` entity: add `roomInterestVector: List<double>?`
- `Join1v1Pool.call({String? interestText})` — optional param
- `JoinGroupRoom.call({String? interestText})` — optional param
- `MatchmakingRepository` interface updated for both

### Data
- `RoomModel`: add `roomInterestVector: List<double>?` (Freezed field)
- `MatchmakingDatasource.join1v1Pool({String? interestText})` — passes to CF
- `MatchmakingDatasource.joinGroupRoom({String? interestText})` — passes to CF
- `MatchmakingRepositoryImpl` forwards params

### Presentation
- `MatchmakingState`: add `interestText: String` (default `''`)
- `MatchmakingNotifier.setInterestText(String)` — updates state + persists to SharedPreferences
- `MatchmakingNotifier.loadSavedInterestText()` — loads from SharedPreferences on screen init
- `join1v1Pool()` / `joinGroupRoom()` pass `state.interestText` to use cases
- `matchmaking_test_screen.dart`: add interest `TextField` above action buttons

---

## Group Matching Priority (user perspective)

| Priority | Condition |
|---|---|
| 1 | Room with matching interest (cosine ≥ 0.65), any size 1–4 |
| 2 | Lone-user room (memberCount == 1) — existing Phase 1 |
| 3 | 2–4 member room — existing Phase 2 |
| 4 | Create new room — existing Phase 3 |

---

## Test Coverage

### Jest — `functions/src/matchmaking/__tests__/`

**New: `embeddingService.test.ts`**
- `cosineSimilarity`: parallel → 1.0; orthogonal → 0.0; opposite → -1.0; zero → 0
- `meanVector`: identity, two-vector average, three vectors
- `embedText`: mocked client returns 256-dim shape; API error → null (no throw)

**New describe groups in `matchmaking.test.ts`**
- `"1v1 interest matching: prefers similar-interest candidates"` — 3 scenarios
- `"1v1 interest matching: falls back to FIFO without interest data"` — 3 scenarios
- `"group interest matching: routes to interest-matching room"` — 4 scenarios
- `"group interest matching: graceful fallback"` — 3 scenarios
- `"room interest vector: maintained on join/leave"` — 6 scenarios

### Flutter — `test/features/matchmaking/`

Updated files:
- `domain/usecases/join_1v1_pool_test.dart` — interestText forwarded/null
- `domain/usecases/join_group_room_test.dart` — same
- `data/models/room_model_test.dart` — roomInterestVector fromJson + toEntity
- `presentation/providers/matchmaking_state_test.dart` — interestText copyWith
- `presentation/screens/matchmaking_test_screen_test.dart` — interest field renders + interaction

Updated shared:
- `domain/shared_fakes.dart` — FakeMatchmakingRepository tracks interestText args

---

## Setup Notes

1. Enable **Vertex AI API** in GCP Console for project `cozytalk-5d984`
2. For local emulator development: run `gcloud auth application-default login`
   - `dev.sh` (Linux/macOS) and `dev.ps1` (Windows) show a warning at startup if ADC credentials are missing
   - Without credentials, `embedText()` returns `null` and matching falls back to random — no crash, no action needed
3. Install new CF dependency: `cd functions && npm install`
4. Rebuild Flutter: `cd apps/mobile && flutter pub get && dart run build_runner build`
