import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/l10n/app_localizations.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/widgets/habit_circles_view.dart';

/// 5b-iv: the Circles view must render the COMPUTED streak (passed by the home
/// screen from the map), not the habit's stored streak field.
void main() {
  testWidgets('Circles tile shows the passed-in (map-derived) streak',
      (tester) async {
    // Stored streak is a stale 99; the computed value passed in is 7.
    final h = Habit(
        id: 'a',
        name: 'A',
        timesPerDay: 1,
        frequencyUnit: 'day',
        createdAt: DateTime(2026, 1, 1));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HabitCirclesView(
          habits: [h],
          onIncrement: (_) {},
          onDecrement: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
          onAtomic: (_) {},
          onShareStreak: (_) {},
          count: (_) => 0,
          completed: (_) => false,
          progress: (_) => 0.0,
          streak: (_) => 7,
          showHint: false,
          onDismissHint: () {},
        ),
      ),
    ));
    // The tile has an infinite ambient animation, so pump a frame rather than
    // pumpAndSettle (which would never settle).
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('🔥 7'), findsOneWidget);
    expect(find.text('🔥 99'), findsNothing);
  });
}
