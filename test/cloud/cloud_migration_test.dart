import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/cloud/cloud_migration.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/firestore_schema.dart';

/// ЕТАП 2 B2: idempotent transactional migration + schema flag.
void main() {
  late FakeFirebaseFirestore db;
  final now = DateTime(2026, 11, 19);
  final localMap = {
    '2026-11-16': {'a': 1},
    '2026-11-18': {'a': 2, 'b': 1},
    '2026-12-01': {'a': 1},
  };

  setUp(() => db = FakeFirebaseFirestore());

  test('writes per-month docs + flips the schema flag', () async {
    final mig = CloudMigration(db: db, uid: 'u1');
    expect(await mig.isMigrated(), isFalse);

    final r = await mig.run(localMap, now);
    expect(r, CloudMigrationResult.migrated);
    expect(await mig.isMigrated(), isTrue);

    // Data landed in the right month docs and reads back through the repo.
    final repo = CloudProgressRepository(db: db, uid: 'u1');
    final map = await repo.load();
    expect(map['2026-11-18'], {'a': 2, 'b': 1});
    expect(map['2026-12-01'], {'a': 1});

    final meta = await db.doc(FirestoreSchema.metaSchemaPath('u1')).get();
    expect(meta.data()!['version'], 2);
    expect(meta.data()!['migratedAt'], '2026-11-19');
  });

  test('a second run is a no-op (idempotent, no doubling)', () async {
    final mig = CloudMigration(db: db, uid: 'u1');
    expect((await mig.run(localMap, now)), CloudMigrationResult.migrated);
    expect((await mig.run(localMap, now)), CloudMigrationResult.alreadyMigrated);

    final repo = CloudProgressRepository(db: db, uid: 'u1');
    final map = await repo.load();
    expect(map['2026-11-18'], {'a': 2, 'b': 1}); // NOT 4/2 — not re-added
  });

  test('migration also uploads habits + paused + achievements + xpBaseline', () async {
    final mig = CloudMigration(db: db, uid: 'u1');
    await mig.run(localMap, now, habits: [
      Habit(id: 'h1', name: 'Вода', timesPerDay: 1, createdAt: DateTime(2026, 1, 1)),
    ], pausedDates: {
      '2026-11-10'
    }, achievements: {
      'centurion'
    }, xpBaseline: 860, profile: {
      'name': 'Иво',
      'streakGraceEnabled': true
    });

    final habit = await db.doc(FirestoreSchema.habitDocPath('u1', 'h1')).get();
    expect(habit.data()!['name'], 'Вода');
    expect(habit.data()!['order'], 0);
    final user = await db.doc(FirestoreSchema.userPath('u1')).get();
    expect(user.data()!['pausedDates'], ['2026-11-10']);
    expect(user.data()!['achievements'], ['centurion']);
    expect(user.data()!['xpBaseline'], 860);
    expect(user.data()!['name'], 'Иво'); // profile fields uploaded
    expect(user.data()!['streakGraceEnabled'], true);
  });

  test('a second device sees the flag (adopts cloud, discards local)', () async {
    // Device 1 migrates.
    await CloudMigration(db: db, uid: 'u1').run(localMap, now);
    // Device 2 (same uid) checks before pushing its own local copy.
    final device2 = CloudMigration(db: db, uid: 'u1');
    expect(await device2.isMigrated(), isTrue); // → caller discards local, uses cloud
  });
}
