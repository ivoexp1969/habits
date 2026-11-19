import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../progress_service.dart' show ProgressMap;
import 'firestore_schema.dart';
import 'month_codec.dart';

/// data-model-v2 ЕТАП 2 — live progress from Firestore. Subscribes to the
/// CURRENT month plus its two neighbours (previous + next) so a day-rollover or
/// a "yesterday" widget read across a month boundary stays covered without
/// loading the whole history. Each snapshot re-merges into one by-date
/// ProgressMap and is emitted on [stream]; Firestore serves the first value from
/// its offline cache, so the UI never blocks on the network.
class MonthListener {
  MonthListener({required this.db, required this.uid});

  final FirebaseFirestore db;
  final String uid;

  final _controller = StreamController<ProgressMap>.broadcast();
  final Map<String, Map<String, Map<String, int>>> _byMonth = {}; // monthKey → slice
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subs = {};

  Stream<ProgressMap> get stream => _controller.stream;

  /// The current merged view (all watched months), as a fresh copy.
  ProgressMap get current {
    final out = <String, Map<String, int>>{};
    for (final slice in _byMonth.values) {
      slice.forEach((day, counts) => out[day] = Map<String, int>.from(counts));
    }
    return out;
  }

  /// (Re)points the listeners at the months around [around]. Idempotent: months
  /// already watched are kept, ones no longer in range are cancelled.
  void watch(DateTime around) {
    final currentKey = FirestoreSchema.monthKeyOf(around);
    final want = {
      FirestoreSchema.adjacentMonthKey(currentKey, -1),
      currentKey,
      FirestoreSchema.adjacentMonthKey(currentKey, 1),
    };

    for (final mk in _subs.keys.toList()) {
      if (!want.contains(mk)) {
        _subs.remove(mk)?.cancel();
        _byMonth.remove(mk);
      }
    }

    for (final mk in want) {
      if (_subs.containsKey(mk)) continue;
      _subs[mk] = db
          .doc(FirestoreSchema.monthDocPath(uid, mk))
          .snapshots()
          .listen((snap) {
        _byMonth[mk] = MonthCodec.decode(mk, snap.data() ?? const {});
        if (!_controller.isClosed) _controller.add(current);
      });
    }
  }

  Future<void> dispose() async {
    for (final s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
    _byMonth.clear();
    await _controller.close();
  }
}
