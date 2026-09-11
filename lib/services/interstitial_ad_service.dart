import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'habit_service.dart';
import 'purchase_service.dart';

/// A single, conservative interstitial ad shown at most once per calendar day,
/// only after the user has completed their WHOLE daily programme (and after the
/// reward animation), and never in the first [_minDaysSinceInstall] days.
///
/// The ad is preloaded ahead of time; if it isn't ready at the moment it would
/// show, it is simply skipped — it never blocks the flow.
class InterstitialAdService {
  InterstitialAdService._();
  static final InterstitialAdService instance = InterstitialAdService._();

  static const String _prefFirstLaunch = 'first_launch_date';
  static const String _prefLastShown = 'last_interstitial_date';
  static const int _minDaysSinceInstall = 5;

  InterstitialAd? _ad;
  bool _loading = false;

  /// Debug builds use Google's official TEST interstitial units (always fill,
  /// safe to tap); release builds use this app's real units. Tapping your own
  /// live ads can get the AdMob account banned — hence test ads in debug.
  static String get _adUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712' // Android test interstitial
          : 'ca-app-pub-4385157735120275/7289359232'; // Android real
    }
    return kDebugMode
        ? 'ca-app-pub-3940256099942544/4411468910' // iOS test interstitial
        : 'ca-app-pub-4385157735120275/6564164021'; // iOS real
  }

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  bool get isReady => _ad != null;

  /// Loads one interstitial into [_ad] if none is loaded/loading. Safe to call
  /// repeatedly; a no-op when unsupported, already loaded, or in flight. Call
  /// once the ad SDK is initialised and only for non-paying users.
  void preload() {
    if (!_supported || _ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ad = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              preload(); // keep one ready for a future day
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _ad = null;
              preload();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          _ad = null;
        },
      ),
    );
  }

  /// Records today's date as the first-launch date the first time it is called
  /// (so "days since install" can be computed). Called at startup.
  static Future<void> ensureFirstLaunchRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_prefFirstLaunch)) {
      await prefs.setString(
          _prefFirstLaunch, DateTime.now().toIso8601String());
    }
  }

  /// Shows the interstitial IF every gate passes: not ad-free, an ad is
  /// preloaded, at least [_minDaysSinceInstall] calendar days since install,
  /// and none shown yet today. Otherwise a silent no-op (never blocks).
  /// Records today's date as "shown" when it does show.
  Future<void> maybeShowAfterDailyComplete() async {
    if (!_supported) return;
    if (PurchaseService.instance.isAdFree) return;
    if (_ad == null) return; // not preloaded in time → skip, no blocking

    final prefs = await SharedPreferences.getInstance();

    // (A) at least 5 calendar days since first launch.
    final firstStr = prefs.getString(_prefFirstLaunch);
    if (firstStr == null) return;
    final first = DateTime.tryParse(firstStr);
    if (first == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(first.year, first.month, first.day);
    if (today.difference(firstDay).inDays < _minDaysSinceInstall) return;

    // once per calendar day.
    final todayKey = dateKeyFromDate(today);
    if (prefs.getString(_prefLastShown) == todayKey) return;

    // Show and record it (count the attempt as today's showing).
    final ad = _ad;
    _ad = null;
    await prefs.setString(_prefLastShown, todayKey);
    ad!.show();
  }
}
