import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/habit_service.dart';
import '../services/theme_service.dart';

/// One-shot "What's new" dialog shown at startup after an update, so existing
/// users learn about new features. It is keyed by a feature-set [_version]
/// (not the build number) stored in [_prefKey]: bump [_version] whenever there
/// is something new to announce.
///
/// It is shown only ONCE per [_version], and only to existing users (someone
/// who already has habits) — a brand-new install is not interrupted; its flag
/// is set silently so it won't see a retroactive announcement.
class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  /// Bump when there is a new feature set to announce.
  static const int _version = 1;
  static const String _prefKey = 'whats_new_seen_version';

  /// Shows the dialog once per [_version] for existing users. Safe to call on
  /// every startup; a no-op when already seen or on a fresh install.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_prefKey);
    if (seen == _version) return;

    // Brand-new install (no habits yet): don't interrupt onboarding with an
    // announcement of features they're seeing for the first time. Mark it seen
    // so it never appears retroactively for them.
    final habits = await HabitService.loadHabits();
    if (habits.isEmpty) {
      await prefs.setInt(_prefKey, _version);
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WhatsNewDialog(),
    );
    await prefs.setInt(_prefKey, _version);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget item(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );

    return AlertDialog(
      backgroundColor: context.palette.card,
      title: Text(l10n.whatsNewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(Icons.event_busy_outlined, l10n.whatsNewPauseTitle,
                l10n.whatsNewPauseBody),
            item(Icons.flag_outlined, l10n.whatsNewGoalTitle,
                l10n.whatsNewGoalBody),
            item(Icons.widgets_outlined, l10n.whatsNewWidgetTitle,
                l10n.whatsNewWidgetBody),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.whatsNewGotIt),
        ),
      ],
    );
  }
}
