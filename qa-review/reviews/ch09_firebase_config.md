# Chapter 09 — Firebase Config & Security Rules QA Review

> Status: COMPLETE
> Date: 2026-05-17

## Summary

Reviewed `firestore.rules`, `firestore.indexes.json`, `database.rules.json`, `firebase.json`, and `.firebaserc`. One CRITICAL issue: `google-services.json` is committed to the repo and not in `.gitignore`. The Firestore security rules are well-designed with strong helper functions and immutability enforcement. One MEDIUM issue: the `reports` create rule allows clients to supply a fabricated `chatLog` field. One MEDIUM RTDB issue: `nameQueue` write access is unrestricted to any authenticated user. Two LOW issues: legacy RTDB `sessions`/`messages` paths are defined but unused; no explicit root deny-all. Emulator ports match documentation exactly.

**Findings: 1 CRITICAL, 2 MEDIUM, 2 LOW, 3 INFO/DOC-DRIFT**

---

## Findings

### F-001 — google-services.json committed to repo without .gitignore protection
- **Severity:** CRITICAL
- **File:** `apps/mobile/android/app/google-services.json` (confirmed present, 1098 bytes)
- **Category:** Security
- **Description:** The Android Firebase config file is committed to the repository. The root `.gitignore` has no entry for `google-services.json` or `GoogleService-Info.plist`. While Firebase API keys are public by design (security is enforced via rules, not key secrecy), committing this file: (1) ties every clone of the repo to this specific Firebase project, blocking contributors who want to use their own project; (2) exposes the Android OAuth client ID which could be used in unauthorized apps attempting to impersonate the official client; (3) is against Firebase/Google recommended practice.
- **Evidence:** File exists at path; `.gitignore` contains no matching pattern.
- **Recommendation:** Add to `.gitignore`. Document in README that the file must be obtained via `flutterfire configure`. **Fixed in this QA pass.**

### F-002 — reports Firestore create rule allows client-supplied chatLog field
- **Severity:** MEDIUM
- **File:** `firestore.rules` — `match /reports/{reportId}` create rule
- **Category:** Security
- **Description:** The `hasOnly()` allowlist for client report creates includes `'chatLog'`. This means a malicious authenticated user can bypass the `reportSession` Cloud Function and directly create a report document with a fabricated `chatLog`. The CF reads actual encrypted messages server-side; a direct client write can forge evidence. The `reporterId` is correctly enforced from `request.auth.uid`, but the chat log content is unvalidated.
- **Evidence:**
  ```
  && request.resource.data.keys().hasOnly([
      'reporterId', 'reportedUserId', 'sessionId', 'reason',
      'description', 'chatLog', 'createdAt', 'status'   // ← chatLog should not be here
  ])
  ```
- **Recommendation:** Remove `'chatLog'` from the `hasOnly()` list. The CF writes `chatLog` via admin SDK (bypasses rules) — legitimate reports are unaffected. **Fixed in this QA pass.**

### F-003 — nameQueue RTDB path allows write by any authenticated user
- **Severity:** MEDIUM
- **File:** `database.rules.json` — `nameQueue` section
- **Category:** Security
- **Description:** `nameQueue/{room_id}` has `.read` and `.write` both set to `"auth != null"`. Any authenticated user (not just room members) can write to the name queue for any room. This path is used for name assignment within rooms. A user not in the room could inject names into the queue, potentially interfering with the name-assignment UX for other users.
- **Evidence:**
  ```json
  "nameQueue": {
    "$room_id": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
  ```
- **Recommendation:** Restrict write to room members using `root.child('rooms').child($room_id).child('members').child(auth.uid).exists()`. **Fixed in this QA pass.**

### F-004 — Legacy sessions and messages RTDB rules reference unused paths
- **Severity:** LOW
- **File:** `database.rules.json` — `sessions` and `messages` sections
- **Category:** Dead Code
- **Description:** The RTDB rules define `sessions/{room_id}` (read-only, no writes) and `messages/{room_id}` (legacy direct RTDB message writes). The current architecture uses Firestore `chat_rooms/` for encrypted messages and RTDB only for presence/typing. No active code path writes to RTDB `sessions/` or `messages/`. These rules are dead weight that reference a pre-encryption architecture.
- **Recommendation:** Remove `sessions` and `messages` blocks from `database.rules.json`. **Fixed in this QA pass.**

### F-005 — RTDB rules have no explicit root-level deny-all
- **Severity:** LOW
- **File:** `database.rules.json`
- **Category:** Defense in Depth
- **Description:** No root `.read` / `.write` rule is defined. Firebase RTDB defaults to deny for paths without explicit rules in new projects. All active paths are explicitly listed, so this is functionally safe. However, there is no explicit documentation of this intent, and a future developer adding a new path might not realize they need to add a rule.
- **Recommendation:** Add a comment at the root of `database.rules.json` noting that RTDB defaults deny-all for unlisted paths and that all active paths are explicitly listed below. No code change required.

### F-006 — Firestore indexes use mode field; CLAUDE.md rooms schema uses roomType
- **Severity:** INFO / DOC-DRIFT
- **File:** `firestore.indexes.json`
- **Category:** Doc-Drift
- **Description:** The rooms index covers `mode (ASCENDING), status, isLocked, memberCount`. In the codebase, `mode` (values: `"1v1" | "group"`) is distinct from `roomType` (values: `"public" | "custom"`). CLAUDE.md's rooms schema description conflates the two. The index is correct; CLAUDE.md needs updating.
- **Recommendation:** Fix CLAUDE.md to show both fields. **Fixed in this QA pass.**

### F-007 — rooms schema expiresAt vs paddingUntil doc-drift
- **Severity:** INFO / DOC-DRIFT
- **File:** `firestore.indexes.json` (index 5: `status + paddingUntil`)
- **Category:** Doc-Drift
- **Description:** CLAUDE.md says rooms have an `expiresAt` field and a TTL policy. The actual design uses `paddingUntil` (a timestamp) with `status: "padding"` — expiry is event-driven by `expireRooms` scheduled function, not a Firestore TTL policy. The `expiresAt` field exists on `chat_rooms/messages` and `session_keys`, not on `rooms`. The index confirms `paddingUntil` is what's queried.
- **Recommendation:** Fix CLAUDE.md rooms schema. **Fixed in this QA pass.**

### F-008 — Missing index on expiresAt for chat_rooms messages (false alarm)
- **Severity:** INFO
- **File:** `firestore.indexes.json`
- **Category:** Observation
- **Description:** The 3-day TTL on `chat_rooms/messages` uses Firestore's native TTL policy on the `expiresAt` field. Firestore TTL policies do not require a composite index — they use the single field directly via a background TTL deletion process. No missing index.
- **Recommendation:** No action required.

---

## Security Rules Audit: Key Questions

| Question | Answer |
|----------|--------|
| Can an unauthenticated user read any Firestore collection? | NO — all rules require isSignedIn() |
| Can a user read another user's profile? | NO — `allow read: if isOwner(userId)` |
| Can a user read another user's chat messages? | NO — isChatRoomParticipant() enforced |
| Can a client read the encryptionKey from rooms/{roomId}? | YES (room members can read the full doc) — but this is by design: the key is needed for client-side decryption during the session. After session end, the key is archived to session_keys (CF-only) or removed via tombstone. |
| Can a user set their own role to admin? | NO — `role` excluded from update affectedKeys allowlist |
| Can a user write to session_keys/{sessionId}? | NO — `allow read, write: if false` |
| Does chat_rooms create validate senderId == request.auth.uid? | YES |
| Does waiting_pool update restrict to updatedAt only? | YES |
| Can a user create a report with forged reporterId? | NO — `reporterId == request.auth.uid` enforced |
| Can a user supply a fabricated chatLog in a report? | YES (M-02) — FIXED |
| Are immutable fields (uid, role, createdAt) protected? | YES — excluded from update affectedKeys |
| RTDB root deny-all? | Functionally yes (default), not explicitly stated |
| Can unauthenticated user write to typing/{roomId}/{uid}? | NO — auth != null && auth.uid == $uid |
| Are presence paths write-restricted to owner? | YES — auth.uid == $uid |
| Is nameQueue write restricted to room members? | NO (M-03) — FIXED |

## Emulator Config Verification

| Service | Documented Port | Actual Port (firebase.json) | Match |
|---------|----------------|----------------------------|-------|
| Auth | 9099 | 9099 | ✅ |
| Functions | 5001 | 5001 | ✅ |
| Firestore | 8080 | 8080 | ✅ |
| RTDB | 9000 | 9000 | ✅ |
| PubSub | 8085 | 8085 | ✅ |

## Index Coverage

| Query | Index Present |
|-------|---------------|
| waiting_pool: status + createdAt (1v1 FIFO) | ✅ |
| waiting_pool: mode + status + createdAt | ✅ |
| waiting_pool: mode + status + updatedAt | ✅ |
| rooms: mode + status + isLocked + memberCount (group join) | ✅ |
| rooms: status + paddingUntil (expireRooms query) | ✅ |
| reports: status + createdAt (admin list) | ✅ |
| chat_rooms/messages expiresAt TTL | ✅ (TTL policy, no composite index needed) |
