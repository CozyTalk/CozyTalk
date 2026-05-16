import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profile_user_model.dart';

abstract class ProfileDatasource {
  Future<ProfileUserModel> getProfile(String uid);
  Future<void> updateDisplayName(String uid, String displayName);
  Future<void> updateInterest(String uid, String interest);
  Future<void> updateThoughts(String uid, String thoughts);
}

class ProfileDatasourceImpl implements ProfileDatasource {
  final FirebaseFirestore _firestore;

  ProfileDatasourceImpl(this._firestore);

  @override
  Future<ProfileUserModel> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      return ProfileUserModel(uid: uid);
    }
    return ProfileUserModel.fromJson(
      Map<String, dynamic>.from(doc.data()!),
    );
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) =>
      _firestore.collection('users').doc(uid).set(
        {
          'uid': uid,
          'displayName': displayName,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  @override
  Future<void> updateInterest(String uid, String interest) =>
      _firestore.collection('users').doc(uid).set(
        {
          'uid': uid,
          'interest': interest,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  @override
  Future<void> updateThoughts(String uid, String thoughts) =>
      _firestore.collection('users').doc(uid).set(
        {
          'uid': uid,
          'thoughts': thoughts,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
}
