import 'package:flutter/material.dart';

import '../services/purchase_service.dart';

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
    (Icons.timer_outlined, 'Pomodoro таймер'),
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
    final success = await PurchaseService.instance.restore();
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✓ Покупката е възстановена!' : 'Няма налична покупка.',
          ),
        ),
      );
      if (success) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
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
            const Text(
              'Habits Premium',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Постигни повече всеки ден',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Feature list
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111318),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2D36)),
              ),
              child: Column(
                children: _features
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(f.$1,
                                size: 18,
                                color: const Color(0xFF00E5FF)),
                            const SizedBox(width: 10),
                            Text(
                              f.$2,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
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
                          ? const Color(0xFF00E5FF).withOpacity(0.07)
                          : const Color(0xFF111318),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF2A2D36),
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
                                ? const Color(0xFF00E5FF)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white24,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 12, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Name + popular badge
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                plan.name,
                                style: const TextStyle(
                                  color: Colors.white,
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
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFFFD740)
                                          .withOpacity(0.5),
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
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              plan.period,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white38),
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
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
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
              child: const Text(
                'Възстанови покупка',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Анулиране по всяко време от Google Play.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11),
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
