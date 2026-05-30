import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/usecases/get_users_by_ids.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late GetUsersByIds usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = GetUsersByIds(repo);
  });

  test('returns empty list when called with empty uid list', () async {
    final result = await usecase([]);
    expect(result, isEmpty);
    expect(repo.getUsersByIdsCallCount, 0);
  });

  test('delegates uid list to repository', () async {
    repo.usersById = [
      const AppUser(uid: 'u1', displayName: 'Alice'),
      const AppUser(uid: 'u2', displayName: 'Bob'),
    ];
    final result = await usecase(['u1', 'u2']);
    expect(repo.lastGetUsersByIds, ['u1', 'u2']);
    expect(result, hasLength(2));
  });

  test('returns the AppUser list from repository', () async {
    repo.usersById = [
      const AppUser(uid: 'u3', displayName: 'Carol'),
    ];
    final result = await usecase(['u3']);
    expect(result[0].uid, 'u3');
    expect(result[0].displayName, 'Carol');
  });

  test('propagates repository exception', () {
    repo.error = Exception('lookup failed');
    expect(() => usecase(['u1']), throwsA(isA<Exception>()));
  });
}
