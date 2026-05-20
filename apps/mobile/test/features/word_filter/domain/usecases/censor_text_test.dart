import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/word_filter/domain/usecases/censor_text.dart';

import '../shared_fakes.dart';

void main() {
  late FakeWordFilterRepository fake;
  late CensorText usecase;

  setUp(() {
    fake = FakeWordFilterRepository(returnValue: '***');
    usecase = CensorText(fake);
  });

  group('CensorText', () {
    test('forwards text to repository and returns result', () async {
      final result = await usecase('badword');
      expect(result, '***');
      expect(fake.callCount, 1);
      expect(fake.lastArg, 'badword');
    });

    test('returns original when repository returns it unchanged', () async {
      final clean = FakeWordFilterRepository(returnValue: 'hello');
      final uc = CensorText(clean);
      final result = await uc('hello');
      expect(result, 'hello');
    });

    test('propagates exception from repository', () async {
      final throwing = FakeWordFilterRepository(shouldThrow: true);
      final uc = CensorText(throwing);
      expect(() async => uc('text'), throwsA(isA<Exception>()));
    });
  });
}
