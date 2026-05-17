# Chapter 13 — Documentation Sync QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase4
> Date: 2026-05-17

## Summary

Final documentation sync pass over all five top-level docs: `CLAUDE.md`, `README.md`, `PROJECT_CONTEXT.md`, `MATCHMAKING_CONTEXT_AWARE.md`, and `context-aware_matchmaking.md`. Also reviewed `CLEAN_ARCH_EXPLAINER.md`. Cross-referenced all findings from Ch07–Ch12. Applied all doc-drift fixes inline: nameQueue access control, removed legacy RTDB paths, removed setTyping.ts reference, chatLog CF-only annotation, correct test counts (92 unit + 7 integration), avatar screen test status, Java version in README, "16 functions" → "15", tools/ description in CLAUDE.md. `MATCHMAKING_CONTEXT_AWARE.md` and `context-aware_matchmaking.md` are accurate; no changes needed beyond cross-references. `CLEAN_ARCH_EXPLAINER.md` is a pure explainer with no implementation references — no drift possible.

**Findings by severity:** HIGH 1 (fixed) · MEDIUM 3 (fixed) · LOW 5 (fixed) · INFO 3

---

## Doc-Drift Table

| Doc File | Section | Was | Now | Severity | Applied |
|---|---|---|---|---|---|
| `README.md` | Prerequisites table | Java 17 \| 17+ | Java 21 \| 21+ | HIGH | ✅ |
| `PROJECT_CONTEXT.md` | RTDB rules table | includes `sessions/` + `messages/` rows | removed (no longer in rules) | MEDIUM | ✅ |
| `PROJECT_CONTEXT.md` | RTDB paths summary | includes `sessions/`, `messages/` rows | removed | MEDIUM | ✅ |
| `PROJECT_CONTEXT.md` | CF table note | "`setTyping.ts` source exists but not exported" | "No CF needed; `setTyping.ts` removed" | MEDIUM | ✅ |
| `PROJECT_CONTEXT.md` | RTDB rules table `nameQueue` | "Read/Write: any signed-in" | "Read/Write: room member only" | MEDIUM | ✅ |
| `PROJECT_CONTEXT.md` | `reports/{reportId}` schema `chatLog` | no CF-only note | "CF-written only (not client-writable)" | LOW | ✅ |
| `PROJECT_CONTEXT.md` | Jest test count | 99 unit tests | 92 unit + 7 integration = 99 total | LOW | ✅ |
| `PROJECT_CONTEXT.md` | CF test breakdown | "chat.test.ts (11 tests)" | "chat.test.ts (12 tests) — rooms/ path added" | LOW | ✅ |
| `PROJECT_CONTEXT.md` | Repo layout | avatar "no tests yet" | "screen widget test pending" | LOW | ✅ |
| `PROJECT_CONTEXT.md` | avatar feature section | "(complete, tests pending)" | "(complete)" | LOW | ✅ |
| `README.md` | check-prod-config.sh section | "16 Cloud Functions" | "15 Cloud Functions" | LOW | ✅ |
| `CLAUDE.md` | Monorepo Layout | `tools/ ← CLI tools (reserved, empty)` | describes `check-prod-config.sh` | LOW | ✅ |

---

## Findings

### F-001 — README Java version table says 17+ (corrected)
- **Severity:** HIGH
- **File:** `README.md` — Prerequisites table
- **Category:** Doc-Drift
- **Description:** README listed "Java 17 | 17+" but `setup.sh` and `setup.ps1` both warn on Java < 21, and Firebase emulators require Java 21+. A new contributor following README would install JDK 17, then encounter cryptic emulator startup failures.
- **Fix applied:** Updated to "Java 21 | 21+".

---

### F-002 — PROJECT_CONTEXT.md RTDB table shows removed `sessions/` and `messages/` paths
- **Severity:** MEDIUM
- **File:** `PROJECT_CONTEXT.md` — Realtime Database rules table and RTDB paths summary
- **Category:** Doc-Drift
- **Description:** `database.rules.json` had `sessions` and `messages` paths removed in Phase 1 (Ch09 finding L-01). PROJECT_CONTEXT still listed them as valid paths with access rules. Any developer reading this to understand the RTDB schema would believe those paths are still active.
- **Fix applied:** Removed both rows from the RTDB rules table; removed both rows from the RTDB paths summary table.

---

### F-003 — PROJECT_CONTEXT.md `setTyping` note references deleted file
- **Severity:** MEDIUM
- **File:** `PROJECT_CONTEXT.md` — Cloud Functions table
- **Category:** Doc-Drift
- **Description:** The CF table included a note: "`setTyping` source exists (`functions/src/chat/setTyping.ts`) but is not exported". `setTyping.ts` was deleted in Phase 1 (Ch08 finding H-02).
- **Fix applied:** Replaced with: "No CF needed for typing — clients write `typing/{roomId}/{uid}` directly via RTDB SDK. (`setTyping.ts` was removed as dead code.)"

---

### F-004 — PROJECT_CONTEXT.md `nameQueue` RTDB access still says "any signed-in"
- **Severity:** MEDIUM
- **File:** `PROJECT_CONTEXT.md` — RTDB rules table
- **Category:** Doc-Drift
- **Description:** Phase 1 (Ch09 finding M-03) restricted `nameQueue` read/write to room members only. The doc still showed "any signed-in".
- **Fix applied:** Updated to "Read/Write: room member only".

---

### F-005 — PROJECT_CONTEXT.md `chatLog` field has no CF-only annotation
- **Severity:** LOW
- **File:** `PROJECT_CONTEXT.md` — `reports/{reportId}` schema
- **Category:** Doc-Drift
- **Description:** Phase 1 (Ch09 finding M-02) removed `chatLog` from the Firestore client-writable create rule. The schema table didn't reflect that clients can no longer write this field.
- **Fix applied:** Added "CF-written only (not client-writable)" to the `chatLog` row notes.

---

### F-006 — PROJECT_CONTEXT.md and CLAUDE.md test counts say "99 unit tests"
- **Severity:** LOW
- **File:** `PROJECT_CONTEXT.md` (test count table and CF breakdown), `CLAUDE.md` (Jest Tests section)
- **Category:** Doc-Drift
- **Description:** 60 + 21 + 11 = 92 unit tests. The 7 integration tests bring the total to 99. Both docs said "99 unit tests" which conflates unit and integration. Additionally, the Phase 3 endSession rooms/ test adds one more to chat.test.ts, bringing it to 12.
- **Fix applied:** PROJECT_CONTEXT.md test count table and CF breakdown updated. CLAUDE.md was already fixed in Phase 3.

---

### F-007 — README "16 Cloud Functions" in check-prod-config section
- **Severity:** LOW
- **File:** `README.md`
- **Category:** Doc-Drift
- **Description:** 15 functions are exported. The check-prod-config.sh only checked 10 (fixed in Ch12). The README description of that script claimed "16".
- **Fix applied:** Updated to "15 Cloud Functions".

---

### F-008 — CLAUDE.md tools/ described as "reserved, empty"
- **Severity:** LOW
- **File:** `CLAUDE.md` — Monorepo Layout
- **Category:** Doc-Drift
- **Description:** `tools/check-prod-config.sh` exists and is documented in README but CLAUDE.md said tools/ is empty.
- **Fix applied:** Updated to describe `check-prod-config.sh`.

---

### F-009 — `context-aware_matchmaking.md` is accurate — no changes needed
- **Severity:** INFO
- **File:** `context-aware_matchmaking.md`
- **Category:** None
- **Description:** The decision log correctly points to `MATCHMAKING_CONTEXT_AWARE.md` as the authoritative reference. All decisions recorded (Vertex AI model, 256 dims, 0.65 threshold, SharedPreferences for interestText, memberInterests map design) are still accurate and implemented as described.
- **Recommendation:** None.

---

### F-010 — `MATCHMAKING_CONTEXT_AWARE.md` is accurate — no changes needed
- **Severity:** INFO
- **File:** `MATCHMAKING_CONTEXT_AWARE.md`
- **Category:** None
- **Description:** All file references, data model tables, embedding API reference, and test suite descriptions are accurate. The test breakdown reflects all current test files. The `testProdVertexAI.ts` manual script was not mentioned in the file map (only `testEmbeddingLive.ts` was listed), but this is a minor omission with no operational impact since both are excluded from Jest.
- **Recommendation:** Optionally add `testProdVertexAI.ts` to the `__tests__/` file map for completeness.

---

### F-011 — `CLEAN_ARCH_EXPLAINER.md` has no implementation references — no drift possible
- **Severity:** INFO
- **File:** `CLEAN_ARCH_EXPLAINER.md`
- **Category:** None
- **Description:** This is a conceptual explainer for developers coming from TypeScript/Java. It uses the `hello` feature as an example but describes the pattern abstractly. No code snippets reference specific file paths or class names that could drift. No changes needed.
- **Recommendation:** None.

---

## Cross-Chapter Drift Summary

This table maps every finding from prior chapters that had a doc-drift component to its resolution status.

| Finding | Chapter | Doc File | Resolution |
|---|---|---|---|
| D-01: `expiresAt` vs `paddingUntil` in rooms schema | Ch07 | CLAUDE.md | ✅ Fixed in Phase 1 |
| D-02: `onProtoPresenceDeleted` described as active | Ch07 | CLAUDE.md | ✅ Fixed in Phase 1 |
| D-03: `helloWorld` missing from CF export count | Ch07 | CLAUDE.md | ✅ Fixed in Phase 1 |
| D-04: `setTyping.ts` dead code | Ch08 | CLAUDE.md, PROJECT_CONTEXT.md | ✅ Fixed Phase 1 + Phase 4 |
| D-05: `mode` vs `roomType` distinction | Ch07 | CLAUDE.md | ✅ Fixed in Phase 1 |
| D-06: Missing index on chat_rooms expiresAt | Ch09 | No change needed (TTL doesn't need index) | ✅ N/A |
| F-005 (Ch11): CLAUDE.md test count 99 "unit" | Ch11 | CLAUDE.md | ✅ Fixed in Phase 3 |
| F-002 (Ch10): CLAUDE.md test count | Ch10 | CLAUDE.md | ✅ Fixed in Phase 3 |
| F-008 (Ch12): README "16 functions" | Ch12 | README.md | ✅ Fixed in Phase 4 |
| F-009 (Ch12): tools/ empty in CLAUDE.md | Ch12 | CLAUDE.md | ✅ Fixed in Phase 4 |
| Java 17 in README | Ch12 | README.md | ✅ Fixed in Phase 4 |
| setTyping note in PROJECT_CONTEXT | Ch08 | PROJECT_CONTEXT.md | ✅ Fixed in Phase 4 |
| sessions/messages RTDB paths in PROJECT_CONTEXT | Ch09 | PROJECT_CONTEXT.md | ✅ Fixed in Phase 4 |
| nameQueue "any signed-in" in PROJECT_CONTEXT | Ch09 | PROJECT_CONTEXT.md | ✅ Fixed in Phase 4 |
| chatLog no CF-only note in PROJECT_CONTEXT | Ch09 | PROJECT_CONTEXT.md | ✅ Fixed in Phase 4 |
| Test counts in PROJECT_CONTEXT | Ch11 | PROJECT_CONTEXT.md | ✅ Fixed in Phase 4 |

All identified doc-drift items across the full QA have been resolved. ✅
