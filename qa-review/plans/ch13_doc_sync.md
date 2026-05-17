# Chapter 13 Plan — Documentation Sync

## Scope

This chapter runs LAST — after all other chapters complete. It uses findings from Ch01–Ch12 to identify every place where docs describe something different from what the code actually does, then updates the docs.

```
CLAUDE.md                           (primary — most-read, most likely to drift)
README.md
PROJECT_CONTEXT.md
MATCHMAKING_CONTEXT_AWARE.md
context-aware_matchmaking.md        (check if duplicate of above)
CLEAN_ARCH_EXPLAINER.md             (check if still accurate)
qa-review/MASTER_QA_PLAN.md        (update tracking table after all chapters done)
```

---

## Checks to Perform

### 13.1 CLAUDE.md — Section-by-Section Audit

#### What is this project?
- [ ] Stack description matches reality (Flutter + Riverpod + Firebase + TypeScript CFs).
- [ ] Platform targets: Android + Web. Is iOS mentioned? Should it be excluded explicitly?

#### Core Principle: Privacy by Design
- [ ] RTDB `messages/{roomId}` — CLAUDE.md says this path is destroyed by CF. Cross-check with Ch08: is it actually `messages/{roomId}` or a different path? (`chat_rooms/{sessionId}/messages` is what the code uses.)
- [ ] `active_sessions` deletion — still accurate after rooms/{roomId} migration?
- [ ] Report retention flow — matches `reportSession.ts` behavior (from Ch08)?

#### Essential Commands
- [ ] `flutter pub get` — still correct (check pubspec.yaml SDK version).
- [ ] `dart run build_runner build` — still correct (no flags mentioned; CLAUDE.md doesn't say `--delete-conflicting-outputs`; is that an issue?).
- [ ] `npm test` command description: "99 unit tests total" — cross-check with Ch11 actual count.
- [ ] Jest test file descriptions: "matchmaking.test.ts (60 tests, 14 describe groups)" — cross-check with Ch11.
- [ ] "7 live Vertex AI integration tests" — cross-check with Ch11.
- [ ] `./dev.sh --emulator-only` — cross-check with Ch12 (does it actually do that?).

#### Architecture / Feature Sections
- [ ] Matchmaking CFs: "11 exported in `functions/src/matchmaking/`" — cross-check with Ch07 index.ts audit.
- [ ] Chat CFs: `setTyping.ts` description matches what Ch08 found (no CF, client writes RTDB directly).
- [ ] `HelloScreen` description as dev hub — still accurate (has "Test Matchmaking" button, "Edit profile" button)?
- [ ] `AvatarPickerScreen` known issue (Firebase.instance direct call) — still present after Ch05 review.
- [ ] Test count: "347 tests total" — cross-check with Ch10 actual `flutter test` count.
- [ ] Test file count per feature — update if any are wrong.
- [ ] Auth feature: `_anonymousName` duplication note ("extract if 3rd caller appears") — is there a 3rd caller yet?
- [ ] Profile feature: `successField` values `'username'|'interest'|'thoughts'` — verify these match actual code.
- [ ] Chat feature: `WatchTypingUsers` use case mentioned — cross-check with actual file name (`watch_partner_typing.dart` vs `watch_typing_users.dart`).
- [ ] Avatar feature: `UpdateDecoration` use case — cross-check it's actually in the codebase.
- [ ] Home feature: "no domain or data layers" — verify this is still true.

#### Firestore Collections Table
- [ ] `users/{uid}` fields — check all fields exist in datasource writes (Ch02, Ch05).
- [ ] `waiting_pool/{uid}` fields — verify against join1v1Pool.ts (Ch07).
- [ ] `rooms/{roomId}` description — accurate after Ch07 review.
- [ ] `active_sessions` — is it still used? Or effectively deprecated?
- [ ] `chat_rooms/{sessionId}/messages/{messageId}` fields — verify against sendMessage.ts (Ch08).
- [ ] `session_keys/{sessionId}` fields — verify against endSession.ts (Ch08).

#### Code Conventions
- [ ] Sentinel pattern description — cross-check actual `copyWith` implementations from Ch02–Ch05.
- [ ] "Map from Firebase" normalization — confirm it's actually used everywhere.
- [ ] "Test fakes — `_FakeXxxNotifier` must track invocations (callCount)" — cross-check with Ch10 findings.

#### Quality Gates
- [ ] ">80% unit test coverage for domain layer" — update with actual Ch10 coverage numbers.

#### Testing Section
- [ ] Test file count claims (per feature) — update from Ch10 findings.
- [ ] Fake patterns — still match what's in the codebase?

---

### 13.2 README.md — Audit

- [ ] Is this the public-facing README (for GitHub visitors)?
- [ ] Does it accurately describe the project (cross-platform stranger chat app)?
- [ ] Stack section matches CLAUDE.md and reality.
- [ ] Setup instructions: do they match `setup.sh` and `dev.sh`?
- [ ] Does it mention the PR template? (Good practice to mention.)
- [ ] Is there a CI badge showing build status? (Should there be?)
- [ ] Are the Firebase project details (project ID, region) exposed in README? (They are public — OK.)
- [ ] Is there a "Contributing" section? If not, at minimum a pointer to CLAUDE.md.

---

### 13.3 PROJECT_CONTEXT.md — Audit

- [ ] Is the RTDB path table complete and accurate? Cross-check with Ch07, Ch08.
- [ ] Room state machine description — matches actual CF behavior after Ch07 review.
- [ ] Firestore schema — every collection, every field, matches code reality.
- [ ] Security model description — matches `firestore.rules` after Ch09 review.
- [ ] Any stale architecture decisions documented here that have since changed?

---

### 13.4 MATCHMAKING_CONTEXT_AWARE.md & context-aware_matchmaking.md

- [ ] Are these two files duplicates, related, or complementary? Determine relationship.
- [ ] If one is a draft and the other is final: delete the draft or clearly label it.
- [ ] Embedding model: `text-multilingual-embedding-002`, 256 dims — verify against `embeddingService.ts` (Ch07).
- [ ] Cosine similarity threshold: `0.65` — verify against `match1v1Users.ts` (Ch07).
- [ ] FIFO fallback description — matches code?
- [ ] `null` on embed failure → graceful degradation — matches code?
- [ ] Test coverage section: matches Ch11 findings.
- [ ] Data model section: `interestText?`, `interestVector?` in `waiting_pool` — matches code.
- [ ] Pitfalls section: are the listed pitfalls still relevant? Any new ones from Ch07/Ch08?

---

### 13.5 CLEAN_ARCH_EXPLAINER.md
- [ ] Does this exist? (It was found in the file tree.)
- [ ] Is it accurate vs actual CLAUDE.md architecture section?
- [ ] Is it redundant with CLAUDE.md? If so, flag for consolidation.

---

### 13.6 Duplicate / Stale Documents
- [ ] `context-aware_matchmaking.md` vs `MATCHMAKING_CONTEXT_AWARE.md` — resolve duplication.
- [ ] `CLEAN_ARCH_EXPLAINER.md` vs CLAUDE.md architecture section — resolve duplication.
- [ ] Any other `.md` files at root that are stale or redundant.

---

### 13.7 Update Priority List

After completing the audit, rank updates by impact:

| Priority | Document | Section | Change Type |
|----------|----------|---------|-------------|
| 1 | CLAUDE.md | Test counts | Update from Ch10/Ch11 actual |
| 2 | CLAUDE.md | RTDB path in Privacy section | Correct path name |
| 3 | CLAUDE.md | CF export count | Verify against Ch07 |
| 4 | PROJECT_CONTEXT.md | RTDB path table | Verify completeness |
| 5 | MATCHMAKING_CONTEXT_AWARE.md | De-duplicate vs context-aware_matchmaking.md | |
| ... | ... | ... | ... |

---

## Output Format

`reviews/ch13_doc_sync.md` must include:

1. **Doc-Drift Table** — every discrepancy found:

| Document | Section | What Doc Says | What Code Does | Severity | Fix |
|----------|---------|---------------|----------------|----------|-----|
| ... | ... | ... | ... | ... | ... |

2. **Required Edits** — specific changes to make in each doc file (enough detail that an agent can execute them without re-reading this plan).

3. **Consolidation Recommendations** — duplicate docs to merge or remove.

4. **Updated MASTER_QA_PLAN.md tracking table** — mark all chapters as "Review Done."

---

## Execution Note

This chapter CANNOT start until chapters 1–12 have produced their review files. The reviewer must read all prior `reviews/chXX_*.md` files before beginning the doc-sync audit.
