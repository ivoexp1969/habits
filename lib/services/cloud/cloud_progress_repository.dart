import 'package:cloud_firestore/cloud_firestore.dart';

import '../habit_service.dart' show dateKeyFromDate;
import '../progress_repository.dart';
import '../progress_service.dart' show ProgressMap;
import 'firestore_schema.dart';
import 'month_codec.dart';

/// data-model-v2 ЕТАП 2 — the Firestore-backed [ProgressRepository]. Progress is
/// one document per month (users/{uid}/months/{yyyy-MM}); a check-in is a single
/// `FieldValue.increment(±1)` on `dd.habitId`, which is offline-buffered and
/// conflict-free across devices. Reads come from Firestore's local cache first
/// (offline persistence), so the UI never blocks on the network.
///
/// The UI gates a decrement to count > 0, so increment never drives a field
/// negative; [setCount] with <= 0 deletes the field to keep documents compact.
class CloudProgressRepository implements ProgressRepository {
  CloudProgressRepository({required this.db, required this.uid});

  final FirebaseFirestore db;
  final String uid;


  DocumentReference<Map<String, dynamic>> _monthDoc(String monthKey) =>
      db.doc(FirestoreSchema.monthDocPath(uid, monthKey));

  @override
  Future<ProgressMap> load() async {
    final snap = await db.collection(FirestoreSchema.monthsPath(uid)).get();
    final map = <String, Map<String, int>>{};
    for (final d in snap.docs) {
      map.addAll(MonthCodec.decode(d.id, d.data()));
    }
    return map;
  }

  @override
  Future<int> countOn(String habitId, DateTime date) async {
    final mk = FirestoreSchema.monthKeyOf(date);
    final doc = await _monthDoc(mk).get();
    final slice = MonthCodec.decode(mk, doc.data() ?? const {});
    return slice[dateKeyFromDate(date)]?[habitId] ?? 0;
  }

  @override
  Future<void> setCount(String habitId, DateTime date, int count) async {
    final mk = FirestoreSchema.monthKeyOf(date);
    final dd = FirestoreSchema.dayFieldOf(date);
    final value = count <= 0 ? FieldValue.delete() : count;
    await _monthDoc(mk).set({
      dd: {habitId: value}
    }, SetOptions(merge: true));
  }

  @override
  Future<void> add(String habitId, DateTime date, int delta) async {
    final mk = FirestoreSchema.monthKeyOf(date);
    final dd = FirestoreSchema.dayFieldOf(date);
    await _monthDoc(mk).set({
      dd: {habitId: FieldValue.increment(delta)}
    }, SetOptions(merge: true));
  }
}
