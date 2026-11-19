import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/cloud/firestore_schema.dart';
import 'package:habits/services/cloud/habit_cloud_codec.dart';
import 'package:habits/services/cloud/misc_cloud_sync.dart';

/// ЕТАП 2 Фаза C: habit LWW codec + paused/achievements/profile/XP.
void main() {
  group('HabitCloudCodec', () {
    final h = Habit(
        id: 'a',
        name: 'Вода',
        timesPerDay: 2,
        createdAt: DateTime(2026, 1, 1),
        deletedAt: DateTime(2026, 11, 10));

    test('round-trips with order + deletedAt preserved', () {
      final doc = HabitCloudCodec.toDoc(h, order: 3, updatedAt: DateTime(2026, 11, 18));
      expect(HabitCloudCodec.orderOf(doc), 3);
      final back = HabitCloudCodec.fromDoc(doc);
      expect(back.name, 'Вода');
      expect(back.timesPerDay, 2);
      expect(back.deletedAt, DateTime(2026, 11, 10)); // tombstone survives
    });

    test('LWW: newer updatedAt wins; missing loses; equal keeps local', () {
      final older = HabitCloudCodec.toDoc(h, order: 0, updatedAt: DateTime(2026, 11, 17));
      final newer = HabitCloudCodec.toDoc(h, order: 0, updatedAt: DateTime(2026, 11, 18));
      expect(HabitCloudCodec.remoteWins(older, newer), isTrue);
      expect(HabitCloudCodec.remoteWins(newer, older), isFalse);
      expect(HabitCloudCodec.remoteWins(newer, newer), isFalse); // equal
      expect(HabitCloudCodec.remoteWins(newer, <String, dynamic>{}), isFalse); // remote no ts
    });
  });

  group('MiscCloudSync', () {
    late FakeFirebaseFirestore db;
    late MiscCloudSync misc;
    setUp(() {
      db = FakeFirebaseFirestore();
      misc = MiscCloudSync(db: db, uid: 'u1');
    });

    Future<Map<String, dynamic>> user() async =>
        (await db.doc(FirestoreSchema.userPath('u1')).get()).data() ?? {};

    test('paused dates: arrayUnion adds, arrayRemove removes', () async {
      await misc.setPaused('2026-11-18', true);
      await misc.setPaused('2026-11-19', true);
      expect(((await user())['pausedDates'] as List).toSet(),
          {'2026-11-18', '2026-11-19'});
      await misc.setPaused('2026-11-18', false);
      expect((await user())['pausedDates'], ['2026-11-19']);
    });

    test('achievements: arrayUnion is idempotent (no duplicates)', () async {
      await misc.unlockAchievement('centurion');
      await misc.unlockAchievement('centurion');
      await misc.unlockAchievement('first_step');
      expect(((await user())['achievements'] as List).toSet(),
          {'centurion', 'first_step'});
    });

    test('profile LWW timestamp + xp baseline', () async {
      await misc.writeProfile({'name': 'Иво'}, DateTime(2026, 11, 18, 10));
      await misc.setXpBaseline(860);
      final u = await user();
      expect(u['name'], 'Иво');
      expect(u['xpBaseline'], 860);
      expect(MiscCloudSync.xpTotal(860, 40), 900);

      final local = {'profileUpdatedAt': '2026-11-18T10:00:00.000'};
      final remoteNewer = {'profileUpdatedAt': '2026-11-18T12:00:00.000'};
      expect(MiscCloudSync.lwwRemoteWins(local, remoteNewer), isTrue);
      expect(MiscCloudSync.lwwRemoteWins(remoteNewer, local), isFalse);
    });
  });
}
