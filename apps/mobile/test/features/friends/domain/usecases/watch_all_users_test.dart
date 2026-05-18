import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/usecases/watch_all_users.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchAllUsers usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchAllUsers(repo);
  });

  test('returns stream from repository', () async {
    repo.allUsers = [
      const AppUser(uid: 'u1', displayName: 'Alice'),
      const AppUser(uid: 'u2', displayName: 'Bob'),
    ];
    final result = await usecase().first;
    expect(result, hasLength(2));
    expect(result[0].uid, 'u1');
    expect(result[1].uid, 'u2');
  });

  test('returns empty list when repository has no users', () async {
    final result = await usecase().first;
    expect(result, isEmpty);
  });

  test('propagates repository stream errors', () {
    repo.error = Exception('firestore unavailable');
    expect(usecase().first, throwsA(isA<Exception>()));
  });
}
