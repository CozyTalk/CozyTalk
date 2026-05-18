import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';
import '../models/friend_message_model.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';

abstract class FriendsDatasource {
  String get currentUid;
  Stream<List<AppUserModel>> watchAllUsers();
  Stream<List<FriendModel>> watchFriends();
  Stream<List<FriendRequestModel>> watchIncomingRequests();
  Stream<List<FriendMessageModel>> watchMessages(String chatRoomId);
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  });
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  });
  Future<void> declineFriendRequest({required String requestId});
  Future<void> removeFriend({required String friendshipId});
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  });
}

class FriendsDatasourceImpl implements FriendsDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FriendsDatasourceImpl(this._firestore, this._auth);

  @override
  String get currentUid => _auth.currentUser?.uid ?? '';

  @override
  Stream<List<AppUserModel>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map((snap) {
      return snap.docs.where((doc) => doc.id != currentUid).map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['uid'] = doc.id;
        data['displayName'] = data['displayName'] as String? ?? 'Anonymous';
        return AppUserModel.fromJson(data);
      }).toList();
    });
  }

  @override
  Stream<List<FriendModel>> watchFriends() {
    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUid)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            _normalizeTimestamp(data, 'createdAt');
            if (data['displayNames'] is Map) {
              final raw = data['displayNames'] as Map;
              data['displayNames'] = {
                for (final e in raw.entries)
                  e.key.toString(): e.value?.toString() ?? 'Anonymous',
              };
            }
            if (data['users'] is List) {
              data['users'] = List<dynamic>.from(data['users'] as List);
            }
            return FriendModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Stream<List<FriendRequestModel>> watchIncomingRequests() {
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            _normalizeTimestamp(data, 'createdAt');
            return FriendRequestModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Stream<List<FriendMessageModel>> watchMessages(String chatRoomId) {
    return _firestore
        .collection('friend_messages')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            _normalizeTimestamp(data, 'timestamp');
            return FriendMessageModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  }) async {
    final docId = '${currentUid}_$toUid';
    await _firestore.collection('friend_requests').doc(docId).set({
      'fromUid': currentUid,
      'fromDisplayName': fromDisplayName,
      'toUid': toUid,
      'toDisplayName': toDisplayName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  }) async {
    final friendshipId = _makeFriendshipId(fromUid, currentUid);
    final batch = _firestore.batch();

    batch.update(_firestore.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
    });

    batch.set(_firestore.collection('friendships').doc(friendshipId), {
      'users': [fromUid, currentUid],
      'displayNames': {fromUid: fromDisplayName, currentUid: myDisplayName},
      'chatRoomId': friendshipId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  @override
  Future<void> declineFriendRequest({required String requestId}) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  @override
  Future<void> removeFriend({required String friendshipId}) async {
    await _firestore.collection('friendships').doc(friendshipId).delete();
  }

  @override
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  }) async {
    await _firestore
        .collection('friend_messages')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': currentUid,
          'senderDisplayName': senderDisplayName,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  static String _makeFriendshipId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static void _normalizeTimestamp(Map<String, dynamic> data, String key) {
    final ts = data[key];
    data[key] = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
  }
}
