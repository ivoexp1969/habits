import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habits/services/progress_repository.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1 step 2: the local by-date progress store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = LocalProgressRepository.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo.resetCache();
  });

  group('decode (pure)', () {
    test('round-trips and drops 0 / malformed entries', () {
      final map = {
        '2026-11-16': {'a': 3, 'b': 0}, // b dropped
        '2026-11-15': {'a': 1},
      };
      final back = LocalProgressRepository.decode(LocalProgressRepository.encode(map));
      expect(back['2026-11-16'], {'a': 3});
      expect(back['2026-11-15'], {'a': 1});
    });

    test('null / empty / garbage → empty map', () {
      expect(LocalProgressRepository.decode(null), isEmpty);
      expect(LocalProgressRepository.decode(''), isEmpty);
      expect(LocalProgressRepository.decode('{not json'), isEmpty);
    });
  });

  group('setCount / add / countOn (persisted)', () {
    test('setCount writes and countOn reads it back', () async {
      await repo.setCount('a', DateTime(2026, 11, 16, 9), 5);
      expect(await repo.countOn('a', DateTime(2026, 11, 16, 23)), 5);
      expect(await repo.countOn('a', DateTime(2026, 11, 15)), 0);
    });

    test('add increments and decrements, clamped at 0', () async {
      await repo.add('a', DateTime(2026, 11, 16), 1);
      await repo.add('a', DateTime(2026, 11, 16), 1);
      expect(await repo.countOn('a', DateTime(2026, 11, 16)), 2);
      await repo.add('a', DateTime(2026, 11, 16), -1);
      expect(await repo.countOn('a', DateTime(2026, 11, 16)), 1);
      await repo.add('a', DateTime(2026, 11, 16), -5); // clamp
      expect(await repo.countOn('a', DateTime(2026, 11, 16)), 0);
    });

    test('a count of 0 removes the entry and the empty day', () async {
      await repo.setCount('a', DateTime(2026, 11, 16), 3);
      await repo.setCount('a', DateTime(2026, 11, 16), 0);
      final m = await repo.load();
      expect(m.containsKey('2026-11-16'), isFalse);
    });

    test('survives a reload from storage (new cache, same prefs)', () async {
      await repo.setCount('a', DateTime(2026, 11, 16), 4);
      repo.resetCache(); // force re-read from prefs
      expect(await repo.countOn('a', DateTime(2026, 11, 16)), 4);
    });

    test('replaceAll swaps the whole map and ProgressService reads it', () async {
      final ProgressMap m = {
        '2026-11-16': {'a': 8},
      };
      await repo.replaceAll(m);
      repo.resetCache();
      final loaded = await repo.load();
      expect(ProgressService.countOn(loaded, 'a', DateTime(2026, 11, 16)), 8);
    });
  });
}
