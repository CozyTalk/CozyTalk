import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/datasources/profile_cache_datasource.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/models/profile_user_model.dart';
import 'package:mobile/features/profile/data/repositories/profile_repository_impl.dart';

class _FakeProfileDatasource implements ProfileDatasource {
  ProfileUserModel? returnModel;
  Exception? error;

  int getProfileCount = 0;
  int updateDisplayNameCount = 0;
  int updateInterestCount = 0;
  int updateThoughtsCount = 0;

  String? lastUid;
  String? lastDisplayName;
  String? lastInterest;
  String? lastThoughts;

  @override
  Future<ProfileUserModel> getProfile(String uid) async {
    getProfileCount++;
    lastUid = uid;
    if (error != null) throw error!;
    return returnModel!;
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    updateDisplayNameCount++;
    lastUid = uid;
    lastDisplayName = displayName;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateInterest(String uid, String interest) async {
    updateInterestCount++;
    lastUid = uid;
    lastInterest = interest;
    if (error != null) throw error!;
  }

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {
    updateThoughtsCount++;
    lastUid = uid;
    lastThoughts = thoughts;
    if (error != null) throw error!;
  }
}

class _FakeProfileCacheDatasource implements ProfileCacheDatasource {
  ProfileUserModel? stored;
  Exception? readError;
  Exception? writeError;

  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  String? lastUid;

  @override
  Future<ProfileUserModel?> read(String uid) async {
    readCount++;
    lastUid = uid;
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<void> write(String uid, ProfileUserModel model) async {
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

const _model = ProfileUserModel(
  uid: 'uid-1',
  displayName: 'Alice',
  interest: 'coding',
  thoughts: 'happy',
);

const _cachedModel = ProfileUserModel(
  uid: 'uid-1',
  displayName: 'CachedAlice',
  interest: 'cached-coding',
  thoughts: 'cached-happy',
);

void main() {
  late _FakeProfileDatasource datasource;
  late _FakeProfileCacheDatasource cacheDs;
  late ProfileRepositoryImpl repository;

  setUp(() {
    datasource = _FakeProfileDatasource();
    cacheDs = _FakeProfileCacheDatasource();
    repository = ProfileRepositoryImpl(datasource, cacheDs);
  });

  group('ProfileRepositoryImpl', () {
    group('getProfile', () {
      test('calls datasource with uid', () async {
        datasource.returnModel = _model;
        await repository.getProfile('uid-1');
        expect(datasource.getProfileCount, 1);
        expect(datasource.lastUid, 'uid-1');
      });

      test('converts model to entity', () async {
        datasource.returnModel = _model;
        final entity = await repository.getProfile('uid-1');
        expect(entity.uid, 'uid-1');
        expect(entity.displayName, 'Alice');
        expect(entity.interest, 'coding');
        expect(entity.thoughts, 'happy');
      });

      test('writes to cache on success', () async {
        datasource.returnModel = _model;
        await repository.getProfile('uid-1');
        expect(cacheDs.writeCount, 1);
      });

      test('cache write error is swallowed — does not throw', () async {
        datasource.returnModel = _model;
        cacheDs.writeError = Exception('storage full');
        final entity = await repository.getProfile('uid-1');
        expect(entity.uid, 'uid-1');
      });

      test('datasource throws, cache hit: returns cached entity', () async {
        datasource.error = Exception('network error');
        cacheDs.stored = _cachedModel;
        final entity = await repository.getProfile('uid-1');
        expect(entity.displayName, 'CachedAlice');
      });

      test('datasource throws, cache miss: rethrows original exception', () {
        datasource.error = Exception('network error');
        cacheDs.stored = null;
        expect(() => repository.getProfile('uid-1'), throwsA(isA<Exception>()));
      });
    });

    group('getCachedProfile', () {
      test('returns entity when cache has data', () async {
        cacheDs.stored = _cachedModel;
        final entity = await repository.getCachedProfile('uid-1');
        expect(entity?.displayName, 'CachedAlice');
        expect(cacheDs.readCount, 1);
        expect(cacheDs.lastUid, 'uid-1');
      });

      test('returns null when cache empty', () async {
        cacheDs.stored = null;
        final result = await repository.getCachedProfile('uid-1');
        expect(result, isNull);
      });
    });

    group('updateDisplayName', () {
      test('calls datasource with uid and displayName', () async {
        await repository.updateDisplayName('uid-1', 'Bob');
        expect(datasource.updateDisplayNameCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastDisplayName, 'Bob');
      });

      test('does not write cache when no entry exists', () async {
        await repository.updateDisplayName('uid-1', 'Bob');
        expect(cacheDs.writeCount, 0);
      });

      test('updates cached displayName when entry exists', () async {
        cacheDs.stored = const ProfileUserModel(
          uid: 'uid-1',
          displayName: 'OldBob',
          interest: 'coding',
          thoughts: 'happy',
        );
        await repository.updateDisplayName('uid-1', 'NewBob');
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.displayName, 'NewBob');
        expect(cacheDs.stored?.interest, 'coding');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('permission denied');
        expect(
          () => repository.updateDisplayName('uid-1', 'Bob'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateInterest', () {
      test('calls datasource with uid and interest', () async {
        await repository.updateInterest('uid-1', 'music');
        expect(datasource.updateInterestCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastInterest, 'music');
      });

      test('does not write cache when no entry exists', () async {
        await repository.updateInterest('uid-1', 'music');
        expect(cacheDs.writeCount, 0);
      });

      test('updates cached interest when entry exists', () async {
        cacheDs.stored = const ProfileUserModel(
          uid: 'uid-1',
          displayName: 'Alice',
          interest: 'oldInterest',
        );
        await repository.updateInterest('uid-1', 'newInterest');
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.interest, 'newInterest');
        expect(cacheDs.stored?.displayName, 'Alice');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('permission denied');
        expect(
          () => repository.updateInterest('uid-1', 'music'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateThoughts', () {
      test('calls datasource with uid and thoughts', () async {
        await repository.updateThoughts('uid-1', 'inspired');
        expect(datasource.updateThoughtsCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastThoughts, 'inspired');
      });

      test('does not write cache when no entry exists', () async {
        await repository.updateThoughts('uid-1', 'inspired');
        expect(cacheDs.writeCount, 0);
      });

      test('updates cached thoughts when entry exists', () async {
        cacheDs.stored = const ProfileUserModel(
          uid: 'uid-1',
          displayName: 'Alice',
          thoughts: 'oldThought',
        );
        await repository.updateThoughts('uid-1', 'newThought');
        expect(cacheDs.writeCount, 1);
        expect(cacheDs.stored?.thoughts, 'newThought');
        expect(cacheDs.stored?.displayName, 'Alice');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('permission denied');
        expect(
          () => repository.updateThoughts('uid-1', 'inspired'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
