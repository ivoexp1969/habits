import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cross-promotion of our other 1969 app — Taskify (tasks & reminders).
///
/// Mirrors Taskify's own „Навици" companion promo, reversed:
///   • Android: detect via `installed_apps` (+ `<package>` in the manifest's
///     `<queries>`, so we never need QUERY_ALL_PACKAGES). Open if installed,
///     else Play Store with a UTM referrer.
///   • iOS: Taskify declares no custom URL scheme, so there is no way to detect
///     it → the card always shows and simply links to the App Store.
///
/// Singleton, like the app's other services. No analytics (this app has none).
class CompanionAppService {
  static final CompanionAppService _instance = CompanionAppService._();
  factory CompanionAppService() => _instance;
  CompanionAppService._();

  static const String taskifyAndroidPackage = 'com.ivoexp.taskify';
  static const String taskifyIOSAppId = '6768345070';

  /// Whether Taskify is installed. Android only; false on iOS/web (no scheme
  /// to probe), which keeps the promo card visible there.
  Future<bool> isTaskifyInstalled() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final installed =
          await InstalledApps.isAppInstalled(taskifyAndroidPackage);
      return installed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Taskify if installed (Android), otherwise the platform's store page.
  Future<void> openOrInstall() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      try {
        if (await isTaskifyInstalled()) {
          final ok = await InstalledApps.startApp(taskifyAndroidPackage);
          if (ok == true) return;
        }
      } catch (_) {
        // fall through to the Play Store below
      }
      await _openPlayStore();
    } else if (Platform.isIOS) {
      await _openAppStore();
    }
  }

  Future<void> _openPlayStore() async {
    final url =
        'https://play.google.com/store/apps/details?id=$taskifyAndroidPackage'
        '&referrer=utm_source%3Dnavici%26utm_medium%3Din_app%26utm_campaign%3Dcross_promo';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openAppStore() async {
    const url = 'https://apps.apple.com/app/id$taskifyIOSAppId';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
