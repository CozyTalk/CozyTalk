import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/user_status_model.dart';

abstract class UserStatusDatasource {
  Stream<UserStatusModel?> watchStatus(String uid);
  Future<void> setOnline();
  Future<void> setInRoom({required String roomId, required String mode});
  Future<void> clearStatus();
}

class UserStatusDatasourceImpl implements UserStatusDatasource {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  UserStatusDatasourceImpl(this._db, this._auth);

  @override
  Stream<UserStatusModel?> watchStatus(String uid) {
    return _db.ref('user_status/$uid').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return UserStatusModel.fromJson(
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  @override
  Future<void> setOnline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.ref('user_status/$uid');
    await ref.onDisconnect().remove();
    await ref.set({'status': 'online'});
  }

  @override
  Future<void> setInRoom({required String roomId, required String mode}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.ref('user_status/$uid');
    await ref.onDisconnect().remove();
    await ref.set({'status': 'in_room', 'roomId': roomId, 'roomMode': mode});
  }

  @override
  Future<void> clearStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.ref('user_status/$uid').remove();
  }
}
