import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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

  // Product ids are language-independent; the displayed name/period are
  // resolved from l10n in build().
  static const _productIds = ['habits_monthly', 'habits_yearly', 'habits_lifetime'];

  List<(IconData, String)> _features(AppLocalizations l10n) => [
        (Icons.all_inclusive, l10n.paywallFeatureUnlimited),
        (Icons.dashboard_customize, l10n.paywallFeatureTemplates),
        (Icons.bolt, l10n.paywallFeatureXp),
        (Icons.bar_chart, l10n.paywallFeatureStats),
        (Icons.block, l10n.paywallFeatureNoAds),
      ];

  List<_Plan> _plansFor(AppLocalizations l10n) => [
        _Plan(l10n.planMonthly, '\$1.99', l10n.perMonth, 'habits_monthly', false),
        _Plan(l10n.planYearly, '\$9.99', l10n.perYear, 'habits_yearly', true),
        _Plan(l10n.planLifetime, '\$24.99', l10n.oneTime, 'habits_lifetime', false),
      ];

  Future<void> _purchase() async {
    setState(() => _loading = true);
    final productId = _productIds[_selected];
    final success = await PurchaseService.instance.purchase(productId);
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).purchaseAfterPublish),
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
        SnackBar(content: Text(AppLocalizations.of(context).purchasesChecked)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    final features = _features(l10n);
    final plans = _plansFor(l10n);
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
              l10n.paywallTagline,
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
                children: features
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
            ...List.generate(plans.length, (i) {
              final plan = plans[i];
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
                                  child: Text(
                                    l10n.popular,
                                    style: const TextStyle(
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
                    : Text(
                        l10n.continuePremium,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : _restore,
              child: Text(
                l10n.restorePurchase,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cancelAnytime,
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
