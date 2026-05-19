# Admin API Specification

> Ground truth: schema verified against CF source code (2026-05-18).
> Auth: all admin CFs verify `users/{uid}.role == "admin"` via admin SDK.

---

## Data Layer Strategy

| Operation | How | Why |
|---|---|---|
| List / read reports | Direct Firestore client read on `reports/` | Real-time, no CF overhead |
| List / read users | Direct Firestore client read on `users/` after rule fix | Same |
| Dashboard stats | CF `adminGetDashboard` | Needs RTDB online count |
| Resolve report | CF `adminResolveReport` | Writes privileged `outcome` field |
| Chat log URL | CF `adminGetChatLog` | Requires Storage signed URL (admin SDK) |
| Ban user | CF `adminBanUser` | Writes ban fields; optionally resolves report atomically |
| Unban user | CF `adminUnbanUser` | Rotates active ban into `banHistory` |

---

## Firestore Rule Applied

**File:** `firestore.rules`  
**Applied rule:** `allow read: if isSignedIn();`

The rule was broadened to `isSignedIn()` (any authenticated user, including anonymous) rather than the narrower `isOwner(userId) || isAdmin()` originally specced. This is required for the friends feature, which must query and stream other users' profiles for the friends search UI. Admin screens benefit from this rule as a side effect — they need to read arbitrary user documents.

```
// Before (owner-only)
allow read: if isOwner(userId);
// After (any authenticated user — required for friends search)
allow read: if isSignedIn();
```

Note: `email` is never stored in Firestore, so exposure is limited to `displayName`, `photoUrl`, `interest`, `hatKey`, `moodKey`, `thoughts`, ban fields, and `role`.

---

## Schema Additions Required

### `reports/{reportId}` — add `outcome` field

Written by `adminResolveReport` and `adminBanUser`. Never set by `reportSession` CF.

```typescript
outcome?: {
  kind: "banned" | "dismissed" | "reviewed";
  by: string;       // admin uid
  byName: string;   // admin displayName
  at: Timestamp;
  note?: string;
}
```

### `users/{uid}` — add ban fields

Written by `adminBanUser` and `adminUnbanUser`.

```typescript
// Present only when user is banned
banned?: true;
banReason?: string;        // e.g. "Harassment or Bullying"
banDuration?: string;      // "1 Day" | "7 Days" | "30 Days" | "Permanent"
bannedAt?: Timestamp;
banExpiresAt?: Timestamp | null;  // null = permanent
bannedBy?: string;         // admin uid
bannedByName?: string;     // admin displayName at time of ban
banNote?: string;

// Append-only audit log (present even before first ban)
banHistory?: Array<{
  reason: string;
  duration: string;
  bannedAt: Timestamp;
  expiresAt: Timestamp | null;
  bannedBy: string;
  bannedByName: string;
  note: string | null;
  unbannedAt: Timestamp;   // present after unban
  unbannedBy: string;      // admin uid who unbanned
}>;
```

---

## Callable Cloud Functions

All functions live in `functions/src/admin/`. All are `onCall` (callable), deployed to `us-central1`. Every function rejects calls where the caller does not have `role == "admin"` in `users/{uid}`.

---

### 1. `adminGetDashboard`

Returns aggregate stats for the dashboard header.

**Input:** _(none)_

**Output:**
```typescript
{
  pendingReports: number;   // count of reports where status == "pending"
  onlineUsers: number;      // count of uids in pool_presence/ RTDB node
  bannedUsers: number;      // count of users where banned == true
}
```

**Process:**
1. Verify caller is admin.
2. Firestore `count()` on `reports/` where `status == "pending"`.
3. RTDB shallow GET on `pool_presence/` to count keys (online users in matchmaking pool). For users currently in active rooms, count from Firestore `rooms/` where `status == "active"` — sum `memberCount`. De-duplicate by taking the union.  
   _Simplified for v1: count unique uids across `pool_presence/` keys + `rooms/` active members._
4. Firestore `count()` on `users/` where `banned == true`.
5. Return all three counts.

---

### 2. `adminResolveReport`

Marks a report as dismissed or reviewed without banning the user.

**Input:**
```typescript
{
  reportId: string;
  action: "dismiss" | "reviewed";
  note?: string;      // optional moderator note, max 500 chars
}
```

**Output:**
```typescript
{ success: true }
```

**Process:**
1. Verify caller is admin.
2. Validate `reportId` non-empty, `action` is one of the allowed values.
3. Read `reports/{reportId}`. Return `{ success: false, reason: "not_found" }` if missing.
4. If `report.status != "pending"`, return `{ success: false, reason: "already_resolved" }`.
5. Update `reports/{reportId}`:
   ```typescript
   {
     status: action === "dismiss" ? "dismissed" : "reviewed",
     outcome: {
       kind: action === "dismiss" ? "dismissed" : "reviewed",
       by: callerUid,
       byName: callerDisplayName,
       at: FieldValue.serverTimestamp(),
       note: note?.trim() ?? null,
     }
   }
   ```
6. Return `{ success: true }`.

---

### 3. `adminGetChatLog`

Returns a short-lived signed URL for the encrypted-then-decrypted chat log stored in Cloud Storage.

**Input:**
```typescript
{ reportId: string }
```

**Output:**
```typescript
{
  signedUrl: string;    // valid for 15 minutes
  expiresAt: string;    // ISO 8601
}
```

**Process:**
1. Verify caller is admin.
2. Read `reports/{reportId}`. Return `{ success: false, reason: "not_found" }` if missing.
3. If `report.chatLogStoragePath` is null/empty, return `{ success: false, reason: "no_chat_log" }`.
4. Generate a signed URL (15-minute TTL) for `report.chatLogStoragePath` using admin SDK Storage.
5. Return `{ signedUrl, expiresAt }`.

---

### 4. `adminBanUser`

Bans a user and optionally resolves a linked report atomically.

**Input:**
```typescript
{
  uid: string;                         // user to ban
  reason: string;                      // from kBanReasons or "Others"
  duration: "1 Day" | "7 Days" | "30 Days" | "Permanent";
  note?: string;                       // optional moderator note, max 500 chars
  reportId?: string;                   // if provided, resolve this report with outcome.kind = "banned"
}
```

**Output:**
```typescript
{ success: true }
```

**Process:**
1. Verify caller is admin.
2. Validate `uid` non-empty, `reason` non-empty, `duration` is one of allowed values.
3. Read `users/{uid}`. Return error if not found.
4. If user is already `banned == true`, return `{ success: false, reason: "already_banned" }`.
5. Compute `banExpiresAt`:
   - `"1 Day"` → `now + 86400s`
   - `"7 Days"` → `now + 604800s`
   - `"30 Days"` → `now + 2592000s`
   - `"Permanent"` → `null`
6. Run Firestore batch:
   - `users/{uid}` update:
     ```typescript
     {
       banned: true,
       banReason: reason,
       banDuration: duration,
       bannedAt: FieldValue.serverTimestamp(),
       banExpiresAt: banExpiresAt,
       bannedBy: callerUid,
       bannedByName: callerDisplayName,
       banNote: note?.trim() ?? null,
     }
     ```
   - If `reportId` provided: `reports/{reportId}` update with `status: "reviewed"` and `outcome.kind: "banned"`.
7. Return `{ success: true }`.

---

### 5. `adminUnbanUser`

Lifts a ban from a user and appends the completed ban to `banHistory`.

**Input:**
```typescript
{
  uid: string;
  note?: string;    // optional note about why unbanning, max 500 chars
}
```

**Output:**
```typescript
{ success: true }
```

**Process:**
1. Verify caller is admin.
2. Read `users/{uid}`. Return error if not found.
3. If `banned != true`, return `{ success: false, reason: "not_banned" }`.
4. Build history record from current ban fields:
   ```typescript
   {
     reason: user.banReason,
     duration: user.banDuration,
     bannedAt: user.bannedAt,
     expiresAt: user.banExpiresAt,
     bannedBy: user.bannedBy,
     bannedByName: user.bannedByName,
     note: user.banNote ?? null,
     unbannedAt: FieldValue.serverTimestamp(),
     unbannedBy: callerUid,
   }
   ```
5. Update `users/{uid}`:
   ```typescript
   {
     banned: FieldValue.delete(),
     banReason: FieldValue.delete(),
     banDuration: FieldValue.delete(),
     bannedAt: FieldValue.delete(),
     banExpiresAt: FieldValue.delete(),
     bannedBy: FieldValue.delete(),
     bannedByName: FieldValue.delete(),
     banNote: FieldValue.delete(),
     banHistory: FieldValue.arrayUnion(historyRecord),
   }
   ```
6. Return `{ success: true }`.

---

## Error Response Shape

All admin CFs return a consistent error on failure (instead of throwing `HttpsError`):

```typescript
// Success
{ success: true, ...data }

// Failure (non-throwing — returned as normal response)
{ success: false, reason: string }
```

Exceptions for auth failures and invalid arguments still use `HttpsError` so the Flutter SDK surfaces them as `FirebaseFunctionsException`.

---

## Direct Firestore Reads (no CF — Flutter client)

After the `|| isAdmin()` rule change, Flutter admin screens read these directly:

| Screen | Query |
|---|---|
| Reports tab | `reports/` ordered by `createdAt desc`, optional `where status == filter` |
| Report detail | `reports/{id}` + `users/{reporterId}` + `users/{reportedUserId}` |
| Users tab | `users/` ordered by `createdAt desc`, pageSize 20 |
| Banned tab | `users/` where `banned == true` ordered by `bannedAt desc` |
| User profile dialog | `users/{uid}` |

---

## Out of Scope (this PR)

- Group room banning — deferred, discussed separately
- Notifications to banned users
- Admin audit log collection
- Report `contextImageUrls` display (image viewer)
