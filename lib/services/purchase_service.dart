import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles the one-time "remove ads" purchase via Google Play / App Store.
///
/// Premium features are currently open to everyone ([isPremium] is always
/// true). The only paid thing is removing the banner ads ([isAdFree]), bought
/// once as a non-consumable product, or unlocked with the owner promo code.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  /// Google Play / App Store product id for the one-time "remove ads" purchase.
  /// Create this as a non-consumable / managed product in the consoles.
  static const String kRemoveAdsProductId = 'remove_ads';
  static const String _adsRemovedKey = 'ads_removed';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  // ── Ad-free state ───────────────────────────────────────────────
  bool _adFree = false;
  bool get isAdFree => _adFree;

  /// Notifies the UI (banner + buttons) when ads get removed so it can hide
  /// them without a manual refresh.
  final ValueNotifier<bool> adFreeNotifier = ValueNotifier<bool>(false);

  // ── Store product ───────────────────────────────────────────────
  ProductDetails? _removeAdsProduct;

  /// Localised price string from the store (e.g. "2,29 лв."), or null until
  /// the product details have loaded.
  String? get removeAdsPrice => _removeAdsProduct?.price;

  /// Premium is disabled for now — everyone gets full functionality.
  /// To re-enable premium gating later, give this its own persisted flag.
  bool get isPremium => true;

  // ── Lifecycle ───────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _adFree = _readAdFree(prefs);
    adFreeNotifier.value = _adFree;
  }

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    _adFree = _readAdFree(prefs);
    adFreeNotifier.value = _adFree;
  }

  // Ads are off if removed via purchase/promo, OR if the user previously held
  // the legacy "premium" flag (older builds where the IVA code unlocked
  // premium) — those users keep their ad-free perk.
  bool _readAdFree(SharedPreferences prefs) =>
      (prefs.getBool(_adsRemovedKey) ?? false) ||
      (prefs.getBool('is_premium') ?? false);

  /// Connects to the store, listens for purchase updates, loads the product
  /// and silently restores a previous purchase. Safe to call once at startup;
  /// a no-op when the store is unavailable (emulator without Play, desktop…).
  Future<void> initIap() async {
    bool available = false;
    try {
      available = await _iap.isAvailable();
    } catch (_) {
      return;
    }
    if (!available) return;

    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {},
    );
    await _loadProducts();
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final resp =
          await _iap.queryProductDetails({kRemoveAdsProductId});
      if (resp.productDetails.isNotEmpty) {
        _removeAdsProduct = resp.productDetails.first;
      }
      // A "not found" id means the product isn't created/active in the store
      // (or the build isn't a Play-signed track) → buyRemoveAds() will fail
      // silently. Surface it in debug so it's diagnosable, not a mystery.
      if (kDebugMode && resp.notFoundIDs.isNotEmpty) {
        debugPrint('IAP: product(s) not found: ${resp.notFoundIDs} — '
            'create/activate "$kRemoveAdsProductId" in the store and test '
            'from a Play track with a licensed account.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('IAP: queryProductDetails failed: $e');
    }
  }

  /// Launches the platform purchase sheet for "remove ads".
  /// Returns false if the product isn't available to buy right now.
  Future<bool> buyRemoveAds() async {
    final product = _removeAdsProduct;
    if (product == null) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == kRemoveAdsProductId &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored)) {
        await _grantAdFree();
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  Future<void> _grantAdFree() async {
    _adFree = true;
    adFreeNotifier.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, true);
  }

  /// Manual restore triggered from the UI ("restore purchases").
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  // ── Owner promo code ────────────────────────────────────────────
  // Single deliberate code that removes ads for life (works in release too).
  static const String _lifetimeCode = 'IVA';

  Future<bool> redeemPromoCode(String code) async {
    if (code.trim().toUpperCase() != _lifetimeCode) return false;
    await _grantAdFree();
    return true;
  }

  /// Debug helper: remove ads locally for testing. No-op in release builds.
  Future<void> debugUnlock() async {
    if (!kDebugMode) return;
    await _grantAdFree();
  }

  void dispose() {
    _sub?.cancel();
  }
}
