import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/habit.dart';
import '../progress_service.dart' show ProgressMap;
import '../diag_log.dart';
import 'auth_backend.dart';
import 'cloud_progress_repository.dart';
import 'firestore_schema.dart';
import 'habit_cloud_codec.dart';

/// Everything a device must carry into a merge — progress AND the definitions,
/// so a kill right after the switch cannot lose the habits (they are part of the
/// SAME durable copy + the SAME merge, not an async push afterwards).
class MergeBundle {
  MergeBundle({
    required this.map,
    this.habits = const [],
    this.paused = const {},
    this.achievements = const {},
  });
  final ProgressMap map;
  final List<Habit> habits;
  final Set<String> paused;
  final Set<String> achievements;

  bool get isEmptyProgress => map.isEmpty;

  Map<String, dynamic> toJson() => {
        'map': map,
        'habits': habits.map((h) => h.toJson()).toList(),
        'paused': paused.toList(),
        'achievements': achievements.toList(),
      };

  static MergeBundle fromJson(Map<String, dynamic> j) {
    final rawMap = (j['map'] as Map).map((day, counts) => MapEntry(
        day as String,
        (counts as Map)
            .map((id, c) => MapEntry(id as String, (c as num).toInt()))));
    return MergeBundle(
      map: rawMap,
      habits: ((j['habits'] as List?) ?? const [])
          .map((e) => Habit.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      paused: ((j['paused'] as List?) ?? const []).map((e) => e.toString()).toSet(),
      achievements:
          ((j['achievements'] as List?) ?? const []).map((e) => e.toString()).toSet(),
    );
  }
}

/// data-model-v2 ЕТАП 2 — links a credential to the anonymous account, merging
/// data when the credential already belongs to someone else.
///
/// Crash-safe order (a durable copy — progress + definitions — is written FIRST):
///   a) persist the durable [MergeBundle] + the anon uid locally;
///   b) delete the anon uid's cloud data (still authed as it);
///   c) sign in to the existing account (current → toUid);
///   d) merge the bundle into toUid — progress in a `mergedFrom`-guarded
///      transaction, habits/paused/achievements written idempotently;
///   e) delete the copy.
/// On start, [resumePending] finishes an interrupted link.
class AccountLinker {
  AccountLinker({required this.db, required this.auth});

  final FirebaseFirestore db;
  final AuthBackend auth;

  static const String _kPending = 'pending_merge_v2';

  Future<LinkResult> linkOrMerge(
      AuthCredential credential, MergeBundle bundle) async {
    final anonUid = auth.currentUid;
    final outcome = await auth.link(credential);
    switch (outcome) {
      case LinkOutcome.linked:
        await DiagLog.auth('linkMerge: linked, same uid=$anonUid (data kept)');
        return LinkResult.linked; // same uid kept, data already there
      case LinkOutcome.alreadyInUse:
        if (anonUid == null) return LinkResult.error;
        // SAFETY: empty copy but the anon STILL has cloud data → bad read, abort.
        if (bundle.isEmptyProgress) {
          final cloud =
              await CloudProgressRepository(db: db, uid: anonUid).load();
          if (cloud.isNotEmpty) {
            await DiagLog.auth('linkMerge ABORT: empty copy but anon $anonUid '
                'has ${cloud.length} days in cloud — nothing deleted');
            return LinkResult.error;
          }
        }
        await DiagLog.auth('linkMerge: $anonUid → (switch) '
            'copy=${_summary(bundle)}');
        await _savePending(anonUid, bundle); // a) durable copy FIRST
        await deleteUserData(anonUid); // b) still anon
        final toUid = await auth.signInWith(credential); // c)
        if (toUid != null) {
          await mergeBundleInto(toUid, anonUid, bundle); // d) idempotent
          await _clearPending(); // e)
          await DiagLog.auth('linkMerge: done $anonUid → $toUid '
              '(${_summary(bundle)})');
          return LinkResult.mergedAndSwitched;
        }
        await DiagLog.auth('linkMerge: signIn failed after delete; copy kept for '
            'resume (anon=$anonUid)');
        return LinkResult.error; // copy kept → resumePending finishes it
      case LinkOutcome.noCurrentUser:
      case LinkOutcome.error:
        await DiagLog.auth('linkMerge: link failed ($outcome) anon=$anonUid');
        return LinkResult.error;
    }
  }

  static String _summary(MergeBundle b) {
    var checkins = 0;
    for (final day in b.map.values) {
      for (final c in day.values) {
        checkins += c;
      }
    }
    return '${b.map.length} days / $checkins check-ins / ${b.habits.length} habits';
  }

  /// Finishes an interrupted link at startup. Returns true if it merged now.
  Future<bool> resumePending() async {
    final pending = await _readPending();
    if (pending == null) return false;
    final uid = auth.currentUid;
    if (uid != null && uid != pending.fromUid) {
      await DiagLog.auth('resumePending: ${pending.fromUid} → $uid '
          '(${_summary(pending.bundle)})');
      await mergeBundleInto(uid, pending.fromUid, pending.bundle);
      await _clearPending();
      return true;
    }
    return false;
  }

  /// Merges the WHOLE bundle into [toUid]: progress (guarded, non-doubling) +
  /// habit definitions + paused + achievements (idempotent — safe to repeat).
  Future<void> mergeBundleInto(
      String toUid, String fromUid, MergeBundle bundle) async {
    await mergeLocalInto(toUid, fromUid, bundle.map);
    await _writeDefs(toUid, bundle);
  }

  Future<void> _writeDefs(String toUid, MergeBundle bundle) async {
    final batch = db.batch();
    final now = DateTime.now();
    // Habits: add this device's habits to the target (its own habits, by id, are
    // untouched). Idempotent — re-writing the same doc is a no-op in effect.
    for (var i = 0; i < bundle.habits.length; i++) {
      batch.set(
          db.doc(FirestoreSchema.habitDocPath(toUid, bundle.habits[i].id)),
          HabitCloudCodec.toDoc(bundle.habits[i], order: i, updatedAt: now));
    }
    // paused + achievements as sets (arrayUnion → merges, never overwrites).
    final userUpdate = <String, dynamic>{};
    if (bundle.paused.isNotEmpty) {
      userUpdate['pausedDates'] = FieldValue.arrayUnion(bundle.paused.toList());
    }
    if (bundle.achievements.isNotEmpty) {
      userUpdate['achievements'] =
          FieldValue.arrayUnion(bundle.achievements.toList());
    }
    if (userUpdate.isNotEmpty) {
      batch.set(db.doc(FirestoreSchema.userPath(toUid)), userUpdate,
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Adds [map] into [toUid]'s month docs, ONCE per [fromUid] (mergedFrom guard).
  Future<void> mergeLocalInto(
      String toUid, String fromUid, ProgressMap map) async {
    final metaRef = db.doc(FirestoreSchema.metaSchemaPath(toUid));

    final additions = <String, Map<String, Map<String, int>>>{};
    map.forEach((dayKey, counts) {
      if (counts.isEmpty) return;
      final monthKey = FirestoreSchema.monthKeyForDayKey(dayKey);
      final dd = dayKey.substring(8);
      final day = additions
          .putIfAbsent(monthKey, () => {})
          .putIfAbsent(dd, () => {});
      counts.forEach((id, c) {
        if (c > 0) day[id] = (day[id] ?? 0) + c;
      });
    });
    final monthKeys = additions.keys.toList();

    await db.runTransaction<void>((tx) async {
      final meta = await tx.get(metaRef);
      final mergedFrom =
          (meta.data()?['mergedFrom'] as List?)?.cast<String>() ?? const [];
      if (mergedFrom.contains(fromUid)) return; // already merged → no doubling

      final existing = <String, Map<String, dynamic>>{};
      for (final mk in monthKeys) {
        final snap =
            await tx.get(db.doc(FirestoreSchema.monthDocPath(toUid, mk)));
        existing[mk] = Map<String, dynamic>.from(snap.data() ?? const {});
      }
      for (final mk in monthKeys) {
        final doc = existing[mk]!;
        additions[mk]!.forEach((dd, ids) {
          final day = Map<String, dynamic>.from(
              (doc[dd] as Map?)?.cast<String, dynamic>() ?? const {});
          ids.forEach((id, c) {
            day[id] = ((day[id] as num?)?.toInt() ?? 0) + c;
          });
          doc[dd] = day;
        });
        tx.set(db.doc(FirestoreSchema.monthDocPath(toUid, mk)), doc);
      }
      tx.set(metaRef, {'mergedFrom': [...mergedFrom, fromUid]},
          SetOptions(merge: true));
    });
  }

  /// Deletes every month/habit/meta document under [uid] (idempotent).
  Future<void> deleteUserData(String uid) async {
    final batch = db.batch();
    for (final coll in [
      FirestoreSchema.monthsPath(uid),
      FirestoreSchema.habitsPath(uid),
      'users/$uid/meta',
    ]) {
      final snap = await db.collection(coll).get();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
    }
    await batch.commit();
  }

  // ---- durable pending-merge copy ------------------------------------------
  Future<void> _savePending(String fromUid, MergeBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPending,
        jsonEncode({'fromUid': fromUid, 'bundle': bundle.toJson()}));
  }

  Future<_Pending?> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kPending);
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return _Pending(j['fromUid'] as String,
          MergeBundle.fromJson(Map<String, dynamic>.from(j['bundle'] as Map)));
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPending);
  }
}

class _Pending {
  _Pending(this.fromUid, this.bundle);
  final String fromUid;
  final MergeBundle bundle;
}

enum LinkResult { linked, mergedAndSwitched, error }
