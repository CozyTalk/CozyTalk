import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/cache_keys.dart';
import '../../../../shared/prefs_provider.dart';

import '../../data/datasources/auth_datasource.dart'
    show AuthDatasource, AuthDatasourceImpl, BanException;
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
  // True when ban is detected while the user is already inside the app.
  // The home screen shows the popup before signing out.
  final bool bannedWhileActive;

  const AuthState({
    this.status = AuthStatus.idle,
    this.user,
    this.error,
    this.isBanned = false,
    this.banDaysLeft = 0,
    this.banReinstateDate = '',
    this.bannedWhileActive = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _sentinel,
    Object? error = _sentinel,
    bool? isBanned,
    int? banDaysLeft,
    String? banReinstateDate,
    bool? bannedWhileActive,
  }) => AuthState(
    status: status ?? this.status,
    user: user == _sentinel ? this.user : user as AuthUser?,
    error: error == _sentinel ? this.error : error as String?,
    isBanned: isBanned ?? this.isBanned,
    banDaysLeft: banDaysLeft ?? this.banDaysLeft,
    banReinstateDate: banReinstateDate ?? this.banReinstateDate,
    bannedWhileActive: bannedWhileActive ?? this.bannedWhileActive,
  );
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<AuthUser?>? _sub;
  StreamSubscription<(int, String)?>? _banSub;

  @override
  AuthState build() {
    _sub?.cancel();
    _banSub?.cancel();
    _sub = ref.read(authRepositoryProvider).watchAuthState().listen((user) {
      final wasIdle = state.status == AuthStatus.idle;
      if (state.status == AuthStatus.loading) return;
      state = state.copyWith(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
        error: null,
      );
      if (user != null) {
        _subscribeToBan(user.uid);
        // On the first auth event (app startup with existing session), validate
        // the token and enforce any active ban so the LoginScreen dialog appears.
        if (wasIdle) _checkTokenAndBan(user.uid);
      } else {
        _banSub?.cancel();
        _banSub = null;
      }
    });
    ref.onDispose(() {
      _sub?.cancel();
      _banSub?.cancel();
    });
    return const AuthState();
  }

  void _subscribeToBan(String uid) {
    _banSub?.cancel();
    _banSub = ref.read(authRepositoryProvider).watchBanStatus(uid).listen((
      banInfo,
    ) {
      if (banInfo == null) return;
      if (!ref.mounted) return;
      _banSub?.cancel();
      _banSub = null;
      // Signal the UI to show the popup first — do NOT sign out yet.
      // confirmBanAndSignOut() is called when user taps "Back To Log in".
      state = state.copyWith(
        bannedWhileActive: true,
        banDaysLeft: banInfo.$1,
        banReinstateDate: banInfo.$2,
      );
    });
  }

  Future<void> confirmBanAndSignOut() async {
    final uid = state.user?.uid;
    if (uid != null) {
      final prefs = ref.read(sharedPreferencesProvider);
      await Future.wait([
        prefs.remove(CacheKeys.profile(uid)),
        prefs.remove(CacheKeys.avatar(uid)),
      ]);
    }
    // Note: active chat/room sessions are cleaned up via widget disposal when the
    // navigator transitions to LoginScreen after signOut() sets unauthenticated.
    // RTDB onDisconnect handlers cover any residual presence/typing entries.
    await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) return;
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      bannedWhileActive: false,
      isBanned: true,
      error: null,
    );
  }

  // Called on app startup when watchAuthState delivers the first (cached) user.
  // Validates the token and enforces any active ban — if banned, transitions to
  // unauthenticated + isBanned so the LoginScreen dialog appears.
  void _checkTokenAndBan(String uid) {
    Future(() async {
      if (!ref.mounted) return;
      try {
        await ref.read(authRepositoryProvider).validateToken();
        await ref.read(authRepositoryProvider).checkBanStatus(uid);
      } catch (e) {
        if (!ref.mounted) return;
        if (e is BanException) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            isBanned: true,
            banDaysLeft: e.daysLeft,
            banReinstateDate: e.reinstateDate,
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

  Future<void> signInAnonymously() async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      isBanned: false,
    );
    try {
      final user = await ref.read(_signInAnonymouslyProvider)();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _subscribeToBan(user.uid);
    } catch (e) {
      _handleSignInError(e);
    }
  }

  Future<void> signInWithGoogle() async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      isBanned: false,
    );
    try {
      final user = await ref.read(_signInWithGoogleProvider)();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _subscribeToBan(user.uid);
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
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      isBanned: false,
    );
    try {
      final user = await ref.read(_signUpProvider)(
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _subscribeToBan(user.uid);
    } catch (e) {
      _handleSignInError(e);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      isBanned: false,
    );
    try {
      final user = await ref.read(_signInProvider)(
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _subscribeToBan(user.uid);
    } catch (e) {
      _handleSignInError(e);
    }
  }

  void _handleSignInError(Object e) {
    if (e is BanException) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isBanned: true,
        banDaysLeft: e.daysLeft,
        banReinstateDate: e.reinstateDate,
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
