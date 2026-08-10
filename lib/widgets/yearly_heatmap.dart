import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../services/habit_service.dart';

/// A GitHub-style contribution heatmap of the last ~12 months. Each square is a
/// day; its colour intensity reflects that day's overall completion percentage
/// (from the global daily-success history). Drawn with a single [CustomPaint]
/// (one repaint for ~370 cells) rather than one widget per cell, so it stays
/// cheap. Scrolls horizontally, starting at the most recent week.
class YearlyHeatmap extends StatelessWidget {
  const YearlyHeatmap({super.key, required this.history});

  /// date key ("yyyy-MM-dd") -> day completion percent (0..100).
  final Map<String, double> history;

  static const double _cell = 12;
  static const double _gap = 3;
  static const int _weeks = 53;
  static const double _topLabelH = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    final accent = scheme.primary;
    final empty = scheme.onSurface.withValues(alpha: 0.06);
    final labelColor = scheme.onSurfaceVariant;

    final double width = _weeks * (_cell + _gap);
    final double height = _topLabelH + 7 * (_cell + _gap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // open scrolled to the most recent (right-hand) week
          child: CustomPaint(
            size: Size(width, height),
            painter: _HeatmapPainter(
              history: history,
              accent: accent,
              empty: empty,
              labelColor: labelColor,
              locale: locale,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Legend(accent: accent, empty: empty, l10n: l10n),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.accent, required this.empty, required this.l10n});

  final Color accent;
  final Color empty;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    Widget box(Color c) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(l10n.heatmapLess, style: style),
        const SizedBox(width: 4),
        box(empty),
        box(accent.withValues(alpha: 0.30)),
        box(accent.withValues(alpha: 0.55)),
        box(accent.withValues(alpha: 0.78)),
        box(accent),
        const SizedBox(width: 4),
        Text(l10n.heatmapMore, style: style),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.history,
    required this.accent,
    required this.empty,
    required this.labelColor,
    required this.locale,
  });

  final Map<String, double> history;
  final Color accent;
  final Color empty;
  final Color labelColor;
  final String locale;

  static const double _cell = YearlyHeatmap._cell;
  static const double _gap = YearlyHeatmap._gap;
  static const double _topLabelH = YearlyHeatmap._topLabelH;

  Color _colorFor(double pct) {
    if (pct <= 0) return empty;
    if (pct < 40) return accent.withValues(alpha: 0.30);
    if (pct < 70) return accent.withValues(alpha: 0.55);
    if (pct < 100) return accent.withValues(alpha: 0.78);
    return accent;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final int todayIdx = today.weekday - 1; // Mon=0 .. Sun=6
    // Top-left cell = Monday of the week 52 weeks before the current week.
    final start = today.subtract(Duration(days: 52 * 7 + todayIdx));

    final paint = Paint()..style = PaintingStyle.fill;
    int? lastLabelMonth;

    for (int col = 0; col < YearlyHeatmap._weeks; col++) {
      for (int row = 0; row < 7; row++) {
        final date = start.add(Duration(days: col * 7 + row));
        if (date.isAfter(today)) continue; // future cells of this week: blank
        paint.color = _colorFor(history[dateKeyFromDate(date)] ?? 0.0);
        final double x = col * (_cell + _gap);
        final double y = _topLabelH + row * (_cell + _gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, _cell, _cell), const Radius.circular(2)),
          paint,
        );
      }

      // Month label above the first column that falls in a new month.
      final colDate = start.add(Duration(days: col * 7));
      if (!colDate.isAfter(today) && colDate.month != lastLabelMonth) {
        lastLabelMonth = colDate.month;
        _drawLabel(canvas, DateFormat.MMM(locale).format(colDate),
            col * (_cell + _gap));
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, double x) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, 0));
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.history != history ||
      old.accent != accent ||
      old.empty != empty ||
      old.labelColor != labelColor ||
      old.locale != locale;
}
