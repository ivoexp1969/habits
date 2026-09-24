import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'backup_service.dart';

enum SyncStatus { uploaded, downloaded, noop, notSignedIn, error }

/// Free cloud backup + cross-device sync for the signed-in user, stored as a
/// single document `users/{uid}`. The whole progress blob (the same JSON
/// [BackupService] produces) is the value, so conflicts resolve as
/// **last-write-wins** at device granularity via [_kSyncedAt]:
///   - cloud `updatedAt` newer than our last sync  -> another device wrote,  download.
///   - otherwise                                    -> we have local changes, upload.
///
/// The ad-free entitlement is never synced (BackupService already excludes it).
/// The app works fully signed-out; this only runs when [AuthService.isSignedIn].
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const String _kSyncedAt = 'cloud_synced_at'; // ms of last known cloud write
  static const Duration _debounce = Duration(seconds: 4);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _debounceTimer;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// Called on sign-in and manual "sync now". Reconciles cloud <-> local.
  Future<SyncStatus> sync() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return SyncStatus.notSignedIn;
    try {
      final snap = await _doc(uid).get();
      final prefs = await SharedPreferences.getInstance();
      final syncedAt = prefs.getInt(_kSyncedAt) ?? 0;

      if (!snap.exists) {
        await _push(uid, prefs);
        return SyncStatus.uploaded;
      }
      final data = snap.data() ?? const {};
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      final payload = data['payload'];

      if (updatedAt > syncedAt && payload is String) {
        final res = BackupService.validate(payload);
        if (res.status == BackupStatus.ok && res.data != null) {
          await BackupService.apply(res.data!);
          await prefs.setInt(_kSyncedAt, updatedAt);
          return SyncStatus.downloaded;
        }
        // Corrupt/newer cloud payload -> don't destroy local; overwrite cloud.
        await _push(uid, prefs);
        return SyncStatus.uploaded;
      }
      await _push(uid, prefs);
      return SyncStatus.uploaded;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudSync sync error: $e');
      return SyncStatus.error;
    }
  }

  Future<void> _push(String uid, SharedPreferences prefs) async {
    final payload = await BackupService.exportJson();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _doc(uid).set({
      'payload': payload,
      'updatedAt': now,
      'platform': _platform,
      'syncedFromVersion': BackupService.backupVersion,
    });
    await prefs.setInt(_kSyncedAt, now);
  }

  /// Immediate upload of the current local state (used before sign-out and on
  /// app pause). No-op when signed out.
  Future<SyncStatus> uploadNow() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return SyncStatus.notSignedIn;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _push(uid, prefs);
      return SyncStatus.uploaded;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudSync uploadNow error: $e');
      return SyncStatus.error;
    }
  }

  /// Debounced upload, safe to call often (after progress changes / on resume).
  void uploadSoon() {
    if (!AuthService.instance.isSignedIn) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => uploadNow());
  }

  /// Deletes the cloud document (GDPR / account deletion). Call before deleting
  /// the auth account.
  Future<void> deleteCloudData() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return;
    try {
      await _doc(uid).delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSyncedAt);
    } catch (e) {
      if (kDebugMode) debugPrint('CloudSync delete error: $e');
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    try {
      return Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other');
    } catch (_) {
      return 'other';
    }
  }
}
