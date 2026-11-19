import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/firestore_schema.dart';

/// ЕТАП 2 A1: Firestore path + key helpers (pure).
void main() {
  test('paths', () {
    expect(FirestoreSchema.monthDocPath('u1', '2026-11'), 'users/u1/months/2026-11');
    expect(FirestoreSchema.habitDocPath('u1', 'a'), 'users/u1/habits/a');
    expect(FirestoreSchema.metaSchemaPath('u1'), 'users/u1/meta/schema');
  });

  test('month + day keys', () {
    final d = DateTime(2026, 11, 9, 13);
    expect(FirestoreSchema.monthKeyOf(d), '2026-11');
    expect(FirestoreSchema.dayFieldOf(d), '09');
    expect(FirestoreSchema.fieldPath(d, 'g'), '09.g');
    expect(FirestoreSchema.dayKeyOf('2026-11', '09'), '2026-11-09');
  });

  test('monthKeyForDayKey', () {
    expect(FirestoreSchema.monthKeyForDayKey('2026-11-18'), '2026-11');
  });

  test('adjacentMonthKey crosses year boundaries', () {
    expect(FirestoreSchema.adjacentMonthKey('2026-11', -1), '2026-10');
    expect(FirestoreSchema.adjacentMonthKey('2026-12', 1), '2027-01');
    expect(FirestoreSchema.adjacentMonthKey('2026-01', -1), '2025-12');
  });
}
