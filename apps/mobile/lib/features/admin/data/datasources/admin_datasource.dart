import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
            uids.add(doc.data()['reporterId'] as String);
            uids.add(doc.data()['reportedUserId'] as String);
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
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (data['outcome'] is Map) {
              data['outcome'] = Map<String, dynamic>.from(
                data['outcome'] as Map,
              );
            }
            return AdminReportModel.fromJson(data).copyWith(
              id: doc.id,
              reporterName: nameMap[data['reporterId']] ?? 'Unknown',
              reportedName: nameMap[data['reportedUserId']] ?? 'Unknown',
              reportedInterest: interestMap[data['reportedUserId']] ?? '',
            );
          }).toList();
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
}
