import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../domain/entities/typing_user.dart';
import '../models/chat_message_model.dart';

abstract class ChatDatasource {
  Future<String> fetchSessionKey(String sessionId);
  Stream<List<ChatMessageModel>> watchRawMessages(String sessionId);
  Stream<List<TypingUser>> watchTypingUsers(String sessionId);
  Future<void> sendMessage({required String sessionId, required String text});
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  });
  Future<void> endSession({required String sessionId});
}

class ChatDatasourceImpl implements ChatDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  ChatDatasourceImpl(this._firestore, this._db, this._functions, this._auth);

  @override
  Future<String> fetchSessionKey(String sessionId) async {
    final doc =
        await _firestore.collection('active_sessions').doc(sessionId).get();
    if (!doc.exists) throw Exception('Session $sessionId not found.');
    final data = Map<String, dynamic>.from(doc.data()!);
    final key = data['encryptionKey'] as String?;
    if (key == null) throw Exception('Encryption key not yet generated.');
    return key;
  }

  @override
  Stream<List<ChatMessageModel>> watchRawMessages(String sessionId) {
    return _firestore
        .collection('chat_rooms')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              // Firestore Timestamp → int (ms since epoch) for json_serializable.
              final ts = data['timestamp'];
              data['timestamp'] =
                  ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
              data['id'] = doc.id;
              return ChatMessageModel.fromJson(data);
            }).toList());
  }

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) {
    return _db.ref('typing/$sessionId').onValue.map((event) {
      final raw = event.snapshot.value as Map? ?? {};
      return raw.entries
          .where((e) {
            final v = e.value;
            return v is Map && v['isTyping'] == true;
          })
          .map((e) {
            final v = Map<String, dynamic>.from(e.value as Map);
            return TypingUser(
              uid: e.key as String,
              displayName: v['displayName'] as String? ?? 'Anonymous',
            );
          })
          .toList();
    });
  }

  @override
  Future<void> sendMessage({
    required String sessionId,
    required String text,
  }) async {
    // TODO: remove proto branch — bypasses sendMessage CF for local prototype testing
    if (sessionId.startsWith('proto-')) {
      final uid = _auth.currentUser?.uid ?? '';
      final name = _auth.currentUser?.displayName ??
          _auth.currentUser?.email ??
          'Anonymous';
      await _firestore
          .collection('chat_rooms')
          .doc(sessionId)
          .collection('messages')
          .add({
        'senderId': uid,
        'displayName': name,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _functions
        .httpsCallable('sendMessage')
        .call({'sessionId': sessionId, 'text': text});
  }

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  }) async {
    final ref = _db.ref('typing/$sessionId/$currentUid');
    if (isTyping) {
      await ref.set({'isTyping': true, 'displayName': displayName});
    } else {
      await ref.remove();
    }
  }

  @override
  Future<void> endSession({required String sessionId}) async {
    // Clear own typing entry before calling the CF so peers see it immediately.
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.ref('typing/$sessionId/$uid').remove();
    }
    await _functions
        .httpsCallable('endSession')
        .call({'sessionId': sessionId});
  }
}
