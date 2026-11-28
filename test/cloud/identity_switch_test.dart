import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/cloud/cloud_docs_sync.dart';
import 'package:habits/services/cloud/cloud_sync_config.dart';
import 'package:habits/services/cloud/sync_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ЕТАП 2 bug1 — on an identity change, rebindAfterAuth bumps identityTick AND
/// re-points the live streams to the NEW uid. The screens listen to identityTick
/// and re-subscribe, so they stop showing the old identity's data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CloudSyncV2.enabled = true;
  });
  tearDown(() => CloudSyncV2.enabled = false);

  Habit h(String id, String name) =>
      Habit(id: id, name: name, timesPerDay: 1, createdAt: DateTime(2026, 1, 1));

  test('rebind → identityTick fires AND liveHabits switches to the new uid', () async {
    final db = FakeFirebaseFirestore();
    // Target profile B already holds its own habits in the cloud.
    await CloudDocsSync(db: db, uid: 'B')
        .pushHabits([h('B', 'Сън'), h('C', 'Спорт')]);

    var ticks = 0;
    void onTick() => ticks++;
    SyncController.instance.identityTick.addListener(onTick);
    addTearDown(
        () => SyncController.instance.identityTick.removeListener(onTick));

    await SyncController.instance.rebindAfterAuth(
        db: db,
        auth: MockFirebaseAuth(
            signedIn: true, mockUser: MockUser(uid: 'B', isAnonymous: false)));

    expect(ticks, greaterThan(0)); // screens are told to re-subscribe
    // The new live stream emits the TARGET's habits, not the old identity's.
    final habits = await SyncController.instance.liveHabits!
        .firstWhere((l) => l.length == 2)
        .timeout(const Duration(seconds: 5));
    expect(habits.map((e) => e.id).toSet(), {'B', 'C'});
  });

  test('sign-out to no uid → identityTick fires, live streams gone (empty UI)', () async {
    final db = FakeFirebaseFirestore();
    var ticks = 0;
    void onTick() => ticks++;
    SyncController.instance.identityTick.addListener(onTick);
    addTearDown(
        () => SyncController.instance.identityTick.removeListener(onTick));

    await SyncController.instance.rebindAfterAuth(
        db: db, auth: MockFirebaseAuth()); // signed out → currentUid null

    expect(ticks, greaterThan(0));
    expect(SyncController.instance.liveHabits, isNull); // nothing to show
  });
}
