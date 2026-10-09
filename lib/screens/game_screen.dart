import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio.dart';
import '../engine.dart';
import '../settings.dart';
import '../theme.dart';

/// Gameplay screen: washi board with sumi grid, bamboo number tokens,
/// action tokens, HUD slips, pause overlay, victory/failure sheets.
class GameScreen extends StatefulWidget {
  final int diffIndex;
  final Map<String, dynamic>? restored;
  final VoidCallback onExitToMenu;
  final VoidCallback onOpenSettings;

  const GameScreen({
    super.key,
    required this.diffIndex,
    this.restored,
    required this.onExitToMenu,
    required this.onOpenSettings,
  });

  static const saveKey = 'sudo_save_v1';

  static Future<void> clearSave() async {
    (await SharedPreferences.getInstance()).remove(saveKey);
  }

  static Future<Map<String, dynamic>?> loadSave() async {
    final raw = (await SharedPreferences.getInstance()).getString(saveKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['v'] != 1) return null;
      final eng = SudokuEngine()..fromJson(m);
      if (eng.won || eng.failed) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final engine = SudokuEngine();
  final s = SudoSettings.instance;
  final audio = SudoAudio.instance;

  late int diffIndex;
  int sel = -1;
  bool notesMode = false;
  bool paused = false;
  bool generating = false;
  bool showVictory = false;
  bool showFailure = false;
  bool newBest = false;
  int hintCount = 3;

  int _shakeCell = -1;
  int _shakeSeq = 0;
  int _errorFlash = -1;

  Timer? _timer;
  late AnimationController _gridReveal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    diffIndex = widget.diffIndex;
    _gridReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.restored != null) {
      engine.fromJson(widget.restored!);
      diffIndex = widget.restored!['diff'] as int;
      hintCount = 3 - engine.hintsUsed;
      if (hintCount < 0) hintCount = 0;
      _startTimerLoop();
    } else {
      _newPuzzle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _gridReveal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseAndSave();
    }
  }

  // --------------------------------------------------------------- lifecycle
  Future<void> _newPuzzle() async {
    setState(() {
      generating = true;
      showVictory = false;
      showFailure = false;
      paused = false;
      sel = -1;
      notesMode = false;
      hintCount = 3;
      newBest = false;
    });
    // Generation is CPU-heavy; let the spinner paint first.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    engine.newGame(diffIndex);
    if (!mounted) return;
    _gridReveal.forward(from: 0);
    setState(() => generating = false);
    _startTimerLoop();
    audio.start();
    _save();
  }

  void _startTimerLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (engine.timerRunning && !paused && !engine.won && !engine.failed) {
        setState(() => engine.seconds++);
      }
    });
  }

  Future<void> _save() async {
    if (engine.won || engine.failed) {
      await GameScreen.clearSave();
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(GameScreen.saveKey, jsonEncode(engine.toJson(diffIndex)));
  }

  void _pauseAndSave() {
    if (engine.won || engine.failed || generating) return;
    if (!paused) setState(() => paused = true);
    _save();
  }

  // ------------------------------------------------------------------- input
  void _tapCell(int i) {
    if (paused || generating || engine.won || engine.failed) return;
    audio.paper();
    setState(() => sel = (sel == i) ? -1 : i);
  }

  void _reject(int i) {
    audio.invalid();
    setState(() {
      _shakeCell = i;
      _shakeSeq++;
    });
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _shakeCell = -1);
    });
  }

  void _tapNumber(int n) {
    if (paused || generating || engine.won || engine.failed) return;
    if (sel < 0) return;
    if (engine.isGiven(sel)) {
      _reject(sel); // RULES §5: givens are locked — reject with feedback.
      return;
    }
    if (notesMode) {
      if (engine.toggleNote(sel, n)) {
        audio.note();
        setState(() {});
        _save();
      }
      return;
    }
    final result =
        engine.enterDigit(sel, n, autoNoteCleanup: s.autoNoteCleanup);
    if (result == 'locked') return;
    if (result == 'removed') {
      audio.erase();
      setState(() {});
      _save();
      return;
    }
    if (result == 'correct') {
      audio.brush();
      setState(() {});
      _save();
      _checkWin();
      return;
    }
    // Wrong digit: recorded as a mistake, stays as a visible vermilion error
    // until erased or corrected (RULES §5).
    audio.invalid();
    setState(() {
      _errorFlash = sel;
      _shakeSeq++;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _errorFlash = -1);
    });
    _save();
    final budget = s.mistakeBudget;
    if (budget > 0 && engine.mistakes >= budget) {
      if (s.strictMode) {
        _fail();
      }
      // Default mode: puzzle continues, star rating capped (RULES §9).
    }
  }

  void _undo() {
    if (paused || generating || engine.won || engine.failed) return;
    if (engine.undo()) {
      audio.undo();
      setState(() {});
      _save();
    }
  }

  void _erase() {
    if (paused || generating || engine.won || engine.failed) return;
    if (sel < 0) return;
    if (engine.erase(sel)) {
      audio.erase();
      setState(() {});
      _save();
    }
  }

  void _hint() {
    if (paused || generating || engine.won || engine.failed) return;
    if (hintCount <= 0) {
      audio.invalid();
      return;
    }
    final filled = engine.useHint(sel);
    if (filled < 0) {
      audio.invalid();
      return;
    }
    audio.hint();
    setState(() {
      hintCount--;
      sel = filled;
    });
    _save();
    _checkWin();
  }

  void _checkWin() {
    if (!engine.checkWin()) return;
    _timer?.cancel();
    _save(); // clears the save
    audio.win();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) audio.stamp();
    });
    s.recordWin(diffIndex, engine.seconds, engine.mistakes).then((best) {
      if (!mounted) return;
      setState(() {
        newBest = best;
        showVictory = true;
      });
    });
  }

  void _fail() {
    engine.failed = true;
    _timer?.cancel();
    audio.lose();
    s.recordFail(diffIndex);
    GameScreen.clearSave();
    setState(() => showFailure = true);
  }

  void _togglePause() {
    audio.click();
    setState(() => paused = !paused);
    if (paused) _save();
  }

  Future<void> _confirmRestart() async {
    audio.click();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _WashiDialog(
        title: 'Restart puzzle?',
        body: 'The board returns to its initial givens. '
            'Entries, mistakes and hints reset.',
        confirm: 'RESTART',
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (ok == true) _newPuzzle();
  }

  Future<void> _confirmQuit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _WashiDialog(
        title: 'Leave the desk?',
        body: 'Your progress is saved — you can continue any time.',
        confirm: 'LEAVE',
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (ok == true) {
      _pauseAndSave();
      widget.onExitToMenu();
    }
  }

  // -------------------------------------------------------------------- ui
  String _fmt(int v) =>
      '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              _topBar(),
              const SizedBox(height: 8),
              _hud(),
              const SizedBox(height: 10),
              Expanded(child: Center(child: _boardArea())),
              const SizedBox(height: 10),
              _actions(),
              const SizedBox(height: 10),
              _numpad(),
              const SizedBox(height: 8),
            ],
          ),
          if (paused && !showVictory && !showFailure) _pauseOverlay(),
          if (showVictory) _victorySheet(),
          if (showFailure) _failureSheet(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          BambooToken(
            label: '‹',
            size: 38,
            onTap: _confirmQuit,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数独 SUDOKU',
                  style: TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: SudoColors.sumi,
                    letterSpacing: 1.5,
                  ),
                ),
                MicroLabel('JAPANESE STATIONERY CRAFT',
                    size: 9, color: SudoColors.walnut),
              ],
            ),
          ),
          BambooToken(
            label: notesMode ? '✎●' : '✎',
            size: 38,
            onTap: () {
              audio.click();
              setState(() => notesMode = !notesMode);
            },
          ),
          const SizedBox(width: 8),
          BambooToken(
            label: '⏸',
            size: 38,
            onTap: _togglePause,
          ),
        ],
      ),
    );
  }

  Widget _hud() {
    final diff = sudoDifficulties[diffIndex];
    final budget = s.mistakeBudget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          WashiSlip(
            child: Column(
              children: [
                const MicroLabel('TIME', size: 8),
                Text(
                  _fmt(engine.seconds),
                  style: const TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SudoColors.walnut,
                  ),
                ),
              ],
            ),
          ),
          WashiSlip(
            child: Column(
              children: [
                const MicroLabel('MISTAKES', size: 8),
                const SizedBox(height: 4),
                budget == 0
                    ? const Text('∞',
                        style: TextStyle(
                            fontFamily: SudoFonts.serif,
                            fontSize: 16,
                            color: SudoColors.walnut))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < budget; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < engine.mistakes
                                      ? SudoColors.vermilion
                                      : SudoColors.sumi.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                        ],
                      ),
              ],
            ),
          ),
          WashiSlip(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  diff.ja,
                  style: const TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: SudoColors.vermilion,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  diff.name,
                  style: const TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: SudoColors.walnut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boardArea() {
    if (generating) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HankoStamp(size: 56),
          const SizedBox(height: 14),
          Text(
            'Grinding fresh ink…',
            style: TextStyle(
              fontFamily: SudoFonts.serif,
              fontSize: 15,
              color: SudoColors.walnut.withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
        return WashiSheet(
          padding: const EdgeInsets.all(7),
          radius: 10,
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 9),
                  itemCount: 81,
                  itemBuilder: (_, i) => _cell(i),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _gridReveal,
                    builder: (_, _) => CustomPaint(
                      size: Size.square(side),
                      painter: SumiGridPainter(
                          animation: _gridReveal.value.clamp(0.0, 1.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(int i) {
    final given = engine.isGiven(i);
    final v = engine.val[i];
    final selVal = sel >= 0 ? engine.val[sel] : 0;
    final r = i ~/ 9, c = i % 9;
    final sr = sel ~/ 9, sc = sel % 9;
    final related = s.highlightRelated &&
        sel >= 0 &&
        (r == sr || c == sc || (r ~/ 3 == sr ~/ 3 && c ~/ 3 == sc ~/ 3));
    final sameDigit =
        s.highlightRelated && selVal != 0 && v == selVal && v != 0;
    final showError = s.highlightErrors && engine.wrong[i];
    final flash = i == _errorFlash;

    Widget content;
    if (v != 0) {
      Color color;
      FontWeight weight;
      if (given) {
        color = SudoColors.sumi;
        weight = FontWeight.w700; // printed givens
      } else if (showError || flash) {
        color = SudoColors.vermilion;
        weight = FontWeight.w600;
      } else {
        color = SudoColors.sumi.withValues(alpha: 0.88);
        weight = FontWeight.w400; // player ink entries
      }
      content = Text(
        '$v',
        style: TextStyle(
          fontFamily: SudoFonts.serif,
          fontSize: 21,
          fontWeight: weight,
          color: color,
        ),
      );
    } else if (engine.notes[i].isNotEmpty) {
      final sorted = engine.notes[i].toList()..sort();
      content = Padding(
        padding: const EdgeInsets.all(1.5),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var n = 1; n <= 9; n++)
              Center(
                child: Text(
                  sorted.contains(n) ? '$n' : '',
                  style: const TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: SudoColors.walnut,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    final cell = GestureDetector(
      onTap: () => _tapCell(i),
      child: Container(
        color: Colors.transparent,
        child: CustomPaint(
          painter: CellHighlightPainter(
            selected: i == sel,
            related: related && i != sel,
            sameDigit: sameDigit && i != sel,
            error: showError || flash,
          ),
          child: Center(child: content),
        ),
      ),
    );

    if (i == _shakeCell) {
      return TweenAnimationBuilder<double>(
        key: ValueKey('shake-$i-$_shakeSeq'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (_, t, child) => Transform.translate(
          offset: Offset(6 * (1 - t) * sin(t * 12), 0),
          child: child,
        ),
        child: cell,
      );
    }
    return cell;
  }

  Widget _actions() {
    Widget token(String label, VoidCallback? onTap,
        {bool active = false, String? tip}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: active
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: SudoColors.vermilion, width: 2.5),
                  )
                : null,
            child: BambooToken(
              label: label,
              size: 44,
              onTap: onTap,
            ),
          ),
          if (tip != null) ...[
            const SizedBox(height: 2),
            MicroLabel(tip, size: 8.5),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          token('↺', engine.hasUndo ? _undo : null, tip: 'UNDO'),
          token('⌫', _erase, tip: 'ERASE'),
          token('✎', () {
            audio.click();
            setState(() => notesMode = !notesMode);
          }, active: notesMode, tip: notesMode ? 'NOTES ●' : 'NOTES'),
          token('🏮', hintCount > 0 ? _hint : null, tip: 'HINT ×$hintCount'),
          token('⟳', _confirmRestart, tip: 'NEW'),
        ],
      ),
    );
  }

  Widget _numpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var n = 1; n <= 9; n++)
            Builder(builder: (_) {
              final left = engine.remainingOf(n);
              return BambooToken(
                label: '$n',
                sub: '$left',
                size: 37,
                enabled: left > 0,
                onTap: () => _tapNumber(n),
              );
            }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- overlays
  Widget _dim() => Container(color: Colors.black.withValues(alpha: 0.42));

  Widget _pauseOverlay() {
    return Stack(
      children: [
        _dim(),
        Center(
          child: WashiSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrushHeading('Paused', size: 26),
                const SizedBox(height: 4),
                const MicroLabel('一服  ·  A QUIET BREATH'),
                const SizedBox(height: 6),
                Text(
                  'Time ${_fmt(engine.seconds)}  ·  '
                  '${sudoDifficulties[diffIndex].name}',
                  style: const TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontSize: 12,
                    color: SudoColors.walnut,
                  ),
                ),
                const SizedBox(height: 18),
                _sheetButton('RESUME  ·  続ける', _togglePause, primary: true),
                const SizedBox(height: 10),
                _sheetButton('RESTART', _confirmRestart),
                const SizedBox(height: 10),
                _sheetButton('MENU', () {
                  _pauseAndSave();
                  widget.onExitToMenu();
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _victorySheet() {
    final stars = engine.stars();
    return Stack(
      children: [
        _dim(),
        Center(
          child: SingleChildScrollView(
            child: WashiSheet(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HankoStamp(size: 72),
                  const SizedBox(height: 10),
                  const BrushHeading('Puzzle complete!', size: 24),
                  const SizedBox(height: 4),
                  const MicroLabel('完成  ·  SEALED WITH CARE'),
                  const SizedBox(height: 12),
                  BrushStars(stars: stars),
                  const SizedBox(height: 10),
                  Text(
                    'Time ${_fmt(engine.seconds)}',
                    style: const TextStyle(
                      fontFamily: SudoFonts.serif,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      color: SudoColors.sumi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sudoDifficulties[diffIndex].name}  ·  '
                    '${engine.mistakes} mistakes  ·  '
                    '${engine.hintsUsed} hints',
                    style: const TextStyle(
                      fontFamily: SudoFonts.sans,
                      fontSize: 12,
                      color: SudoColors.walnut,
                    ),
                  ),
                  if (newBest) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: SudoColors.vermilion.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: SudoColors.vermilion.withValues(alpha: 0.6)),
                      ),
                      child: const MicroLabel('NEW BEST!  ·  新記録',
                          color: SudoColors.vermilion,
                          weight: FontWeight.w800),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sheetButton('NEW PUZZLE', () {
                    audio.click();
                    _newPuzzle();
                  }, primary: true),
                  const SizedBox(height: 10),
                  _sheetButton('MENU', () {
                    audio.click();
                    widget.onExitToMenu();
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _failureSheet() {
    return Stack(
      children: [
        _dim(),
        Center(
          child: WashiSheet(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '終',
                  style: TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: SudoColors.vermilion,
                  ),
                ),
                const SizedBox(height: 6),
                const BrushHeading('Ink ran dry', size: 22),
                const SizedBox(height: 6),
                Text(
                  'The mistake limit was reached.\n'
                  'Every master was once a beginner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontSize: 12.5,
                    color: SudoColors.walnut.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _sheetButton('TRY AGAIN', () {
                  audio.click();
                  _newPuzzle();
                }, primary: true),
                const SizedBox(height: 10),
                _sheetButton('MENU', () {
                  audio.click();
                  widget.onExitToMenu();
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheetButton(String label, VoidCallback onTap,
      {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [SudoColors.bambooHi, SudoColors.bamboo],
                )
              : null,
          color: primary ? null : SudoColors.washiShade,
          border: Border.all(
              color: primary
                  ? SudoColors.bambooDark
                  : SudoColors.washLine,
              width: 1.6),
          boxShadow: SudoColors.tokenShadows,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: SudoFonts.sans,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.2,
              color: primary ? SudoColors.sumi : SudoColors.walnut,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small washi-paper confirm dialog.
class _WashiDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirm;
  final VoidCallback onConfirm;

  const _WashiDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: WashiSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrushHeading(title, size: 20),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: SudoFonts.sans,
                fontSize: 13,
                color: SudoColors.walnut,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    SudoAudio.instance.click();
                    Navigator.of(context).pop(false);
                  },
                  child: const MicroLabel('CANCEL', weight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 11),
                    decoration: BoxDecoration(
                      color: SudoColors.vermilion,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: SudoColors.tokenShadows,
                    ),
                    child: Text(
                      confirm,
                      style: const TextStyle(
                        fontFamily: SudoFonts.sans,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        letterSpacing: 1.1,
                        color: SudoColors.washi,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
