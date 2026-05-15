import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/usecases/sign_out.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late SignOut usecase;

  setUp(() {
    repo = FakeAuthRepository();
    usecase = SignOut(repo);
  });

  group('SignOut', () {
    test('delegates to repository', () async {
      await usecase();
      expect(repo.signOutCount, 1);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('sign out failed');
      expect(() => usecase(), throwsA(isA<Exception>()));
    });
  });
}
