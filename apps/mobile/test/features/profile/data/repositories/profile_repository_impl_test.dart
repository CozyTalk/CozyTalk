import 'package:flutter_test/flutter_test.dart';
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

const _model = ProfileUserModel(
  uid: 'uid-1',
  displayName: 'Alice',
  interest: 'coding',
  thoughts: 'happy',
);

void main() {
  late _FakeProfileDatasource datasource;
  late ProfileRepositoryImpl repository;

  setUp(() {
    datasource = _FakeProfileDatasource();
    repository = ProfileRepositoryImpl(datasource);
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

      test('propagates datasource exception', () {
        datasource.error = Exception('not found');
        expect(() => repository.getProfile('uid-1'), throwsA(isA<Exception>()));
      });
    });

    group('updateDisplayName', () {
      test('calls datasource with uid and displayName', () async {
        await repository.updateDisplayName('uid-1', 'Bob');
        expect(datasource.updateDisplayNameCount, 1);
        expect(datasource.lastUid, 'uid-1');
        expect(datasource.lastDisplayName, 'Bob');
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
