import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/usecases/update_thoughts.dart';
import '../shared_fakes.dart';

void main() {
  late FakeProfileRepository repo;
  late UpdateThoughts usecase;

  setUp(() {
    repo = FakeProfileRepository();
    usecase = UpdateThoughts(repo);
  });

  group('UpdateThoughts', () {
    test('passes uid and thoughts to repository', () async {
      await usecase('u1', 'feeling creative');
      expect(repo.updateThoughtsCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastThoughts, 'feeling creative');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('permission denied');
      expect(
        () => usecase('u1', 'feeling creative'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
