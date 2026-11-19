import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/month_codec.dart';

/// ЕТАП 2 A1: month-document ↔ ProgressMap-slice codec (pure).
void main() {
  test('decode: month doc → full yyyy-MM-dd keys, drops 0/garbage', () {
    final doc = {
      '09': {'a': 1, 'b': 0}, // b dropped (0)
      '16': {'a': 2},
      'note': 'x', // non-day field ignored
      '31': 5, // malformed (not a map) ignored
    };
    final slice = MonthCodec.decode('2026-11', doc);
    expect(slice, {
      '2026-11-09': {'a': 1},
      '2026-11-16': {'a': 2},
    });
  });

  test('encode: slice → month doc, only days in that month', () {
    final slice = {
      '2026-11-09': {'a': 1},
      '2026-11-16': {'a': 2},
      '2026-12-01': {'a': 9}, // different month → excluded
    };
    expect(MonthCodec.encode('2026-11', slice), {
      '09': {'a': 1},
      '16': {'a': 2},
    });
  });

  test('round-trip decode(encode) is identity for one month', () {
    final slice = {
      '2026-11-05': {'x': 3, 'y': 1},
      '2026-11-28': {'x': 1},
    };
    final doc = MonthCodec.encode('2026-11', slice);
    expect(MonthCodec.decode('2026-11', doc), slice);
  });

  test('splitByMonth groups a whole map into per-month docs', () {
    final map = {
      '2026-10-31': {'a': 1},
      '2026-11-01': {'a': 1},
      '2026-11-30': {'b': 2},
    };
    final months = MonthCodec.splitByMonth(map);
    expect(months.keys.toSet(), {'2026-10', '2026-11'});
    expect(months['2026-10'], {
      '31': {'a': 1}
    });
    expect(months['2026-11'], {
      '01': {'a': 1},
      '30': {'b': 2},
    });
  });
}
