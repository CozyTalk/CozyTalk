# Feature: jukebox

Synced music queue for chat rooms. Any participant can add an Audiomack song URL; all participants see the same track and controls in sync. Supports skip and remove from queue. Playback is handled via the Audiomack embed iframe on both Android and web using `webview_flutter`.

## File Map

```
features/jukebox/
├── domain/
│   ├── entities/
│   │   ├── jukebox_track.dart          JukeboxTrack (id, audiomackUrl, embedUrl, streamingUrl, streamingUrlTimeout, title, artist, artworkUrl, addedBy, addedByName)
│   │   └── jukebox_room_state.dart     JukeboxRoomState (isPlaying, currentIndex, startedAt, queue) + hasCurrentTrack / currentTrack / upNext
│   ├── repositories/jukebox_repository.dart  abstract JukeboxRepository
│   └── usecases/
│       ├── watch_jukebox.dart          WatchJukebox — stream RTDB state
│       ├── resolve_track.dart          ResolveTrack — fetch metadata from Audiomack URL
│       ├── add_to_queue.dart           AddToQueue — appends track; auto-starts on first add
│       ├── remove_from_queue.dart      RemoveFromQueue — splice + index adjustment
│       ├── skip_track.dart             SkipTrack — advance index or clear when exhausted
│       └── set_playing.dart            SetPlaying — pause/resume with startedAt reset
├── data/
│   ├── models/
│   │   ├── jukebox_track_model.dart        @freezed JukeboxTrackModel + toEntity()
│   │   └── jukebox_room_state_model.dart   @freezed JukeboxRoomStateModel + toEntity()
│   ├── datasources/jukebox_datasource.dart  abstract + JukeboxDatasourceImpl (RTDB + Audiomack oEmbed)
│   └── repositories/jukebox_repository_impl.dart
└── presentation/
    ├── providers/jukebox_provider.dart   jukeboxNotifierProvider, JukeboxNotifier, JukeboxUiState
    └── widgets/
        ├── jukebox_player.dart               invisible widget — calls enterRoom() in ChatScreen body
        ├── jukebox_web_player.dart           WebViewWidget wrapping Audiomack embed iframe
        ├── jukebox_sheet.dart                DraggableScrollableSheet modal
        └── queue_slot_tile.dart              queue item tile with remove button
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `jukeboxNotifierProvider` | `NotifierProvider<JukeboxNotifier, JukeboxUiState>` | subscribes to RTDB stream; no audio player |

`JukeboxNotifier` has no `AudioPlayer`. Playback is handled entirely by the `JukeboxWebPlayer` iframe embed on both platforms.

## State

`JukeboxUiState` — `roomId` (String?), `roomState` (JukeboxRoomState?), `isResolving` (bool), `resolveError` (String?), `urlInput` (String)

Sentinel pattern for nullable fields (`roomId`, `roomState`, `resolveError`) — callers must pass `null` explicitly to clear.

## Audiomack oEmbed API

No authentication required.

| Endpoint | Purpose |
|---|---|
| `GET https://creators.audiomack.com/oembed?url={encoded_url}&format=json` | Fetch track metadata (title, author_name, thumbnail_url) |

URL input format: `https://audiomack.com/{artist}/song/{slug}` — path segments [0] = artist, [2] = slug, [1] must be `'song'`.

Embed URL format: `https://audiomack.com/embed/song/{artist}/{slug}` (note: `embed/song/` prefix, not `embed/{artist}/`).

The Audiomack Data API (`api.audiomack.com/v1`) is NOT used — it requires OAuth 1.0.

## RTDB Path

`jukebox/{roomId}` — read/write restricted to room members (same rule as `rooms/{roomId}/members`).

Queue max: 4 tracks (index 0 = now playing + 3 up next). All writes are full-document `.set()` — never partial `.update()`.

`startedAt` is client `DateTime.now().millisecondsSinceEpoch` (ms epoch). Written on track change; all clients reload the embed on each RTDB state update.

## Key Behavior

- `JukeboxPlayer` widget mounts in `ChatScreen.body` (not inside the bottom sheet) — ensures RTDB subscription stays alive when the sheet is closed.
- First track added to an empty queue auto-starts: `isPlaying: true`, `startedAt: now`.
- `JukeboxWebPlayer` uses a `WebViewController` with JS enabled. In test environments (no platform WebView available), the controller init throws and `build()` returns `SizedBox.shrink()` gracefully.
- On session end: `endSession` CF clears `jukebox/{sessionId}` from RTDB.

## Platform Differences

| | Android | Web |
|---|---|---|
| Audio playback | Audiomack embed iframe (`JukeboxWebPlayer`) | Audiomack embed iframe (`JukeboxWebPlayer`) |
| Sync precision | Best-effort — iframe auto-plays from start on each track change | Best-effort — same |
| Play/pause control | Controlled within iframe player | Controlled within iframe player |
| Skip button | Shown in `JukeboxSheet` | Shown in `JukeboxSheet` |

## Integration with ChatScreen

`chat_screen.dart` — added:
- Jukebox music button in `AppBar.actions` (before report button)
- `JukeboxPlayer(roomId: widget.sessionId)` in `Column` body
- `_openJukeboxSheet()` triggers `showModalBottomSheet` with `JukeboxSheet`
