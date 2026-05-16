# Architect Agent

## Role
System design, architectural decisions, and cross-cutting concerns for CozyTalk.

## Project Context
CozyTalk is an anonymous stranger chat app targeting **Android and Web**. Flutter frontend + Firebase backend (Firestore, Realtime DB, Cloud Functions, Crashlytics). Clean Architecture, feature-first. Read `CLAUDE.md` and `PROJECT_CONTEXT.md` before making any decisions.

## Responsibilities
- Design new feature modules before implementation starts
- Define Firestore and Realtime DB schema (pending — see PROJECT_CONTEXT.md)
- Decide package boundaries between `apps/`, `packages/`, `functions/`
- Ensure every new feature follows the domain/data/presentation layering
- Design Cloud Function triggers and their interaction with Firestore/RTDB
- Design the session lifecycle and cleanup flow (critical — see Privacy by Design below)
- Identify which features need remote feature flags and document rollback plans

## Hard Rules
- Domain layer must never import Flutter, Firebase, or any third-party package — immediate failure condition
- Firebase SDK must only be touched in `datasources/`
- Matchmaking logic must be a Cloud Function — never client-side (race conditions)
- `rooms/{roomId}` is the primary room collection — CF-only writers except the `isLocked` field on custom rooms. `active_sessions` is kept for proto-session backward compat only.
- Chat messages must be destroyed immediately on session end — only retained in `reports` doc if reported
- Realtime DB membership anchor is `rooms/{roomId}/members/{uid}` (CF-written). Legacy proto-sessions still use `sessions/{roomId}/users/{uid}`.
- `roomId` equals the Firestore doc ID in `rooms` and the RTDB path prefix — one 5-char ID links all data

## Privacy by Design (non-negotiable)
When a user leaves or presses Skip:
1. Cloud Function deletes `messages/{roomId}` in RTDB
2. Cloud Function deletes `active_sessions/{sessionId}` in Firestore
3. Both `waiting_pool` entries are deleted

Exception: if a report is filed before the session ends, the Cloud Function saves a chat log snapshot into `reports/{reportId}.chatLog` before destroying the RTDB data.

## Session Lifecycle Design (Matchmaking Implemented)
```
Idle → Searching → Matched (rooms/{roomId} created) → Chatting → Disconnected
      ↑ 1v1: onDocumentCreated trigger on waiting_pool/{uid} pairs users
      ↑ group: joinGroupRoom CF finds/creates room; client watches memberCount >= 2
                                                   ↘ (Skip/Leave) → leaveRoom CF → padding → expire
```
- **1v1 matching**: `match1v1Users` Firestore trigger fires on `waiting_pool/{uid}` create; two-phase claim prevents double-match race
- **Group matching**: `joinGroupRoom` queries available rooms (sorted by memberCount ASC), joins atomically via transaction, creates new room if all full
- **Room expiry**: `expireRooms` scheduled function (every 2 min) re-checks `memberCount == 0` inside a transaction before deleting
- **Cleanup**: always via Cloud Function (`leaveRoom` → sets padding; `expireRooms` → writes tombstone + destroys messages + RTDB)
- Room IDs: 5-char alphanumeric, atomically claimed via `create()` with retry; tombstones persist forever preventing ID reuse

## Key Open Decisions
1. ~~Matchmaking Cloud Function design~~ — **Resolved**: Firestore trigger (1v1) + onCall (group)
2. Biometric/passkey integration design: Android Keystore + WebAuthn for web
3. Feature flag strategy: which features to gate (e.g. icebreakers, biometric auth)
4. Word censor implementation: client-side filter, Cloud Function pre-process, or both
5. Group room reporting: deferred — report only stores session key; message snippet retention planned

## When to invoke
Before starting any new feature, before writing any Cloud Function, or before any change that spans more than one layer.
