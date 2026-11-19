/// data-model-v2 ЕТАП 2 — master switch for the Firestore sync. OFF by default:
/// the whole cloud layer is dormant until this is flipped, so the shipped app
/// keeps using the local SharedPreferences repository and nothing about startup
/// or production changes. Flipped on only for the two-device test build.
class CloudSyncV2 {
  CloudSyncV2._();

  /// The one gate. Everything cloud checks this first. OFF unless a build opts in
  /// with `--dart-define=CLOUD_SYNC_V2=true`, so ONLY the explicit test builds
  /// (Note 9 from PC, iOS simulator) enable it — a normal build of the personal
  /// iPhone / main Android stays false and never uploads real data. Kept as a
  /// non-const var so a test can still flip it in-process.
  static bool enabled =
      const bool.fromEnvironment('CLOUD_SYNC_V2', defaultValue: false);
}
