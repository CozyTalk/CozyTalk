import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/usecases/update_interest.dart';
import '../shared_fakes.dart';

void main() {
  late FakeProfileRepository repo;
  late UpdateInterest usecase;

  setUp(() {
    repo = FakeProfileRepository();
    usecase = UpdateInterest(repo);
  });

  group('UpdateInterest', () {
    test('passes uid and interest to repository', () async {
      await usecase('u1', 'music and coding');
      expect(repo.updateInterestCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastInterest, 'music and coding');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('permission denied');
      expect(
        () => usecase('u1', 'music'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
