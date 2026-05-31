import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/admin_blocked_entry.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../models/admin_report_model.dart';
import '../models/admin_user_model.dart';

abstract class AdminDatasource {
  Future<AdminDashboardStats> getDashboardStats();
  Stream<List<AdminReportModel>> watchReports();
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  });
  Future<String> getChatLogUrl(String reportId);
  Stream<List<AdminUserModel>> watchUsers();
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  });
  Future<void> unbanUser(String uid);
  void dispose();
  Future<List<AdminBlockedEntry>> getBlockedUsers(String uid);
}

class AdminDatasourceImpl implements AdminDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  Set<String> _onlineUids = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _roomsSub;

  AdminDatasourceImpl(this._firestore, this._functions) {
    _roomsSub = _firestore
        .collection('rooms')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
          _onlineUids = {
            for (final doc in snap.docs)
              ...(doc.data()['users'] as List? ?? []).cast<String>(),
          };
        });
  }

  @override
  void dispose() => _roomsSub?.cancel();

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    final result = await _functions.httpsCallable('adminGetDashboard').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return AdminDashboardStats(
      pendingReports: data['pendingReports'] as int,
      onlineUsers: data['onlineUsers'] as int,
      bannedUsers: data['bannedUsers'] as int,
    );
  }

  @override
  Stream<List<AdminReportModel>> watchReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final uids = <String>{};
          for (final doc in snap.docs) {
            final d = doc.data();
            final rid = d['reporterId'];
            final ruid = d['reportedUserId'];
            if (rid is String && rid.isNotEmpty) uids.add(rid);
            if (ruid is String && ruid.isNotEmpty) uids.add(ruid);
          }
          final nameMap = <String, String>{};
          final interestMap = <String, String>{};
          if (uids.isNotEmpty) {
            final userDocs = await Future.wait(
              uids.map((uid) => _firestore.collection('users').doc(uid).get()),
            );
            for (final d in userDocs) {
              if (d.exists) {
                nameMap[d.id] =
                    d.data()!['displayName'] as String? ?? 'Unknown';
                interestMap[d.id] = d.data()!['interest'] as String? ?? '';
              }
            }
          }
          final results = <AdminReportModel>[];
          Object? firstParseError;
          for (final doc in snap.docs) {
            try {
              final data = Map<String, dynamic>.from(doc.data());
              data['reporterId'] ??= '';
              data['reportedUserId'] ??= '';
              data['sessionId'] ??= '';
              data['reportType'] ??= 'other';
              data['reason'] ??= '';
              if (data['contextImageUrls'] is! List) {
                data['contextImageUrls'] = <String>[];
              }
              if (data['outcome'] is Map) {
                data['outcome'] = Map<String, dynamic>.from(
                  data['outcome'] as Map,
                );
              }
              results.add(
                AdminReportModel.fromJson(data).copyWith(
                  id: doc.id,
                  reporterName: nameMap[data['reporterId']] ?? 'Unknown',
                  reportedName: nameMap[data['reportedUserId']] ?? 'Unknown',
                  reportedInterest: interestMap[data['reportedUserId']] ?? '',
                ),
              );
            } catch (e) {
              firstParseError ??= e;
            }
          }
          if (results.isEmpty && firstParseError != null) {
            // ignore: only_throw_errors
            throw firstParseError;
          }
          return results;
        });
  }

  @override
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    await _functions.httpsCallable('adminResolveReport').call({
      'reportId': reportId,
      'action': action,
      'note': note,
    });
  }

  @override
  Future<String> getChatLogUrl(String reportId) async {
    final result = await _functions.httpsCallable('adminGetChatLog').call({
      'reportId': reportId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to get chat log URL');
    }
    return data['signedUrl'] as String;
  }

  @override
  Stream<List<AdminUserModel>> watchUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (data['banHistory'] is List) {
              data['banHistory'] = (data['banHistory'] as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            }
            return AdminUserModel.fromJson(
              data,
            ).copyWith(uid: doc.id, online: _onlineUids.contains(doc.id));
          }).toList();
        });
  }

  @override
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) async {
    await _functions.httpsCallable('adminBanUser').call({
      'uid': uid,
      'reason': reason,
      'duration': duration,
      'note': note,
      'reportId': reportId,
    });
  }

  @override
  Future<void> unbanUser(String uid) async {
    await _functions.httpsCallable('adminUnbanUser').call({'uid': uid});
  }

  @override
  Future<List<AdminBlockedEntry>> getBlockedUsers(String uid) async {
    final result = await _functions
        .httpsCallable('adminGetBlockedUsers')
        .call<Map>({'uid': uid});
    final data = Map<String, dynamic>.from(result.data);
    final list = (data['blockedUsers'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return list.map((e) {
      final raw = e['blockedAt'] as String?;
      return AdminBlockedEntry(
        uid: e['uid'] as String,
        displayName: e['displayName'] as String?,
        blockedAt: raw != null ? DateTime.tryParse(raw) : null,
      );
    }).toList();
  }
}
