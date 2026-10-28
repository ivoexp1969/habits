import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, privacy-first wrapper around Firebase Analytics for Навици.
///
/// PRIVACY RULES (enforced by only exposing the typed helpers below):
///  • Events NEVER carry a habit name, note, identity text, reward text, a user
///    id, or any free text — only aggregate booleans/counts/enums
///    (habit_count, is_atomic, streak_days, share_target, source).
///  • Firebase Analytics parameters accept only String/num, so booleans are sent
///    as 1/0.
///
/// AD / CONSENT POSTURE:
///  • Consent defaults are DENIED for all ad signals and granted only for
///    analytics storage — set here via setConsent() AND, so they apply before
///    the first event even fires, as default-consent flags in AndroidManifest /
///    Info.plist (google_analytics_default_allow_*).
///  • On iOS the pod is built WithoutAdIdSupport (no IDFA access) via
///    `$FirebaseAnalyticsWithoutAdIdSupport = true` in ios/Podfile, so Analytics
///    requires no App Tracking Transparency prompt. On Android the Advertising
///    ID is likewise disabled (google_analytics_adid_collection_enabled=false).
///
/// LIFECYCLE: [init] runs AFTER the first frame (from
/// RootNavigation._initBackgroundServices), never on the startup critical path.
/// It is safe to call even if Firebase failed to initialise — analytics then
/// simply stays disabled and every log is a no-op.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Pref: the user's "Anonymous statistics" opt-out toggle (Settings →
  /// Privacy). ON by default — there is no UMP/consent dialog in the app, so
  /// this switch IS the analytics-storage consent control. Turning it off stops
  /// all collection (incl. app_open) and sets analytics_storage = denied.
  static const String kPrefsAnalyticsEnabled = 'analytics_enabled';

  FirebaseAnalytics? _fa;
  bool _ready = false;

  /// Reads the toggle (default true) without needing the SDK — used by the
  /// Settings UI to show the switch's initial state.
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kPrefsAnalyticsEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      final enabled = await isEnabled();
      final fa = FirebaseAnalytics.instance;
      await _applyConsent(fa, enabled);
      _fa = fa;
      _ready = true;
    } catch (e) {
      debugPrint('Analytics init skipped: $e');
    }
  }

  /// Applies consent + collection to match [enabled]. Ad signals are ALWAYS
  /// denied; only analytics_storage + collection follow the user's toggle.
  Future<void> _applyConsent(FirebaseAnalytics fa, bool enabled) async {
    await fa.setConsent(
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
      analyticsStorageConsentGranted: enabled,
    );
    await fa.setAnalyticsCollectionEnabled(enabled);
  }

  /// Flips the "Anonymous statistics" toggle: persists it and applies it live
  /// (safe to call before [init] — the pref is still saved for next launch).
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefsAnalyticsEnabled, enabled);
    } catch (_) {/* best effort */}
    final fa = _fa;
    if (fa != null) {
      try {
        await _applyConsent(fa, enabled);
      } catch (_) {}
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logEvent(name: name, parameters: params);
    } catch (_) {/* analytics must never affect the app */}
  }

  // ── Typed events (aggregate only — no PII) ────────────────────────────────

  /// A habit was created. [source] is 'manual' or 'pack'.
  Future<void> habitCreated({
    required bool isAtomic,
    required int habitCount,
    required String source,
  }) =>
      _log('habit_created', {
        'is_atomic': isAtomic ? 1 : 0,
        'habit_count': habitCount,
        'source': source,
      });

  /// A habit check-in (+1) was counted.
  Future<void> habitChecked({
    required bool isAtomic,
    required int streakDays,
    required bool becameComplete,
  }) =>
      _log('habit_checked', {
        'is_atomic': isAtomic ? 1 : 0,
        'streak_days': streakDays,
        'became_complete': becameComplete ? 1 : 0,
      });

  /// The streak share card preview was opened.
  Future<void> streakCardShown({required int streakDays}) =>
      _log('streak_card_shown', {'streak_days': streakDays});

  /// The streak card was shared. [shareTarget] is 'image' or 'copy_link'.
  Future<void> streakCardShared({
    required int streakDays,
    required String shareTarget,
  }) =>
      _log('streak_card_shared', {
        'streak_days': streakDays,
        'share_target': shareTarget,
      });

  /// The optional "Atomic Habits" section was expanded in the add/edit sheet.
  Future<void> atomicSectionOpened() => _log('atomic_section_opened');
}
