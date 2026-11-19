import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../progress_service.dart' show ProgressMap;
import 'cloud_identity.dart';
import 'firestore_schema.dart';

/// data-model-v2 ЕТАП 2 — links a credential to the anonymous account, merging
/// data when the credential already belongs to someone else.
///
/// Flow on `credential-already-in-use`:
///   1. (still anon) delete the anonymous uid's cloud data — months/habits/meta —
///      because after switching accounts the rules forbid touching it;
///   2. switch to the existing account (now current = toUid);
///   3. merge THIS device's LOCAL map into toUid with `FieldValue.increment`,
///      guarded by `mergedFrom` on users/{toUid}/meta/schema in the SAME
///      transaction, so a repeated link never doubles the counts.
///
/// The merge uses the in-memory local map, not a read of the anon uid's docs —
/// after the switch the rules' own-uid restriction would block that read, and the
/// local map already holds exactly what the anonymous user accumulated here.
class AccountLinker {
  AccountLinker({required this.db, required this.identity});

  final FirebaseFirestore db;
  final CloudIdentity identity;

  Future<LinkResult> linkOrMerge(
      AuthCredential credential, ProgressMap localMap) async {
    final anonUid = identity.uid;
    final outcome = await identity.link(credential);
    switch (outcome) {
      case LinkOutcome.linked:
        return LinkResult.linked; // same uid kept, data already there
      case LinkOutcome.alreadyInUse:
        if (anonUid != null) await deleteUserData(anonUid); // while still anon
        final toUid = await identity.signInWith(credential);
        if (toUid != null && anonUid != null) {
          await mergeLocalInto(toUid, anonUid, localMap);
        }
        return LinkResult.mergedAndSwitched;
      case LinkOutcome.noCurrentUser:
      case LinkOutcome.error:
        return LinkResult.error;
    }
  }

  /// Adds [localMap] into [toUid]'s month docs, ONCE per [fromUid]. The
  /// `mergedFrom` guard lives on users/{toUid}/meta/schema and is read + written
  /// in the SAME transaction as the sums, so a crashed or repeated merge never
  /// doubles. The transaction reads each target month, adds the local day counts,
  /// and writes the absolute result (a transaction cannot trust a blind
  /// increment to run exactly once).
  Future<void> mergeLocalInto(
      String toUid, String fromUid, ProgressMap localMap) async {
    final metaRef = db.doc(FirestoreSchema.metaSchemaPath(toUid));

    // Local additions grouped as plain ints: { monthKey: { dd: { id: count } } }.
    final additions = <String, Map<String, Map<String, int>>>{};
    localMap.forEach((dayKey, counts) {
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

      // ALL reads before ANY writes (Firestore transaction rule).
      final existing = <String, Map<String, dynamic>>{};
      for (final mk in monthKeys) {
        final snap = await tx.get(db.doc(FirestoreSchema.monthDocPath(toUid, mk)));
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

  /// Deletes every month/habit/meta document under [uid] (the orphaned anonymous
  /// account's data after a merge). Call while still authenticated as [uid].
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
}

enum LinkResult { linked, mergedAndSwitched, error }
