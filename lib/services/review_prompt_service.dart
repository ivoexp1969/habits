import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Иска НАТИВНАТА системна оценка (`InAppReview.requestReview()`) — Google Play
/// In-App Review на Android / SKStoreReviewController на iOS, с един и същ код.
///
/// Показва се САМО когато всички условия са изпълнени (виж [maybeRequestReview]).
/// БЕЗ предварителен въпрос „харесва ли ти", БЕЗ бутони към магазина — това е
/// изискване и на Google, и на Apple. Нашите лимити са по-строги от системните.
class ReviewPromptService {
  ReviewPromptService._();
  static final ReviewPromptService instance = ReviewPromptService._();

  static const String _kFirstLaunch = 'review_first_launch_ms';
  static const String _kLastRequest = 'review_last_request_ms';
  static const String _kCount = 'review_request_count';

  static const int _minStreak = 7;
  static const int _minInstallDays = 3;
  static const int _cooldownDays = 60;
  static const int _maxRequests = 3;
  static const Duration _delay = Duration(milliseconds: 1500);

  final InAppReview _inAppReview = InAppReview.instance;

  /// Записва момента на първото стартиране (ако липсва). Викай веднъж от `main`.
  Future<void> ensureFirstLaunchRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kFirstLaunch) == null) {
      await prefs.setInt(_kFirstLaunch, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Показва системния диалог за оценка, само ако:
  ///  • [currentStreak] >= 7 (навикът току-що е достигнал 7+ дни серия);
  ///  • приложението е инсталирано поне 3 дни;
  ///  • не е искано през последните 60 дни;
  ///  • искано е общо по-малко от 3 пъти;
  ///  • `isAvailable()` връща true.
  /// Извиква се със ~1.5 сек закъснение, за да не прекъсва анимацията.
  Future<void> maybeRequestReview({required int currentStreak}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    void log(String why) {
      if (kDebugMode) debugPrint('ReviewPrompt: $why');
    }

    if (currentStreak < _minStreak) {
      log('skip — streak $currentStreak < $_minStreak');
      return;
    }

    final firstLaunch = prefs.getInt(_kFirstLaunch);
    if (firstLaunch == null) {
      // Първо стартиране още не е записано — записваме сега, но не показваме.
      await prefs.setInt(_kFirstLaunch, now);
      log('skip — first launch just recorded');
      return;
    }
    final installDays = (now - firstLaunch) / (1000 * 60 * 60 * 24);
    if (installDays < _minInstallDays) {
      log('skip — installed ${installDays.toStringAsFixed(1)}d < $_minInstallDays');
      return;
    }

    final count = prefs.getInt(_kCount) ?? 0;
    if (count >= _maxRequests) {
      log('skip — already requested $count >= $_maxRequests times');
      return;
    }

    final lastRequest = prefs.getInt(_kLastRequest) ?? 0;
    final daysSinceLast = (now - lastRequest) / (1000 * 60 * 60 * 24);
    if (lastRequest != 0 && daysSinceLast < _cooldownDays) {
      log('skip — last request ${daysSinceLast.toStringAsFixed(1)}d ago < $_cooldownDays');
      return;
    }

    final available = await _inAppReview.isAvailable();
    if (!available) {
      log('skip — isAvailable() == false');
      return;
    }

    await Future.delayed(_delay);
    try {
      await _inAppReview.requestReview();
      await prefs.setInt(_kLastRequest, now);
      await prefs.setInt(_kCount, count + 1);
      log('requested (count now ${count + 1}, streak $currentStreak)');
    } catch (e) {
      log('requestReview threw: $e');
    }
  }
}
