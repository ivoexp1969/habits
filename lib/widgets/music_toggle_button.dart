import 'package:flutter/material.dart';

import '../services/music_service.dart';

/// App-bar button that plays / stops the relaxing background music. Place in
/// each screen's AppBar `actions`. Shows the live play/stop state.
class MusicToggleButton extends StatelessWidget {
  const MusicToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MusicService.instance.isPlaying,
      builder: (context, playing, _) => IconButton(
        onPressed: MusicService.instance.toggle,
        tooltip: playing ? 'Спри музиката' : 'Релаксираща музика',
        icon: Icon(playing ? Icons.music_off : Icons.music_note),
      ),
    );
  }
}
