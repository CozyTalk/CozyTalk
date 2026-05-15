import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
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
    String? photoUrl,
  });
  Future<void> endSession({required String sessionId});

  Future<String> joinProtoSession({
    required String sessionId,
    required String uid,
  });
}

class ChatDatasourceImpl implements ChatDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  ChatDatasourceImpl(this._firestore, this._db, this._functions, this._auth);

  @override
  Future<String> fetchSessionKey(String sessionId) async {
    if (sessionId.startsWith('proto-')) {
      final bytes = await _protoKeyBytes(sessionId);
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
    final doc = await _firestore
        .collection('active_sessions')
        .doc(sessionId)
        .get();
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
        .map(
          (snap) => snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());

            final ts = data['timestamp'];
            data['timestamp'] = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;

            final exp = data['expiresAt'];
            data['expiresAt'] = exp is Timestamp
                ? exp.millisecondsSinceEpoch
                : 0;

            data['id'] = doc.id;
            return ChatMessageModel.fromJson(data);
          }).toList(),
        );
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
              photoUrl: v['photoUrl'] as String?,
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
    if (sessionId.startsWith('proto-')) {
      final uid = _auth.currentUser?.uid ?? '';

      // Read the name claimed during joinProtoSession; fall back if presence
      // was lost (e.g. reconnect before re-join).
      final nameSnap = await _db.ref('presence/$sessionId/$uid').get();
      final name =
          nameSnap.value as String? ??
          _auth.currentUser?.displayName ??
          _auth.currentUser?.email ??
          'Anonymous';

      final keyBytes = await _protoKeyBytes(sessionId);
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final secretBox = await algorithm.encrypt(
        utf8.encode(text),
        secretKey: secretKey,
      );

      await _firestore
          .collection('chat_rooms')
          .doc(sessionId)
          .collection('messages')
          .add({
            'senderId': uid,
            'displayName': name,
            'encryptedText': base64Encode(secretBox.cipherText),
            'iv': base64Encode(secretBox.nonce),
            'authTag': base64Encode(secretBox.mac.bytes),
            'timestamp': FieldValue.serverTimestamp(),
            'expiresAt': FieldValue.serverTimestamp(),
            'flagged': false,
          });
      return;
    }

    await _functions.httpsCallable('sendMessage').call({
      'sessionId': sessionId,
      'text': text,
    });
  }

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
    String? photoUrl,
  }) async {
    if (sessionId.startsWith('proto-')) {
      if (currentUid.isEmpty) return;
      final ref = _db.ref('typing/$sessionId/$currentUid');
      if (isTyping) {
        await ref.set({
          'isTyping': true,
          'displayName': displayName,
          'photoUrl': ?photoUrl,
        });
      } else {
        await ref.remove();
      }
      return;
    }

    await _functions.httpsCallable('setTyping').call({
      'sessionId': sessionId,
      'isTyping': isTyping,
    });
  }

  @override
  Future<void> endSession({required String sessionId}) async {
    final uid = _auth.currentUser?.uid;

    if (sessionId.startsWith('proto-')) {
      if (uid != null) {
        await Future.wait([
          _db.ref('typing/$sessionId/$uid').remove(),
          _db.ref('presence/$sessionId/$uid').remove(),
        ]);
      }
      return;
    }

    if (uid != null) {
      await _db.ref('typing/$sessionId/$uid').remove();
    }
    await _functions.httpsCallable('endSession').call({'sessionId': sessionId});
  }

  @override
  Future<String> joinProtoSession({
    required String sessionId,
    required String uid,
  }) async {
    final presenceSnap = await _db.ref('presence/$sessionId').get();
    final presence = presenceSnap.value is Map
        ? Map<String, dynamic>.from(presenceSnap.value as Map)
        : <String, dynamic>{};

    if (presence.length >= 5) {
      throw Exception('Room is full. Max 5 users per session.');
    }

    final existingNames = presence.values.whereType<String>().toSet();
    final user = _auth.currentUser;

    final String name;
    if (user == null || user.isAnonymous) {
      name = _anonymousName(uid, existingNames);
    } else {
      final baseName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!
          : (user.email ?? 'User');
      name = _deduplicateName(baseName, existingNames);
    }

    final myRef = _db.ref('presence/$sessionId/$uid');
    await myRef.onDisconnect().remove();
    await myRef.set(name);

    return name;
  }

  Future<List<int>> _protoKeyBytes(String sessionId) async {
    final hash = await Sha256().hash(
      utf8.encode('cozytalk-proto-v1:$sessionId'),
    );
    return hash.bytes;
  }

  // UID-derived seed ensures the same user gets the same name in an empty room; steps forward on collision.
  static String _anonymousName(String uid, Set<String> taken) {
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

  static String _deduplicateName(String baseName, Set<String> taken) {
    if (!taken.contains(baseName)) return baseName;
    for (var i = 2; i <= 10; i++) {
      final candidate = '$baseName $i';
      if (!taken.contains(candidate)) return candidate;
    }
    return baseName;
  }
}
