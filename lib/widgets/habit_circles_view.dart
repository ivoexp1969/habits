import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../services/theme_service.dart';

/// The "Circles" home layout: a grid of fill-up circles, one per habit.
///
/// Presentation only — the check-in / undo logic is NOT duplicated here. Every
/// tap calls back into the SAME [onIncrement] / [onDecrement] the standard list
/// uses (HomeScreenState._incrementHabit / _decrementHabit via the home screen).
class HabitCirclesView extends StatelessWidget {
  const HabitCirclesView({
    super.key,
    required this.habits,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
    required this.onAtomic,
    required this.onShareStreak,
    required this.showHint,
    required this.onDismissHint,
  });

  final List<Habit> habits;
  final void Function(Habit) onIncrement;
  final void Function(Habit) onDecrement;
  // Long-press actions — the SAME handlers the standard card's "⋮" menu uses.
  final void Function(Habit) onEdit;
  final void Function(Habit) onDelete;
  final void Function(Habit) onAtomic;
  final void Function(Habit) onShareStreak;
  // First-run coach strip; hidden once the user dismisses it (persisted by the
  // home screen).
  final bool showHint;
  final VoidCallback onDismissHint;

  @override
  Widget build(BuildContext context) {
    // Layout: 1 habit → one big centred circle; 2+ → a fixed TWO-column grid
    // (bigger circles = easier tap), scrolling as needed. Diameter is derived
    // from the actual column width so the circles use the space sensibly.
    final int cols = habits.length <= 1 ? 1 : 2;
    const double hPad = 8; // 4 left + 4 right (GridView padding)
    const double spacing = 10; // crossAxisSpacing between columns

    return Column(
      children: [
        if (showHint) _CirclesHint(onDismiss: onDismissHint),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double usable =
                  constraints.maxWidth - hPad - spacing * (cols - 1);
              final double cellW = usable / cols;
              // A touch smaller than the cell so there's margin around the
              // circle; capped so a lone circle isn't oversized.
              final double diameter = math.min(
                cellW * (cols == 1 ? 0.6 : 0.82),
                150.0,
              );
              return GridView.builder(
                padding: EdgeInsets.fromLTRB(4, showHint ? 4 : 2, 4, 90),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  // Fixed cell HEIGHT (circle + gap + up-to-2-line name).
                  mainAxisExtent: diameter + 46,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 16,
                ),
                itemCount: habits.length,
                itemBuilder: (context, i) {
                  final habit = habits[i];
                  return _HabitCircleTile(
                    habit: habit,
                    diameter: diameter,
                    onIncrement: () => onIncrement(habit),
                    onDecrement: () => onDecrement(habit),
                    onEdit: () => onEdit(habit),
                    onDelete: () => onDelete(habit),
                    onAtomic: () => onAtomic(habit),
                    onShareStreak: () => onShareStreak(habit),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// First-run coaching strip for the Circles view. Two short l10n lines + a
/// dismiss. Deliberately quiet; disappears for good once dismissed.
class _CirclesHint extends StatelessWidget {
  const _CirclesHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: context.palette.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.circlesHintTap,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.circlesHintAtomic,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: scheme.primary,
            ),
            child: Text(
              l10n.circlesHintGotIt,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One habit as a fill-up circle. Stateful only for the local animations
/// (fill, +1 bounce, spark pulse, partial-fill shimmer) — never for the habit
/// data, which stays owned by the home screen.
class _HabitCircleTile extends StatefulWidget {
  const _HabitCircleTile({
    required this.habit,
    required this.diameter,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
    required this.onAtomic,
    required this.onShareStreak,
  });

  final Habit habit;
  final double diameter;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAtomic;
  final VoidCallback onShareStreak;

  @override
  State<_HabitCircleTile> createState() => _HabitCircleTileState();
}

class _HabitCircleTileState extends State<_HabitCircleTile>
    with TickerProviderStateMixin {
  // Repeating ambient animation driving the spark pulse and the surface
  // shimmer. Only runs when the OS isn't set to reduce motion.
  late final AnimationController _ambient;
  // One-shot "pop" played when a check-in raises the fill.
  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;

  // Progress at the previous build, so we can tell an increment (fill rose)
  // from an undo (fill dropped) even though the Habit is mutated in place.
  late double _prevProgress = widget.habit.progress;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.14)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 45),
      TweenSequenceItem(
          tween: Tween(begin: 1.14, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 55),
    ]).animate(_bounce);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _reduced = reduce;
    if (reduce) {
      if (_ambient.isAnimating) _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void didUpdateWidget(_HabitCircleTile old) {
    super.didUpdateWidget(old);
    final now = widget.habit.progress;
    // A check-in that raised the fill → pop. An undo just lets the fill fall.
    if (now > _prevProgress && !_reduced) {
      _bounce.forward(from: 0);
    }
    _prevProgress = now;
  }

  @override
  void dispose() {
    _ambient.dispose();
    _bounce.dispose();
    super.dispose();
  }

  // A brighter, more saturated variant used for the top of the fill gradient
  // (same idea as the standard card's vivid stop: shift lightness via HSL
  // instead of mixing toward white, so the colour stays vivid).
  static Color _vivid(Color c) {
    final h = HSLColor.fromColor(c);
    return h
        .withSaturation((h.saturation + 0.25).clamp(0.0, 1.0))
        .withLightness((h.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
  }

  // A lighter variant via HSL lightness — used for the empty-circle icon/inner
  // atomic ring so the colour stays identifiable without washing to white.
  static Color _lighten(Color c, double amount) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  void _handleTap() {
    final habit = widget.habit;
    // Тап НАВСЯКЪДЕ по кръга = +1 (shared increment), докато не се стигне max.
    // При достигнат max → нищо (не цикли към 0). Намаляването (−1, рядко) е през
    // long-press менюто. A goal keeps "+" open past the period cap.
    if (habit.completedTimes < habit.timesPerDay || habit.hasGoal) {
      widget.onIncrement();
    }
  }

  // Long-press opens the same actions the standard card exposes via its "⋮"
  // menu (edit / share / atomic / delete), so no capability is lost in the
  // Circles view. Each action just forwards to the shared handler.
  void _handleLongPress() {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final habit = widget.habit;
    final baseColor = habit.color ?? scheme.primary;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Icon(habit.icon ?? Icons.check_circle,
                        size: 20, color: baseColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Намаляване (−1) — рядко, затова е тук, а не на самия кръг (тап =
              // +1). Показва се само ако има какво да се върне. Ползва СЪЩИЯ
              // decrement callback като стандартната карта.
              if (habit.completedTimes > 0)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(l10n.circlesReduce),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    widget.onDecrement();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editMenu),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.onEdit();
                },
              ),
              ListTile(
                leading: Icon(Icons.ios_share, color: scheme.primary),
                title: Text(l10n.streakShareMenu),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.onShareStreak();
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome, color: scheme.primary),
                title: Text(l10n.atomicMenu),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.onAtomic();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(l10n.deleteMenu),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habit = widget.habit;
    final d = widget.diameter;
    final baseColor = habit.color ?? scheme.primary;
    final progress = habit.progress;
    final isCompleted = habit.isCompleted;
    final showShimmer = !_reduced && progress > 0.02 && progress < 0.98;
    // Празен кръг — лек радиален градиент от цвета на навика (център) към фона
    // (ръбове), за да оживее вместо почти-черно. Към тъмно (тъмна тема) / светло
    // (светла). Иконата е вариант на цвета на навика, четим в двете теми.
    final emptyEdge = isDark ? const Color(0xFF0C0E13) : const Color(0xFFF2F0EA);
    final iconColor = isDark
        ? _lighten(baseColor, 0.22)
        : HSLColor.fromColor(baseColor)
            .withLightness(
                (HSLColor.fromColor(baseColor).lightness - 0.22).clamp(0.0, 1.0))
            .toColor();

    final circle = SizedBox(
      width: d,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tappable circle body: tint + outline, bottom-up fill, glyph.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Живо празно състояние: радиален градиент от цвета на навика
                // (център) към фона (ръбове) + по-наситен цветен контур; glow
                // при завършен.
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        baseColor.withValues(alpha: isDark ? 0.28 : 0.22),
                        emptyEdge,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                    border: Border.all(
                      color: baseColor
                          .withValues(alpha: isCompleted ? 0.95 : 0.8),
                      width: 3,
                    ),
                    boxShadow: isCompleted
                        ? [
                            BoxShadow(
                              color: baseColor.withValues(alpha: 0.5),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                // Атомно отличие — втори, вътрешен пръстен в по-светъл вариант на
                // цвета (inset ~4px, лека прозрачност). Заменя старата светеща
                // точка. Обикновените навици нямат този пръстен.
                if (habit.isAtomic)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _lighten(baseColor, 0.2)
                              .withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                // Bottom → top fill, clipped to the circle and animated so a
                // check-in rises and an undo falls smoothly.
                ClipOval(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: Duration(milliseconds: _reduced ? 0 : 320),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: value.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  baseColor.withValues(alpha: 0.85),
                                  _vivid(baseColor).withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Subtle living "wave" at the fill surface — only while the
                // circle is partially filled and motion isn't reduced.
                if (showShimmer)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipOval(
                        child: AnimatedBuilder(
                          animation: _ambient,
                          builder: (context, _) {
                            final s =
                                (math.sin(_ambient.value * 2 * math.pi) + 1) / 2;
                            return Align(
                              // Map the fill top (fraction 1−progress from the
                              // top) to Alignment.y ∈ [−1, 1].
                              alignment: Alignment(0, 1 - 2 * progress),
                              child: Container(
                                height: 3,
                                color: Colors.white
                                    .withValues(alpha: 0.12 + 0.18 * s),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // Иконата е вариант на цвета на навика (светъл в тъмна тема /
                // тъмен в светла), с лек glow от същия цвят — четима и над
                // празния фон, и над запълването.
                Center(
                  child: Icon(
                    habit.icon ?? Icons.check_circle,
                    size: d * 0.34,
                    color: iconColor,
                    shadows: [
                      Shadow(
                        color: baseColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                // cur / max inside the bottom — only for multi-count habits.
                if (habit.timesPerDay > 1)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: d * 0.11),
                      child: Text(
                        '${habit.completedTimes}/${habit.timesPerDay}',
                        style: TextStyle(
                          fontSize: d * 0.14,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Streak — top-right, always with the number.
          if (habit.streak > 0)
            Positioned(
              top: -4,
              right: -4,
              child: _CornerBadge(
                child: Text(
                  '🔥 ${habit.streak}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF57C00),
                  ),
                ),
              ),
            ),
          // (Атомното отличие вече е вътрешният двоен пръстен в самия кръг —
          // старата светеща точка горе-ляво е премахната, за да няма два знака.)
          // Reward — bottom-right 🎁 icon only; full text via tooltip on hold.
          if (habit.rewardAfter != null)
            Positioned(
              bottom: -2,
              right: -2,
              child: Tooltip(
                message: habit.rewardAfter!,
                child: _CornerBadge(
                  child: const Text('🎁', style: TextStyle(fontSize: 11)),
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The +1 pop scales the whole circle.
        ScaleTransition(scale: _bounceScale, child: circle),
        const SizedBox(height: 6),
        Flexible(
          child: Text(
            habit.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// A small rounded chip used for the corner badges (streak, reward) so they
/// read clearly over the circle and the background in both themes.
class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.border),
      ),
      child: child,
    );
  }
}
