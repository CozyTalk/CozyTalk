import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/avatar_decoration_model.dart';

abstract class AvatarDatasource {
  Future<AvatarDecorationModel?> getDecoration(String uid);
  Future<void> updateHat(String uid, String? hatKey);
  Future<void> updateMood(String uid, String? moodKey);
  Future<void> updateDecoration(String uid, String? hatKey, String? moodKey);
}

class AvatarDatasourceImpl implements AvatarDatasource {
  final FirebaseFirestore _db;
  AvatarDatasourceImpl(this._db);

  @override
  Future<AvatarDecorationModel?> getDecoration(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    return AvatarDecorationModel.fromJson(data);
  }

  @override
  Future<void> updateHat(String uid, String? hatKey) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    if (doc.exists) {
      // update() is safe on existing docs and correctly uses FieldValue.delete()
      // to remove the field when hatKey is null.
      await docRef.update({'hatKey': hatKey ?? FieldValue.delete()});
    } else {
      // Document missing (e.g. anonymous sign-in path that skips Firestore doc
      // creation). The create rule requires uid and role to be present.
      await docRef.set({
        'uid': uid,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        if (hatKey != null) 'hatKey': hatKey,
      });
    }
  }

  @override
  Future<void> updateMood(String uid, String? moodKey) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({'moodKey': moodKey ?? FieldValue.delete()});
    } else {
      await docRef.set({
        'uid': uid,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        if (moodKey != null) 'moodKey': moodKey,
      });
    }
  }

  @override
  Future<void> updateDecoration(
    String uid,
    String? hatKey,
    String? moodKey,
  ) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({
        'hatKey': hatKey ?? FieldValue.delete(),
        'moodKey': moodKey ?? FieldValue.delete(),
      });
    } else {
      await docRef.set({
        'uid': uid,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        if (hatKey != null) 'hatKey': hatKey,
        if (moodKey != null) 'moodKey': moodKey,
      });
    }
  }
}
