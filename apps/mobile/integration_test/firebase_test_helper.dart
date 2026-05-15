import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import 'package:mobile/firebase_options.dart';

// Android emulator routes host-machine traffic through 10.0.2.2; everywhere
// else (Linux desktop, physical device on same LAN) 127.0.0.1 is correct.
String get _emulatorHost => Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

bool _initialized = false;

/// Initializes Firebase pointed at the local emulator suite.
/// Safe to call multiple times — only initializes once per process.
Future<void> setupFirebaseForTest() async {
  if (_initialized) return;
  _initialized = true;
  // Linux desktop has no firebase_options entry — use the Web config, which
  // points at the same project and works fine against local emulators.
  final options = defaultTargetPlatform == TargetPlatform.linux
      ? DefaultFirebaseOptions.web
      : DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  FirebaseFunctions.instanceFor(
    region: 'us-central1',
  ).useFunctionsEmulator('127.0.0.1', 5001);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);
}

/// Signs in anonymously and returns the uid.
Future<String> signInAnon() async {
  final cred = await FirebaseAuth.instance.signInAnonymously();
  return cred.user!.uid;
}

/// Signs out the current user.
Future<void> signOut() async {
  await FirebaseAuth.instance.signOut();
}

/// Calls a Cloud Function (us-central1) and returns the result data as a Map.
Future<Map<String, dynamic>> callFn(
  String name, [
  Map<String, dynamic> data = const {},
]) async {
  final result = await FirebaseFunctions.instanceFor(
    region: 'us-central1',
  ).httpsCallable(name).call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

/// Reads a Firestore document snapshot.
Future<DocumentSnapshot<Map<String, dynamic>>> firestoreDoc(String path) =>
    FirebaseFirestore.instance.doc(path).get();

/// Reads a value from RTDB.
Future<DataSnapshot> rtdbGet(String path) =>
    FirebaseDatabase.instance.ref(path).get();

/// Leaves a room, ignoring not-found errors.
Future<void> tryLeaveRoom(String roomId) async {
  try {
    await callFn('leaveRoom', {'roomId': roomId});
  } catch (_) {}
}

/// Cancels a user's 1v1 pool entry, ignoring errors.
Future<void> tryCancelPool() async {
  try {
    await callFn('cancel1v1Pool');
  } catch (_) {}
}

/// Wipes ALL Firestore documents and RTDB data in the local emulator.
/// Both deletes run concurrently. Call in setUp() for deterministic test state.
Future<void> resetEmulatorData() async {
  final host = _emulatorHost;
  await Future.wait([
    http.delete(
      Uri.parse(
        'http://$host:8080/emulator/v1/projects/cozytalk-5d984/databases/(default)/documents',
      ),
    ),
    http.delete(
      Uri.parse('http://$host:9000/.json?ns=cozytalk-5d984-default-rtdb'),
    ),
  ]);
}

/// Polls [path] every [interval] until [predicate] returns true or [timeout] elapses.
/// Returns the last snapshot seen. Used to wait for async CF trigger side-effects.
Future<DocumentSnapshot<Map<String, dynamic>>> waitUntilDocMatches(
  String path,
  bool Function(Map<String, dynamic>?) predicate, {
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final doc = await firestoreDoc(path);
    if (predicate(doc.data())) return doc;
    await Future.delayed(interval);
  }
  return firestoreDoc(path);
}

/// Reads a Firestore document via the emulator admin REST API.
/// Bypasses security rules — use this for test assertions when the current
/// signed-in user may not have read access (e.g. reading another user's pool
/// entry, or a room whose users array is empty after padding).
/// [path] is 'collection/docId', e.g. 'rooms/XYZ12' or 'waiting_pool/uid'.
Future<Map<String, dynamic>?> adminFirestoreDoc(String path) async {
  final host = _emulatorHost;
  final uri = Uri.parse(
    'http://$host:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/$path',
  );
  final response = await http.get(
    uri,
    headers: {'Authorization': 'Bearer owner'},
  );
  if (response.statusCode == 404) return null;
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final fields = body['fields'] as Map<String, dynamic>?;
  return fields == null ? {} : _decodeFirestoreFields(fields);
}

Map<String, dynamic> _decodeFirestoreFields(Map<String, dynamic> f) =>
    f.map((k, v) => MapEntry(k, _decodeFirestoreValue(v)));

dynamic _decodeFirestoreValue(dynamic v) {
  if (v is! Map) return v;
  final m = (v as Map<Object?, Object?>).cast<String, dynamic>();
  if (m.containsKey('stringValue')) return m['stringValue'];
  if (m.containsKey('integerValue')) {
    return int.parse(m['integerValue'].toString());
  }
  if (m.containsKey('doubleValue')) return (m['doubleValue'] as num).toDouble();
  if (m.containsKey('booleanValue')) return m['booleanValue'] as bool;
  if (m.containsKey('nullValue')) return null;
  if (m.containsKey('timestampValue')) return m['timestampValue'];
  if (m.containsKey('arrayValue')) {
    final vals =
        ((m['arrayValue'] as Map<String, dynamic>?) ?? {})['values'] as List? ??
        [];
    return vals.map(_decodeFirestoreValue).toList();
  }
  if (m.containsKey('mapValue')) {
    final mapFields =
        ((m['mapValue'] as Map?)?.cast<String, dynamic>() ?? {})['fields'];
    if (mapFields == null) return {};
    return _decodeFirestoreFields(Map<String, dynamic>.from(mapFields as Map));
  }
  return m;
}

/// Polls [path] via admin read (bypasses security rules) until [predicate]
/// passes or [timeout] elapses. Use when polling a document owned by a user
/// that is not the currently signed-in user.
Future<Map<String, dynamic>?> waitUntilAdminDocMatches(
  String path,
  bool Function(Map<String, dynamic>?) predicate, {
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final doc = await adminFirestoreDoc(path);
    if (predicate(doc)) return doc;
    await Future.delayed(interval);
  }
  return adminFirestoreDoc(path);
}

/// Creates a custom room and fills it to exactly [targetSize] members via
/// createCustomRoom + joinRoomById. Bypasses joinGroupRoom priority/random
/// logic — gives precise control over room state for test setup.
/// After returning, the current auth user is the last member added.
Future<String> buildRoom(int targetSize) async {
  assert(targetSize >= 1 && targetSize <= 5);
  await signOut();
  await signInAnon();
  final res = await callFn('createCustomRoom');
  final roomId = res['roomId'] as String;
  for (int i = 1; i < targetSize; i++) {
    await signOut();
    await signInAnon();
    await callFn('joinRoomById', {'roomId': roomId});
  }
  return roomId;
}
