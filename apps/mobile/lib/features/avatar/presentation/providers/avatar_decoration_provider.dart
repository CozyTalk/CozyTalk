import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/avatar_overlay.dart';
import '../../data/datasources/avatar_datasource.dart';
import '../../data/repositories/avatar_repository_impl.dart';
import '../../domain/entities/avatar_decoration.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../../domain/usecases/get_avatar_decoration.dart';
import '../../domain/usecases/update_hat.dart';
import '../../domain/usecases/update_mood.dart';

final _avatarDatasourceProvider = Provider<AvatarDatasource>(
  (ref) => AvatarDatasourceImpl(FirebaseFirestore.instance),
);

final _avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepositoryImpl(ref.watch(_avatarDatasourceProvider)),
);

final _getAvatarDecorationProvider = Provider<GetAvatarDecoration>(
  (ref) => GetAvatarDecoration(ref.watch(_avatarRepositoryProvider)),
);

final _updateHatProvider = Provider<UpdateHat>(
  (ref) => UpdateHat(ref.watch(_avatarRepositoryProvider)),
);

final _updateMoodProvider = Provider<UpdateMood>(
  (ref) => UpdateMood(ref.watch(_avatarRepositoryProvider)),
);

final avatarDecorationNotifierProvider =
    NotifierProvider<AvatarDecorationNotifier, AvatarDecorationState>(
  AvatarDecorationNotifier.new,
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
    state = state.copyWith(status: AvatarDecorationStatus.saving, error: null);
    try {
      await ref.read(_updateHatProvider)(uid, hatKey);
      final confirmed = await ref.read(_getAvatarDecorationProvider)(uid);
      state = state.copyWith(
        status: AvatarDecorationStatus.idle,
        decoration: confirmed,
      );
      _syncToSharedProvider(confirmed);
    } catch (e) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateMood(String uid, String? moodKey) async {
    if (state.status == AvatarDecorationStatus.saving) return;
    state = state.copyWith(status: AvatarDecorationStatus.saving, error: null);
    try {
      await ref.read(_updateMoodProvider)(uid, moodKey);
      final confirmed = await ref.read(_getAvatarDecorationProvider)(uid);
      state = state.copyWith(
        status: AvatarDecorationStatus.idle,
        decoration: confirmed,
      );
      _syncToSharedProvider(confirmed);
    } catch (e) {
      state = state.copyWith(
        status: AvatarDecorationStatus.error,
        error: e.toString(),
      );
    }
  }

  // Keeps the shared in-memory avatarProvider in sync so LayeredAvatar
  // reflects the persisted selection without a full reload.
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
