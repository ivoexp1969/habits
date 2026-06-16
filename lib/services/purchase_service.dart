import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Free limit ────────────────────────────────────────────────────
const int kFreeHabitLimit = 5;

// ── Purchase service stub ─────────────────────────────────────────
// TODO: Integrate RevenueCat when API key is ready:
//   1. Add purchases_flutter to pubspec.yaml
//   2. Replace stub methods with real RevenueCat calls
//   3. Set kRcAndroidKey below
//
// const String kRcAndroidKey = 'YOUR_REVENUECAT_ANDROID_API_KEY';

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  bool _premium = false;
  bool get isPremium => _premium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _premium = prefs.getBool('is_premium') ?? false;
  }

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    _premium = prefs.getBool('is_premium') ?? false;
  }

  // Returns false — stub. Real implementation sends to RevenueCat.
  Future<bool> purchase(String productId) async => false;

  // Returns false — stub.
  Future<bool> restore() async => false;

  // Debug helper: unlock premium locally for testing.
  // No-op in release builds so it can never be used to bypass payment.
  Future<void> debugUnlock() async {
    if (!kDebugMode) return;
    _premium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
  }
}
