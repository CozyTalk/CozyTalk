import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_in_anonymously.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

final _authDatasourceProvider = Provider<AuthDatasource>(
  (ref) => AuthDatasourceImpl(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final _authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(_authDatasourceProvider)),
);

final _signUpProvider = Provider<SignUp>(
  (ref) => SignUp(ref.watch(_authRepositoryProvider)),
);

final _signInAnonymouslyProvider = Provider<SignInAnonymously>(
  (ref) => SignInAnonymously(ref.watch(_authRepositoryProvider)),
);

final _signInProvider = Provider<SignIn>(
  (ref) => SignIn(ref.watch(_authRepositoryProvider)),
);

final _signOutProvider = Provider<SignOut>(
  (ref) => SignOut(ref.watch(_authRepositoryProvider)),
);

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

enum AuthStatus { idle, loading, authenticated, unauthenticated }

const _sentinel = Object();

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.idle,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _sentinel,
    Object? error = _sentinel,
  }) => AuthState(
        status: status ?? this.status,
        user: user == _sentinel ? this.user : user as AuthUser?,
        error: error == _sentinel ? this.error : error as String?,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<AuthUser?>? _sub;

  @override
  AuthState build() {
    _sub?.cancel();
    _sub = ref.read(_authRepositoryProvider).watchAuthState().listen((user) {
      if (state.status == AuthStatus.loading) return;
      state = state.copyWith(
        status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: user,
        error: null,
      );
    });
    ref.onDispose(() => _sub?.cancel());
    return const AuthState();
  }

  Future<void> signInAnonymously() async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signInAnonymouslyProvider)();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signUpProvider)(email: email, password: password);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref.read(_signInProvider)(email: email, password: password);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    await ref.read(_signOutProvider)();
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null, error: null);
  }
}
