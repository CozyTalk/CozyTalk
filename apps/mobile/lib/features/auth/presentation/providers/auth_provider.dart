import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/cache_keys.dart';
import '../../../../shared/prefs_provider.dart';

import '../../data/datasources/auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_in_anonymously.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

final _authDatasourceProvider = Provider<AuthDatasource>(
  (ref) =>
      AuthDatasourceImpl(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(_authDatasourceProvider)),
);

final _signUpProvider = Provider<SignUp>(
  (ref) => SignUp(ref.watch(authRepositoryProvider)),
);

final _signInAnonymouslyProvider = Provider<SignInAnonymously>(
  (ref) => SignInAnonymously(ref.watch(authRepositoryProvider)),
);

final _signInWithGoogleProvider = Provider<SignInWithGoogle>(
  (ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);

final _signInProvider = Provider<SignIn>(
  (ref) => SignIn(ref.watch(authRepositoryProvider)),
);

final _signOutProvider = Provider<SignOut>(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final userRoleProvider = StreamProvider.autoDispose.family<String, String>((
  ref,
  uid,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? (doc.data()!['role'] as String? ?? '') : '');
});

enum AuthStatus { idle, loading, authenticated, unauthenticated }

const _sentinel = Object();

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;
  final bool isBanned;
  final int banDaysLeft;
  final String banReinstateDate;

  const AuthState({
    this.status = AuthStatus.idle,
    this.user,
    this.error,
    this.isBanned = false,
    this.banDaysLeft = 0,
    this.banReinstateDate = '',
  });

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _sentinel,
    Object? error = _sentinel,
    bool? isBanned,
    int? banDaysLeft,
    String? banReinstateDate,
  }) => AuthState(
    status: status ?? this.status,
    user: user == _sentinel ? this.user : user as AuthUser?,
    error: error == _sentinel ? this.error : error as String?,
    isBanned: isBanned ?? this.isBanned,
    banDaysLeft: banDaysLeft ?? this.banDaysLeft,
    banReinstateDate: banReinstateDate ?? this.banReinstateDate,
  );
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<AuthUser?>? _sub;

  @override
  AuthState build() {
    _sub?.cancel();
    _sub = ref.read(authRepositoryProvider).watchAuthState().listen((user) {
      if (state.status == AuthStatus.loading) return;
      state = state.copyWith(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
        error: null,
      );
    });
    ref.onDispose(() => _sub?.cancel());
    _checkTokenOnStartup();
    return const AuthState();
  }

  void _checkTokenOnStartup() {
    Future(() async {
      if (!ref.mounted) return;
      if (state.user == null) return;
      try {
        await ref.read(authRepositoryProvider).validateToken();
        await ref.read(authRepositoryProvider).checkBanStatus(state.user!.uid);
      } catch (e) {
        if (!ref.mounted) return;
        final banState = _parseBanException(e);
        if (banState != null) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            isBanned: true,
            banDaysLeft: banState.$1,
            banReinstateDate: banState.$2,
          );
          return;
        }
        await signOut();
        if (!ref.mounted) return;
        state = state.copyWith(
          error: 'Your session has expired. Please sign in again.',
        );
      }
    });
  }

  // Returns (daysLeft, reinstateDate) if the exception is a ban, null otherwise.
  (int, String)? _parseBanException(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (!msg.startsWith('BANNED:')) return null;
    final parts = msg.split(':');
    if (parts.length < 3) return null;
    final days = int.tryParse(parts[1]) ?? 0;
    final date = parts.sublist(2).join(':');
    return (days, date);
  }

  Future<void> signInAnonymously() async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signInAnonymouslyProvider)();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      _handleSignInError(e);
    }
  }

  Future<void> signInWithGoogle() async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signInWithGoogleProvider)();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.isEmpty) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }
      _handleSignInError(e);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signUpProvider)(
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      _handleSignInError(e);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signInProvider)(
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      _handleSignInError(e);
    }
  }

  void _handleSignInError(Object e) {
    final banState = _parseBanException(e);
    if (banState != null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isBanned: true,
        banDaysLeft: banState.$1,
        banReinstateDate: banState.$2,
      );
      return;
    }
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      error: e.toString().replaceFirst('Exception: ', ''),
    );
  }

  Future<void> signOut() async {
    final uid = state.user?.uid;
    if (uid != null) {
      final prefs = ref.read(sharedPreferencesProvider);
      await Future.wait([
        prefs.remove(CacheKeys.profile(uid)),
        prefs.remove(CacheKeys.avatar(uid)),
      ]);
    }
    await ref.read(_signOutProvider)();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      error: null,
    );
  }
}
