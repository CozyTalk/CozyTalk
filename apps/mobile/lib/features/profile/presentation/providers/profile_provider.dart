import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/profile_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_display_name.dart';
import '../../domain/usecases/update_interest.dart';
import '../../domain/usecases/update_thoughts.dart';

final _profileDatasourceProvider = Provider<ProfileDatasource>(
  (ref) => ProfileDatasourceImpl(FirebaseFirestore.instance),
);

final _profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(_profileDatasourceProvider)),
);

final _getProfileProvider = Provider<GetProfile>(
  (ref) => GetProfile(ref.watch(_profileRepositoryProvider)),
);

final _updateDisplayNameProvider = Provider<UpdateDisplayName>(
  (ref) => UpdateDisplayName(ref.watch(_profileRepositoryProvider)),
);

final _updateInterestProvider = Provider<UpdateInterest>(
  (ref) => UpdateInterest(ref.watch(_profileRepositoryProvider)),
);

final _updateThoughtsProvider = Provider<UpdateThoughts>(
  (ref) => UpdateThoughts(ref.watch(_profileRepositoryProvider)),
);

final profileNotifierProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

const _sentinel = Object();

class ProfileState {
  final ProfileUser? profile;
  final bool isLoading;
  final String? error;
  final String? successField;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.successField,
  });

  ProfileState copyWith({
    Object? profile = _sentinel,
    bool? isLoading,
    Object? error = _sentinel,
    Object? successField = _sentinel,
  }) => ProfileState(
    profile: profile == _sentinel ? this.profile : profile as ProfileUser?,
    isLoading: isLoading ?? this.isLoading,
    error: error == _sentinel ? this.error : error as String?,
    successField:
        successField == _sentinel
            ? this.successField
            : successField as String?,
  );
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();

  Future<void> load(String uid) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null, successField: null);
    try {
      final profile = await ref.read(_getProfileProvider)(uid);
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null, successField: null);
    try {
      await ref.read(_updateDisplayNameProvider)(uid, displayName);
      state = state.copyWith(
        isLoading: false,
        profile: state.profile == null
            ? ProfileUser(uid: uid, displayName: displayName)
            : ProfileUser(
                uid: state.profile!.uid,
                displayName: displayName,
                interest: state.profile!.interest,
                thoughts: state.profile!.thoughts,
              ),
        successField: 'username',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateInterest(String uid, String interest) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null, successField: null);
    try {
      await ref.read(_updateInterestProvider)(uid, interest);
      state = state.copyWith(
        isLoading: false,
        profile: state.profile == null
            ? ProfileUser(uid: uid, interest: interest)
            : ProfileUser(
                uid: state.profile!.uid,
                displayName: state.profile!.displayName,
                interest: interest,
                thoughts: state.profile!.thoughts,
              ),
        successField: 'interest',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateThoughts(String uid, String thoughts) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null, successField: null);
    try {
      await ref.read(_updateThoughtsProvider)(uid, thoughts);
      state = state.copyWith(
        isLoading: false,
        profile: state.profile == null
            ? ProfileUser(uid: uid, thoughts: thoughts)
            : ProfileUser(
                uid: state.profile!.uid,
                displayName: state.profile!.displayName,
                interest: state.profile!.interest,
                thoughts: thoughts,
              ),
        successField: 'thoughts',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
