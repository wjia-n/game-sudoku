import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/sudoku_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/sumi_themes.dart';
import '../widgets/sumi_widgets.dart';

/// Gameplay screen: washi board with sumi grid, bamboo number tokens,
/// action tokens, HUD, pause overlay, victory/failure sheets.
///
/// The engine owns ALL game state and the timer; the screen only renders
/// and forwards input. A watchdog inside the engine makes stuck states
/// impossible.
class GameScreen extends StatefulWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  final StoreService? store;
  final int diffIndex;
  final bool daily;
  final String dateKey;
  final int? seed;
  final Map<String, dynamic>? restored;

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.store,
    required this.diffIndex,
    this.daily = false,
    this.dateKey = '',
    this.seed,
    this.restored,
  });

  static const saveKey = 'sudoku_save_v2';

  static Future<void> clearSave() async {
    (await SharedPreferences.getInstance()).remove(saveKey);
  }

  static Future<Map<String, dynamic>?> loadSave() async {
    final raw = (await SharedPreferences.getInstance()).getString(saveKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['v'] != 2) return null;
      // Sanity: must be a playable in-progress puzzle.
      final val = List<int>.from(m['val'] as List);
      final sol = List<int>.from(m['solution'] as List);
      if (val.length != 81 || sol.length != 81) return null;
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
  late final SudokuEngine engine;
  int sel = -1;
  bool notesMode = false;
  bool generating = false;

  // Animation triggers (cell index + animation clock).
  int _popCell = -1;
  int _popSeq = 0;
  int _hintCell = -1;
  int _hintSeq = 0;
  int _shakeCell = -1;
  int _shakeSeq = 0;
  int _errorPulse = -1;
  int _errorSeq = 0;

  late AnimationController _gridReveal;
  late AnimationController _confetti;
  late AnimationController _stamp;
  late AnimationController _cellPulse;

  bool _winHandled = false;
  bool _failHandled = false;
  bool _newBest = false;
  int _winStars = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = SudokuEngine();
    engine.onEvent = _onEngineEvent;
    _gridReveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _confetti = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _stamp = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cellPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    if (widget.restored != null) {
      engine.fromJson(widget.restored!);
      _gridReveal.forward();
    } else {
      _newPuzzle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    _gridReveal.dispose();
    _confetti.dispose();
    _stamp.dispose();
    _cellPulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseAndSave();
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  // --------------------------------------------------------------- lifecycle
  Future<void> _newPuzzle() async {
    setState(() {
      generating = true;
      sel = -1;
      notesMode = false;
      _winHandled = false;
      _failHandled = false;
      _newBest = false;
    });
    // Generation is CPU-heavy; let the spinner paint first.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final s = widget.settings;
    engine.newGame(
      widget.diffIndex,
      relaxedMode: s.relaxedMode,
      budget: s.mistakeBudget,
      strict: s.strictMode,
      autoCleanup: s.autoNoteCleanup,
      daily: widget.daily,
      dateKey: widget.dateKey,
      seed: widget.seed,
    );
    if (!mounted) return;
    _gridReveal.forward(from: 0);
    setState(() => generating = false);
    widget.audio.start();
    _save();
  }

  Future<void> _save() async {
    if (engine.over) {
      await GameScreen.clearSave();
      return;
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(GameScreen.saveKey, jsonEncode(engine.toJson()));
    } catch (_) {}
  }

  void _pauseAndSave() {
    if (engine.over || generating) return;
    engine.setPaused(true);
    _save();
  }

  // ---------------------------------------------------------------- events
  void _onEngineEvent(SudoEvent e) {
    final a = widget.audio;
    switch (e) {
      case SudoEvent.correctEntry:
        a.brush();
      case SudoEvent.wrongEntry:
        a.invalid();
      case SudoEvent.invalid:
        a.invalid();
      case SudoEvent.note:
        a.note();
      case SudoEvent.erase:
        a.erase();
      case SudoEvent.undo:
        a.undo();
      case SudoEvent.hint:
        a.hint();
      case SudoEvent.win:
        _handleWin();
      case SudoEvent.fail:
        _handleFail();
      case SudoEvent.timerStarted:
        break;
    }
    if (mounted) setState(() {});
    _save();
  }

  Future<void> _handleWin() async {
    if (_winHandled) return;
    _winHandled = true;
    final s = widget.settings;
    final diffKey = widget.daily
        ? 'daily'
        : sudoDifficulties[engine.diffIndex].key;
    _winStars = engine.stars();
    if (widget.daily) {
      await s.recordDaily(widget.dateKey, _winStars);
      _newBest = false;
    } else {
      _newBest =
          await s.recordWin(diffKey, engine.seconds, engine.mistakes);
    }
    await GameScreen.clearSave();
    widget.audio.win();
    if (!mounted) return;
    setState(() {});
    _confetti.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _stamp.forward(from: 0);
        widget.audio.stamp();
      }
    });
  }

  Future<void> _handleFail() async {
    if (_failHandled) return;
    _failHandled = true;
    final diffKey = widget.daily
        ? 'daily'
        : sudoDifficulties[engine.diffIndex].key;
    await widget.settings.recordFail(diffKey);
    await GameScreen.clearSave();
    widget.audio.lose();
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------------ input
  void _tapCell(int i) {
    if (generating || engine.over || engine.paused) return;
    widget.audio.paper();
    setState(() => sel = (sel == i) ? -1 : i);
  }

  void _shake(int i) {
    setState(() {
      _shakeCell = i;
      _shakeSeq++;
    });
    _cellPulse.forward(from: 0);
  }

  void _tapNumber(int n) {
    if (generating || engine.over || engine.paused) return;
    if (sel < 0) return;
    if (engine.isLocked(sel)) {
      _shake(sel);
      return;
    }
    if (notesMode) {
      engine.toggleNote(sel, n);
    } else {
      final r = engine.enterDigit(sel, n);
      if (r == 'correct' || r == 'removed') {
        setState(() {
          _popCell = sel;
          _popSeq++;
        });
        _cellPulse.forward(from: 0);
      } else if (r == 'wrong') {
        setState(() {
          _errorPulse = sel;
          _errorSeq++;
          _popCell = sel;
          _popSeq++;
        });
        _cellPulse.forward(from: 0);
      }
    }
  }

  void _eraseSel() {
    if (generating || engine.over || engine.paused || sel < 0) return;
    if (!engine.erase(sel)) _shake(sel);
  }

  void _undo() {
    if (generating || engine.over || engine.paused) return;
    engine.undo();
  }

  void _hint() {
    if (generating || engine.over || engine.paused) return;
    if (engine.hintsLeft <= 0) {
      _shake(sel >= 0 ? sel : 40);
      return;
    }
    final target = engine.useHint(sel);
    if (target >= 0) {
      setState(() {
        _hintCell = target;
        _hintSeq++;
        sel = target;
      });
    }
  }

  void _toggleNotes() {
    if (generating || engine.over) return;
    widget.audio.click();
    setState(() => notesMode = !notesMode);
  }

  void _confirmRestart() {
    final t = widget.settings.themeDef();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.washi,
        title: Text('Restart puzzle?', style: SumiType.display(20, t)),
        content: Text('All entries, mistakes and the timer reset.',
            style: SumiType.body(15, t)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: SumiType.label(13, t)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.audio.click();
              engine.restart();
              setState(() {
                sel = -1;
                _winHandled = false;
                _failHandled = false;
              });
              _save();
            },
            child: Text('Restart',
                style: SumiType.label(13, t, color: t.vermilion)),
          ),
        ],
      ),
    );
  }

  void _confirmQuit() {
    final t = widget.settings.themeDef();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.washi,
        title: Text('Leave puzzle?', style: SumiType.display(20, t)),
        content: Text('Your progress autosaves — you can continue later.',
            style: SumiType.body(15, t)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Stay', style: SumiType.label(13, t)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.audio.click();
              _pauseAndSave();
              widget.audio.startMenuMusic();
              Navigator.of(context).pop();
            },
            child:
                Text('Menu', style: SumiType.label(13, t, color: t.vermilion)),
          ),
        ],
      ),
    );
  }

  void _nextPuzzle() {
    widget.audio.click();
    setState(() {
      _winHandled = false;
      _failHandled = false;
    });
    _newPuzzle();
  }

  // ----------------------------------------------------------------- build
  static String fmtTime(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([engine, widget.settings]),
      builder: (_, _) {
        final t = widget.settings.themeDef();
        final digitStyle = widget.settings.digitStyle();
        final accent = widget.settings.gridAccent();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: TatamiBackdrop(
            theme: t,
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _Hud(
                        theme: t,
                        engine: engine,
                        settings: widget.settings,
                        onPause: () {
                          widget.audio.click();
                          _pauseAndSave();
                        },
                        onQuit: _confirmQuit,
                        onRestart: _confirmRestart,
                      ),
                      Expanded(
                        child: Center(
                          child: generating
                              ? _Generating(theme: t)
                              : _Board(
                                  theme: t,
                                  digitStyle: digitStyle,
                                  accent: accent,
                                  engine: engine,
                                  settings: widget.settings,
                                  sel: sel,
                                  popCell: _popCell,
                                  popSeq: _popSeq,
                                  hintCell: _hintCell,
                                  hintSeq: _hintSeq,
                                  shakeCell: _shakeCell,
                                  shakeSeq: _shakeSeq,
                                  errorPulse: _errorPulse,
                                  errorSeq: _errorSeq,
                                  cellPulse: _cellPulse,
                                  reveal: _gridReveal,
                                  onTapCell: _tapCell,
                                ),
                        ),
                      ),
                      _NumberPad(
                        theme: t,
                        digitStyle: digitStyle,
                        engine: engine,
                        notesMode: notesMode,
                        onNumber: _tapNumber,
                        onToggleNotes: _toggleNotes,
                      ),
                      _ActionRow(
                        theme: t,
                        engine: engine,
                        notesMode: notesMode,
                        onUndo: _undo,
                        onErase: _eraseSel,
                        onNotes: _toggleNotes,
                        onHint: _hint,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  if (engine.paused && !engine.over) _PauseOverlay(
                    theme: t,
                    onResume: () {
                      widget.audio.click();
                      engine.setPaused(false);
                    },
                    onRestart: _confirmRestart,
                    onQuit: _confirmQuit,
                  ),
                  if (engine.phase == SudoPhase.won) _VictorySheet(
                    theme: t,
                    engine: engine,
                    stars: _winStars,
                    newBest: _newBest,
                    confetti: _confetti,
                    stamp: _stamp,
                    daily: widget.daily,
                    onNext: _nextPuzzle,
                    onMenu: () {
                      widget.audio.click();
                      widget.audio.startMenuMusic();
                      Navigator.of(context).pop();
                    },
                  ),
                  if (engine.phase == SudoPhase.failed) _FailureSheet(
                    theme: t,
                    engine: engine,
                    onRetry: () {
                      widget.audio.click();
                      setState(() {
                        _failHandled = false;
                        sel = -1;
                      });
                      engine.restart();
                      _save();
                    },
                    onMenu: () {
                      widget.audio.click();
                      widget.audio.startMenuMusic();
                      Navigator.of(context).pop();
                    },
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

// ---------------------------------------------------------------------------
class _Generating extends StatelessWidget {
  final SumiThemeDef theme;
  const _Generating({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: theme.vermilion),
        ),
        const SizedBox(height: 14),
        Text('Brushing a new puzzle…',
            style: SumiType.body(15, theme)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class _Hud extends StatelessWidget {
  final SumiThemeDef theme;
  final SudokuEngine engine;
  final SudoSettings settings;
  final VoidCallback onPause;
  final VoidCallback onQuit;
  final VoidCallback onRestart;
  const _Hud({
    required this.theme,
    required this.engine,
    required this.settings,
    required this.onPause,
    required this.onQuit,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final diffName = engine.isDaily
        ? 'Daily'
        : sudoDifficulties[engine.diffIndex].name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Row(
        children: [
          WoodToken(
            theme: t,
            size: 42,
            onTap: onQuit,
            child: Icon(Icons.arrow_back, color: t.washi, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$diffName · ${settings.relaxedMode ? 'Relaxed' : 'Timed'}',
                    style: SumiType.label(12, t)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 15, color: t.walnut.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      settings.relaxedMode
                          ? '—'
                          : _GameScreenState.fmtTime(engine.seconds),
                      style: SumiType.micro(14, t),
                    ),
                    const SizedBox(width: 12),
                    if (!engine.relaxed && settings.mistakeBudget > 0) ...[
                      Icon(Icons.favorite,
                          size: 15, color: t.vermilion),
                      const SizedBox(width: 4),
                      Text('${engine.mistakesLeft}/${settings.mistakeBudget}',
                          style: SumiType.micro(14, t)),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.lightbulb_outline,
                        size: 15,
                        color: t.gold),
                    const SizedBox(width: 4),
                    Text('${engine.hintsLeft}',
                        style: SumiType.micro(14, t)),
                  ],
                ),
              ],
            ),
          ),
          WoodToken(
            theme: t,
            size: 42,
            onTap: onRestart,
            child: Icon(Icons.refresh, color: t.washi, size: 20),
          ),
          const SizedBox(width: 8),
          WoodToken(
            theme: t,
            size: 42,
            onTap: onPause,
            child: Icon(Icons.pause, color: t.washi, size: 20),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// The washi board: grid lines per the chosen accent + 81 tappable cells.
class _Board extends StatelessWidget {
  final SumiThemeDef theme;
  final DigitStyle digitStyle;
  final GridAccent accent;
  final SudokuEngine engine;
  final SudoSettings settings;
  final int sel;
  final int popCell, popSeq, hintCell, hintSeq, shakeCell, shakeSeq;
  final int errorPulse, errorSeq;
  final AnimationController cellPulse;
  final AnimationController reveal;
  final void Function(int) onTapCell;

  const _Board({
    required this.theme,
    required this.digitStyle,
    required this.accent,
    required this.engine,
    required this.settings,
    required this.sel,
    required this.popCell,
    required this.popSeq,
    required this.hintCell,
    required this.hintSeq,
    required this.shakeCell,
    required this.shakeSeq,
    required this.errorPulse,
    required this.errorSeq,
    required this.cellPulse,
    required this.reveal,
    required this.onTapCell,
  });

  Set<int> _related(int s) {
    final out = <int>{};
    if (s < 0) return out;
    final r = s ~/ 9, c = s % 9;
    for (var k = 0; k < 9; k++) {
      out.add(r * 9 + k);
      out.add(k * 9 + c);
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        out.add((br + dr) * 9 + bc + dc);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final related = _related(sel);
    final selDigit = sel >= 0 ? engine.val[sel] : 0;
    return LayoutBuilder(
      builder: (_, constraints) {
        final side = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight)
            .clamp(200.0, 560.0);
        final cell = side / 9;
        return AnimatedBuilder(
          animation: reveal,
          builder: (_, _) => Opacity(
            opacity: reveal.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.96 + 0.04 * reveal.value,
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  color: t.washi,
                  borderRadius: BorderRadius.circular(
                      accent.roundedSheet ? 18 : 6),
                  border: Border.all(
                      color: t.bambooDark, width: accent.doubleFrame ? 4 : 2),
                  boxShadow: [
                    BoxShadow(
                        color: t.walnut.withValues(alpha: 0.12),
                        offset: const Offset(0, 2),
                        blurRadius: 4),
                    BoxShadow(
                        color: t.walnut.withValues(alpha: 0.12),
                        offset: const Offset(0, 10),
                        blurRadius: 28),
                  ],
                ),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(side, side),
                      painter: _GridPainter(
                          theme: t, accent: accent, cell: cell),
                    ),
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 9),
                      itemCount: 81,
                      itemBuilder: (_, i) => _Cell(
                        index: i,
                        size: cell,
                        theme: t,
                        digitStyle: digitStyle,
                        engine: engine,
                        settings: settings,
                        selected: i == sel,
                        related: related.contains(i),
                        sameDigit: selDigit != 0 &&
                            engine.val[i] == selDigit &&
                            i != sel,
                        isPop: i == popCell && popSeq > 0,
                        isHint: i == hintCell && hintSeq > 0,
                        isShake: i == shakeCell && shakeSeq > 0,
                        isError: i == errorPulse && errorSeq > 0,
                        cellPulse: cellPulse,
                        onTap: () => onTapCell(i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final SumiThemeDef theme;
  final GridAccent accent;
  final double cell;
  _GridPainter(
      {required this.theme, required this.accent, required this.cell});

  @override
  void paint(Canvas canvas, Size size) {
    if (accent.cellLineWidth > 0) {
      final thin = Paint()
        ..color = theme.washLine
        ..strokeWidth = accent.cellLineWidth;
      for (int k = 1; k < 9; k++) {
        if (k % 3 == 0) continue;
        final p = k * cell;
        canvas.drawLine(Offset(p, 0), Offset(p, size.height), thin);
        canvas.drawLine(Offset(0, p), Offset(size.width, p), thin);
      }
    } else {
      // Minimal Dots: tiny dots at cell intersections.
      final dot = Paint()..color = theme.washLine;
      for (int r = 1; r < 9; r++) {
        for (int c = 1; c < 9; c++) {
          if (r % 3 == 0 || c % 3 == 0) continue;
          canvas.drawCircle(Offset(c * cell, r * cell), 1.5, dot);
        }
      }
    }
    final thick = Paint()
      ..color = theme.boxLine
      ..strokeWidth = accent.boxLineWidth
      ..strokeCap = StrokeCap.round;
    for (int k = 1; k < 3; k++) {
      final p = k * 3 * cell;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), thick);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), thick);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.theme.id != theme.id || old.accent.id != accent.id;
}

class _Cell extends StatelessWidget {
  final int index;
  final double size;
  final SumiThemeDef theme;
  final DigitStyle digitStyle;
  final SudokuEngine engine;
  final SudoSettings settings;
  final bool selected;
  final bool related;
  final bool sameDigit;
  final bool isPop;
  final bool isHint;
  final bool isShake;
  final bool isError;
  final AnimationController cellPulse;
  final VoidCallback onTap;

  const _Cell({
    required this.index,
    required this.size,
    required this.theme,
    required this.digitStyle,
    required this.engine,
    required this.settings,
    required this.selected,
    required this.related,
    required this.sameDigit,
    required this.isPop,
    required this.isHint,
    required this.isShake,
    required this.isError,
    required this.cellPulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final i = index;
    final v = engine.val[i];
    final given = engine.isGiven(i);
    final hinted = engine.hinted.contains(i);
    final wrong = engine.wrong[i];
    final showErr = settings.highlightErrors && wrong;

    Color bg = Colors.transparent;
    if (selected) {
      bg = t.selWash;
    } else if (sameDigit && settings.highlightSameDigit) {
      bg = t.sameDigitTint;
    } else if (related && settings.highlightRelated) {
      bg = t.relatedTint;
    }
    if (showErr) bg = t.errorWash;

    Widget content;
    if (v != 0) {
      final conflicts =
          showErr ? engine.conflictsOf(i) : const <int>[];
      content = Text(
        '$v',
        style: SumiType.digit(
          size * 0.58,
          t,
          digitStyle,
          given: given || hinted,
          override: showErr
              ? t.vermilion
              : (given || hinted ? t.sumi : t.walnut),
        ),
      );
      if (showErr && conflicts.isNotEmpty) {
        // Hand-drawn vermilion circle around the error digit.
        content = Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.82,
              height: size * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.vermilion, width: 2),
              ),
            ),
            content,
          ],
        );
      }
    } else if (engine.notes[i].isNotEmpty) {
      final ns = engine.notes[i].toList()..sort();
      content = Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (int n = 1; n <= 9; n++)
              Center(
                child: Text(
                  ns.contains(n) ? '$n' : '',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w600,
                    fontSize: size * 0.20,
                    color: t.walnut.withValues(alpha: 0.85),
                    height: 1.0,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    Widget cell = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: bg,
        child: Center(child: content),
      ),
    );

    if (isPop || isHint || isShake || isError) {
      cell = AnimatedBuilder(
        animation: cellPulse,
        builder: (_, _) {
          final p = cellPulse.value.clamp(0.0, 1.0);
          double scale = 1.0;
          double dx = 0;
          if (isShake) {
            dx = sin(p * pi * 4) * 6 * (1 - p);
          } else if (isHint) {
            scale = 1.0 + sin(p * pi) * 0.35;
          } else {
            scale = 1.0 + sin(p * pi) * 0.22;
          }
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: scale,
              child: Container(
                color: isHint
                    ? t.vermilion.withValues(alpha: 0.25 * (1 - p))
                    : (isError
                        ? t.vermilion.withValues(alpha: 0.20 * (1 - p))
                        : bg),
                child: Center(child: content),
              ),
            ),
          );
        },
      );
      // Wrap so the tap target stays the animated cell.
      cell = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cell,
      );
    }
    return cell;
  }
}

// ---------------------------------------------------------------------------
class _NumberPad extends StatelessWidget {
  final SumiThemeDef theme;
  final DigitStyle digitStyle;
  final SudokuEngine engine;
  final bool notesMode;
  final void Function(int) onNumber;
  final VoidCallback onToggleNotes;
  const _NumberPad({
    required this.theme,
    required this.digitStyle,
    required this.engine,
    required this.notesMode,
    required this.onNumber,
    required this.onToggleNotes,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int n = 1; n <= 9; n++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _PadToken(
                  theme: t,
                  digitStyle: digitStyle,
                  n: n,
                  remaining: engine.remainingOf(n),
                  notesMode: notesMode,
                  onTap: () => onNumber(n),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PadToken extends StatelessWidget {
  final SumiThemeDef theme;
  final DigitStyle digitStyle;
  final int n;
  final int remaining;
  final bool notesMode;
  final VoidCallback onTap;
  const _PadToken({
    required this.theme,
    required this.digitStyle,
    required this.n,
    required this.remaining,
    required this.notesMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final done = remaining <= 0;
    return GestureDetector(
      onTap: done ? null : onTap,
      child: Opacity(
        opacity: done ? 0.35 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: notesMode
                      ? [t.ochre, t.bambooDark]
                      : [t.bambooHi, t.bamboo, t.bambooDark],
                ),
                border: Border.all(color: t.bambooDark, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: t.walnut.withValues(alpha: 0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$n',
                  style: SumiType.digit(19, t, digitStyle,
                      given: true, override: t.washi),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text('$remaining',
                style: SumiType.micro(10, t)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ActionRow extends StatelessWidget {
  final SumiThemeDef theme;
  final SudokuEngine engine;
  final bool notesMode;
  final VoidCallback onUndo;
  final VoidCallback onErase;
  final VoidCallback onNotes;
  final VoidCallback onHint;
  const _ActionRow({
    required this.theme,
    required this.engine,
    required this.notesMode,
    required this.onUndo,
    required this.onErase,
    required this.onNotes,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget action(IconData icon, String label, VoidCallback fn,
        {bool active = false, bool disabled = false, String? badge}) {
      return Expanded(
        child: GestureDetector(
          onTap: disabled ? null : fn,
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    WoodToken(
                      theme: t,
                      size: 50,
                      selected: active,
                      onTap: disabled ? null : fn,
                      child: Icon(icon, color: t.washi, size: 22),
                    ),
                    if (badge != null)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.vermilion,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge,
                              style: SumiType.micro(10, t,
                                  color: t.washi)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(label, style: SumiType.micro(11, t)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          action(Icons.undo, 'Undo', onUndo, disabled: !engine.hasUndo),
          action(Icons.backspace_outlined, 'Erase', onErase),
          action(Icons.edit_outlined, 'Notes', onNotes, active: notesMode),
          action(Icons.lightbulb_outline, 'Hint', onHint,
              disabled: engine.hintsLeft <= 0,
              badge: '${engine.hintsLeft}'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final SumiThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: t.sumi.withValues(alpha: 0.55),
      child: Center(
        child: WashiCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: SumiType.display(30, t)),
              const SizedBox(height: 6),
              Text('The ink rests.',
                  style: SumiType.body(14, t)),
              const SizedBox(height: 18),
              WoodButton(
                  theme: t,
                  text: 'Resume',
                  icon: Icons.play_arrow,
                  primary: true,
                  onTap: onResume),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: onRestart,
                      child: Text('Restart',
                          style: SumiType.label(13, t))),
                  TextButton(
                      onPressed: onQuit,
                      child: Text('Menu',
                          style: SumiType.label(13, t))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _VictorySheet extends StatelessWidget {
  final SumiThemeDef theme;
  final SudokuEngine engine;
  final int stars;
  final bool newBest;
  final bool daily;
  final AnimationController confetti;
  final AnimationController stamp;
  final VoidCallback onNext;
  final VoidCallback onMenu;
  const _VictorySheet({
    required this.theme,
    required this.engine,
    required this.stars,
    required this.newBest,
    required this.daily,
    required this.confetti,
    required this.stamp,
    required this.onNext,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: t.sumi.withValues(alpha: 0.55),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: confetti,
            builder: (_, _) => CustomPaint(
              size: Size.infinite,
              painter: ConfettiPainter(t, confetti.value),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: WashiCard(
                theme: t,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: stamp,
                      builder: (_, _) => Transform.scale(
                        scale: 1.6 - 0.6 * stamp.value.clamp(0.0, 1.0),
                        child: Opacity(
                          opacity: stamp.value.clamp(0.0, 1.0),
                          child: HankoStamp(theme: t, kanji: '完'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Puzzle Complete!',
                        style: SumiType.display(28, t)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int k = 0; k < 3; k++)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 3),
                            child: Text(
                              k < stars ? '★' : '☆',
                              style: TextStyle(
                                  fontSize: 34, color: t.gold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${daily ? 'Daily' : sudoDifficulties[engine.diffIndex].name}'
                      ' · ${_GameScreenState.fmtTime(engine.seconds)}'
                      ' · ${engine.mistakes} mistake${engine.mistakes == 1 ? '' : 's'}'
                      ' · ${engine.hintsUsed} hint${engine.hintsUsed == 1 ? '' : 's'}',
                      style: SumiType.micro(13, t),
                      textAlign: TextAlign.center,
                    ),
                    if (newBest)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: t.gold),
                          ),
                          child: Text('✦ New best time! ✦',
                              style: SumiType.label(13, t,
                                  color: t.gold)),
                        ),
                      ),
                    const SizedBox(height: 18),
                    WoodButton(
                        theme: t,
                        text: daily ? 'Menu' : 'Next puzzle',
                        icon: daily ? Icons.home : Icons.arrow_forward,
                        primary: true,
                        onTap: daily ? onMenu : onNext),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: onMenu,
                        child: Text('Back to menu',
                            style: SumiType.label(13, t))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _FailureSheet extends StatelessWidget {
  final SumiThemeDef theme;
  final SudokuEngine engine;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  const _FailureSheet({
    required this.theme,
    required this.engine,
    required this.onRetry,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: t.sumi.withValues(alpha: 0.55),
      child: Center(
        child: WashiCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ink spilled…',
                  style: SumiType.display(26, t)),
              const SizedBox(height: 8),
              Text(
                'The mistake limit was reached in strict mode.\nEvery master was once a beginner.',
                style: SumiType.body(14, t),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              WoodButton(
                  theme: t,
                  text: 'Try again',
                  icon: Icons.refresh,
                  primary: true,
                  onTap: onRetry),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: onMenu,
                  child:
                      Text('Back to menu', style: SumiType.label(13, t))),
            ],
          ),
        ),
      ),
    );
  }
}
