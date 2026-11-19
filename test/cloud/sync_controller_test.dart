import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/cloud_sync_config.dart';
import 'package:habits/services/cloud/sync_controller.dart';
import 'package:habits/services/progress_repository.dart';

/// ЕТАП 2 Фаза D: repository selection + the off-by-default flag.
void main() {
  test('CloudSyncV2 is OFF by default (production untouched)', () {
    expect(CloudSyncV2.enabled, isFalse);
  });

  test('select: local unless flag ON and signed in with a cloud repo', () {
    final local = LocalProgressRepository.instance;
    final cloud = CloudProgressRepository(db: FakeFirebaseFirestore(), uid: 'u1');

    // disabled → local even if signed in
    expect(SyncController.select(enabled: false, signedIn: true, local: local, cloud: cloud),
        same(local));
    // enabled but not signed in → local (buffer)
    expect(SyncController.select(enabled: true, signedIn: false, local: local, cloud: cloud),
        same(local));
    // enabled + signed in + cloud present → cloud
    expect(SyncController.select(enabled: true, signedIn: true, local: local, cloud: cloud),
        same(cloud));
    // enabled + signed in but no cloud repo yet → local
    expect(SyncController.select(enabled: true, signedIn: true, local: local, cloud: null),
        same(local));
  });

  test('activeRepository falls back to local before start', () {
    final local = LocalProgressRepository.instance;
    expect(SyncController.instance.activeRepository(local), same(local));
  });
}
