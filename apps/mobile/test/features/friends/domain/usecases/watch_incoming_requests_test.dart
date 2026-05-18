import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/domain/usecases/watch_incoming_requests.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchIncomingRequests usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchIncomingRequests(repo);
  });

  test('returns incoming requests stream from repository', () async {
    repo.requests = [
      FriendRequest(
        id: 'req-1',
        fromUid: 'u1',
        fromDisplayName: 'Alice',
        toUid: 'u2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2024),
      ),
    ];
    final result = await usecase().first;
    expect(result, hasLength(1));
    expect(result[0].id, 'req-1');
    expect(result[0].fromDisplayName, 'Alice');
  });

  test('returns empty list when no pending requests', () async {
    final result = await usecase().first;
    expect(result, isEmpty);
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('permission denied');
    expect(usecase().first, throwsA(isA<Exception>()));
  });
}
