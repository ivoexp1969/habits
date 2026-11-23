import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/cloud/cloud_docs_sync.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/month_listener.dart';

/// ЕТАП 2 — full round-trip across TWO devices sharing one cloud (uid): a habit
/// + a check-in made on A appear on B; a pause on B appears on A; a delete on B
/// removes the habit from A (soft-delete tombstone).
void main() {
  const uid = 'U';
  final today = DateTime(2026, 11, 19);
  Duration t() => const Duration(seconds: 5);

  test('A creates habit+check-in → B sees; B pauses → A sees; B deletes → gone on A',
      () async {
    final db = FakeFirebaseFirestore(); // the shared cloud

    // Device A
    final aProg = CloudProgressRepository(db: db, uid: uid);
    final aDocs = CloudDocsSync(db: db, uid: uid);
    // Device B
    final bProg = CloudProgressRepository(db: db, uid: uid);
    final bDocs = CloudDocsSync(db: db, uid: uid);
    // B's live progress listener — subscribed BEFORE A writes so the live push is
    // observed (a broadcast stream drops emissions that predate the listener).
    final bMonths = MonthListener(db: db, uid: uid)..watch(today);
    addTearDown(bMonths.dispose);
    final bLiveCheckIn =
        bMonths.stream.firstWhere((m) => m['2026-11-19']?['h1'] == 1);

    // --- A creates a habit and checks it in ---
    final habit = Habit(
        id: 'h1', name: 'Вода', timesPerDay: 1, createdAt: DateTime(2026, 1, 1));
    await aDocs.pushHabits([habit]);
    await aProg.add('h1', today, 1);

    // --- B sees the habit ---
    final bHabits = await bDocs
        .watchHabits()
        .firstWhere((l) => l.any((h) => h.id == 'h1'))
        .timeout(t());
    expect(bHabits.single.name, 'Вода');

    // --- B sees the check-in: live (listener) AND by a direct read ---
    final bMap = await bLiveCheckIn.timeout(t());
    expect(bMap['2026-11-19'], {'h1': 1});
    expect(await bProg.countOn('h1', today), 1);

    // --- B marks a pause → A sees it ---
    await bDocs.setPaused('2026-11-18', true);
    final aPaused = await aDocs
        .watchPaused()
        .firstWhere((s) => s.contains('2026-11-18'))
        .timeout(t());
    expect(aPaused, contains('2026-11-18'));

    // --- B deletes the habit (soft-delete) → A sees the tombstone ---
    final deleted = Habit(
        id: 'h1',
        name: 'Вода',
        timesPerDay: 1,
        createdAt: DateTime(2026, 1, 1),
        deletedAt: DateTime(2026, 11, 20));
    await bDocs.pushHabits([deleted]);
    final aAfter = await aDocs
        .watchHabits()
        .firstWhere((l) => l.any((h) => h.id == 'h1' && h.deletedAt != null))
        .timeout(t());
    expect(aAfter.single.deletedAt, isNotNull); // the UI filters deletedAt out
  });
}
