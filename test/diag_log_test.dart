import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/diag_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ЕТАП 2 — auth diagnostics live in their own 200-line buffer, so frequent
/// widget/sync writes never push them out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('auth events survive heavy default-channel (widget) spam', () async {
    await DiagLog.auth('linkMerge: PIGb7 → 1WBic');
    // Far more default writes than the single old 20-line buffer could hold.
    for (var i = 0; i < 100; i++) {
      await DiagLog.add('widget push $i');
    }
    final auth = await DiagLog.recentAuth();
    expect(auth.any((e) => e.contains('linkMerge: PIGb7 → 1WBic')), isTrue);
  });

  test('auth buffer caps at 200 (ring)', () async {
    for (var i = 0; i < 230; i++) {
      await DiagLog.auth('evt $i');
    }
    final auth = await DiagLog.recentAuth();
    expect(auth.length, 200);
    expect(auth.first, contains('evt 229')); // newest first
    expect(auth.any((e) => e.endsWith('evt 30')), isTrue); // oldest kept (230-200)
    expect(auth.any((e) => e.endsWith('evt 29')), isFalse); // evicted
  });

  test('recent() merges both channels, newest first', () async {
    await DiagLog.add('default A');
    await DiagLog.auth('auth B');
    final all = await DiagLog.recent();
    expect(all.any((e) => e.contains('default A')), isTrue);
    expect(all.any((e) => e.contains('auth B')), isTrue);
  });
}
