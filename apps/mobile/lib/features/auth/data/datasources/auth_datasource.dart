import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_user_model.dart';

abstract class AuthDatasource {
  Stream<AuthUserModel?> watchAuthState();
  Future<AuthUserModel> signInAnonymously();
  Future<AuthUserModel> signInWithGoogle();
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
  });
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  });
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
        : AuthUserModel(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
          ),
  );

  @override
  Future<AuthUserModel> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user!;
      final displayName = _anonymousName(user.uid, {});
      if (credential.additionalUserInfo?.isNewUser == true) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'role': 'user',
          'displayName': displayName,
          'interest': '',
          'moodKey': 'Happy',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      return AuthUserModel(
        uid: user.uid,
        email: user.email,
        displayName: displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    }
  }

  @override
  Future<AuthUserModel> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: googleAuth.idToken),
        );
      }
      final user = credential.user!;
      if (credential.additionalUserInfo?.isNewUser == true) {
        final displayName = (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!
            : _anonymousName(user.uid, {});
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'role': 'user',
          'displayName': displayName,
          'interest': '',
          'moodKey': 'Happy',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      return AuthUserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
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
      final displayName = _anonymousName(user.uid, {});
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'role': 'user',
        'displayName': displayName,
        'interest': '',
        'moodKey': 'Happy',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return AuthUserModel(
        uid: user.uid,
        email: user.email,
        displayName: displayName,
      );
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
      return AuthUserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

// UID-derived seed ensures the same user gets the same name in an empty room; steps forward on collision.
String _anonymousName(String uid, Set<String> taken) {
  const adjectives = [
    'Brave',
    'Calm',
    'Cozy',
    'Daring',
    'Eager',
    'Fluffy',
    'Gentle',
    'Happy',
    'Kind',
    'Lucky',
    'Mellow',
    'Noble',
    'Quiet',
    'Swift',
    'Witty',
  ];
  const animals = [
    'Bear',
    'Crane',
    'Deer',
    'Duck',
    'Fox',
    'Frog',
    'Hawk',
    'Lynx',
    'Otter',
    'Owl',
    'Panda',
    'Quail',
    'Seal',
    'Wolf',
    'Wren',
  ];
  final total = adjectives.length * animals.length;
  final seed = uid.codeUnits.fold(
    5381,
    (h, c) => ((h << 5) + h + c) & 0x7FFFFFFF,
  );
  for (var i = 0; i < total; i++) {
    final idx = (seed + i) % total;
    final name =
        '${adjectives[idx % adjectives.length]} ${animals[idx ~/ adjectives.length]}';
    if (!taken.contains(name)) return name;
  }
  return 'Anonymous';
}

String _authErrorMessage(String code) => switch (code) {
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Invalid email or password.',
  'email-already-in-use' => 'This email is already registered.',
  'invalid-email' => 'Please enter a valid email address.',
  'weak-password' => 'Password must be at least 6 characters.',
  'too-many-requests' => 'Too many attempts. Please try again later.',
  _ => 'Authentication failed. Please try again.',
};
