# Chapter 11 Plan — Cloud Functions Tests

## Scope

```
functions/src/matchmaking/__tests__/
├── matchmaking.test.ts            (60 unit tests, 14 describe groups)
├── embeddingService.test.ts       (21 unit tests)
├── embeddingService.integration.test.ts  (7 live Vertex AI tests)
├── testEmbeddingLive.ts           (manual test script)
├── testProdVertexAI.ts            (manual prod test script)
└── helpers.ts                     (shared test helpers)

functions/src/chat/__tests__/
└── chat.test.ts                   (11 unit tests)

functions/jest.config.js
functions/jest.integration.config.js
functions/tsconfig.test.json
```

---

## Checks to Perform

### 11.1 Jest Configuration
- [ ] `jest.config.js` — unit test pattern matches `**/__tests__/**/*.test.ts` but excludes `.integration.test.ts`.
- [ ] `jest.integration.config.js` — integration test pattern matches only `*.integration.test.ts`.
- [ ] Both configs: single worker (sequential) — confirm `--runInBand` or `maxWorkers: 1`.
- [ ] Timeout: 60s for unit, 30s for integration — are these appropriate? Integration hitting real Vertex AI may need more.
- [ ] TypeScript resolved via `ts-jest` preset.
- [ ] `tsconfig.test.json` extends base tsconfig and doesn't exclude `__tests__/`.
- [ ] `eslint.config.mjs` correctly ignores `__tests__/**` (per CLAUDE.md — confirm this is intentional and why).

### 11.2 Test Count Verification
- [ ] Run `npm test -- --verbose` and count:
  - `matchmaking.test.ts`: should be 60 tests in 14 describe groups.
  - `embeddingService.test.ts`: should be 21 tests.
  - `chat.test.ts`: should be 11 tests.
  - Total unit: 92 (CLAUDE.md says 99 — discrepancy?).
- [ ] Note actual count and flag any mismatch with CLAUDE.md.

### 11.3 `matchmaking.test.ts` Quality Review
- [ ] All 14 describe groups correspond to real CF behavior areas (not arbitrary groupings).
- [ ] Auth checks tested — unauthenticated caller rejected.
- [ ] `match1v1Users.ts` — transaction behavior tested (simulate concurrent writes).
- [ ] `match1v1Users.ts` — cosine similarity threshold (0.65) tested:
  - Pair with similarity > 0.65: matched.
  - Pair with similarity < 0.65: falls back to FIFO.
  - Pair where one has no vector: FIFO used.
- [ ] `expireRooms.ts` — `memberCount == 0` check before delete tested.
- [ ] `joinRoomById.ts` — locked room rejection tested.
- [ ] `createCustomRoom.ts` — roomId collision retry tested (or at least that retry logic is unit-tested somewhere).
- [ ] `cleanupMember.ts` — Firestore memberCount decrement tested.
- [ ] `cleanupPoolMember.ts` — waiting_pool delete tested.
- [ ] Error cases: invalid-argument, not-found, permission-denied are all tested.
- [ ] Firebase Admin SDK is mocked (not real Firestore in unit tests).
- [ ] Mock library used: confirm it's not jest.mock of the actual Firebase SDK in a way that couples tests to implementation details.

### 11.4 `embeddingService.test.ts` Quality Review
- [ ] `embedText()` — success case: returns `number[]` of length 256.
- [ ] `embedText()` — failure case: Vertex AI throws → function returns `null`.
- [ ] `embedText()` — empty string input handled gracefully.
- [ ] `cosineSimilarity()` — correct value for known vectors.
- [ ] `cosineSimilarity()` — zero vector: no divide-by-zero (returns 0 or handles gracefully).
- [ ] `cosineSimilarity()` — same vector: returns 1.0 (exactly or approximately).
- [ ] `cosineSimilarity()` — orthogonal vectors: returns 0.
- [ ] `meanVector()` — correct mean for simple case.
- [ ] `meanVector()` — empty array: handled gracefully (returns zero vector or throws with clear message?).
- [ ] `meanVector()` — mismatched dimension arrays: handled?

### 11.5 `embeddingService.integration.test.ts` Quality Review
- [ ] 7 live tests — what do they test exactly?
- [ ] Require `GOOGLE_APPLICATION_CREDENTIALS` or Firebase project access.
- [ ] Are they isolated from production data?
- [ ] Can they run in CI? (CLAUDE.md says they require `npm run test:embedding` separately — not in main CI.)
- [ ] Confirm these are excluded from `npm test` (unit-only run).

### 11.6 `chat.test.ts` Quality Review
- [ ] `sendMessage` — authenticated caller, message written with correct fields.
- [ ] `sendMessage` — `senderId` set from auth UID (not from payload).
- [ ] `sendMessage` — `displayName` sourced from Firestore (not from payload).
- [ ] `sendMessage` — encryption fields present (IV unique per call — test two messages, IVs differ).
- [ ] `sendMessage` — unauthenticated caller rejected.
- [ ] `endSession` — encryption key archived to `session_keys`.
- [ ] `endSession` — RTDB data destroyed.
- [ ] `endSession` — non-participant rejected.
- [ ] `reportSession` — chat log retained.
- [ ] `reportSession` — self-report rejected.
- [ ] `reportSession` — unauthenticated rejected.
- [ ] Are all 11 tests accounting for the above behaviors? Any obvious gaps?

### 11.7 `helpers.ts`
- [ ] What does it export? (Test data factories, Firebase Admin mock setup, etc.)
- [ ] Is the emulator connection code correct (points to localhost:ports)?
- [ ] Helper functions are reusable and not test-specific.

### 11.8 Manual Test Scripts (`testEmbeddingLive.ts`, `testProdVertexAI.ts`)
- [ ] These are manual scripts, not Jest tests — confirm they're not in the Jest test pattern.
- [ ] They should NOT be committed with real credentials.
- [ ] Are they gitignored? (They may contain env-specific config that shouldn't be in the repo.)
- [ ] Do they have a `// DO NOT COMMIT CREDENTIALS` comment?

### 11.9 ESLint on Test Files
- [ ] `eslint.config.mjs` ignores `__tests__/**` — this means test files have NO linting.
- [ ] Is this intentional? Document the tradeoff in the review.
- [ ] Check for `console.log` spam in test files (would normally be caught by lint).
- [ ] Check for `any` types in test files (no lint means they're unchecked).

### 11.10 Test-to-Source Mapping
For each CF source file, verify test coverage exists:

| Source File | Has Unit Test | Key Behaviors Tested | Gaps |
|-------------|---------------|----------------------|------|
| `join1v1Pool.ts` | ? | ? | ? |
| `cancel1v1Pool.ts` | ? | ? | ? |
| `match1v1Users.ts` | ? | Transaction? Similarity? | ? |
| `joinGroupRoom.ts` | ? | ? | ? |
| `createCustomRoom.ts` | ? | ? | ? |
| `joinRoomById.ts` | ? | Locked room? | ? |
| `leaveRoom.ts` | ? | ? | ? |
| `setRoomLock.ts` | ? | Non-custom room? | ? |
| `expireRooms.ts` | ? | memberCount==0 check? | ? |
| `cleanupMember.ts` | ? | ? | ? |
| `cleanupPoolMember.ts` | ? | ? | ? |
| `sendMessage.ts` | ? | IV uniqueness? | ? |
| `endSession.ts` | ? | Non-participant? | ? |
| `reportSession.ts` | ? | Self-report? | ? |

---

## Files to Read in Full

1. `functions/src/matchmaking/__tests__/matchmaking.test.ts`
2. `functions/src/matchmaking/__tests__/embeddingService.test.ts`
3. `functions/src/matchmaking/__tests__/embeddingService.integration.test.ts`
4. `functions/src/matchmaking/__tests__/helpers.ts`
5. `functions/src/chat/__tests__/chat.test.ts`
6. `functions/jest.config.js`
7. `functions/jest.integration.config.js`

---

## Expected Findings Categories

- Test count mismatch with CLAUDE.md (99 vs actual) (INFO — update docs)
- Missing IV uniqueness test in chat tests (HIGH — crypto correctness)
- Missing cosine similarity threshold boundary tests (MEDIUM)
- Missing `match1v1Users` transaction race condition test (HIGH)
- `testEmbeddingLive.ts` committed with credentials (CRITICAL if found)
- ESLint bypass for test files — unchecked `any` types (MEDIUM)
- Missing `cosineSimilarity` zero-vector test (HIGH — div-by-zero protection)

---

## Output

Write findings to `reviews/ch11_cf_tests.md` including:
- Actual test counts (unit vs integration)
- Test-to-source mapping table (filled in)
- Specific missing behaviors for each CF
