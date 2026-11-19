import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../progress_service.dart' show ProgressMap;
import 'cloud_identity.dart';
import 'firestore_schema.dart';

/// data-model-v2 ЕТАП 2 — links a credential to the anonymous account, merging
/// data when the credential already belongs to someone else.
///
/// Crash-safe order (a durable local copy is written FIRST, so a crash between
/// any two steps loses nothing and never doubles):
///   a) persist a durable copy of the anon progress map + its uid locally;
///   b) delete the anon uid's cloud data (months/habits/meta) — still authed as
///      that uid, because the rules forbid it after the switch;
///   c) sign in to the existing account (current → toUid);
///   d) merge from the COPY into toUid, in a transaction guarded by `mergedFrom`
///      (idempotent — a repeat is a no-op);
///   e) delete the copy.
/// On start, [resumePending] finishes an interrupted link: if a copy exists and
/// we are already signed in to the target (c done), it runs d)+e); if we are
/// still anonymous (crash before c), it leaves the copy for the next link attempt
/// (b is already done / idempotent, so retrying is safe).
class AccountLinker {
  AccountLinker({required this.db, required this.identity});

  final FirebaseFirestore db;
  final CloudIdentity identity;

  static const String _kPending = 'pending_merge_v2';

  Future<LinkResult> linkOrMerge(
      AuthCredential credential, ProgressMap localMap) async {
    final anonUid = identity.uid;
    final outcome = await identity.link(credential);
    switch (outcome) {
      case LinkOutcome.linked:
        return LinkResult.linked; // same uid kept, data already there
      case LinkOutcome.alreadyInUse:
        if (anonUid == null) return LinkResult.error;
        await _savePending(anonUid, localMap); // a) durable copy FIRST
        await deleteUserData(anonUid); // b) still anon
        final toUid = await identity.signInWith(credential); // c)
        if (toUid != null) {
          await mergeLocalInto(toUid, anonUid, localMap); // d) idempotent
          await _clearPending(); // e)
          return LinkResult.mergedAndSwitched;
        }
        return LinkResult.error; // copy kept → resumePending finishes it
      case LinkOutcome.noCurrentUser:
      case LinkOutcome.error:
        return LinkResult.error;
    }
  }

  /// Finishes an interrupted link at startup. Returns true if it completed a
  /// merge now.
  Future<bool> resumePending() async {
    final pending = await _readPending();
    if (pending == null) return false;
    final uid = identity.uid;
    // Signed in to the TARGET (step c already happened) → run d)+e).
    if (uid != null && uid != pending.fromUid) {
      await mergeLocalInto(uid, pending.fromUid, pending.map);
      await _clearPending();
      return true;
    }
    // Still anonymous (crash before c): leave the copy; the next linkOrMerge
    // retries from b) (deletion is idempotent) and completes the merge.
    return false;
  }

  /// Adds [map] into [toUid]'s month docs, ONCE per [fromUid]. The `mergedFrom`
  /// guard on users/{toUid}/meta/schema is read + written in the SAME transaction
  /// as the sums, so a crashed or repeated merge never doubles. The transaction
  /// reads each target month, adds the counts and writes the absolute result.
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

  /// Deletes every month/habit/meta document under [uid] (idempotent — a second
  /// call on already-empty collections is a no-op).
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
  Future<void> _savePending(String fromUid, ProgressMap map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPending, jsonEncode({'fromUid': fromUid, 'map': map}));
  }

  Future<_Pending?> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kPending);
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final rawMap = (j['map'] as Map).map((day, counts) => MapEntry(
          day as String,
          (counts as Map).map((id, c) => MapEntry(id as String, (c as num).toInt()))));
      return _Pending(j['fromUid'] as String, rawMap);
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
  _Pending(this.fromUid, this.map);
  final String fromUid;
  final ProgressMap map;
}

enum LinkResult { linked, mergedAndSwitched, error }
