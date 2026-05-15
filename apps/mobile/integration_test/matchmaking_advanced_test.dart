import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'firebase_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setupFirebaseForTest);
  setUp(() async {
    await signOut();
    await resetEmulatorData();
  });

  // ── Group Room: Priority Selection ─────────────────────────────────────────

  test('priority: 1-member room chosen over 2-member room', () async {
    final roomA = await buildRoom(2);
    final roomB = await buildRoom(1);

    await signOut();
    await signInAnon();
    final res = await callFn('joinGroupRoom');

    expect(res['roomId'], equals(roomB));

    final docA = await adminFirestoreDoc('rooms/$roomA');
    expect(docA!['memberCount'], equals(2));
  });

  test(
    'priority: 1-member room chosen when competing with 3-member and 4-member rooms',
    () async {
      final roomA = await buildRoom(4);
      final roomB = await buildRoom(3);
      final roomC = await buildRoom(1);

      await signOut();
      await signInAnon();
      final res = await callFn('joinGroupRoom');

      expect(res['roomId'], equals(roomC));

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$roomA'),
        adminFirestoreDoc('rooms/$roomB'),
      ]);
      expect(docs[0]!['memberCount'], equals(4));
      expect(docs[1]!['memberCount'], equals(3));
    },
  );

  test(
    'priority: 1-member room wins from mixed field (1/5, 2/5, 3/5, 4/5)',
    () async {
      final room4 = await buildRoom(4);
      final room2 = await buildRoom(2);
      final room3 = await buildRoom(3);
      final room1 = await buildRoom(1);

      await signOut();
      await signInAnon();
      final res = await callFn('joinGroupRoom');

      expect(res['roomId'], equals(room1));

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$room4'),
        adminFirestoreDoc('rooms/$room2'),
        adminFirestoreDoc('rooms/$room3'),
      ]);
      expect(docs[0]!['memberCount'], equals(4));
      expect(docs[1]!['memberCount'], equals(2));
      expect(docs[2]!['memberCount'], equals(3));
    },
  );

  test(
    'priority distribution: 12 consecutive joiners spread randomly across 3 one-member rooms',
    () async {
      final roomX = await buildRoom(1);
      final roomY = await buildRoom(1);
      final roomZ = await buildRoom(1);
      final knownRooms = {roomX, roomY, roomZ};
      final counts = <String, int>{roomX: 0, roomY: 0, roomZ: 0};

      for (int i = 0; i < 12; i++) {
        await signOut();
        await signInAnon();
        final res = await callFn('joinGroupRoom');
        final joined = res['roomId'] as String;

        expect(knownRooms, contains(joined));
        counts[joined] = (counts[joined] ?? 0) + 1;
        await callFn('leaveRoom', {'roomId': joined});
      }

      final distinct = counts.values.where((c) => c > 0).length;
      expect(distinct, greaterThanOrEqualTo(2));
      expect(counts.values.reduce(max), lessThan(9));
    },
  );

  test(
    'priority: after first 1-member room fills, next joiner picks the remaining 1-member room',
    () async {
      final roomX = await buildRoom(1);
      final roomY = await buildRoom(1);

      await signOut();
      await signInAnon();
      final resU = await callFn('joinGroupRoom');
      final joinedByU = resU['roomId'] as String;
      expect({roomX, roomY}, contains(joinedByU));
      final remaining = joinedByU == roomX ? roomY : roomX;

      await signOut();
      await signInAnon();
      final resV = await callFn('joinGroupRoom');
      expect(resV['roomId'], equals(remaining));

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$roomX'),
        adminFirestoreDoc('rooms/$roomY'),
      ]);
      expect(docs[0]!['memberCount'], equals(2));
      expect(docs[1]!['memberCount'], equals(2));
    },
  );

  test('priority load test: 20 joiners across 5 one-member rooms', () async {
    final rooms = <String>[];
    for (int i = 0; i < 5; i++) {
      rooms.add(await buildRoom(1));
    }
    final knownRooms = rooms.toSet();
    final counts = <String, int>{for (final r in rooms) r: 0};

    for (int i = 0; i < 20; i++) {
      await signOut();
      await signInAnon();
      final res = await callFn('joinGroupRoom');
      final joined = res['roomId'] as String;

      expect(knownRooms, contains(joined));
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn('leaveRoom', {'roomId': joined});
    }

    final distinct = counts.values.where((c) => c > 0).length;
    expect(distinct, greaterThanOrEqualTo(3));
    expect(counts.values.reduce(max), lessThan(8));
  });

  test(
    'priority concurrent race: two rapid joiners to the same 1-member room',
    () async {
      final roomX = await buildRoom(1);

      await signOut();
      final uidA = await signInAnon();
      final resA = await callFn('joinGroupRoom');
      final joinedA = resA['roomId'] as String;

      await signOut();
      await signInAnon();
      final resB = await callFn('joinGroupRoom');
      final joinedB = resB['roomId'] as String;

      expect(resA['roomId'], isNotNull);
      expect(resB['roomId'], isNotNull);

      if (joinedA == roomX && joinedB == roomX) {
        final doc = await adminFirestoreDoc('rooms/$roomX');
        final users = (doc!['users'] as List).cast<String>();
        expect(users.toSet().length, equals(users.length));
        expect(users, contains(uidA));
      }

      final roomDoc = await adminFirestoreDoc('rooms/$roomX');
      expect(roomDoc!['memberCount'], lessThanOrEqualTo(5));
    },
  );

  // ── Group Room: Secondary Randomness ──────────────────────────────────────

  test(
    'secondary randomness: 15 joiners spread across 3 two-member rooms',
    () async {
      final roomA = await buildRoom(2);
      final roomB = await buildRoom(2);
      final roomC = await buildRoom(2);
      final knownRooms = {roomA, roomB, roomC};
      final counts = <String, int>{roomA: 0, roomB: 0, roomC: 0};

      for (int i = 0; i < 15; i++) {
        await signOut();
        await signInAnon();
        final res = await callFn('joinGroupRoom');
        final joined = res['roomId'] as String;

        expect(knownRooms, contains(joined));
        counts[joined] = (counts[joined] ?? 0) + 1;
        await callFn('leaveRoom', {'roomId': joined});
      }

      final distinct = counts.values.where((c) => c > 0).length;
      expect(distinct, greaterThanOrEqualTo(2));
      expect(counts.values.reduce(max), lessThan(12));
    },
  );

  test(
    'secondary randomness: repeated join-leave by same user does not always hit same room',
    () async {
      await buildRoom(3);
      await buildRoom(3);
      await buildRoom(3);

      final visited = <String>{};

      for (int i = 0; i < 12; i++) {
        await signOut();
        await signInAnon();
        final res = await callFn('joinGroupRoom');
        final joined = res['roomId'] as String;
        visited.add(joined);
        await callFn('leaveRoom', {'roomId': joined});
      }

      expect(visited.length, greaterThanOrEqualTo(2));
    },
  );

  test(
    'secondary randomness: joins distributed across rooms of different sizes (2/5, 3/5, 4/5)',
    () async {
      final roomA = await buildRoom(2);
      final roomB = await buildRoom(3);
      final roomC = await buildRoom(4);
      final knownRooms = {roomA, roomB, roomC};
      final counts = <String, int>{roomA: 0, roomB: 0, roomC: 0};

      for (int i = 0; i < 9; i++) {
        await signOut();
        await signInAnon();
        final res = await callFn('joinGroupRoom');
        final joined = res['roomId'] as String;
        expect(knownRooms, contains(joined));
        counts[joined] = (counts[joined] ?? 0) + 1;
        await callFn('leaveRoom', {'roomId': joined});
      }

      final distinct = counts.values.where((c) => c > 0).length;
      expect(distinct, greaterThanOrEqualTo(2));
    },
  );

  test('secondary: all secondary rooms fill up → new room created', () async {
    final roomA = await buildRoom(4);

    await signOut();
    await signInAnon();
    await callFn('joinRoomById', {'roomId': roomA});
    expect(
      (await adminFirestoreDoc('rooms/$roomA'))!['memberCount'],
      equals(5),
    );

    await signOut();
    await signInAnon();
    final res = await callFn('joinGroupRoom');
    expect(res['isNewRoom'], isTrue);
    expect(res['roomId'], isNot(equals(roomA)));
  });

  // ── Padding: Not Joinable ──────────────────────────────────────────────────

  test(
    'padding: last user leaves → padding → next joiner creates new room',
    () async {
      await signOut();
      await signInAnon();
      final res = await callFn('joinGroupRoom');
      final originalRoomId = res['roomId'] as String;
      await callFn('leaveRoom', {'roomId': originalRoomId});

      final paddingDoc = await adminFirestoreDoc('rooms/$originalRoomId');
      expect(paddingDoc!['status'], equals('padding'));
      expect(paddingDoc['memberCount'], equals(0));

      await signOut();
      await signInAnon();
      final newRes = await callFn('joinGroupRoom');
      expect(newRes['isNewRoom'], isTrue);
      expect(newRes['roomId'], isNot(equals(originalRoomId)));

      final stillPadding = await adminFirestoreDoc('rooms/$originalRoomId');
      expect(stillPadding!['status'], equals('padding'));
    },
  );

  test(
    'padding: joinRoomById on padding room throws failed-precondition',
    () async {
      await signOut();
      await signInAnon();
      final res = await callFn('joinGroupRoom');
      final roomId = res['roomId'] as String;
      await callFn('leaveRoom', {'roomId': roomId});

      expect(
        (await adminFirestoreDoc('rooms/$roomId'))!['status'],
        equals('padding'),
      );

      await signOut();
      await signInAnon();
      try {
        await callFn('joinRoomById', {'roomId': roomId});
        fail('expected exception for padding room');
      } catch (e) {
        expect(e.toString(), contains('failed-precondition'));
      }
    },
  );

  test('padding: expired room via joinRoomById throws an error', () async {
    await signOut();
    await signInAnon();
    final res = await callFn('joinGroupRoom');
    final roomId = res['roomId'] as String;
    await callFn('leaveRoom', {'roomId': roomId});

    await signOut();
    await signInAnon();
    try {
      await callFn('joinRoomById', {'roomId': roomId});
      fail('expected exception for unavailable room');
    } catch (e) {
      expect(
        e.toString(),
        anyOf(contains('failed-precondition'), contains('not-found')),
      );
    }
  });

  test(
    'padding: 1v1 room in padding is not returned by joinGroupRoom',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final v1RoomId = poolDoc!['roomId'] as String;

      await callFn('leaveRoom', {'roomId': v1RoomId});

      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );
      await tryCancelPool();

      await signOut();
      await signInAnon();
      final groupRes = await callFn('joinGroupRoom');
      expect(groupRes['isNewRoom'], isTrue);
      expect(groupRes['roomId'], isNot(equals(v1RoomId)));

      final v1Doc = await adminFirestoreDoc('rooms/$v1RoomId');
      expect(v1Doc!['mode'], equals('1v1'));
      expect(v1Doc['status'], equals('padding'));
    },
  );

  // ── RTDB & Edge Cases ──────────────────────────────────────────────────────

  test('RTDB: membership set for both creator and joiner', () async {
    final uidA = await signInAnon();
    final resA = await callFn('joinGroupRoom');
    final roomId = resA['roomId'] as String;

    await signOut();
    final uidB = await signInAnon();
    await callFn('joinGroupRoom');

    final snapAFut = rtdbGet('rooms/$roomId/members/$uidA');
    final snapBFut = rtdbGet('rooms/$roomId/members/$uidB');
    expect((await snapAFut).value, equals(true));
    expect((await snapBFut).value, equals(true));

    await tryLeaveRoom(roomId);
  });

  test(
    'RTDB: leaveRoom cleans typing and presence paths (not just members)',
    () async {
      await signInAnon();
      final resA = await callFn('joinGroupRoom');
      final roomId = resA['roomId'] as String;

      await signOut();
      final uidB = await signInAnon();
      await callFn('joinGroupRoom');
      await callFn('leaveRoom', {'roomId': roomId});

      final typingFut = rtdbGet('typing/$roomId/$uidB');
      final presenceFut = rtdbGet('presence/$roomId/$uidB');
      final memberFut = rtdbGet('rooms/$roomId/members/$uidB');
      expect((await typingFut).exists, isFalse);
      expect((await presenceFut).exists, isFalse);
      expect((await memberFut).exists, isFalse);

      await tryLeaveRoom(roomId);
    },
  );

  test(
    'full room (5/5): joinGroupRoom creates new room; joinRoomById throws',
    () async {
      final roomA = await buildRoom(4);

      await signOut();
      await signInAnon();
      await callFn('joinRoomById', {'roomId': roomA});
      expect(
        (await adminFirestoreDoc('rooms/$roomA'))!['memberCount'],
        equals(5),
      );

      await signOut();
      await signInAnon();
      final newRes = await callFn('joinGroupRoom');
      expect(newRes['isNewRoom'], isTrue);
      expect(newRes['roomId'], isNot(equals(roomA)));

      try {
        await callFn('joinRoomById', {'roomId': roomA});
        fail('expected exception for full room');
      } catch (e) {
        expect(
          e.toString(),
          anyOf(
            contains('resource-exhausted'),
            contains('failed-precondition'),
          ),
        );
      }
    },
  );

  test(
    'locked room excluded from joinGroupRoom; unlocked room still joinable',
    () async {
      final roomA = await buildRoom(1);
      await callFn('setRoomLock', {'roomId': roomA, 'isLocked': true});

      final roomB = await buildRoom(3);

      await signOut();
      await signInAnon();
      final res = await callFn('joinGroupRoom');

      expect(res['roomId'], equals(roomB));
      expect(
        (await adminFirestoreDoc('rooms/$roomA'))!['memberCount'],
        equals(1),
      );

      await tryLeaveRoom(roomB);
    },
  );

  test(
    'user already in room: joinGroupRoom produces no duplicate in users array',
    () async {
      final uidA = await signInAnon();
      final resA = await callFn('joinGroupRoom');
      final roomId = resA['roomId'] as String;

      final resA2 = await callFn('joinGroupRoom');

      final doc = await adminFirestoreDoc('rooms/$roomId');
      final users = (doc!['users'] as List).cast<String>();
      expect(users.where((u) => u == uidA).length, lessThanOrEqualTo(1));

      await tryLeaveRoom(roomId);
      final secondRoom = resA2['roomId'] as String;
      if (secondRoom != roomId) await tryLeaveRoom(secondRoom);
    },
  );

  // ── 1v1 Pool & Match Trigger ───────────────────────────────────────────────

  test('join1v1Pool: pool entry has all required fields', () async {
    final uid = await signInAnon();
    await callFn('join1v1Pool');

    final doc = await adminFirestoreDoc('waiting_pool/$uid');
    expect(doc!['status'], equals('waiting'));
    expect(doc['mode'], equals('1v1'));
    expect(doc['roomId'], isNull);
    expect(doc['createdAt'], isNotNull);
    expect(doc['updatedAt'], isNotNull);

    await tryCancelPool();
  });

  test(
    'match1v1Users trigger: two users matched with correct room and RTDB membership',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId = poolDoc!['roomId'] as String;
      expect(roomId, hasLength(5));

      final roomDocFut = adminFirestoreDoc('rooms/$roomId');
      final rtdbAFut = rtdbGet('rooms/$roomId/members/$uidA');
      final rtdbBFut = rtdbGet('rooms/$roomId/members/$uidB');

      final roomDoc = await roomDocFut;
      expect(roomDoc!['mode'], equals('1v1'));
      expect(roomDoc['status'], equals('active'));
      expect(roomDoc['memberCount'], equals(2));
      expect((roomDoc['users'] as List), containsAll([uidA, uidB]));
      expect((await rtdbAFut).value, equals(true));
      expect((await rtdbBFut).value, equals(true));

      await callFn('leaveRoom', {'roomId': roomId});
    },
  );

  test(
    'match1v1Users: single user in pool stays waiting — trigger handles no-candidate',
    () async {
      final uid = await signInAnon();
      await callFn('join1v1Pool');

      await Future.delayed(const Duration(seconds: 5));

      final doc = await adminFirestoreDoc('waiting_pool/$uid');
      expect(doc!['status'], equals('waiting'));

      await tryCancelPool();
    },
  );

  test(
    'match1v1Users: 3 users in pool — first two matched, third stays waiting',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();

      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );

      await signOut();
      final uidC = await signInAnon();
      await callFn('join1v1Pool');

      await Future.delayed(const Duration(seconds: 5));

      final docs = await Future.wait([
        adminFirestoreDoc('waiting_pool/$uidA'),
        adminFirestoreDoc('waiting_pool/$uidB'),
        adminFirestoreDoc('waiting_pool/$uidC'),
      ]);

      expect(docs[0]!['status'], equals('matched'));
      expect(docs[1]!['status'], equals('matched'));
      expect(docs[0]!['roomId'], equals(docs[1]!['roomId']));
      expect(docs[2]!['status'], equals('waiting'));

      await tryCancelPool();
      await tryLeaveRoom(docs[0]!['roomId'] as String);
    },
  );

  test(
    'match1v1Users scale: 10 users → 5 pairs all matched correctly',
    () async {
      final uids = <String>[];
      for (int i = 0; i < 10; i++) {
        await signOut();
        uids.add(await signInAnon());
        await callFn('join1v1Pool');
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final poolDocs = await Future.wait(
        uids.map(
          (uid) => waitUntilAdminDocMatches(
            'waiting_pool/$uid',
            (d) => d?['status'] == 'matched',
          ),
        ),
      );

      for (int i = 0; i < 10; i++) {
        expect(
          poolDocs[i]!['status'],
          equals('matched'),
          reason: 'user $i not matched within timeout',
        );
      }

      final roomIds = poolDocs.map((d) => d!['roomId'] as String).toSet();
      expect(roomIds.length, equals(5));

      final roomDocs = await Future.wait(
        roomIds.map((id) => adminFirestoreDoc('rooms/$id')).toList(),
      );
      for (final doc in roomDocs) {
        expect(doc!['memberCount'], equals(2));
        expect((doc['users'] as List).length, equals(2));
        expect(doc['mode'], equals('1v1'));
      }

      for (final id in roomIds) {
        await tryLeaveRoom(id);
      }
    },
  );

  test(
    'join1v1Pool idempotent: calling twice recreates entry without error',
    () async {
      final uid = await signInAnon();
      await callFn('join1v1Pool');
      expect(
        (await adminFirestoreDoc('waiting_pool/$uid'))!['status'],
        equals('waiting'),
      );

      await callFn('join1v1Pool');
      expect(
        (await adminFirestoreDoc('waiting_pool/$uid'))!['status'],
        equals('waiting'),
      );

      await tryCancelPool();
    },
  );

  test('cancel1v1Pool: entry deleted; re-join creates fresh entry', () async {
    final uid = await signInAnon();
    await callFn('join1v1Pool');
    await callFn('cancel1v1Pool');

    expect(await adminFirestoreDoc('waiting_pool/$uid'), isNull);

    await callFn('join1v1Pool');
    final recreated = await adminFirestoreDoc('waiting_pool/$uid');
    expect(recreated!['status'], equals('waiting'));

    await tryCancelPool();
  });

  // ── 1v1 Leave & Requeue ───────────────────────────────────────────────────

  test(
    'leaveRoom (1v1): room enters 30-second padding — not 5-minute group padding',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId = poolDoc!['roomId'] as String;
      await callFn('leaveRoom', {'roomId': roomId});

      final roomDoc = await adminFirestoreDoc('rooms/$roomId');
      expect(roomDoc!['status'], equals('padding'));

      final paddingUntil = roomDoc['paddingUntil'];
      expect(paddingUntil, isNotNull);

      final paddingMs = int.parse(
        DateTime.parse(
          paddingUntil as String,
        ).millisecondsSinceEpoch.toString(),
      );
      final diffSeconds =
          (paddingMs - DateTime.now().millisecondsSinceEpoch) / 1000;
      expect(
        diffSeconds,
        lessThan(35),
        reason:
            '1v1 padding should be ~30s, got ${diffSeconds.toStringAsFixed(1)}s',
      );
      expect(diffSeconds, greaterThan(0));

      expect(uidA, isNotEmpty);
    },
  );

  test(
    'leaveRoom (1v1): remaining user gets fresh waiting_pool entry (delete+set fix)',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId = poolDoc!['roomId'] as String;
      await callFn('leaveRoom', {'roomId': roomId});

      final requeuedDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );
      expect(requeuedDoc!['status'], equals('waiting'));
      expect(requeuedDoc['mode'], equals('1v1'));
      expect(requeuedDoc['roomId'], isNull);
    },
  );

  test(
    'leaveRoom (1v1): RTDB cleared for both users including remaining user',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId = poolDoc!['roomId'] as String;
      await callFn('leaveRoom', {'roomId': roomId});

      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );

      final snapAFut = rtdbGet('rooms/$roomId/members/$uidA');
      final snapBFut = rtdbGet('rooms/$roomId/members/$uidB');
      expect((await snapAFut).exists, isFalse);
      expect((await snapBFut).exists, isFalse);
    },
  );

  test(
    'leaveRoom (1v1): typing and presence RTDB paths removed for leaving user',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolDoc = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId = poolDoc!['roomId'] as String;
      await callFn('leaveRoom', {'roomId': roomId});

      final typingFut = rtdbGet('typing/$roomId/$uidB');
      final presenceFut = rtdbGet('presence/$roomId/$uidB');
      expect((await typingFut).exists, isFalse);
      expect((await presenceFut).exists, isFalse);

      expect(uidA, isNotEmpty);
    },
  );

  // ── Complete User Flows ────────────────────────────────────────────────────

  test(
    'flow: full 1v1 lifecycle — pool → match → RTDB → leave → requeue → cancel',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      expect(
        (await adminFirestoreDoc('waiting_pool/$uidA'))!['status'],
        equals('waiting'),
      );

      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolB = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId = poolB!['roomId'] as String;

      final roomDoc = await adminFirestoreDoc('rooms/$roomId');
      expect(roomDoc!['mode'], equals('1v1'));
      expect(roomDoc['memberCount'], equals(2));

      final snapAFut = rtdbGet('rooms/$roomId/members/$uidA');
      final snapBFut = rtdbGet('rooms/$roomId/members/$uidB');
      expect((await snapAFut).value, equals(true));
      expect((await snapBFut).value, equals(true));

      await callFn('leaveRoom', {'roomId': roomId});
      expect(
        (await adminFirestoreDoc('rooms/$roomId'))!['status'],
        equals('padding'),
      );

      final requeuedA = await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );
      expect(requeuedA!['status'], equals('waiting'));

      await tryCancelPool();
    },
  );

  test(
    'flow: 1v1 chain — A+B match → B leaves → A+C match in new room',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolB = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId1 = poolB!['roomId'] as String;

      await callFn('leaveRoom', {'roomId': roomId1});
      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );

      expect(
        (await adminFirestoreDoc('rooms/$roomId1'))!['status'],
        equals('padding'),
      );

      await signOut();
      final uidC = await signInAnon();
      await callFn('join1v1Pool');

      final poolC = await waitUntilAdminDocMatches(
        'waiting_pool/$uidC',
        (d) => d?['status'] == 'matched',
      );
      final roomId2 = poolC!['roomId'] as String;

      expect(roomId2, isNot(equals(roomId1)));

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$roomId2'),
        adminFirestoreDoc('rooms/$roomId1'),
      ]);
      expect((docs[0]!['users'] as List), containsAll([uidA, uidC]));
      expect(docs[1]!['status'], equals('padding'));

      await callFn('leaveRoom', {'roomId': roomId2});
    },
  );

  test(
    'flow: group room lifecycle — fill to 3 → sequential leaves → padding → new user gets new room',
    () async {
      final uidA = await signInAnon();
      final resA = await callFn('joinGroupRoom');
      final roomX = resA['roomId'] as String;
      expect(resA['isNewRoom'], isTrue);

      await signOut();
      final uidB = await signInAnon();
      final resB = await callFn('joinGroupRoom');
      expect(resB['roomId'], equals(roomX));

      await signOut();
      final uidC = await signInAnon();
      await callFn('joinGroupRoom');
      final doc3 = await adminFirestoreDoc('rooms/$roomX');
      expect(doc3!['memberCount'], equals(3));
      expect((doc3['users'] as List), containsAll([uidA, uidB, uidC]));

      await callFn('leaveRoom', {'roomId': roomX});
      expect(
        (await adminFirestoreDoc('rooms/$roomX'))!['memberCount'],
        equals(2),
      );
      expect(
        (await adminFirestoreDoc('rooms/$roomX'))!['status'],
        equals('active'),
      );

      await tryLeaveRoom(roomX);
      await Future.delayed(const Duration(milliseconds: 500));

      await signOut();
      await signInAnon();
      final resD = await callFn('joinGroupRoom');
      expect((resD['roomId'] as String).length, equals(5));

      await tryLeaveRoom(resD['roomId'] as String);
    },
  );

  test(
    'flow: custom room — create → lock → block → unlock → join → message → padding',
    () async {
      await signInAnon();
      final resA = await callFn('createCustomRoom');
      final roomId = resA['roomId'] as String;

      final docInit = await adminFirestoreDoc('rooms/$roomId');
      expect(docInit!['roomType'], equals('custom'));
      expect(docInit['isLocked'], isFalse);

      await callFn('setRoomLock', {'roomId': roomId, 'isLocked': true});
      expect((await adminFirestoreDoc('rooms/$roomId'))!['isLocked'], isTrue);

      await signOut();
      await signInAnon();
      try {
        await callFn('joinRoomById', {'roomId': roomId});
        fail('expected failed-precondition for locked room');
      } catch (e) {
        expect(e.toString(), contains('failed-precondition'));
      }

      await tryLeaveRoom(roomId);
    },
  );

  test('flow: 1v1 and group rooms do not cross-contaminate', () async {
    final uidA = await signInAnon();
    await callFn('join1v1Pool');

    await signOut();
    final uidB = await signInAnon();
    final resB = await callFn('joinGroupRoom');
    final groupRoomId = resB['roomId'] as String;

    await signOut();
    final uidC = await signInAnon();
    await callFn('join1v1Pool');

    final poolC = await waitUntilAdminDocMatches(
      'waiting_pool/$uidC',
      (d) => d?['status'] == 'matched',
    );
    final v1RoomId = poolC!['roomId'] as String;

    final docs = await Future.wait([
      adminFirestoreDoc('rooms/$v1RoomId'),
      adminFirestoreDoc('rooms/$groupRoomId'),
    ]);

    final v1Room = docs[0]!;
    final groupRoom = docs[1]!;

    expect(v1Room['mode'], equals('1v1'));
    expect((v1Room['users'] as List), containsAll([uidA, uidC]));
    expect(groupRoom['mode'], equals('group'));
    expect(groupRoom['memberCount'], equals(1));
    expect((groupRoom['users'] as List), contains(uidB));
    expect((groupRoom['users'] as List), isNot(contains(uidA)));
    expect((groupRoom['users'] as List), isNot(contains(uidC)));

    await Future.wait<void>([
      callFn('leaveRoom', {'roomId': v1RoomId}),
      tryLeaveRoom(groupRoomId),
    ]);
  });

  test(
    'flow: repeated switching — user visits multiple rooms across cycles',
    () async {
      // All three rooms are 3/5 so they are in the secondary (random) pool.
      // There is no priority room, so selection is random across P, Q, R.
      final roomP = await buildRoom(3);
      final roomQ = await buildRoom(3);
      final roomR = await buildRoom(3);
      final knownRooms = {roomP, roomQ, roomR};
      final visited = <String>{};

      for (int i = 0; i < 10; i++) {
        await signOut();
        await signInAnon();
        final res = await callFn('joinGroupRoom');
        final joined = res['roomId'] as String;
        expect(knownRooms, contains(joined));
        visited.add(joined);
        await callFn('leaveRoom', {'roomId': joined});
      }

      expect(visited.length, greaterThanOrEqualTo(2));
    },
  );

  test('flow: rapid 10 join-leave cycles without error', () async {
    await buildRoom(3);
    await buildRoom(3);
    await buildRoom(3);

    final visited = <String>{};
    var errors = 0;

    for (int i = 0; i < 10; i++) {
      await signOut();
      await signInAnon();
      try {
        final res = await callFn('joinGroupRoom');
        final joined = res['roomId'] as String;
        visited.add(joined);
        await callFn('leaveRoom', {'roomId': joined});
      } catch (_) {
        errors++;
      }
    }

    expect(errors, equals(0));
    expect(visited.length, greaterThanOrEqualTo(2));
  });

  test(
    'flow: 1v1 triple chain — A matches 3 different partners in sequence',
    () async {
      Future<String> doMatch(String uidWaiting) async {
        await signOut();
        final uidPartner = await signInAnon();
        await callFn('join1v1Pool');
        final poolDoc = await waitUntilAdminDocMatches(
          'waiting_pool/$uidPartner',
          (d) => d?['status'] == 'matched',
        );
        return poolDoc!['roomId'] as String;
      }

      final uidA = await signInAnon();
      await callFn('join1v1Pool');

      final roomId1 = await doMatch(uidA);
      await callFn('leaveRoom', {'roomId': roomId1});
      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );

      final roomId2 = await doMatch(uidA);
      await callFn('leaveRoom', {'roomId': roomId2});
      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );

      final roomId3 = await doMatch(uidA);

      expect({roomId1, roomId2, roomId3}.length, equals(3));

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$roomId1'),
        adminFirestoreDoc('rooms/$roomId2'),
        adminFirestoreDoc('rooms/$roomId3'),
      ]);
      expect(docs[0]!['status'], equals('padding'));
      expect(docs[1]!['status'], equals('padding'));
      expect(docs[2]!['status'], equals('active'));

      await callFn('leaveRoom', {'roomId': roomId3});
    },
  );

  test(
    'flow: padding blocks all re-entry — joinRoomById and joinGroupRoom both refuse',
    () async {
      await signOut();
      await signInAnon();
      final resA = await callFn('joinGroupRoom');
      final roomX = resA['roomId'] as String;

      await signOut();
      await signInAnon();
      await callFn('joinGroupRoom');
      await callFn('leaveRoom', {'roomId': roomX});

      await tryLeaveRoom(roomX);
      await Future.delayed(const Duration(milliseconds: 300));

      final paddingDoc = await adminFirestoreDoc('rooms/$roomX');
      if (paddingDoc!['status'] == 'padding') {
        await signOut();
        await signInAnon();

        try {
          await callFn('joinRoomById', {'roomId': roomX});
          fail('expected failed-precondition for padding room');
        } catch (e) {
          expect(e.toString(), contains('failed-precondition'));
        }

        final newRes = await callFn('joinGroupRoom');
        expect(newRes['roomId'], isNot(equals(roomX)));
        await tryLeaveRoom(newRes['roomId'] as String);
      }
    },
  );

  test(
    'flow: mixed mode — user transitions from 1v1 to group, no contamination',
    () async {
      final uidA = await signInAnon();
      await callFn('join1v1Pool');
      await signOut();
      final uidB = await signInAnon();
      await callFn('join1v1Pool');

      final poolB = await waitUntilAdminDocMatches(
        'waiting_pool/$uidB',
        (d) => d?['status'] == 'matched',
      );
      final roomId1v1 = poolB!['roomId'] as String;

      await callFn('leaveRoom', {'roomId': roomId1v1});
      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );

      await signOut();
      final uidC = await signInAnon();
      await callFn('join1v1Pool');

      final poolC = await waitUntilAdminDocMatches(
        'waiting_pool/$uidC',
        (d) => d?['status'] == 'matched',
      );
      final roomId2 = poolC!['roomId'] as String;

      await callFn('leaveRoom', {'roomId': roomId2});
      await waitUntilAdminDocMatches(
        'waiting_pool/$uidA',
        (d) => d != null && d['status'] == 'waiting',
        timeout: const Duration(seconds: 10),
      );

      await signOut();
      await signInAnon();
      final groupRes = await callFn('joinGroupRoom');
      final groupRoomId = groupRes['roomId'] as String;

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$groupRoomId'),
        adminFirestoreDoc('rooms/$roomId1v1'),
        adminFirestoreDoc('rooms/$roomId2'),
      ]);

      expect(docs[0]!['mode'], equals('group'));
      expect(docs[1]!['mode'], equals('1v1'));
      expect(docs[2]!['mode'], equals('1v1'));

      final groupUsers = (docs[0]!['users'] as List).cast<String>();
      expect(groupUsers, isNot(contains(uidA)));
      expect(groupUsers, isNot(contains(uidB)));

      await tryLeaveRoom(groupRoomId);
    },
  );

  test(
    'flow: concurrent group room creation merge — near-simultaneous creators',
    () async {
      await signOut();
      final uidA = await signInAnon();
      final resA = await callFn('joinGroupRoom');
      final roomA = resA['roomId'] as String;

      await signOut();
      await signInAnon();
      final resB = await callFn('joinGroupRoom');
      final roomB = resB['roomId'] as String;

      expect(roomA, hasLength(5));
      expect(roomB, hasLength(5));

      final docs = await Future.wait([
        adminFirestoreDoc('rooms/$roomA'),
        adminFirestoreDoc('rooms/$roomB'),
      ]);

      for (final doc in docs) {
        expect(doc!['memberCount'], greaterThanOrEqualTo(1));
        expect(doc['memberCount'], lessThanOrEqualTo(5));
        expect(doc['mode'], equals('group'));
        final users = (doc['users'] as List).cast<String>();
        expect(users.toSet().length, equals(users.length));
      }

      if (roomA == roomB) {
        final mergedDoc = await adminFirestoreDoc('rooms/$roomA');
        final users = (mergedDoc!['users'] as List).cast<String>();
        expect(users.where((u) => u == uidA).length, equals(1));
      }

      await Future.wait<void>([tryLeaveRoom(roomA), tryLeaveRoom(roomB)]);
    },
  );

  test(
    'flow: group room load test — 15 users fill rooms, each UID in exactly one room',
    () async {
      final uids = <String>[];
      final roomAssignments = <String, String>{};

      for (int i = 0; i < 15; i++) {
        await signOut();
        uids.add(await signInAnon());
        final res = await callFn('joinGroupRoom');
        roomAssignments[uids.last] = res['roomId'] as String;
      }

      expect(roomAssignments.values.every((r) => r.length == 5), isTrue);

      final uniqueRooms = roomAssignments.values.toSet();
      expect(uniqueRooms.length, greaterThanOrEqualTo(3));

      final roomDocs = await Future.wait(
        uniqueRooms.map((id) => adminFirestoreDoc('rooms/$id')).toList(),
      );
      for (final doc in roomDocs) {
        expect(doc!['memberCount'], lessThanOrEqualTo(5));
        expect(doc['memberCount'], greaterThan(0));
      }

      final allUsers = roomDocs.expand(
        (d) => (d!['users'] as List).cast<String>(),
      );
      for (final uid in uids) {
        expect(
          allUsers.where((u) => u == uid).length,
          equals(1),
          reason: 'uid $uid appears in wrong number of rooms',
        );
      }

      for (final id in uniqueRooms) {
        await tryLeaveRoom(id);
      }
    },
  );
}
