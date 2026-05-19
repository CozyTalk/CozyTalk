# Plan: Audiomack Jukebox Feature

**Branch:** `feat/audiomack-jukebox`
**Scope:** Shared music queue in 1v1 and group chat rooms. Any participant can add, skip, pause, or remove tracks. Synced via RTDB. Works on Android and Flutter Web.

---

## 1. Audiomack API — What Actually Exists

Source: https://audiomack.com/data-api/docs · Base URL: `https://api.audiomack.com/v1`

### Authentication reality

| Tier | What it unlocks | Credentials needed |
|---|---|---|
| **Public / unauthenticated** | Read music metadata, search, get streaming URL, log stats | None |
| **App-level (consumer key)** | HQ streaming, rate-limit increase | Consumer key + secret (register with Audiomack) |
| **User OAuth 1.0a** | Favorites, reposts, playlists, user feed | Full 3-legged OAuth flow |

**For our MVP: zero credentials needed.** All endpoints we use are publicly accessible.

### Endpoints used in this feature

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /v1/music/song/{artist}/{slug}` | None | Resolve URL → id, title, artist, artwork, streaming_url, streaming_url_timeout |
| `GET /search?q=...&show=songs` | None | In-sheet search (alternative to URL paste) |
| `POST /v1/music/{id}/play` | None (basic quality) | Fresh streaming MP3 URL — valid ~10 seconds from call |
| `GET /v1/music/stats/token?device={md5}&music_id={id}` | None | Get stats token before reporting a play |
| `POST /v1/music/stats/{id}` | None | Report play to Audiomack (required by ToS) |

### GET /v1/music/song/{artist}/{slug} — key response fields

```json
{
  "id": "12345678",
  "title": "Song Title",
  "artist": "artist-slug",
  "image": "https://cdn.audiomack.com/...",
  "streaming_url": "https://songs.dev.audiomack.com/streaming/....mp3?Expires=...&Signature=...&Key-Pair-Id=...",
  "streaming_url_timeout": 1234567890,
  "type": "song"
}
```

`streaming_url` is a CloudFront signed URL. `streaming_url_timeout` is its Unix expiry timestamp.
**Its TTL is longer than the 10s `/play` URL** — likely minutes to an hour (to be verified on first run).

### POST /v1/music/{id}/play — response

Returns a raw string streaming URL:
```
"https://songs.dev.audiomack.com/streaming/artist/song.mp3?Expires=...&Signature=...&Key-Pair-Id=..."
```
Valid for **~10 seconds** — must be fetched immediately before initiating playback.

---

## 2. Playback Architecture — Android vs Web

### The CORS problem

Audiomack's CDN (`songs.dev.audiomack.com`) serves CloudFront signed URLs. These CDN URLs are **not guaranteed to carry `Access-Control-Allow-Origin` headers**, which means a browser (Flutter Web) cannot fetch them directly via `just_audio_web` without hitting a CORS block.

| Platform | Approach | Why |
|---|---|---|
| **Android** | `just_audio` with direct streaming URL | Native HTTP — no CORS. Full playback control: pause, seek, position tracking. |
| **Flutter Web** | Audiomack iframe embed via `HtmlElementView` | Iframe bypasses CORS entirely. Audiomack's own embed player handles playback. |

Both are driven by the same RTDB state. The `JukeboxPlayer` widget is platform-aware via `kIsWeb`.

### Embed URL derivation (Web)

```
Input:  https://audiomack.com/{artist}/song/{slug}
Embed:  https://audiomack.com/embed/{artist}/song/{slug}
```
Append `?background=1` to hide Audiomack's own UI chrome (we render our own controls on top).

### Sync strategy

RTDB stores: `{currentTrackId, currentTrackIndex, isPlaying, startedAt (server timestamp), streamingUrl, streamingUrlTimeout}`

- **Android**: on play, check `streamingUrlTimeout > now`. If valid, use `streamingUrl` from RTDB. If expired, call `POST /v1/music/{id}/play` independently, then seek to `now - startedAt` ms.
- **Web**: on `currentTrackIndex` change, reload `HtmlElementView` with new embed URL. On `isPlaying` toggle, mount/unmount iframe.
- **Sync quality**: Android ±1–3s (seek-based). Web: same track, restarts from beginning on each resume. Document the Web limitation in UI.

---

## 3. RTDB Data Model

New path: `jukebox/{roomId}`

```json
{
  "jukebox": {
    "{roomId}": {
      "isPlaying": true,
      "currentIndex": 0,
      "startedAt": 1234567890000,
      "queue": [
        {
          "id": "12345678",
          "audiomackUrl": "https://audiomack.com/artistslug/song/songslug",
          "embedUrl": "https://audiomack.com/embed/artistslug/song/songslug",
          "streamingUrl": "https://songs.dev.audiomack.com/streaming/....mp3?Expires=...",
          "streamingUrlTimeout": 1234567890,
          "title": "Song Title",
          "artist": "Artist Name",
          "artworkUrl": "https://cdn.audiomack.com/...",
          "addedBy": "{uid}",
          "addedByName": "display name"
        }
      ]
    }
  }
}
```

**Queue capacity**: 3 slots beyond the currently playing track (`_kQueueMax = 4` total including now-playing).  
**Current track**: `queue[currentIndex]`.  
**Exhaustion**: when `currentIndex >= queue.length`, set `isPlaying = false`.

---

## 4. RTDB Security Rules

Add to `database.rules.json` under `"rules"`:

```json
"jukebox": {
  "$room_id": {
    ".read":  "auth != null && root.child('rooms').child($room_id).child('members').child(auth.uid).exists()",
    ".write": "auth != null && root.child('rooms').child($room_id).child('members').child(auth.uid).exists()",
    "isPlaying": {
      ".validate": "newData.isBoolean()"
    },
    "currentIndex": {
      ".validate": "newData.isNumber() && newData.val() >= 0"
    },
    "startedAt": {
      ".validate": "newData.isNumber()"
    },
    "queue": {
      "$index": {
        ".validate": "newData.hasChildren(['id','audiomackUrl','embedUrl','streamingUrl','streamingUrlTimeout','title','artist','artworkUrl','addedBy','addedByName']) && newData.child('audiomackUrl').val().matches(/^https:\\/\\/audiomack\\.com\\/[a-zA-Z0-9_-]+\\/song\\/[a-zA-Z0-9_-]+$/) && newData.child('addedByName').val().length <= 100 && newData.child('title').val().length <= 300 && newData.child('artist').val().length <= 200"
      }
    }
  }
}
```

The `audiomackUrl` regex enforces `audiomack.com/{slug}/song/{slug}` format, blocking arbitrary URLs.

---

## 5. New Packages

```yaml
# pubspec.yaml — dependencies
just_audio: ^0.9.40          # Android playback (existing platform has audio; no new permission needed)
webview_flutter: ^4.10.0     # Web embed player (HtmlElementView on Flutter Web)
```

`http` is already in `dev_dependencies` — promote to `dependencies` for API calls.

> Per CLAUDE.md §14: both packages require architect approval. `just_audio` needs `INTERNET` permission (already declared for Firebase). `webview_flutter` needs no new Android permissions.

---

## 6. CA Feature Structure: `features/jukebox/`

```
features/jukebox/
├── domain/
│   ├── entities/
│   │   ├── jukebox_track.dart          JukeboxTrack (id, audiomackUrl, embedUrl, streamingUrl,
│   │   │                               streamingUrlTimeout, title, artist, artworkUrl, addedBy, addedByName)
│   │   └── jukebox_room_state.dart     JukeboxRoomState (queue, currentIndex, isPlaying, startedAt)
│   ├── repositories/
│   │   └── jukebox_repository.dart     abstract JukeboxRepository
│   └── usecases/
│       ├── watch_jukebox.dart           WatchJukebox — Stream<JukeboxRoomState>
│       ├── resolve_track.dart           ResolveTrack — URL → JukeboxTrack
│       ├── search_tracks.dart           SearchTracks — query → List<JukeboxTrack>
│       ├── add_to_queue.dart            AddToQueue
│       ├── remove_from_queue.dart       RemoveFromQueue
│       ├── skip_track.dart              SkipTrack
│       ├── set_playing.dart             SetPlaying
│       └── refresh_stream_url.dart      RefreshStreamUrl — calls /play, returns fresh URL
├── data/
│   ├── models/
│   │   ├── jukebox_track_model.dart     @freezed · toEntity()
│   │   └── jukebox_room_state_model.dart  @freezed · toEntity()
│   ├── datasources/
│   │   └── jukebox_datasource.dart      JukeboxDatasourceImpl
│   │       — Audiomack API calls (dart:io HttpClient, no auth headers)
│   │       — RTDB reads/writes (firebase_database)
│   └── repositories/
│       └── jukebox_repository_impl.dart
└── presentation/
    ├── providers/
    │   └── jukebox_provider.dart        jukeboxNotifierProvider · JukeboxNotifier · JukeboxUiState
    └── widgets/
        ├── jukebox_sheet.dart           Modal bottom sheet — full jukebox UI
        ├── jukebox_player.dart          Platform switch: _NativePlayer | _WebEmbedPlayer
        ├── track_search_field.dart      Search + URL input widget
        └── queue_slot_tile.dart         Single queue item (artwork, title, artist, remove button)
```

---

## 7. JukeboxDatasource — All Methods

```dart
// ─── Audiomack API calls ─────────────────────────────────────────────────────

// GET https://api.audiomack.com/v1/music/song/{artist}/{slug}
// Parse artist/slug from audiomack.com/{artist}/song/{slug} input URL
Future<JukeboxTrack> resolveTrack(String audiomackUrl, String addedBy, String addedByName);

// GET https://api.audiomack.com/v1/search?q={query}&show=songs&limit=10
Future<List<JukeboxTrack>> searchTracks(String query);

// POST https://api.audiomack.com/v1/music/{id}/play
// Returns fresh streaming URL — call immediately before Android playback starts
Future<String> getStreamUrl(String trackId);

// Stats: GET /v1/music/stats/token?device={md5DeviceId}&music_id={id}
//        POST /v1/music/stats/{id} body: token=...&type=play
Future<void> reportPlay(String trackId, String deviceId);

// ─── RTDB ────────────────────────────────────────────────────────────────────

Stream<JukeboxRoomState?> watchJukebox(String roomId);
Future<void> setJukeboxState(String roomId, JukeboxRoomState state);
Future<void> deleteJukebox(String roomId);   // called by endSession cleanup
```

---

## 8. JukeboxNotifier

```
JukeboxUiState {
  roomState: JukeboxRoomState?   // null = jukebox not yet active for room
  searchResults: List<JukeboxTrack>
  isSearching: bool
  isAddingTrack: bool            // true while resolveTrack / RTDB write in progress
  error: String?
}
```

**Actions on `JukeboxNotifier`:**

| Method | What it does |
|---|---|
| `enter(roomId)` | Subscribe to RTDB stream; start emitting state |
| `search(query)` | Calls `SearchTracks` usecase, populates `searchResults` |
| `addFromUrl(url)` | Parse URL → `ResolveTrack` → validate queue not full → write to RTDB |
| `addFromSearch(track)` | Same as above but track already resolved |
| `removeFromQueue(index)` | Remove item; if `index < currentIndex`, decrement `currentIndex`; if `index == currentIndex`, skip |
| `skip()` | Increment `currentIndex`; if exhausted set `isPlaying = false` |
| `setPlaying(bool)` | Toggle `isPlaying`; on `true` set `startedAt = ServerValue.timestamp` |

**Loading guard**: every submit handler checks `isAddingTrack` at the top.

---

## 9. Platform-Aware Player Widget

```dart
// jukebox_player.dart
class JukeboxPlayer extends StatelessWidget {
  final JukeboxTrack track;
  final bool isPlaying;
  final int startedAt;   // ms epoch — used by Android to seek on late join

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _WebEmbedPlayer(embedUrl: track.embedUrl);
    return _NativePlayer(track: track, isPlaying: isPlaying, startedAt: startedAt);
  }
}

// _WebEmbedPlayer — HtmlElementView iframe
// Remounts on track change (key: track.id). No seek control.

// _NativePlayer — just_audio AudioPlayer
// On mount: check streamingUrlTimeout. If valid, use streamingUrl from RTDB.
//           If expired, call getStreamUrl(track.id) CF, then seek to (now - startedAt).
// On isPlaying toggle: player.play() / player.pause().
// On track change: player.stop(), reload with new URL.
```

---

## 10. UI Plan

### Music button

Added to `ChatScreen` AppBar actions (after the report icon):

```dart
IconButton(
  icon: const Icon(Icons.queue_music_rounded),
  tooltip: 'Jukebox',
  onPressed: state.status == SessionStatus.chatting ? _showJukeboxSheet : null,
)
```

### Jukebox bottom sheet

```
┌────────────────────────────────────────────┐
│  Jukebox                                ✕  │
├────────────────────────────────────────────┤
│  NOW PLAYING                               │
│  ┌─────────────────────────────────────┐   │
│  │ [artwork 48×48]  Song Title         │   │
│  │                  Artist Name        │   │
│  └─────────────────────────────────────┘   │
│        [⏸ Pause / ▶ Resume]  [⏭ Skip]    │
│        (web: "Web — song restarts on       │
│         resume" tooltip on pause btn)      │
│  ── invisible JukeboxPlayer widget ────    │
├────────────────────────────────────────────┤
│  UP NEXT  (3 slots)                        │
│  ┌──────────────────────────────── [✕] ┐   │
│  │ [art]  Song A · Artist             │   │
│  └───────────────────────────────────── ┘  │
│  ┌──────────────────────────── [✕] ─── ┐   │
│  │ [art]  Song B · Artist             │   │
│  └───────────────────────────────────── ┘  │
│  ┌─────────────────────────────────────┐   │
│  │  (empty slot)                       │   │
│  └───────────────────────────────────── ┘  │
├────────────────────────────────────────────┤
│  ADD TO QUEUE                              │
│  [Search or paste audiomack.com link   ]   │
│  [Search results list — tap to add     ]   │
│                               [+ Add URL]  │
└────────────────────────────────────────────┘
```

- **Now Playing**: `NetworkImage` artwork, title, artist. Shows "Queue empty" when `queue.isEmpty`.
- **Controls**: Play/Pause calls `setPlaying()`. Skip calls `skip()`. Both disabled when queue empty.
- **Queue slots**: always shows 3 slots. Filled = `QueueSlotTile` with remove button. Empty = grey placeholder.
- **Add field**: user can type a search query (triggers `search()` and shows dropdown results) OR paste a full `audiomack.com/{artist}/song/{slug}` URL and tap "+ Add URL". Shows `CircularProgressIndicator` while resolving. Inline error if resolve fails.
- **`JukeboxPlayer`**: mounted inside the sheet, zero-height `SizedBox` wrapper so it stays alive while sheet is open but is invisible — audio plays in background.

---

## 11. Stats Reporting (Required by Audiomack ToS)

When a track starts playing on a client:

1. Compute `deviceId`: MD5 of Firebase `uid` (stable per device, anonymous-safe, no PII).
2. `GET /v1/music/stats/token?device={md5}&music_id={trackId}` → `token`
3. `POST /v1/music/stats/{trackId}` body: `token=...&type=play`

Done in `JukeboxDatasource.reportPlay()`. Called from `_NativePlayer` and `_WebEmbedPlayer` when playback begins. Fire-and-forget — failure is non-fatal.

---

## 12. Sync Behavior Reference

| Event | Writer | RTDB change | Android clients | Web clients |
|---|---|---|---|---|
| User adds track | Requester | Append to `queue[]` | See new slot appear | See new slot appear |
| User plays | Any | `isPlaying=true`, `startedAt=serverNow` | Fetch fresh URL if expired → seek to `now−startedAt` → play | Mount/reload embed iframe |
| User pauses | Any | `isPlaying=false` | `player.pause()` | Unmount iframe |
| User skips | Any | `currentIndex++` | Stop old player → load new track URL | Unmount old iframe → mount new |
| User removes (not current) | Any | Splice queue; adjust `currentIndex` if needed | Queue UI updates | Queue UI updates |
| User removes (current track) | Any | Splice queue; `currentIndex` clamped | Treated as skip | Treated as skip |
| Queue exhausted | Auto (on skip) | `isPlaying=false` | Player stops | Iframe unmounted |
| Session ends | CF (`endSession`) | `jukebox/{roomId}` deleted | State cleared | State cleared |

---

## 13. Cloud Function Changes

One change to **`endSession.ts`**: after tombstoning the room, delete `jukebox/{roomId}` from RTDB.

```typescript
// After existing RTDB cleanup:
await rtdb.ref(`jukebox/${sessionId}`).remove();
```

No new CF needed. All queue operations are client-direct RTDB writes gated by security rules.

---

## 14. URL Parsing Logic

Input: `https://audiomack.com/{artist}/song/{slug}`

```dart
// In JukeboxDatasourceImpl:
({String artist, String slug}) _parseAudiomackUrl(String url) {
  final uri = Uri.parse(url);
  // host must be audiomack.com, path segments: ['', artist, 'song', slug]
  final segments = uri.pathSegments; // ['artist', 'song', 'slug']
  if (segments.length < 3 || segments[1] != 'song') throw FormatException('Not a song URL');
  return (artist: segments[0], slug: segments[2]);
}
```

API call: `GET https://api.audiomack.com/v1/music/song/{artist}/{slug}`

---

## 15. File Change Summary

| Action | Path |
|---|---|
| **New feature** | `apps/mobile/lib/features/jukebox/**` — 14 files |
| **Edit** | `apps/mobile/lib/features/chat/presentation/screens/chat_screen.dart` — add music button to AppBar |
| **Edit** | `apps/mobile/pubspec.yaml` — add `just_audio`, `webview_flutter`; promote `http` |
| **Edit** | `database.rules.json` — add `jukebox` path |
| **Edit** | `functions/src/chat/endSession.ts` — delete `jukebox/{roomId}` on session end |
| **New doc** | `docs/features/jukebox.md` |
| **Edit** | `docs/features/chat.md` — note jukebox button integration point |
| **Edit** | `docs/backend/cloud-functions.md` — update `endSession` with jukebox cleanup |
| **Edit** | `docs/database/schema.md` — add `jukebox/{roomId}` RTDB path |
| **Edit** | `PROJECT_CONTEXT.md` — RTDB paths table, tech stack (two new packages) |
| **Edit** | `CLAUDE.md` §4 — add jukebox to features table; §4 — update Jest/Flutter test counts |

---

## 16. Tests Required

| Layer | What to test |
|---|---|
| `JukeboxTrack` entity | Construction, all fields, null defaults |
| `JukeboxRoomState` entity | `copyWith` sentinel pattern; exhaustion boundary (`currentIndex >= queue.length`) |
| `ResolveTrack` usecase | Args forwarded; `FormatException` propagated |
| `SearchTracks` usecase | Args forwarded; empty result |
| `AddToQueue` usecase | Appends; rejects when `queue.length == 4` |
| `RemoveFromQueue` usecase | Correct splice; `currentIndex` adjusts when `index < currentIndex` |
| `SkipTrack` usecase | Increments; sets `isPlaying=false` when exhausted |
| `SetPlaying` usecase | Updates `isPlaying`; `startedAt` set on `true` |
| `JukeboxTrackModel` | `fromJson` all fields, nulls, `toEntity()` |
| `JukeboxRoomStateModel` | `fromJson` all fields, nulls, `toEntity()` |
| `JukeboxRepositoryImpl` | Call counts; stream via `Stream.value` |
| `JukeboxNotifier` providers | `copyWith` preserves/sets/clears nullables |
| `JukeboxSheet` widget | Empty state renders; queue slots render; add button calls notifier; loading state |

No Firebase SDK in tests. Hand-rolled `_FakeJukeboxNotifier` only. Estimated: ~40 new tests.

---

## 17. Known Limitations

| Limitation | Impact | Mitigation |
|---|---|---|
| Web: iframe sync restarts on resume | After pause, song restarts from beginning on Web | Tooltip on Pause button: "On web, resuming restarts the track" |
| Android: streaming URL 10s TTL via `/play` | Each client fetches independently — parallel calls possible | Acceptable; calls are free and unauthenticated |
| `streaming_url` TTL from metadata unknown | May need `/play` refresh even at start | Check `streamingUrlTimeout` before use; call `/play` if expired |
| Audiomack API unauthenticated limits | May rate-limit if many users add tracks rapidly | Cache resolved tracks by URL in notifier; don't re-fetch if already in queue |
| WebView autoplay on Android | Android may suppress audio without user gesture | Make embed player visible briefly on first load; after gesture, hide behind controls |
| Queue in RTDB is plaintext | Song titles/URLs visible in Firebase console | Acceptable — not chat content. Document in privacy notes. |
| `jukebox/{roomId}` persists if `endSession` CF fails | Orphaned RTDB node | `expireRooms` cron could clean stale nodes; or add TTL cleanup |

---

## 18. Out of Scope

- Seek bar / playback position UI (only Android has position data)
- Volume control
- Song history
- Album/playlist support (songs only)
- DJ mode (one controller user)
- Audiomack account linking (favorites, reposts)
- Search genre filter

---

## 19. Implementation Order

1. Create branch `feat/audiomack-jukebox`
2. **RTDB rules** — add and deploy `jukebox` path
3. **Domain layer** — all entities + repository interface + usecases
4. **Data layer** — models → datasource (API + RTDB) → repo impl
5. **Provider** — `JukeboxNotifier`
6. **`endSession.ts`** — add jukebox cleanup line; rebuild functions
7. **Widgets** — `JukeboxPlayer` (platform split) → `QueueSlotTile` → `TrackSearchField` → `JukeboxSheet` → music button in `ChatScreen`
8. **Tests** — all layers, ~40 tests
9. **Docs** — update all 7 listed docs

---

## 20. Pre-implementation Checklist

- [ ] Architect approves `just_audio` and `webview_flutter` packages (CLAUDE.md §14)
- [ ] Verify `GET /v1/music/song/{artist}/{slug}` returns without auth headers (run one `curl` to confirm)
- [ ] Verify `streaming_url_timeout` TTL duration (long enough to cache in RTDB, or must use `/play` every time)
- [ ] Check `just_audio_web` CORS against `songs.dev.audiomack.com` — if it works, drop `webview_flutter` entirely and unify both platforms
- [ ] Confirm `INTERNET` permission already declared in `AndroidManifest.xml` (it is, for Firebase)
