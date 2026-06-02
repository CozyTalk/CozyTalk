import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/friend_room_status.dart';
import '../models/app_user_model.dart';
import '../models/friend_message_model.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';

abstract class FriendsDatasource {
  String get currentUid;
  Stream<List<AppUserModel>> watchAllUsers();
  Stream<List<FriendModel>> watchFriends();
  Stream<List<FriendRequestModel>> watchIncomingRequests();
  Stream<List<FriendRequestModel>> watchOutgoingRequests();
  Stream<List<FriendMessageModel>> watchMessages(String chatRoomId);
  Stream<bool> watchFriendPresence(String friendUid);
  Stream<({String text, DateTime? timestamp, String senderId})>
  watchFriendLastMessage(String chatRoomId);
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid);
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
  Future<void> cancelFriendRequest({required String toUid});
  Future<void> removeFriend({required String friendshipId});
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  });
  Future<List<AppUser>> getUsersByIds(List<String> uids);
  Future<int> getUnreadMessageCount(
    String chatRoomId, {
    required int sinceMs,
    required String friendUid,
  });
  Future<void> setChatRead(String chatRoomId);
  Stream<DateTime?> watchChatRead(String chatRoomId);
  Future<void> setFriendTyping(String chatRoomId, bool isTyping);
  Stream<bool> watchFriendTyping(String chatRoomId);
}

class FriendsDatasourceImpl implements FriendsDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  FriendsDatasourceImpl(this._firestore, this._auth, this._database);

  @override
  String get currentUid => _auth.currentUser?.uid ?? '';

  @override
  Stream<List<AppUserModel>> watchAllUsers() {
    return _firestore.collection('users').limit(100).snapshots().map((snap) {
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
  Stream<List<FriendRequestModel>> watchOutgoingRequests() {
    return _firestore
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
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
  Stream<bool> watchFriendPresence(String friendUid) {
    return _database
        .ref('user_status/$friendUid')
        .onValue
        .map((event) => event.snapshot.exists && event.snapshot.value != null);
  }

  @override
  Stream<({String text, DateTime? timestamp, String senderId})>
  watchFriendLastMessage(String chatRoomId) {
    return _firestore
        .collection('friend_messages')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) {
            return (text: '', timestamp: null, senderId: '');
          }
          final data = Map<String, dynamic>.from(snap.docs.first.data());
          final ts = data['timestamp'];
          DateTime? timestamp;
          if (ts is Timestamp) {
            timestamp = ts.toDate();
          } else if (ts is int) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
          }
          return (
            text: data['text'] as String? ?? '',
            timestamp: timestamp,
            senderId: data['senderId'] as String? ?? '',
          );
        });
  }

  @override
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid) {
    return _database.ref('user_status/$friendUid').onValue.asyncMap((
      event,
    ) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      if (data['status'] != 'in_room') return null;
      final roomId = data['roomId'] as String?;
      if (roomId == null) return null;

      var backgroundTheme = data['backgroundTheme'] as String?;
      if (backgroundTheme == null) {
        try {
          final doc = await _firestore.collection('rooms').doc(roomId).get();
          backgroundTheme = doc.data()?['backgroundTheme'] as String?;
        } catch (_) {
          // Non-member reads fail per security rules; degrade to null theme.
        }
      }

      return FriendRoomStatus(
        roomId: roomId,
        memberCount: (data['memberCount'] as num?)?.toInt() ?? 1,
        maxUsers: (data['maxUsers'] as num?)?.toInt() ?? 5,
        isLocked: data['isLocked'] as bool? ?? false,
        mode: data['roomMode'] as String? ?? 'group',
        backgroundTheme: backgroundTheme,
      );
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
    // RTDB friends nodes are written by the onFriendshipCreated CF using admin
    // credentials, which bypasses the owner-only write rule that would deny
    // writing the peer's node from this client.
  }

  @override
  Future<void> declineFriendRequest({required String requestId}) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  @override
  Future<void> cancelFriendRequest({required String toUid}) async {
    final docId = '${currentUid}_$toUid';
    await _firestore.collection('friend_requests').doc(docId).delete();
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

  @override
  Future<List<AppUser>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final docs = await Future.wait(
      uids.map((uid) => _firestore.collection('users').doc(uid).get()),
    );
    return docs.where((d) => d.exists).map((d) {
      final data = Map<String, dynamic>.from(d.data()!);
      return AppUser(
        uid: d.id,
        displayName: data['displayName'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<int> getUnreadMessageCount(
    String chatRoomId, {
    required int sinceMs,
    required String friendUid,
  }) async {
    // Count the trailing run of messages sent by the friend, newest-first.
    // Stop at the first message the current user sent: replying (or opening the
    // chat, which advances sinceMs) means everything older has been read. So if
    // the last message is the current user's own, the count is 0.
    // Filtering and ordering on the same field keeps this on the default
    // single-field index (no composite index required).
    final snap = await _firestore
        .collection('friend_messages')
        .doc(chatRoomId)
        .collection('messages')
        .where(
          'timestamp',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMs),
        )
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    var count = 0;
    for (final doc in snap.docs) {
      if (doc.data()['senderId'] == friendUid) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  @override
  Future<void> setChatRead(String chatRoomId) async {
    // serverTimestamp() is assigned by the server, so the read marker shares the
    // same clock as message timestamps — no client skew. Per-user doc keeps the
    // security rule trivial (uid == request.auth.uid) and syncs across devices.
    await _firestore
        .collection('friend_messages')
        .doc(chatRoomId)
        .collection('reads')
        .doc(currentUid)
        .set({'lastReadAt': FieldValue.serverTimestamp()});
  }

  @override
  Stream<DateTime?> watchChatRead(String chatRoomId) {
    return _firestore
        .collection('friend_messages')
        .doc(chatRoomId)
        .collection('reads')
        .doc(currentUid)
        .snapshots()
        .map((doc) {
          final ts = doc.data()?['lastReadAt'];
          return ts is Timestamp ? ts.toDate() : null;
        });
  }

  @override
  Future<void> setFriendTyping(String chatRoomId, bool isTyping) async {
    final ref = _database.ref('friend_typing/$chatRoomId/$currentUid');
    if (isTyping) {
      await ref.set(true);
      ref.onDisconnect().remove();
    } else {
      await ref.remove();
    }
  }

  @override
  Stream<bool> watchFriendTyping(String chatRoomId) {
    return _database.ref('friend_typing/$chatRoomId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return false;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries
          .where((e) => e.key != currentUid)
          .any((e) => e.value == true);
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
