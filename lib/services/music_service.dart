import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a single looping relaxing background track. One shared instance across
/// the app; the app-bar toggle reflects and controls [isPlaying].
///
/// Track: Memoraphile "I Do Know" — CC0 (no attribution required).
/// Source: https://opengameart.org/content/i-do-know
class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  // Path relative to the assets/ folder (audioplayers prepends "assets/").
  static const String _asset = 'audio/relax.ogg';

  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  /// Whether music is currently playing — drives the toggle icon.
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  // ── Sleep timer ─────────────────────────────────────────────────
  Timer? _sleepTimer;

  /// Selected sleep-timer length in minutes (0 = off). Drives the chips UI.
  final ValueNotifier<int> sleepMinutes = ValueNotifier<int>(0);

  /// Sets a sleep timer that stops the music after [minutes] (0 = off).
  /// The countdown runs only while music is playing.
  void setSleepTimer(int minutes) {
    sleepMinutes.value = minutes;
    _sleepTimer?.cancel();
    if (minutes > 0 && isPlaying.value) {
      _sleepTimer = Timer(Duration(minutes: minutes), stop);
    }
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.loop);
    _player.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });
    _ready = true;
  }

  Future<void> play() async {
    try {
      await _ensureReady();
      await _player.play(AssetSource(_asset));
      isPlaying.value = true;
      // (Re)start the sleep countdown if one is selected.
      if (sleepMinutes.value > 0) {
        _sleepTimer?.cancel();
        _sleepTimer = Timer(Duration(minutes: sleepMinutes.value), stop);
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    isPlaying.value = false;
    _sleepTimer?.cancel();
    sleepMinutes.value = 0;
  }

  Future<void> toggle() => isPlaying.value ? stop() : play();

  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
  }
}
