import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/datasources/profile_cache_datasource.dart';
import 'package:mobile/features/profile/data/models/profile_user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _model = ProfileUserModel(
  uid: 'uid-1',
  displayName: 'Alice',
  interest: 'coding',
  thoughts: 'happy',
);

void main() {
  late ProfileCacheDatasourceImpl cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cache = ProfileCacheDatasourceImpl(prefs);
  });

  group('ProfileCacheDatasource', () {
    test('read returns null when key missing', () async {
      final result = await cache.read('uid-1');
      expect(result, isNull);
    });

    test('write then read returns correct model', () async {
      await cache.write('uid-1', _model);
      final result = await cache.read('uid-1');
      expect(result?.uid, 'uid-1');
      expect(result?.displayName, 'Alice');
      expect(result?.interest, 'coding');
      expect(result?.thoughts, 'happy');
    });

    test('write then clear makes read return null', () async {
      await cache.write('uid-1', _model);
      await cache.clear('uid-1');
      final result = await cache.read('uid-1');
      expect(result, isNull);
    });

    test('uid isolation: write uid-A, read uid-B returns null', () async {
      await cache.write('uid-A', _model);
      final result = await cache.read('uid-B');
      expect(result, isNull);
    });

    test('read handles malformed JSON without throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_cache_uid-1', 'not-valid-json');
      final result = await cache.read('uid-1');
      expect(result, isNull);
    });
  });
}
