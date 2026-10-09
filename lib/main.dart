import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = SudoSettings();
  await settings.load();
  final audio = SumiAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.masterVol,
    musicVol: settings.musicVol,
  );
  final store = StoreService();
  // Store init is best-effort: the game works fully offline without it.
  unawaited(store.init());
  runApp(SudokuApp(audio: audio, settings: settings, store: store));
}

class SudokuApp extends StatefulWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  final StoreService store;
  const SudokuApp({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire store → settings: a real Pro purchase flips the local flag.
    widget.store.proPurchased.addListener(_onStorePro);
  }

  void _onStorePro() {
    if (widget.store.proPurchased.value && !widget.settings.isPro) {
      widget.settings.setPro(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.proPurchased.removeListener(_onStorePro);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App-scoped music: pause on background, resume on return. Never
    // silently dies on screen navigation — screens never stop music.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE5D5BC),
        fontFamily: 'Manrope',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFA67C48),
          surface: Color(0xFFFAF6EE),
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(
        audio: widget.audio,
        settings: widget.settings,
        store: widget.store,
      ),
    );
  }
}
