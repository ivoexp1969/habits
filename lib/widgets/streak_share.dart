import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

/// Кръгли серии, при които предлагаме споделяне: 7, 14, 21, 30, 50, 66, 100,
/// после на всеки 50 дни (150, 200, ...).
bool isStreakMilestone(int n) {
  const fixed = {7, 14, 21, 30, 50, 66, 100};
  if (fixed.contains(n)) return true;
  return n > 100 && n % 50 == 0;
}

const String _shareUrl =
    'https://taskify1969.com/n?utm_source=share&utm_medium=streak_card&utm_campaign=navici_share';

// Бранд цветове (фиксирани, за да изглежда картата еднакво при споделяне,
// независимо от светла/тъмна тема).
const Color _bg = Color(0xFF0B0E14);
const Color _cyan = Color(0xFF00E5FF);
const Color _purple = Color(0xFF7C4DFF);
const Color _pink = Color(0xFFFF2D95);

/// Карта за Stories (проектирана 360×640 → заснема се ×3 → 1080×1920).
class StreakShareCard extends StatelessWidget {
  const StreakShareCard({super.key, required this.streak, this.habitName});

  final int streak;
  final String? habitName; // null → скрито име

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final built = streak >= 66;
    final progress = (streak / 66).clamp(0.0, 1.0);
    return Container(
      width: 360,
      height: 640,
      decoration: const BoxDecoration(
        color: _bg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0E14), Color(0xFF141A2A), Color(0xFF0B0E14)],
        ),
      ),
      child: Stack(
        children: [
          // мек цветен ореол горе
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyan.withValues(alpha: 0.35), _bg.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 54, 34, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (habitName != null && habitName!.trim().isNotEmpty)
                  Text(
                    habitName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                // Голямо „Ден {n}"
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [_cyan, _purple, _pink],
                  ).createShader(r),
                  child: Text(
                    l10n.streakCardDay(streak),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.streakCardNoBreak,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                // Лента за напредък към 66 дни
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 12,
                    color: Colors.white.withValues(alpha: 0.12),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [_cyan, _purple, _pink]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  built ? l10n.streakCardBuilt : l10n.streakCardProgress(streak),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: built ? _cyan : Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Навици · taskify1969.com/n',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Малък празничен bottom sheet при кръгла серия. „Сподели" → отваря прегледа;
/// „Затвори" — просто затваря. (Молбата за оценка се пропуска, когато този се
/// показва — извикващият се грижи за това.)
Future<void> showStreakMilestoneSheet(
  BuildContext context, {
  required int streak,
  required String habitName,
}) async {
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            l10n.streakMilestoneTitle(streak),
            textAlign: TextAlign.center,
            style: Theme.of(ctx)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showStreakSharePreview(context,
                    streak: streak, habitName: habitName);
              },
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.commonShare),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    ),
  );
}

/// Преглед на картата + превключвател „Скрий името" + бутон „Сподели".
Future<void> showStreakSharePreview(
  BuildContext context, {
  required int streak,
  required String habitName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _StreakSharePreview(streak: streak, habitName: habitName),
  );
}

class _StreakSharePreview extends StatefulWidget {
  const _StreakSharePreview({required this.streak, required this.habitName});
  final int streak;
  final String habitName;

  @override
  State<_StreakSharePreview> createState() => _StreakSharePreviewState();
}

class _StreakSharePreviewState extends State<_StreakSharePreview> {
  final GlobalKey _cardKey = GlobalKey();
  bool _hideName = false;
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = AppLocalizations.of(context);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0); // 360×640 → 1080×1920
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/navici_streak.png');
      await file.writeAsBytes(bytes);
      final text = '${l10n.streakShareBody(widget.streak)}\n$_shareUrl';
      await Share.shareXFiles([XFile(file.path)], text: text);
    } catch (_) {
      // тихо — споделянето е по избор
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Преглед на картата (заснема се точно този RepaintBoundary).
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: _cardKey,
                child: StreakShareCard(
                  streak: widget.streak,
                  habitName: _hideName ? null : widget.habitName,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _hideName,
            onChanged: (v) => setState(() => _hideName = v),
            title: Text(l10n.streakHideName),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.commonShare),
            ),
          ),
        ],
      ),
    );
  }
}
