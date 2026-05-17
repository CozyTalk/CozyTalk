import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../matchmaking/domain/entities/matchmaking_status.dart';
import '../../../matchmaking/domain/entities/room.dart';
import '../../../matchmaking/presentation/providers/matchmaking_provider.dart';
import '../../data/datasources/user_status_datasource.dart';
import '../../data/repositories/user_status_repository_impl.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/repositories/user_status_repository.dart';
import '../../domain/usecases/clear_status.dart';
import '../../domain/usecases/set_in_room.dart';
import '../../domain/usecases/set_online.dart';
import '../../domain/usecases/watch_user_status.dart';

// ── DI chain ─────────────────────────────────────────────────────────────────

final _userStatusDatasourceProvider = Provider<UserStatusDatasource>(
  (ref) => UserStatusDatasourceImpl(
    FirebaseDatabase.instance,
    FirebaseAuth.instance,
  ),
);

final _userStatusRepositoryProvider = Provider<UserStatusRepository>(
  (ref) => UserStatusRepositoryImpl(ref.watch(_userStatusDatasourceProvider)),
);

final _watchUserStatusUsecaseProvider = Provider<WatchUserStatus>(
  (ref) => WatchUserStatus(ref.watch(_userStatusRepositoryProvider)),
);

final _setOnlineProvider = Provider<SetOnline>(
  (ref) => SetOnline(ref.watch(_userStatusRepositoryProvider)),
);

final _setInRoomProvider = Provider<SetInRoom>(
  (ref) => SetInRoom(ref.watch(_userStatusRepositoryProvider)),
);

final _clearStatusProvider = Provider<ClearStatus>(
  (ref) => ClearStatus(ref.watch(_userStatusRepositoryProvider)),
);

// ── Public API ────────────────────────────────────────────────────────────────

/// Watches real-time status for any user by uid.
/// Emits [UserOnlineStatus.offline] when the RTDB node is absent.
final watchUserStatusProvider = StreamProvider.family<UserStatus, String>((
  ref,
  uid,
) {
  return ref.watch(_watchUserStatusUsecaseProvider)(uid);
});

/// Manages the current user's own RTDB status.
/// Must be kept alive from the root widget (call ref.watch in _AuthRouter).
final ownStatusNotifierProvider = NotifierProvider<OwnStatusNotifier, void>(
  OwnStatusNotifier.new,
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class OwnStatusNotifier extends Notifier<void> {
  @override
  void build() {
    // Tracks the last roomId reported to RTDB to avoid redundant writes as
    // currentRoom populates incrementally after matching.
    String? lastReportedRoomId;

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        ref.read(_setOnlineProvider)().catchError((_) {});
      } else if (next.status == AuthStatus.unauthenticated &&
          previous?.status == AuthStatus.authenticated) {
        ref.read(_clearStatusProvider)().catchError((_) {});
      }
    }, fireImmediately: true);

    ref.listen<MatchmakingState>(matchmakingNotifierProvider, (previous, next) {
      if (next.status == MatchmakingStatus.matched &&
          next.roomId != null &&
          next.currentRoom != null &&
          next.roomId != lastReportedRoomId) {
        lastReportedRoomId = next.roomId;
        final mode = next.currentRoom!.mode == RoomMode.oneToOne
            ? '1v1'
            : 'group';
        ref
            .read(_setInRoomProvider)(roomId: next.roomId!, mode: mode)
            .catchError((_) {});
      } else if (previous?.status == MatchmakingStatus.matched &&
          next.status != MatchmakingStatus.matched) {
        lastReportedRoomId = null;
        ref.read(_setOnlineProvider)().catchError((_) {});
      }
    });
  }
}
