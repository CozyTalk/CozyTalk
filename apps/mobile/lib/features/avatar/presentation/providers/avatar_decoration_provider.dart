import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/avatar_overlay.dart';
import '../../../../shared/connectivity_provider.dart';
import '../../../../shared/prefs_provider.dart';
import '../../data/datasources/avatar_cache_datasource.dart';
import '../../data/datasources/avatar_datasource.dart';
import '../../data/repositories/avatar_repository_impl.dart';
import '../../domain/entities/avatar_decoration.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../../domain/usecases/get_avatar_decoration.dart';
import '../../domain/usecases/update_decoration.dart';
import '../../domain/usecases/update_hat.dart';
import '../../domain/usecases/update_mood.dart';

final _avatarDatasourceProvider = Provider<AvatarDatasource>(
  (ref) => AvatarDatasourceImpl(FirebaseFirestore.instance),
);

final _avatarCacheDatasourceProvider = Provider<AvatarCacheDatasource>(
  (ref) => AvatarCacheDatasourceImpl(ref.watch(sharedPreferencesProvider)),
);

final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepositoryImpl(
    ref.watch(_avatarDatasourceProvider),
    ref.watch(_avatarCacheDatasourceProvider),
  ),
);

final _getAvatarDecorationProvider = Provider<GetAvatarDecoration>(
  (ref) => GetAvatarDecoration(ref.watch(avatarRepositoryProvider)),
);

final _updateHatProvider = Provider<UpdateHat>(
  (ref) => UpdateHat(ref.watch(avatarRepositoryProvider)),
);

final _updateMoodProvider = Provider<UpdateMood>(
  (ref) => UpdateMood(ref.watch(avatarRepositoryProvider)),
);

final _updateDecorationProvider = Provider<UpdateDecoration>(
  (ref) => UpdateDecoration(ref.watch(avatarRepositoryProvider)),
);

final avatarDecorationNotifierProvider =
    NotifierProvider<AvatarDecorationNotifier, AvatarDecorationState>(
      AvatarDecorationNotifier.new,
    );

/// Fetches another user's avatar decoration (hatKey, moodKey) from Firestore.
/// Scoped per-UID; disposes automatically when no longer watched.
final partnerDecorationProvider = FutureProvider.autoDispose
    .family<AvatarDecoration?, String>(
      (ref, uid) =>
          GetAvatarDecoration(ref.watch(avatarRepositoryProvider))(uid),
    );

enum AvatarDecorationStatus { idle, loading, saving, error }

const _sentinel = Object();

class AvatarDecorationState {
  final AvatarDecorationStatus status;
  final AvatarDecoration? decoration;
  final String? error;

  const AvatarDecorationState({
    this.status = AvatarDecorationStatus.idle,
    this.decoration,
    this.error,
  });

  AvatarDecorationState copyWith({
    AvatarDecorationStatus? status,
    Object? decoration = _sentinel,
    Object? error = _sentinel,
  }) => AvatarDecorationState(
    status: status ?? this.status,
    decoration: decoration == _sentinel
        ? this.decoration
        : decoration as AvatarDecoration?,
    error: error == _sentinel ? this.error : error as String?,
  );
}

class AvatarDecorationNotifier extends Notifier<AvatarDecorationState> {
  @override
  AvatarDecorationState build() => const AvatarDecorationState();

  Future<void> load(String uid) async {
    if (state.status == AvatarDecorationStatus.loading) return;
    state = state.copyWith(status: AvatarDecorationStatus.loading, error: null);
    try {
      final decoration = await ref.read(_getAvatarDecorationProvider)(uid);
      state = state.copyWith(
        status: AvatarDecorationStatus.idle,
        decoration: decoration,
      );
      _syncToSharedProvider(decoration);
    } catch (e) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateHat(String uid, String? hatKey) async {
    if (state.status == AvatarDecorationStatus.saving) return;
    _resetErrorIfAny();
    if (!await ref.read(networkInfoProvider).isConnected) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: "You're offline. Changes require a connection.",
      );
      return;
    }
    state = state.copyWith(status: AvatarDecorationStatus.saving, error: null);
    try {
      await ref.read(_updateHatProvider)(uid, hatKey);
      final updated = AvatarDecoration(
        hatKey: hatKey,
        moodKey: state.decoration?.moodKey,
      );
      state = state.copyWith(
        status: AvatarDecorationStatus.idle,
        decoration: updated,
      );
      _syncToSharedProvider(updated);
    } catch (e) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateMood(String uid, String? moodKey) async {
    if (state.status == AvatarDecorationStatus.saving) return;
    _resetErrorIfAny();
    if (!await ref.read(networkInfoProvider).isConnected) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: "You're offline. Changes require a connection.",
      );
      return;
    }
    state = state.copyWith(status: AvatarDecorationStatus.saving, error: null);
    try {
      await ref.read(_updateMoodProvider)(uid, moodKey);
      final updated = AvatarDecoration(
        hatKey: state.decoration?.hatKey,
        moodKey: moodKey,
      );
      state = state.copyWith(
        status: AvatarDecorationStatus.idle,
        decoration: updated,
      );
      _syncToSharedProvider(updated);
    } catch (e) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateDecoration(
    String uid,
    String? hatKey,
    String? moodKey,
  ) async {
    if (state.status == AvatarDecorationStatus.saving) return;
    _resetErrorIfAny();
    if (!await ref.read(networkInfoProvider).isConnected) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: "You're offline. Changes require a connection.",
      );
      return;
    }
    state = state.copyWith(status: AvatarDecorationStatus.saving, error: null);
    try {
      await ref.read(_updateDecorationProvider)(uid, hatKey, moodKey);
      final updated = AvatarDecoration(hatKey: hatKey, moodKey: moodKey);
      state = state.copyWith(
        status: AvatarDecorationStatus.idle,
        decoration: updated,
      );
      _syncToSharedProvider(updated);
    } catch (e) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: e.toString(),
      );
    }
  }

  // Clears error state so the HomeScreen ref.listen fires a fresh
  // null→error transition on every repeated offline write attempt.
  void _resetErrorIfAny() {
    if (state.error != null) {
      state = state.copyWith(status: AvatarDecorationStatus.idle, error: null);
    }
  }

  void _syncToSharedProvider(AvatarDecoration? decoration) {
    final local = ref.read(avatarProvider.notifier);
    local.setAccessory(
      decoration?.hatKey != null
          ? AvatarOverlays.accessory[decoration!.hatKey]
          : null,
    );
    local.setMood(
      decoration?.moodKey != null
          ? AvatarOverlays.mood[decoration!.moodKey]
          : null,
    );
  }
}
