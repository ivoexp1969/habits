import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A small adaptive-height AdMob banner. Renders nothing until the ad has
/// loaded (so there's no empty gap) and on platforms without AdMob support.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  /// AdMob banner ad-unit ids. In debug builds we use Google's official TEST
  /// units (always fill, safe to tap); release builds use this app's real
  /// units. Tapping your own live ads can get the AdMob account banned, and a
  /// brand-new real unit serves no ads for hours — hence test ads in debug.
  static String get _bannerUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111' // Android test banner
          : 'ca-app-pub-4385157735120275/2222728831'; // Android real
    }
    return kDebugMode
        ? 'ca-app-pub-3940256099942544/2934735716' // iOS test banner
        : 'ca-app-pub-4385157735120275/7184511557'; // iOS real
  }

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_supported) _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
