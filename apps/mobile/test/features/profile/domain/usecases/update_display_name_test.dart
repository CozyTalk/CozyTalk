import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/usecases/update_display_name.dart';
import '../shared_fakes.dart';

void main() {
  late FakeProfileRepository repo;
  late UpdateDisplayName usecase;

  setUp(() {
    repo = FakeProfileRepository();
    usecase = UpdateDisplayName(repo);
  });

  group('UpdateDisplayName', () {
    test('passes uid and displayName to repository', () async {
      await usecase('u1', 'Alice');
      expect(repo.updateDisplayNameCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastDisplayName, 'Alice');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('permission denied');
      expect(() => usecase('u1', 'Alice'), throwsA(isA<Exception>()));
    });
  });
}
