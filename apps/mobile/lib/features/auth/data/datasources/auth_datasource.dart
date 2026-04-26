import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_user_model.dart';

abstract class AuthDatasource {
  Stream<AuthUserModel?> watchAuthState();
  Future<AuthUserModel> signInAnonymously();
  Future<AuthUserModel> signUp({required String email, required String password});
  Future<AuthUserModel> signIn({required String email, required String password});
  Future<void> signOut();
}

class AuthDatasourceImpl implements AuthDatasource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthDatasourceImpl(this._auth, this._firestore);

  @override
  Stream<AuthUserModel?> watchAuthState() => _auth.authStateChanges().map(
        (user) => user == null
            ? null
            : AuthUserModel(uid: user.uid, email: user.email, displayName: user.displayName),
      );

  @override
  Future<AuthUserModel> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user!;
      return AuthUserModel(uid: user.uid, email: user.email, displayName: user.displayName);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    }
  }

  @override
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return AuthUserModel(uid: user.uid, email: user.email, displayName: user.displayName);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    }
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      return AuthUserModel(uid: user.uid, email: user.email, displayName: user.displayName);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

String _authErrorMessage(String code) => switch (code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Invalid email or password.',
      'email-already-in-use' => 'This email is already registered.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => 'Authentication failed. Please try again.',
    };
