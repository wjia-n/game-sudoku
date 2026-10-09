import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'screens/menu_screen.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/settings_service.dart';

/// Navigation helpers shared by splash/menu/main. Kept in one place so
/// screens never import main.dart (no import cycles).
class MenuRoute {
  static Route<void> build({
    required SumiAudio audio,
    required SudoSettings settings,
    required StoreService store,
  }) {
    return MaterialPageRoute(
      builder: (_) => MenuScreen(
        audio: audio,
        settings: settings,
        store: store,
      ),
    );
  }
}

/// Resume helper used by the menu's Continue button.
class ResumeHelper {
  static void resume(
    BuildContext context, {
    required SumiAudio audio,
    required SudoSettings settings,
    required StoreService store,
    required Map<String, dynamic> save,
  }) {
    audio.click();
    audio.startGameMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: audio,
          settings: settings,
          store: store,
          diffIndex: (save['diff'] as int?) ?? 1,
          restored: save,
        ),
      ),
    )
        .then((_) {
      audio.startMenuMusic();
    });
  }
}
