import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'screens/game_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/settings_screen.dart';
import 'settings.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SudoSettings.instance.init();
  await SudoAudio.instance.init();
  runApp(const SudokuApp());
}

enum _Screen { menu, game, settings }

class SudokuApp extends StatefulWidget {
  const SudokuApp({super.key});

  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  _Screen _screen = _Screen.menu;
  _Screen _settingsReturn = _Screen.menu;
  GameScreen? _game; // retained while settings is pushed over a live game
  Map<String, dynamic>? _save;
  bool _saveChecked = false;

  final audio = SudoAudio.instance;

  @override
  void initState() {
    super.initState();
    audio.playMusic('audio/music_menu.wav');
    _checkSave();
  }

  Future<void> _checkSave() async {
    final save = await GameScreen.loadSave();
    if (mounted) {
      setState(() {
        _save = save;
        _saveChecked = true;
      });
    }
  }

  void _goMenu() {
    _game = null;
    setState(() {
      _screen = _Screen.menu;
      _saveChecked = false;
    });
    audio.playMusic('audio/music_menu.wav');
    _checkSave();
  }

  void _startGame({required int diff, Map<String, dynamic>? restored}) {
    audio.start();
    setState(() {
      _game = GameScreen(
        key: ValueKey('game-$diff-${DateTime.now().millisecondsSinceEpoch}'),
        diffIndex: diff,
        restored: restored,
        onExitToMenu: _goMenu,
        onOpenSettings: () {
          _settingsReturn = _Screen.game;
          setState(() => _screen = _Screen.settings);
        },
      );
      _screen = _Screen.game;
    });
    audio.playMusic('audio/music_game.wav');
  }

  void _openSettings() {
    _settingsReturn = _Screen.menu;
    setState(() => _screen = _Screen.settings);
    audio.click();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: SudoColors.tatami,
        fontFamily: SudoFonts.sans,
        colorScheme: const ColorScheme.light(
          primary: SudoColors.bambooDark,
          surface: SudoColors.washi,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: TatamiBackground(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _currentScreen(),
          ),
        ),
      ),
    );
  }

  Widget _currentScreen() {
    switch (_screen) {
      case _Screen.menu:
        return MenuScreen(
          key: const ValueKey('menu'),
          hasSave: _saveChecked && _save != null,
          onPlay: () => _startGame(diff: 1),
          onPlayDiff: (d) => _startGame(diff: d),
          onResume: () {
            final save = _save;
            if (save == null) return;
            _startGame(
              diff: save['diff'] as int,
              restored: save,
            );
          },
          onOpenSettings: _openSettings,
        );
      case _Screen.game:
        return _game ?? const SizedBox.shrink(key: ValueKey('empty'));
      case _Screen.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          onBack: () {
            audio.click();
            setState(() => _screen = _settingsReturn);
            if (_settingsReturn == _Screen.menu) {
              audio.playMusic('audio/music_menu.wav');
            } else {
              audio.playMusic('audio/music_game.wav');
            }
          },
        );
    }
  }
}
