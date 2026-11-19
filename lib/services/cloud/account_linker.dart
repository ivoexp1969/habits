import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../progress_service.dart' show ProgressMap;
import 'cloud_identity.dart';
import 'firestore_schema.dart';

/// data-model-v2 ЕТАП 2 — links a credential to the anonymous account, merging
/// data when the credential already belongs to someone else.
///
/// The merge adds this device's LOCAL map into the target account's month docs
/// with `FieldValue.increment` (counts add, never overwrite). It uses the
/// in-memory local map, NOT a read of the anonymous uid's Firestore docs —
/// after switching accounts the rules forbid reading the old uid, and the local
/// map already holds exactly what the anonymous user accumulated here.
class AccountLinker {
  AccountLinker({required this.db, required this.identity});

  final FirebaseFirestore db;
  final CloudIdentity identity;

  /// Full flow: try to link; on `credential-already-in-use`, switch to the
  /// existing account and merge the local map into it.
  Future<LinkResult> linkOrMerge(
      AuthCredential credential, ProgressMap localMap) async {
    final outcome = await identity.link(credential);
    switch (outcome) {
      case LinkOutcome.linked:
        return LinkResult.linked; // same uid kept, data already there
      case LinkOutcome.alreadyInUse:
        final toUid = await identity.signInWith(credential);
        if (toUid != null) await mergeLocalInto(toUid, localMap);
        return LinkResult.mergedAndSwitched;
      case LinkOutcome.noCurrentUser:
      case LinkOutcome.error:
        return LinkResult.error;
    }
  }

  /// Adds [localMap] into [toUid]'s month documents with increments.
  Future<void> mergeLocalInto(String toUid, ProgressMap localMap) async {
    // Group the local days into per-month nested increment payloads.
    final perMonth = <String, Map<String, dynamic>>{};
    localMap.forEach((dayKey, counts) {
      if (counts.isEmpty) return;
      final monthKey = FirestoreSchema.monthKeyForDayKey(dayKey);
      final dd = dayKey.substring(8); // 'yyyy-MM-dd' → 'dd'
      final month = perMonth.putIfAbsent(monthKey, () => <String, dynamic>{});
      final day = month.putIfAbsent(dd, () => <String, dynamic>{})
          as Map<String, dynamic>;
      counts.forEach((habitId, c) {
        if (c > 0) day[habitId] = FieldValue.increment(c);
      });
    });

    final batch = db.batch();
    perMonth.forEach((monthKey, payload) {
      batch.set(db.doc(FirestoreSchema.monthDocPath(toUid, monthKey)), payload,
          SetOptions(merge: true));
    });
    await batch.commit();
  }
}

enum LinkResult { linked, mergedAndSwitched, error }
