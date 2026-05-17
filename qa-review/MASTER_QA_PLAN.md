# CozyTalk — Master QA Plan

> **Purpose:** This document is the top-level plan-of-plans for the full project QA. Each chapter has its own plan file under `plans/` and its own output review file under `reviews/`. When all chapters are complete the final step is a doc-sync pass to bring CLAUDE.md, README.md, PROJECT_CONTEXT.md, and MATCHMAKING_CONTEXT_AWARE.md into agreement with reality.

---

## QA Goals

1. **Find every real bug or regression** — logic errors, race conditions, broken flows.
2. **Flag every industry-standard violation** — Clean Architecture boundary breaks, missing error handling at system boundaries, Dart/TypeScript style violations, security rule gaps.
3. **Surface every doc/code drift** — places where the docs describe something that is no longer true in code, or where code has drifted from the stated design.
4. **Produce per-chapter review files** — structured markdown that a future agent or human reviewer can act on directly.
5. **Produce a final doc-sync pass** — update CLAUDE.md, README.md, PROJECT_CONTEXT.md, and MATCHMAKING_CONTEXT_AWARE.md to reflect reality after all reviews are done.

---

## Chapter Index

| # | Chapter | Plan File | Review File | Focus Area |
|---|---------|-----------|-------------|------------|
| 1 | Flutter Core & Entrypoint | `plans/ch01_flutter_core.md` | `reviews/ch01_flutter_core.md` | main.dart, routing, theme, env config, dual-mode toggle |
| 2 | Auth Feature | `plans/ch02_auth_feature.md` | `reviews/ch02_auth_feature.md` | auth datasource, models, use cases, providers, screens, tests |
| 3 | Chat Feature | `plans/ch03_chat_feature.md` | `reviews/ch03_chat_feature.md` | crypto, RTDB integration, state machine, tests |
| 4 | Matchmaking Feature | `plans/ch04_matchmaking_feature.md` | `reviews/ch04_matchmaking_feature.md` | Flutter matchmaking, room model, use cases, provider, tests |
| 5 | Profile, Avatar, Home, Hello Features | `plans/ch05_small_features.md` | `reviews/ch05_small_features.md` | profile, avatar, home, hello — all layers + tests |
| 6 | Legacy UI Screens & Shared Widgets | `plans/ch06_legacy_ui.md` | `reviews/ch06_legacy_ui.md` | screens/, dialogs/, shared/ — completeness, wiring, patterns |
| 7 | Cloud Functions — Matchmaking Backend | `plans/ch07_cf_matchmaking.md` | `reviews/ch07_cf_matchmaking.md` | 11 exported CFs, _utils, embedding service, race conditions |
| 8 | Cloud Functions — Chat Backend | `plans/ch08_cf_chat.md` | `reviews/ch08_cf_chat.md` | sendMessage, endSession, reportSession, proto-presence |
| 9 | Firebase Config & Security Rules | `plans/ch09_firebase_config.md` | `reviews/ch09_firebase_config.md` | firestore.rules, RTDB rules, indexes, firebase.json |
| 10 | Flutter Tests | `plans/ch10_flutter_tests.md` | `reviews/ch10_flutter_tests.md` | coverage, fake patterns, sentinel tests, missing cases |
| 11 | Cloud Functions Tests | `plans/ch11_cf_tests.md` | `reviews/ch11_cf_tests.md` | Jest unit + integration tests, coverage, patterns |
| 12 | CI/CD, Scripts & DevOps | `plans/ch12_cicd_scripts.md` | `reviews/ch12_cicd_scripts.md` | GitHub Actions, shell scripts, emulator setup, build configs |
| 13 | Documentation Sync | `plans/ch13_doc_sync.md` | `reviews/ch13_doc_sync.md` | CLAUDE.md, README, PROJECT_CONTEXT, MATCHMAKING_CONTEXT_AWARE |

---

## Execution Order

Chapters can be executed in any order within a phase. Recommended order:

**Phase 1 — Backend & Rules (Chapters 7, 8, 9)**
These are the most security-critical. Run first so findings inform Flutter and doc chapters.

**Phase 2 — Flutter Features (Chapters 1, 2, 3, 4, 5)**
Core app logic. Chapter 1 first (entrypoint sets context), then auth → chat → matchmaking → small features.

**Phase 3 — Tests & Supporting Code (Chapters 6, 10, 11)**
Verify the tests actually cover what the features do. Legacy UI is lower risk but needs cataloguing.

**Phase 4 — Infra & Docs (Chapters 12, 13)**
CI/CD + final doc sync. Chapter 13 should always be last — it incorporates all prior findings.

---

## Review File Format

Each `reviews/chXX_*.md` file must follow this structure:

```markdown
# Chapter N — <Title> QA Review

> Status: DRAFT | IN PROGRESS | COMPLETE
> Reviewer: <agent-id or human>
> Date: YYYY-MM-DD

## Summary
One paragraph: what was reviewed, overall health, count of findings by severity.

## Findings

### F-NNN — <Short Title>
- **Severity:** CRITICAL | HIGH | MEDIUM | LOW | INFO
- **File:** `path/to/file.dart` line N
- **Category:** Bug | CA-Violation | Style | Security | Doc-Drift | Missing-Test | Performance
- **Description:** What is wrong.
- **Evidence:** Code snippet or log excerpt.
- **Recommendation:** Exactly what to change.

## Clean Architecture Compliance (Flutter chapters only)
Table: layer → imports → violations found

## Test Coverage Assessment (test chapters only)
Table: use case / entity → has test → has sentinel test → gaps

## Doc-Drift Items (doc sync chapter only)
Table: doc file → section → what it says → what code says → verdict
```

---

## Severity Definitions

| Severity | Meaning |
|----------|---------|
| CRITICAL | Data loss, security hole, app crash in production path |
| HIGH | Functional regression, CA boundary break, broken feature |
| MEDIUM | Code smell with real risk, missing test for non-trivial logic |
| LOW | Style violation, minor inconsistency, doc drift with low impact |
| INFO | Observation, suggestion, no action required |

---

## Tracking

Copy this table to track progress. Mark each chapter when review file is complete and findings are actioned.

| Chapter | Plan Written | Review Started | Review Done | Findings Actioned |
|---------|-------------|----------------|-------------|-------------------|
| 01 | ✅ | ✅ | ✅ | ✅ |
| 02 | ✅ | ✅ | ✅ | ✅ |
| 03 | ✅ | ✅ | ✅ | ✅ |
| 04 | ✅ | ✅ | ✅ | ✅ |
| 05 | ✅ | ✅ | ✅ | ✅ |
| 06 | ✅ | ✅ | ✅ | ✅ |
| 07 | ✅ | ✅ | ✅ | ✅ |
| 08 | ✅ | ✅ | ✅ | ✅ |
| 09 | ✅ | ✅ | ✅ | ✅ |
| 10 | ✅ | ✅ | ✅ | ✅ |
| 11 | ✅ | ✅ | ✅ | ✅ |
| 12 | ✅ | ✅ | ✅ | ✅ |
| 13 | ✅ | ✅ | ✅ | ✅ |
