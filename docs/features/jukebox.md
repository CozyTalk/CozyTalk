# Feature: jukebox

Synced music queue for chat rooms. Any participant can add an Audiomack song URL; all participants hear the same track in sync. Supports pause/resume, skip, and remove from queue. Android: `just_audio` streams the track directly with seek-based sync. Web: Audiomack embed iframe (`JukeboxEmbedPlayer`) loaded in `HtmlElementView`; the iframe player handles playback natively.

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
│   ├── datasources/jukebox_datasource.dart  abstract + JukeboxDatasourceImpl (RTDB + Audiomack HTTP)
│   └── repositories/jukebox_repository_impl.dart
└── presentation/
    ├── providers/jukebox_provider.dart   jukeboxNotifierProvider, JukeboxNotifier (owns AudioPlayer), JukeboxUiState
    └── widgets/
        ├── jukebox_embed_player.dart         conditional export (web/stub)
        ├── jukebox_embed_player_stub.dart    SizedBox.shrink() on Android
        ├── jukebox_embed_player_web.dart     HtmlElementView iframe (package:web)
        ├── jukebox_player.dart               invisible widget — mounts AudioPlayer in ChatScreen body
        ├── jukebox_sheet.dart                DraggableScrollableSheet modal
        └── queue_slot_tile.dart              queue item tile with remove button
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `jukeboxNotifierProvider` | `NotifierProvider<JukeboxNotifier, JukeboxUiState>` | owns AudioPlayer (Android only), drives RTDB sync and playback |

`JukeboxNotifier` skips `AudioPlayer` creation on web (`kIsWeb` guard) and `_syncPlayer()` returns early on web — playback is handled entirely by the `JukeboxEmbedPlayer` iframe.

## State

`JukeboxUiState` — `roomId` (String?), `roomState` (JukeboxRoomState?), `isResolving` (bool), `resolveError` (String?), `urlInput` (String)

Sentinel pattern for nullable fields (`roomId`, `roomState`, `resolveError`) — callers must pass `null` explicitly to clear.

## Audiomack API

Base: `https://api.audiomack.com/v1` — zero auth for all MVP endpoints.

| Endpoint | Purpose |
|---|---|
| `GET /v1/music/song/{artist}/{slug}` | Fetch track metadata + streaming URL |
| `POST /v1/music/{id}/play` | Refresh streaming URL (valid ~10s) |
| `GET /v1/music/stats/token?device=anonymous&music_id={id}` | Stats token |
| `POST /v1/music/stats/{id}` body `token=…&type=play` | Report play (ToS requirement) |

URL format: `https://audiomack.com/{artist}/song/{slug}` — path segments [0] = artist, [2] = slug, [1] must be `'song'`.

## RTDB Path

`jukebox/{roomId}` — read/write restricted to room members (same rule as `rooms/{roomId}/members`).

Queue max: 4 tracks (index 0 = now playing + 3 up next). All writes are full-document `.set()` — never partial `.update()`.

`startedAt` is client `DateTime.now().millisecondsSinceEpoch` (ms epoch). All clients seek to `now - startedAt` when a new track starts. Drift < 3s is acceptable.

## Key Behavior

- `JukeboxPlayer` widget mounts in `ChatScreen.body` (not inside the bottom sheet) — `AudioPlayer` lives in the `JukeboxNotifier` so audio continues when the sheet is closed.
- First track added to an empty queue auto-starts: `isPlaying: true`, `startedAt: now`.
- Streaming URL TTL: use stored URL if `streamingUrlTimeout > nowSec + 30`; otherwise call `/play` to refresh.
- Stats reporting is fire-and-forget — never blocks UI or rethrows.
- On session end: `endSession` CF clears `jukebox/{sessionId}` from RTDB.

## Platform Differences

| | Android | Web |
|---|---|---|
| Audio playback | `just_audio` streams CloudFront signed URL | Audiomack embed iframe (`JukeboxEmbedPlayer`) |
| Sync precision | Seek to `now - startedAt` on track change | Best-effort — iframe auto-plays from start on each track change |
| Play/pause control | Notifier-driven (RTDB `isPlaying`) | Controlled within iframe player |
| Pause/resume button | Shown in `JukeboxSheet` | Hidden (iframe has its own controls) |
| Skip button | Shown | Shown |

## Integration with ChatScreen

`chat_screen.dart` — added:
- Jukebox music button in `AppBar.actions` (before report button)
- `JukeboxPlayer(roomId: widget.sessionId)` in `Column` body
- `_openJukeboxSheet()` triggers `showModalBottomSheet` with `JukeboxSheet`
