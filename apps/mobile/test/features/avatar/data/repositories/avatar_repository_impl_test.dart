import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/data/datasources/avatar_cache_datasource.dart';
import 'package:mobile/features/avatar/data/datasources/avatar_datasource.dart';
import 'package:mobile/features/avatar/data/models/avatar_decoration_model.dart';
import 'package:mobile/features/avatar/data/repositories/avatar_repository_impl.dart';

class _FakeAvatarDatasource implements AvatarDatasource {
  AvatarDecorationModel? returnModel;
  Exception? error;

  int getDecorationCount = 0;
  int updateHatCount = 0;
  int updateMoodCount = 0;
  int updateDecorationCount = 0;

  String? lastUid;
  String? lastHatKey;
  String? lastMoodKey;

  @override
  Future<AvatarDecorationModel?> getDecoration(String uid) async {
    getDecorationCount++;
    lastUid = uid;
    if (error != null) throw error!;
    return returnModel;
  }

  @override
  Future<void> updateHat(String uid, String? hatKey) async {
    updateHatCount++;
    lastUid = uid;
    lastHatKey = hatKey;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateMood(String uid, String? moodKey) async {
    updateMoodCount++;
    lastUid = uid;
    lastMoodKey = moodKey;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateDecoration(
    String uid,
    String? hatKey,
    String? moodKey,
  ) async {
    updateDecorationCount++;
    lastUid = uid;
    lastHatKey = hatKey;
    lastMoodKey = moodKey;
    if (error != null) throw error!;
  }
}

class _FakeAvatarCacheDatasource implements AvatarCacheDatasource {
  AvatarDecorationModel? stored;
  Exception? writeError;

  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<AvatarDecorationModel?> read(String uid) async {
    readCount++;
    return stored;
  }

  @override
  Future<void> write(String uid, AvatarDecorationModel model) async {
    writeCount++;
    if (writeError != null) throw writeError!;
    stored = model;
  }

  @override
  Future<void> clear(String uid) async {
    clearCount++;
    stored = null;
  }
}

void main() {
  late _FakeAvatarDatasource datasource;
  late _FakeAvatarCacheDatasource cacheDs;
  late AvatarRepositoryImpl repository;

  setUp(() {
    datasource = _FakeAvatarDatasource();
    cacheDs = _FakeAvatarCacheDatasource();
    repository = AvatarRepositoryImpl(datasource, cacheDs);
  });

  group('AvatarRepositoryImpl', () {
    group('getDecoration', () {
      test('calls datasource with uid', () async {
        await repository.getDecoration('uid-1');
        expect(datasource.getDecorationCount, 1);
        expect(datasource.lastUid, 'uid-1');
      });

      test('converts non-null model to entity', () async {
        datasource.returnModel = const AvatarDecorationModel(
          hatKey: 'Crown',
          moodKey: 'Happy',
        );
        final entity = await repository.getDecoration('uid-1');
        expect(entity?.hatKey, 'Crown');
        expect(entity?.moodKey, 'Happy');
      });

      test('returns null when datasource returns null', () async {
        datasource.returnModel = null;
        final entity = await repository.getDecoration('uid-1');
        expect(entity, isNull);
      });

      test('writes to cache when datasource returns non-null model', () async {
        datasource.returnModel = const AvatarDecorationModel(hatKey: 'Cap');
        await repository.getDecoration('uid-1');
        expect(cacheDs.writeCount, 1);
      });

      test('does NOT write to cache when datasource returns null', () async {
        datasource.returnModel = null;
        await repository.getDecoration('uid-1');
        expect(cacheDs.writeCount, 0);
      });

      test('cache write error is swallowed — does not throw', () async {
        datasource.returnModel = const AvatarDecorationModel(moodKey: 'Sad');
        cacheDs.writeError = Exception('storage full');
        final entity = await repository.getDecoration('uid-1');
        expect(entity?.moodKey, 'Sad');
      });

      test('datasource throws, cache hit: returns cached entity', () async {
        datasource.error = Exception('network error');
        cacheDs.stored = const AvatarDecorationModel(
          hatKey: 'Beanie',
          moodKey: 'Grumpy',
        );
        final entity = await repository.getDecoration('uid-1');
        expect(entity?.hatKey, 'Beanie');
        expect(entity?.moodKey, 'Grumpy');
      });

      test(
        'datasource throws, cache miss: returns null (not rethrow)',
        () async {
          datasource.error = Exception('network error');
          cacheDs.stored = null;
          final entity = await repository.getDecoration('uid-1');
          expect(entity, isNull);
        },
      );
    });

    group('getCachedDecoration', () {
      test('returns entity when cache has data', () async {
        cacheDs.stored = const AvatarDecorationModel(
          hatKey: 'Crown',
          moodKey: 'Happy',
        );
        final entity = await repository.getCachedDecoration('uid-1');
        expect(entity?.hatKey, 'Crown');
        expect(cacheDs.readCount, 1);
      });

      test('returns null when cache empty', () async {
        cacheDs.stored = null;
        final result = await repository.getCachedDecoration('uid-1');
        expect(result, isNull);
      });
    });

    group('updateHat', () {
      test('calls datasource with uid and hatKey', () async {
        await repository.updateHat('uid-1', 'Beanie');
        expect(datasource.updateHatCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastHatKey, 'Beanie');
      });

      test('does not write cache when no entry exists', () async {
        await repository.updateHat('uid-1', 'Beanie');
        expect(cacheDs.writeCount, 0);
      });

      test('updates cached hatKey when entry exists', () async {
        cacheDs.stored = const AvatarDecorationModel(
          hatKey: 'OldCap',
          moodKey: 'Happy',
        );
        await repository.updateHat('uid-1', 'NewCap');
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.hatKey, 'NewCap');
        expect(cacheDs.stored?.moodKey, 'Happy');
      });

      test('clears cached hatKey when null', () async {
        cacheDs.stored = const AvatarDecorationModel(hatKey: 'OldCap');
        await repository.updateHat('uid-1', null);
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.hatKey, isNull);
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('permission denied');
        expect(
          () => repository.updateHat('uid-1', 'Cap'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateMood', () {
      test('calls datasource with uid and moodKey', () async {
        await repository.updateMood('uid-1', 'Grumpy');
        expect(datasource.updateMoodCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastMoodKey, 'Grumpy');
      });

      test('does not write cache when no entry exists', () async {
        await repository.updateMood('uid-1', 'Grumpy');
        expect(cacheDs.writeCount, 0);
      });

      test('updates cached moodKey when entry exists', () async {
        cacheDs.stored = const AvatarDecorationModel(
          hatKey: 'Crown',
          moodKey: 'OldMood',
        );
        await repository.updateMood('uid-1', 'NewMood');
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.moodKey, 'NewMood');
        expect(cacheDs.stored?.hatKey, 'Crown');
      });

      test('clears cached moodKey when null', () async {
        cacheDs.stored = const AvatarDecorationModel(moodKey: 'OldMood');
        await repository.updateMood('uid-1', null);
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.moodKey, isNull);
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('permission denied');
        expect(
          () => repository.updateMood('uid-1', 'Sad'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateDecoration', () {
      test('calls datasource with uid, hatKey, and moodKey', () async {
        await repository.updateDecoration('uid-1', 'Crown', 'Happy');
        expect(datasource.updateDecorationCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastHatKey, 'Crown');
        expect(datasource.lastMoodKey, 'Happy');
      });

      test('does not write cache when no entry exists', () async {
        await repository.updateDecoration('uid-1', 'Crown', 'Happy');
        expect(cacheDs.writeCount, 0);
      });

      test('updates both cached fields when entry exists', () async {
        cacheDs.stored = const AvatarDecorationModel(
          hatKey: 'OldHat',
          moodKey: 'OldMood',
        );
        await repository.updateDecoration('uid-1', 'NewHat', 'NewMood');
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.hatKey, 'NewHat');
        expect(cacheDs.stored?.moodKey, 'NewMood');
      });

      test('clears both cached fields when null', () async {
        cacheDs.stored = const AvatarDecorationModel(
          hatKey: 'Crown',
          moodKey: 'Happy',
        );
        await repository.updateDecoration('uid-1', null, null);
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.hatKey, isNull);
        expect(cacheDs.stored?.moodKey, isNull);
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('permission denied');
        expect(
          () => repository.updateDecoration('uid-1', 'Crown', 'Happy'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
