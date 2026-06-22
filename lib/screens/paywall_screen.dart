import 'package:flutter/material.dart';

import '../services/purchase_service.dart';
import '../services/theme_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selected = 1; // 0=monthly 1=yearly 2=lifetime
  bool _loading = false;

  static const _features = [
    (Icons.all_inclusive, 'Неограничени навици'),
    (Icons.dashboard_customize, 'Всички шаблони'),
    (Icons.bolt, 'XP система и постижения'),
    (Icons.bar_chart, 'Детайлна статистика'),
    (Icons.block, 'Без реклами'),
  ];

  static const _plans = [
    _Plan('Месечен', '\$1.99', '/месец', 'habits_monthly', false),
    _Plan('Годишен', '\$9.99', '/година', 'habits_yearly', true),
    _Plan('Lifetime', '\$24.99', 'еднократно', 'habits_lifetime', false),
  ];

  Future<void> _purchase() async {
    setState(() => _loading = true);
    final productId = _plans[_selected].productId;
    final success = await PurchaseService.instance.purchase(productId);
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Покупките ще бъдат активни след публикуване в Play Store.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    await PurchaseService.instance.restore();
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Покупките са проверени.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          children: [
            // Hero
            const Text('💎', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 10),
            Text(
              'Habits Premium',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Постигни повече всеки ден',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Feature list
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: _features
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(f.$1, size: 18, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              f.$2,
                              style: TextStyle(
                                  color: scheme.onSurface, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Pricing cards
            ...List.generate(_plans.length, (i) {
              final plan = _plans[i];
              final isSelected = i == _selected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.07)
                          : palette.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary
                            : palette.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio dot
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? scheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.check,
                                  size: 12, color: scheme.onPrimary)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Name + popular badge
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                plan.name,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (plan.popular) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD740)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFFFD740)
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'Популярен',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFFFD740),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan.price,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              plan.period,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 6),

            // CTA button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _purchase,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'Продължи с Premium',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : _restore,
              child: Text(
                'Възстанови покупка',
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Анулиране по всяко време от Google Play.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  const _Plan(
      this.name, this.price, this.period, this.productId, this.popular);
  final String name;
  final String price;
  final String period;
  final String productId;
  final bool popular;
}
