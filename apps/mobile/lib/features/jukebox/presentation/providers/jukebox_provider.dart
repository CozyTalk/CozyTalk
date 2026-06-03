import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/jukebox_datasource.dart';
import '../../data/repositories/jukebox_repository_impl.dart';
import '../../domain/entities/jukebox_room_state.dart';
import '../../domain/repositories/jukebox_repository.dart';
import '../../domain/usecases/add_to_queue.dart';
import '../../domain/usecases/remove_from_queue.dart';
import '../../domain/usecases/resolve_track.dart';
import '../../domain/usecases/set_playing.dart';
import '../../domain/usecases/skip_track.dart';
import '../../domain/usecases/watch_jukebox.dart';

// ── DI chain ──────────────────────────────────────────────────────────────────

final _jukeboxDatasourceProvider = Provider<JukeboxDatasource>(
  (ref) => JukeboxDatasourceImpl(FirebaseDatabase.instance),
);

final _jukeboxRepositoryProvider = Provider<JukeboxRepository>(
  (ref) => JukeboxRepositoryImpl(ref.watch(_jukeboxDatasourceProvider)),
);

final _watchJukeboxProvider = Provider<WatchJukebox>(
  (ref) => WatchJukebox(ref.watch(_jukeboxRepositoryProvider)),
);

final _resolveTrackProvider = Provider<ResolveTrack>(
  (ref) => ResolveTrack(ref.watch(_jukeboxRepositoryProvider)),
);

final _addToQueueProvider = Provider<AddToQueue>(
  (ref) => AddToQueue(ref.watch(_jukeboxRepositoryProvider)),
);

final _removeFromQueueProvider = Provider<RemoveFromQueue>(
  (ref) => RemoveFromQueue(ref.watch(_jukeboxRepositoryProvider)),
);

final _skipTrackProvider = Provider<SkipTrack>(
  (ref) => SkipTrack(ref.watch(_jukeboxRepositoryProvider)),
);

final _setPlayingProvider = Provider<SetPlaying>(
  (ref) => SetPlaying(ref.watch(_jukeboxRepositoryProvider)),
);

final jukeboxNotifierProvider =
    NotifierProvider<JukeboxNotifier, JukeboxUiState>(JukeboxNotifier.new);

// ── State ─────────────────────────────────────────────────────────────────────

const _sentinel = Object();

class JukeboxUiState {
  final String? roomId;
  final JukeboxRoomState? roomState;
  final bool isResolving;
  final String? resolveError;
  final String urlInput;

  const JukeboxUiState({
    this.roomId,
    this.roomState,
    this.isResolving = false,
    this.resolveError,
    this.urlInput = '',
  });

  JukeboxUiState copyWith({
    Object? roomId = _sentinel,
    Object? roomState = _sentinel,
    bool? isResolving,
    Object? resolveError = _sentinel,
    String? urlInput,
  }) => JukeboxUiState(
    roomId: roomId == _sentinel ? this.roomId : roomId as String?,
    roomState: roomState == _sentinel
        ? this.roomState
        : roomState as JukeboxRoomState?,
    isResolving: isResolving ?? this.isResolving,
    resolveError: resolveError == _sentinel
        ? this.resolveError
        : resolveError as String?,
    urlInput: urlInput ?? this.urlInput,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class JukeboxNotifier extends Notifier<JukeboxUiState> {
  StreamSubscription<JukeboxRoomState?>? _rtdbSub;
  // True only while the subscription has connected and is receiving data.
  bool _subActive = false;

  @override
  JukeboxUiState build() {
    ref.onDispose(_dispose);
    return const JukeboxUiState();
  }

  // Called from both JukeboxPlayer (on every ChatScreen build) and
  // JukeboxSheet.initState as a safety net.
  void enterRoom(String roomId) {
    // Re-subscribe if: different room, OR subscription is dead/errored.
    if (state.roomId == roomId && _subActive) return;
    _rtdbSub?.cancel();
    _subActive = false;
    state = state.copyWith(roomId: roomId);
    _subscribeToJukebox(roomId);
  }

  void leaveRoom() {
    _rtdbSub?.cancel();
    _rtdbSub = null;
    _subActive = false;
    state = const JukeboxUiState();
  }

  void _subscribeToJukebox(String roomId) {
    _rtdbSub = ref
        .read(_watchJukeboxProvider)(roomId)
        .listen(
          (s) {
            _subActive = true;
            _onRtdbState(s);
          },
          onError: (Object _) {
            _subActive = false;
            _scheduleRetry(roomId);
          },
          // Flutter Web Firebase RTDB fires onDone (not onError) for permission
          // denied — retry here too so the subscription heals once rules pass.
          onDone: () {
            _subActive = false;
            _scheduleRetry(roomId);
          },
        );
  }

  void _scheduleRetry(String roomId) {
    Future.delayed(const Duration(seconds: 1), () {
      if (state.roomId == roomId && !_subActive) {
        _subscribeToJukebox(roomId);
      }
    });
  }

  // URL is passed directly from the text field — no state sync required.
  Future<void> addUrl(String url) async {
    final roomId = state.roomId;
    if (roomId == null) {
      state = state.copyWith(
        resolveError: 'Connecting to room… try again in a moment.',
      );
      return;
    }
    if (url.isEmpty || state.isResolving) return;
    if ((state.roomState?.queue.length ?? 0) >= 4) {
      state = state.copyWith(resolveError: 'Queue is full (max 4 tracks).');
      return;
    }
    state = state.copyWith(isResolving: true, resolveError: null, urlInput: '');
    try {
      final user = FirebaseAuth.instance.currentUser;
      final track = await ref.read(_resolveTrackProvider)(
        youtubeUrl: url,
        addedBy: user?.uid ?? '',
        addedByName: user?.displayName ?? 'Anonymous',
      );
      final current =
          state.roomState ??
          const JukeboxRoomState(
            isPlaying: false,
            currentIndex: 0,
            startedAt: 0,
            queue: [],
          );
      final newRoomState = await ref.read(_addToQueueProvider)(
        roomId: roomId,
        current: current,
        track: track,
      );
      state = state.copyWith(isResolving: false, roomState: newRoomState);
    } catch (e) {
      state = state.copyWith(
        isResolving: false,
        resolveError: _friendlyError(e),
      );
    }
  }

  Future<void> skip() async {
    final roomId = state.roomId;
    final roomState = state.roomState;
    if (roomId == null || roomState == null) return;
    await ref.read(_skipTrackProvider)(roomId: roomId, current: roomState);
  }

  Future<void> setPlaying(bool isPlaying) async {
    final roomId = state.roomId;
    final roomState = state.roomState;
    if (roomId == null || roomState == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final pausedAt = isPlaying ? 0 : (now - roomState.startedAt);
    await ref.read(_setPlayingProvider)(
      roomId: roomId,
      current: roomState,
      isPlaying: isPlaying,
      pausedAt: pausedAt,
    );
  }

  Future<void> removeFromQueue(int index) async {
    final roomId = state.roomId;
    final roomState = state.roomState;
    if (roomId == null || roomState == null) return;
    final updated = await ref.read(_removeFromQueueProvider)(
      roomId: roomId,
      current: roomState,
      index: index,
    );
    state = state.copyWith(roomState: updated);
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onRtdbState(JukeboxRoomState? roomState) {
    state = state.copyWith(roomState: roomState);
  }

  void _dispose() {
    _rtdbSub?.cancel();
  }

  static String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid YouTube URL')) {
      return 'Paste a valid youtube.com/watch?v=... or youtu.be/... link.';
    }
    if (msg.contains('404') || msg.contains('not found')) {
      return 'Video not found on YouTube.';
    }
    if (msg.contains('Queue is full')) return 'Queue is full (max 4 tracks).';
    return 'Could not add track. Try again.';
  }
}
