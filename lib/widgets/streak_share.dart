import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

// Smart redirect (taskify1969.com/n → App Store id6806278691 на iOS, Google Play
// com.ivoexp.habits на Android). Ползва се от бутона „Копирай линк". НЕ се подава
// в text: на share-а — иначе Stories отказва картинката с „Link cannot be shared
// to your story". utm_source=streak_card отделя този трафик.
const String _shareUrl = 'https://taskify1969.com/n?utm_source=streak_card';

// Спокойна дуотон палитра — тъмен ink фон + един студен акцент (без пъстрота).
const Color _ink0 = Color(0xFF0E1420); // горе
const Color _ink1 = Color(0xFF06090F); // долу
const Color _accentA = Color(0xFF22D3EE); // циан
const Color _accentB = Color(0xFF34E0C0); // мента

/// Карта за Stories — проектирана 360×640, заснема се ×3 → 1080×1920.
class StreakShareCard extends StatelessWidget {
  const StreakShareCard({super.key, required this.streak, this.habitName});

  final int streak;
  final String? habitName; // null → без име (глобална серия)

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final built = streak >= 66;
    final progress = (streak / 66).clamp(0.0, 1.0);
    final label =
        (habitName != null && habitName!.trim().isNotEmpty) ? habitName! : 'НАВИЦИ';

    return Container(
      width: 360,
      height: 640,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ink0, _ink1],
        ),
      ),
      child: Stack(
        children: [
          // Един много мек акцентен ореол зад числото — деликатен, не крещящ.
          Positioned(
            top: 210,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accentA.withValues(alpha: 0.10),
                    _accentA.withValues(alpha: 0.0),
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 56, 40, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Малък етикет горе — име на навика или марката.
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: _accentB.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                // Голямо число.
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_accentA, _accentB],
                  ).createShader(r),
                  child: Text(
                    '$streak',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontSize: 132,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                      letterSpacing: -3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.streakCardNoBreakDays, // „дни без прекъсване"
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 34),
                // Тънка лента за напредък към 66 дни.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 5,
                    color: Colors.white.withValues(alpha: 0.10),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient:
                              LinearGradient(colors: [_accentA, _accentB]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  built ? l10n.streakCardBuilt : l10n.streakCardProgress(streak),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: built
                        ? _accentB
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'taskify1969.com/n',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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

/// Малък празничен bottom sheet при кръгла серия. „Сподели" → отваря прегледа.
Future<void> showStreakMilestoneSheet(
  BuildContext context, {
  required int streak,
  String? habitName,
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
              onPressed: () async {
                Navigator.pop(ctx);
                // Изчакай да се затвори този sheet, преди да отворим прегледа
                // (иначе новият модал се състезава с анимацията и не се появява).
                await Future.delayed(const Duration(milliseconds: 250));
                if (context.mounted) {
                  showStreakSharePreview(context,
                      streak: streak, habitName: habitName);
                }
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

/// Преглед на картата + (при per-habit) превключвател „Скрий името" + „Сподели".
Future<void> showStreakSharePreview(
  BuildContext context, {
  required int streak,
  String? habitName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _StreakSharePreview(streak: streak, habitName: habitName),
  );
}

class _StreakSharePreview extends StatefulWidget {
  const _StreakSharePreview({required this.streak, this.habitName});
  final int streak;
  final String? habitName;

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
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Изчакай кадър, за да е сигурно, че RepaintBoundary е нарисуван.
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0); // 360×640 → 1080×1920
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/navici_streak.png');
      await file.writeAsBytes(bytes);
      // Само текстов надпис — БЕЗ линк. Линкът пътува през QR кода и нарисувания
      // текст върху самата картинка; URL в text: кара Stories да откаже картинката.
      final text = l10n.streakShareBody(widget.streak);
      // sharePositionOrigin е задължителен на iPad (иначе гърми/не показва нищо);
      // безвреден на iPhone.
      final box = context.findRenderObject() as RenderBox?;
      final origin = (box != null && box.hasSize)
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      debugPrint('streak share failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasName =
        widget.habitName != null && widget.habitName!.trim().isNotEmpty;
    final maxH = MediaQuery.of(context).size.height * 0.52;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // По-компактен преглед: картата се показва умалено (заснема се
          // оригиналният 360×640 RepaintBoundary при пълна резолюция).
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: FittedBox(
              fit: BoxFit.contain,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: StreakShareCard(
                    streak: widget.streak,
                    habitName:
                        (hasName && !_hideName) ? widget.habitName : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hasName)
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
          const SizedBox(height: 8),
          // Линкът НЕ влиза в споделената картинка/текст (Stories го отказва) —
          // този бутон го копира, за да се прати в чат ръчно при желание.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.link, size: 18),
              label: Text(l10n.streakCopyLink),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLink() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: _shareUrl));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.streakLinkCopied)));
  }
}
