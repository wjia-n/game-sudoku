import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../widgets/sumi_widgets.dart';
import '../navigation.dart';

/// Launch splash: game logo + name, animated loading line, and credits.
/// Single splash only — the WAJIHA company logo appears in the credits row.
class SplashScreen extends StatefulWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  final StoreService store;
  const SplashScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MenuRoute.build(
        audio: widget.audio,
        settings: widget.settings,
        store: widget.store,
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = widget.settings.themeDef();
        return Scaffold(
          backgroundColor: theme.canvas,
          body: TatamiBackdrop(
            theme: theme,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: theme.walnut.withValues(alpha: 0.35),
                          offset: const Offset(0, 12),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/sudoku_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => CustomPaint(
                        painter: SudokuLogoPainter(theme),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Sudoku', style: SumiType.display(52, theme)),
                  const SizedBox(height: 6),
                  Text(
                    'THE WASHI & SUMI CRAFT EDITION',
                    style: SumiType.label(12, theme),
                  ),
                  const SizedBox(height: 30),
                  // Animated loading line.
                  SizedBox(
                    width: 220,
                    child: AnimatedBuilder(
                      animation: _loader,
                      builder: (_, _) => Column(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: theme.walnut.withValues(alpha: 0.18),
                              border: Border.all(
                                  color: theme.bamboo
                                      .withValues(alpha: 0.6)),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _loader.value.clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: theme.vermilion,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _loader.value < 1
                                ? 'Grinding the ink…'
                                : 'Ready!',
                            style: SumiType.body(13, theme,
                                color: theme.walnut
                                    .withValues(alpha: 0.75)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/wajiha_logo.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(
                            width: 30, height: 30),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Credits: WAJIHA',
                        style: SumiType.label(14, theme),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
