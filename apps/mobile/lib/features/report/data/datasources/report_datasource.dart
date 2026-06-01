import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

abstract class ReportDatasource {
  Future<void> submitReport({
    required String sessionId,
    required String reportedUserId,
    required String reportType,
    required String reason,
    String? contextText,
    List<String> contextImagePaths,
  });
}

class ReportDatasourceImpl implements ReportDatasource {
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  const ReportDatasourceImpl(this._storage, this._functions, this._auth);

  @override
  Future<void> submitReport({
    required String sessionId,
    required String reportedUserId,
    required String reportType,
    required String reason,
    String? contextText,
    List<String> contextImagePaths = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Not authenticated.');
    }

    final imageUrls = await _uploadImages(sessionId, uid, contextImagePaths);

    await _functions
        .httpsCallable(
          'reportSession',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call({
          'sessionId': sessionId,
          'reportedUserId': reportedUserId,
          'reportType': reportType,
          'reason': reason,
          if (contextText != null) 'contextText': contextText,
          'contextImageUrls': imageUrls,
        });
  }

  Future<List<String>> _uploadImages(
    String sessionId,
    String uid,
    List<String> paths,
  ) async {
    // Firebase Storage requires CORS to be configured on the bucket before
    // browser uploads work. Skip on web until storage.cors.json is applied
    // via: gsutil cors set storage.cors.json gs://cozytalk-5d984.firebasestorage.app
    if (paths.isEmpty || kIsWeb) return const [];
    final urls = <String>[];
    for (final path in paths) {
      final xFile = XFile(path);
      final bytes = await xFile.readAsBytes();
      final mimeType = xFile.mimeType ?? 'image/jpeg';
      final ext = _extFromMime(mimeType);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref(
        'reports/$sessionId/$uid/${timestamp}_image.$ext',
      );
      await ref.putData(bytes, SettableMetadata(contentType: mimeType));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  String _extFromMime(String mimeType) {
    if (mimeType.contains('png')) return 'png';
    if (mimeType.contains('webp')) return 'webp';
    if (mimeType.contains('gif')) return 'gif';
    return 'jpg';
  }
}
