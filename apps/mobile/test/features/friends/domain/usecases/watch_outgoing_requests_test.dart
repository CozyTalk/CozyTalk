import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/domain/usecases/watch_outgoing_requests.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchOutgoingRequests usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchOutgoingRequests(repo);
  });

  test('returns outgoing requests stream from repository', () async {
    repo.outgoingRequests = [
      FriendRequest(
        id: 'req-1',
        fromUid: 'me',
        fromDisplayName: 'Me',
        toUid: 'u2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2024),
      ),
    ];
    final result = await usecase().first;
    expect(result, hasLength(1));
    expect(result[0].id, 'req-1');
    expect(result[0].toUid, 'u2');
  });

  test('returns empty list when no outgoing requests', () async {
    final result = await usecase().first;
    expect(result, isEmpty);
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('permission denied');
    expect(usecase().first, throwsA(isA<Exception>()));
  });
}
