import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late _FakeAvatarDatasource datasource;
  late AvatarRepositoryImpl repository;

  setUp(() {
    datasource = _FakeAvatarDatasource();
    repository = AvatarRepositoryImpl(datasource);
  });

  group('AvatarRepositoryImpl', () {
    group('getDecoration', () {
      test('calls datasource with uid', () async {
        await repository.getDecoration('uid-1');
        expect(datasource.getDecorationCount, 1);
        expect(datasource.lastUid, 'uid-1');
      });

      test('converts model to entity', () async {
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

      test('propagates datasource exception', () {
        datasource.error = Exception('not found');
        expect(
          () => repository.getDecoration('uid-1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateHat', () {
      test('calls datasource with uid and hatKey', () async {
        await repository.updateHat('uid-1', 'Beanie');
        expect(datasource.updateHatCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastHatKey, 'Beanie');
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
