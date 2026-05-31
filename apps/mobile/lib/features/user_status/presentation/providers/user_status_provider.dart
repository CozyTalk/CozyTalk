import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
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
  String? _lastReportedRoomId;
  int? _lastReportedMemberCount;
  bool? _lastReportedIsLocked;
  String? _lastReportedBackgroundTheme;

  @override
  void build() {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        ref.read(_setOnlineProvider)().catchError((e) {
          debugPrint('[OwnStatus] setOnline failed: $e');
        });
      } else if (next.status == AuthStatus.unauthenticated &&
          previous?.status == AuthStatus.authenticated) {
        ref.read(_clearStatusProvider)().catchError((e) {
          debugPrint('[OwnStatus] clearStatus failed: $e');
        });
      }
    }, fireImmediately: true);

    ref.listen<MatchmakingState>(matchmakingNotifierProvider, (previous, next) {
      // User left the room.
      if (previous?.status == MatchmakingStatus.matched &&
          next.status != MatchmakingStatus.matched) {
        _lastReportedRoomId = null;
        _lastReportedMemberCount = null;
        _lastReportedIsLocked = null;
        _lastReportedBackgroundTheme = null;
        ref.read(_setOnlineProvider)().catchError((e) {
          debugPrint('[OwnStatus] setOnline (after leave) failed: $e');
        });
        return;
      }

      // User is matched — write user_status. Falls back to defaults when
      // currentRoom hasn't streamed in yet so the RTDB node updates
      // immediately on match instead of waiting for the Firestore room
      // subscription.
      if (next.status != MatchmakingStatus.matched || next.roomId == null) {
        return;
      }
      final room = next.currentRoom;
      final mode = room?.mode == RoomMode.oneToOne ? '1v1' : 'group';
      final maxUsers = room?.maxUsers ?? (mode == '1v1' ? 2 : 5);
      final memberCount = room?.memberCount ?? 1;
      final isLocked = room?.isLocked ?? false;
      final backgroundTheme = room?.backgroundTheme;

      final roomChanged = next.roomId != _lastReportedRoomId;
      final memberCountChanged = memberCount != _lastReportedMemberCount;
      final isLockedChanged = isLocked != _lastReportedIsLocked;
      final backgroundThemeChanged =
          backgroundTheme != _lastReportedBackgroundTheme;
      if (!roomChanged &&
          !memberCountChanged &&
          !isLockedChanged &&
          !backgroundThemeChanged) {
        return;
      }

      _lastReportedRoomId = next.roomId;
      _lastReportedMemberCount = memberCount;
      _lastReportedIsLocked = isLocked;
      _lastReportedBackgroundTheme = backgroundTheme;

      ref
          .read(_setInRoomProvider)(
            roomId: next.roomId!,
            mode: mode,
            maxUsers: maxUsers,
            memberCount: memberCount,
            isLocked: isLocked,
            backgroundTheme: backgroundTheme,
          )
          .then((_) {
            debugPrint(
              '[OwnStatus] setInRoom OK roomId=${next.roomId} '
              'members=$memberCount/$maxUsers locked=$isLocked '
              'theme=$backgroundTheme',
            );
          })
          .catchError((e) {
            debugPrint('[OwnStatus] setInRoom failed: $e');
          });
    });
  }
}
