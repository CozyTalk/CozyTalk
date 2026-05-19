# Feature: jukebox

Synced music queue for chat rooms. Any participant can add a YouTube video URL; all participants see the same track and controls in sync. Supports skip, pause/resume, remove from queue, and auto-advance when a track ends. Playback is handled via the YouTube IFrame API on both Android and web.

## File Map

```
features/jukebox/
├── domain/
│   ├── entities/
│   │   ├── jukebox_track.dart          JukeboxTrack (id, youtubeUrl, videoId, title, artist, artworkUrl, addedBy, addedByName)
│   │   └── jukebox_room_state.dart     JukeboxRoomState (isPlaying, currentIndex, startedAt, pausedAt, queue) + hasCurrentTrack / currentTrack / upNext
│   ├── repositories/jukebox_repository.dart  abstract JukeboxRepository
│   └── usecases/
│       ├── watch_jukebox.dart          WatchJukebox — stream RTDB state
│       ├── resolve_track.dart          ResolveTrack — extract videoId + fetch YouTube oEmbed metadata
│       ├── add_to_queue.dart           AddToQueue — appends track; auto-starts on first add; returns new JukeboxRoomState
│       ├── remove_from_queue.dart      RemoveFromQueue — splice + index adjustment
│       ├── skip_track.dart             SkipTrack — advance index or clear when exhausted; resets pausedAt = 0
│       └── set_playing.dart            SetPlaying — pause/resume with startedAt/pausedAt sync math
├── data/
│   ├── models/
│   │   ├── jukebox_track_model.dart        @freezed JukeboxTrackModel + toEntity()
│   │   └── jukebox_room_state_model.dart   @freezed JukeboxRoomStateModel + toEntity(); pausedAt @Default(0)
│   ├── datasources/jukebox_datasource.dart  abstract + JukeboxDatasourceImpl (RTDB + YouTube oEmbed)
│   └── repositories/jukebox_repository_impl.dart  URL extraction + oEmbed delegation
└── presentation/
    ├── providers/jukebox_provider.dart   jukeboxNotifierProvider, JukeboxNotifier, JukeboxUiState
    └── widgets/
        ├── jukebox_player.dart               ConsumerStatefulWidget in ChatScreen body — calls enterRoom/leaveRoom, owns the embed
        ├── jukebox_web_player.dart           conditional export: native on Android, web iframe on Flutter Web
        ├── jukebox_web_player_native.dart    WebViewWidget + loadHtmlString (YouTube IFrame API JS) (Android)
        ├── jukebox_web_player_web.dart       HtmlElementView invisible iframe + postMessage (Flutter Web)
        ├── jukebox_sheet.dart                DraggableScrollableSheet modal — play/pause + skip + queue
        └── queue_slot_tile.dart              queue item tile with remove button
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `jukeboxNotifierProvider` | `NotifierProvider<JukeboxNotifier, JukeboxUiState>` | subscribes to RTDB stream; no audio player |

`JukeboxNotifier` has no `AudioPlayer`. Playback is handled entirely by the `JukeboxWebPlayer` embed on both platforms.

## State

`JukeboxUiState` — `roomId` (String?), `roomState` (JukeboxRoomState?), `isResolving` (bool), `resolveError` (String?), `urlInput` (String)

Sentinel pattern for nullable fields (`roomId`, `roomState`, `resolveError`) — callers must pass `null` explicitly to clear.

After `addUrl()` succeeds, `roomState` is updated optimistically from the `JukeboxRoomState` returned by `AddToQueue` — the NOW PLAYING section becomes visible immediately without waiting for the RTDB round-trip.

## Sync Model

RTDB stores:
- `startedAt` (int, ms epoch) — virtual "when did time=0 of this track happen"
- `pausedAt` (int, ms into the song when paused; 0 while playing)
- `isPlaying` (bool)

Every `JukeboxWebPlayer` calculates seek position on each RTDB update:
```
seekSeconds = isPlaying
  ? (now - startedAt) / 1000
  : pausedAt / 1000
```

**Pausing:** notifier writes `{isPlaying: false, pausedAt: now - startedAt, startedAt: unchanged}`.
**Resuming:** use case writes `{isPlaying: true, startedAt: now - current.pausedAt, pausedAt: 0}`.
**Skip:** use case writes `{isPlaying: true, startedAt: now, pausedAt: 0, currentIndex: next}`.

## YouTube oEmbed API

No authentication required.

| Endpoint | Purpose |
|---|---|
| `GET https://www.youtube.com/oembed?url={encoded_url}&format=json` | Fetch track metadata (title, author_name, thumbnail_url) |

URL input formats supported:
- `https://www.youtube.com/watch?v={videoId}`
- `https://youtu.be/{videoId}`
- `https://www.youtube.com/embed/{videoId}`
- `https://www.youtube.com/shorts/{videoId}`

Video ID extraction is in `JukeboxRepositoryImpl._extractVideoId()`.

The YouTube Data API (`youtube.googleapis.com/v3`) is NOT used — it requires an API key.

## RTDB Path

`jukebox/{roomId}` — read/write restricted to users whose UID appears in either `rooms/{roomId}/members/{uid}` (written by matchmaking CF before users enter chat) OR `presence/{roomId}/{uid}`. Dual condition avoids a race where the jukebox subscription fires before presence is written.

Queue max: 4 tracks (index 0 = now playing + 3 up next). All writes are full-document `.set()` — never partial `.update()`.

## Key Behavior

- `JukeboxPlayer` (`ConsumerStatefulWidget`) mounts in `ChatScreen.body` (not inside the bottom sheet). It calls `enterRoom()` on mount and `leaveRoom()` on dispose (clears subscription and resets state when user navigates back). The embed is always rendered here so it never restarts when the sheet is opened/closed.
- First track added to an empty queue auto-starts: `isPlaying: true`, `startedAt: now`, `pausedAt: 0`.
- `AddToQueue` returns the new `JukeboxRoomState`; `addUrl()` applies it optimistically so the NOW PLAYING section renders without waiting for RTDB.
- Auto-advance: when the currently playing track ends, `JukeboxWebPlayer` fires `onTrackEnded` → `notifier.skip()` → RTDB updated → all clients load the next embed. On Android this is triggered by `onStateChange(0)` (ended) in the YouTube IFrame API JS. On web it uses the `onStateChange` postMessage event from YouTube.
- `JukeboxWebPlayer` is a conditional export. In test environments (no platform WebView), the native controller init throws and `build()` returns `SizedBox.shrink()`.
- `JukeboxSheet` shows track title, artist, artwork, play/pause button, skip button, and queue management. It does NOT render an embed — the embed lives in `JukeboxPlayer` to prevent restarts.
- On session end: `endSession` CF clears `jukebox/{sessionId}` from RTDB.

## Platform Differences

| | Android | Web |
|---|---|---|
| Implementation | `jukebox_web_player_native.dart` | `jukebox_web_player_web.dart` |
| Embed mechanism | `WebViewWidget` with `loadHtmlString` | `HtmlElementView` iframe |
| Visibility | 56px height — small video preview | Fully hidden (`opacity:0`, `pointer-events:none`, 1×1px) |
| YouTube API | IFrame API JS loaded in HTML string | `enablejsapi=1` on iframe src + postMessage |
| Autoplay | `autoplay:1` in `playerVars` | `autoplay=1` in src param + `allow="autoplay"` |
| Track-end detection | `onStateChange(0)` → `FlutterYT.postMessage('ended')` | `onStateChange` info=0 via `window.message` |
| Seek/sync | `player.seekTo(seekSeconds, true)` via `runJavaScript` | `{event:'command',func:'seekTo'}` postMessage |
| Skip button | Shown in `JukeboxSheet` | Shown in `JukeboxSheet` |

## Integration with ChatScreen

`chat_screen.dart` — added:
- Jukebox music button in `AppBar.actions` (before report button)
- `JukeboxPlayer(roomId: widget.sessionId)` in `Column` body
- `_openJukeboxSheet()` triggers `showModalBottomSheet` with `JukeboxSheet`
