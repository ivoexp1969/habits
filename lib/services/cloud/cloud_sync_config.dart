/// data-model-v2 ЕТАП 2 — master switch for the Firestore sync. OFF by default:
/// the whole cloud layer is dormant until this is flipped, so the shipped app
/// keeps using the local SharedPreferences repository and nothing about startup
/// or production changes. Flipped on only for the two-device test build.
class CloudSyncV2 {
  CloudSyncV2._();

  /// The one gate. Everything cloud checks this first.
  static bool enabled = false;
}
