import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/room.dart';

part 'room_model.freezed.dart';
part 'room_model.g.dart';

@freezed
abstract class RoomModel with _$RoomModel {
  const factory RoomModel({
    required String roomId,
    required String roomType,
    required String mode,
    required String status,
    required int maxUsers,
    required int memberCount,
    required List<String> users,
    required bool isLocked,
    required int createdAt,
    int? paddingUntil,
    List<double>? roomInterestVector,
  }) = _RoomModel;

  factory RoomModel.fromJson(Map<String, dynamic> json) =>
      _$RoomModelFromJson(json);

  /// Constructs a [RoomModel] from a Firestore document snapshot,
  /// converting Timestamp fields to milliseconds.
  factory RoomModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data()!);

    final createdTs = data['createdAt'];
    data['createdAt'] = createdTs is Timestamp
        ? createdTs.millisecondsSinceEpoch
        : 0;

    final paddingTs = data['paddingUntil'];
    data['paddingUntil'] = paddingTs is Timestamp
        ? paddingTs.millisecondsSinceEpoch
        : null;

    data.putIfAbsent('users', () => <String>[]);
    data.putIfAbsent('isLocked', () => false);
    data.putIfAbsent('memberCount', () => 0);
    data.putIfAbsent('maxUsers', () => 5);

    final rvRaw = data['roomInterestVector'];
    if (rvRaw is List) {
      data['roomInterestVector'] = List<double>.from(
        rvRaw.map((e) => (e as num).toDouble()),
      );
    } else {
      data.remove('roomInterestVector');
    }

    return RoomModel.fromJson(data);
  }
}

RoomStatus _parseRoomStatus(String s) {
  switch (s) {
    case 'padding':
      return RoomStatus.padding;
    case 'expired':
      return RoomStatus.expired;
    default:
      return RoomStatus.active;
  }
}

extension RoomModelX on RoomModel {
  Room toEntity() {
    return Room(
      roomId: roomId,
      roomType: roomType == 'custom' ? RoomType.custom : RoomType.public,
      mode: mode == '1v1' ? RoomMode.oneToOne : RoomMode.group,
      status: _parseRoomStatus(status),
      maxUsers: maxUsers,
      memberCount: memberCount,
      users: users,
      isLocked: isLocked,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      paddingUntil: paddingUntil != null
          ? DateTime.fromMillisecondsSinceEpoch(paddingUntil!)
          : null,
      roomInterestVector: roomInterestVector,
    );
  }
}
