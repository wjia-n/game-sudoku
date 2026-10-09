import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Difficulties (RULES.md §2; Novice added 2026-10-09 retrofit — see RULES.md).
// ---------------------------------------------------------------------------
class SudoDifficulty {
  const SudoDifficulty({
    required this.name,
    required this.ja,
    required this.givens,
    required this.key,
  });

  final String name;
  final String ja; // kanji seal mark
  final int givens;
  final String key;
}

const sudoDifficulties = [
  SudoDifficulty(name: 'Novice', ja: '新', givens: 45, key: 'novice'),
  SudoDifficulty(name: 'Easy', ja: '易', givens: 38, key: 'easy'),
  SudoDifficulty(name: 'Medium', ja: '中', givens: 32, key: 'medium'),
  SudoDifficulty(name: 'Hard', ja: '難', givens: 28, key: 'hard'),
  SudoDifficulty(name: 'Expert', ja: '極', givens: 24, key: 'expert'),
];

/// Engine-owned game phases. The UI only renders — it never drives phases.
enum SudoPhase { idle, playing, paused, won, failed }

/// UI hooks for sounds / animations. Set by the screen.
enum SudoEvent {
  correctEntry,
  wrongEntry,
  invalid,
  note,
  erase,
  undo,
  hint,
  win,
  fail,
  timerStarted,
}

// ---------------------------------------------------------------------------
// Engine: deterministic rules per RULES.md, owns ALL game state.
// The timer is engine-owned; a watchdog recovers any inconsistent state,
// so stuck states are impossible by construction.
// ---------------------------------------------------------------------------
class SudokuEngine extends ChangeNotifier {
  SudokuEngine({Random? rng}) : _rng = rng ?? Random();

  Random _rng;

  // Config (set at newGame; persisted with the save).
  int diffIndex = 1;
  bool relaxed = false; // relaxed mode: no mistake counting, timer hidden
  int mistakeBudget = 3; // 0 = off
  bool strictMode = false;
  bool autoNoteCleanup = true;
  bool isDaily = false;
  String dailyKey = '';

  // Board state.
  List<int> solution = List.filled(81, 0);
  List<int> start = List.filled(81, 0); // printed givens
  List<int> val = List.filled(81, 0);
  List<bool> wrong = List.filled(81, false);
  List<Set<int>> notes = List.generate(81, (_) => <int>{});
  Set<int> hinted = <int>{}; // hint-locked cells (locked like givens)

  int mistakes = 0;
  int hintsUsed = 0;
  int seconds = 0;
  SudoPhase phase = SudoPhase.idle;
  bool timerRunning = false;

  final List<_Snapshot> _undoStack = [];
  bool get hasUndo => _undoStack.isNotEmpty;

  void Function(SudoEvent event)? onEvent;

  // Engine-owned 1s ticker + watchdog.
  Timer? _tick;
  Timer? _watchdog;
  DateTime _lastTickAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  int get hintLimit => 3;
  int get hintsLeft => (hintLimit - hintsUsed).clamp(0, hintLimit);
  bool get playing => phase == SudoPhase.playing;
  bool get paused => phase == SudoPhase.paused;
  bool get over => phase == SudoPhase.won || phase == SudoPhase.failed;
  int get mistakesLeft =>
      mistakeBudget <= 0 ? 0 : (mistakeBudget - mistakes).clamp(0, 99);

  bool isLocked(int i) => start[i] != 0 || hinted.contains(i);
  bool isGiven(int i) => start[i] != 0;

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- game setup
  /// Generate and start a fresh puzzle. Heavy: call off the UI thread's
  /// critical path (show a spinner first).
  void newGame(
    int diff, {
    bool relaxedMode = false,
    int budget = 3,
    bool strict = false,
    bool autoCleanup = true,
    bool daily = false,
    String dateKey = '',
    int? seed,
  }) {
    diffIndex = diff.clamp(0, sudoDifficulties.length - 1);
    relaxed = relaxedMode;
    mistakeBudget = budget;
    strictMode = strict;
    autoNoteCleanup = autoCleanup;
    isDaily = daily;
    dailyKey = dateKey;
    if (seed != null) _rng = Random(seed);

    final target = sudoDifficulties[diffIndex].givens;
    var solved = _genSolved();
    // Dig with retries: greedy removal can stall just above the target on
    // some shuffles — re-dig (fresh order, then fresh solved grids) and
    // keep the best result, so the exact given count is reliably hit.
    var dug = _digBest(solved, target);
    solved = dug.solved;
    var puzzle = dug.puzzle;
    // Difficulty calibration (RULES §11.4): Hard/Expert must need real
    // technique; re-dig from a fresh solution a few times if too easy.
    if (diffIndex >= 3) {
      final need = diffIndex == 4 ? 4 : 1;
      var attempts = 0;
      while (_branchRating(puzzle) < need && attempts < 5) {
        attempts++;
        dug = _digBest(_genSolved(), target);
        solved = dug.solved;
        puzzle = dug.puzzle;
      }
    }
    solution = solved;
    start = puzzle;
    val = List<int>.from(puzzle);
    wrong = List.filled(81, false);
    notes = List.generate(81, (_) => <int>{});
    hinted = <int>{};
    mistakes = 0;
    hintsUsed = 0;
    seconds = 0;
    timerRunning = false;
    phase = SudoPhase.playing;
    _undoStack.clear();
    _startTimers();
    notifyListeners();
  }

  /// Number of branch points (cells with no naked single) the MRV solver
  /// hits — a cheap difficulty proxy for calibration.
  static int _branchRating(List<int> puzzle) {
    final g = List<int>.from(puzzle);
    var branches = 0;
    bool solve() {
      var bi = -1;
      List<int>? bc;
      for (var i = 0; i < 81; i++) {
        if (g[i] != 0) continue;
        final c = candidates(g, i);
        if (c.isEmpty) return false;
        if (bc == null || c.length < bc.length) {
          bi = i;
          bc = c;
        }
        if (c.length == 1) break;
      }
      if (bi < 0) return true;
      if (bc!.length > 1) branches++;
      for (final n in bc) {
        g[bi] = n;
        if (solve()) return true;
        g[bi] = 0;
      }
      return false;
    }

    solve();
    return branches;
  }

  // ------------------------------------------------------- puzzle generation
  /// Candidate digits for cell [i] in grid [g].
  static List<int> candidates(List<int> g, int i) {
    final used = List.filled(10, false);
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 9; k++) {
      used[g[r * 9 + k]] = true;
      used[g[k * 9 + c]] = true;
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        used[g[(br + dr) * 9 + bc + dc]] = true;
      }
    }
    return [for (var n = 1; n <= 9; n++) if (!used[n]) n];
  }

  /// Count solutions up to [limit].
  static int countSolutions(List<int> g, int limit) {
    var count = 0;

    void solve() {
      if (count >= limit) return;
      var bi = -1;
      List<int>? bc;
      for (var i = 0; i < 81; i++) {
        if (g[i] != 0) continue;
        final c = candidates(g, i);
        if (c.isEmpty) return;
        if (bc == null || c.length < bc.length) {
          bi = i;
          bc = c;
        }
        if (c.length == 1) break;
      }
      if (bi < 0) {
        count++;
        return;
      }
      for (final n in bc!) {
        g[bi] = n;
        solve();
        g[bi] = 0;
        if (count >= limit) return;
      }
    }

    solve();
    return count;
  }

  List<int> _genSolved() {
    final g = List.filled(81, 0);

    bool fill(int pos) {
      if (pos == 81) return true;
      final ns = candidates(g, pos)..shuffle(_rng);
      for (final n in ns) {
        g[pos] = n;
        if (fill(pos + 1)) return true;
        g[pos] = 0;
      }
      return false;
    }

    fill(0);
    _applySymmetries(g);
    return g;
  }

  /// RULES §11.2: random symmetries diversify the solved grid.
  void _applySymmetries(List<int> g) {
    // Digit relabeling.
    final relabel = List.generate(9, (i) => i + 1)..shuffle(_rng);
    for (var i = 0; i < 81; i++) {
      g[i] = relabel[g[i] - 1];
    }
    var grid = List<int>.from(g);
    // Transpose / rotate.
    if (_rng.nextBool()) {
      final t = List.filled(81, 0);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          t[c * 9 + r] = grid[r * 9 + c];
        }
      }
      grid = t;
    }
    final rots = _rng.nextInt(4);
    for (var k = 0; k < rots; k++) {
      final t = List.filled(81, 0);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          t[c * 9 + (8 - r)] = grid[r * 9 + c];
        }
      }
      grid = t;
    }
    // Shuffle bands/stacks and rows/cols within them. The row permutation
    // for a band and the column permutation for a stack must each be chosen
    // ONCE (not per sub-iteration), or columns/rows stop being consistent
    // permutations and the grid stops being a valid solution.
    int cell(int r, int c) => grid[r * 9 + c];
    final bands = [0, 1, 2]..shuffle(_rng);
    final stacks = [0, 1, 2]..shuffle(_rng);
    final rowPerms = [for (var k = 0; k < 3; k++) [0, 1, 2]..shuffle(_rng)];
    final colPerms = [for (var k = 0; k < 3; k++) [0, 1, 2]..shuffle(_rng)];
    final out = List.filled(81, 0);
    for (var br = 0; br < 3; br++) {
      for (var bc = 0; bc < 3; bc++) {
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 3; c++) {
            out[(br * 3 + r) * 9 + bc * 3 + c] = cell(
                bands[br] * 3 + rowPerms[br][r],
                stacks[bc] * 3 + colPerms[bc][c]);
          }
        }
      }
    }
    for (var i = 0; i < 81; i++) {
      g[i] = out[i];
    }
  }

  static int _givens(List<int> p) => p.where((v) => v != 0).length;

  /// Dig with retries: greedy removal can stall just above [target] on some
  /// shuffles — re-dig (fresh order, then fresh solved grids) and keep the
  /// best result, so the exact given count is reliably hit. Returns the
  /// solved grid the winning puzzle was dug from (kept in sync).
  ({List<int> solved, List<int> puzzle}) _digBest(
      List<int> solved, int target) {
    var grid = solved;
    var best = _dig(grid, target);
    var bestCount = _givens(best);
    var bestGrid = grid;
    for (var round = 0; round < 3 && bestCount > target; round++) {
      for (var attempt = 0; attempt < 4 && bestCount > target; attempt++) {
        final retry = _dig(grid, target);
        final n = _givens(retry);
        if (n < bestCount) {
          best = retry;
          bestCount = n;
          bestGrid = grid;
        }
      }
      if (bestCount > target) grid = _genSolved();
    }
    return (solved: bestGrid, puzzle: best);
  }

  /// Dig to exactly [target] givens: symmetric pairs first, then a single
  /// non-center singleton per even target (parity: pairs from 81 can only
  /// reach odd counts — RULES.md §7). Every removal is uniqueness-verified.
  List<int> _dig(List<int> solved, int target) {
    final p = List<int>.from(solved);
    final pairs = <List<int>>[];
    for (var i = 0; i < 40; i++) {
      pairs.add([i, 80 - i]);
    }
    pairs.shuffle(_rng);
    var remaining = 81;
    for (final pair in pairs) {
      if (remaining <= target + 1) break;
      final a = p[pair[0]], b = p[pair[1]];
      p[pair[0]] = 0;
      p[pair[1]] = 0;
      if (countSolutions(List<int>.from(p), 2) != 1) {
        p[pair[0]] = a;
        p[pair[1]] = b;
      } else {
        remaining -= 2;
      }
    }
    // Finish to the exact target with uniqueness-checked singles.
    var guard = 0;
    while (remaining > target && guard < 400) {
      guard++;
      var removed = false;
      final order = List.generate(81, (i) => i)..shuffle(_rng);
      for (final i in order) {
        if (p[i] == 0 || i == 40) continue;
        final bak = p[i];
        p[i] = 0;
        if (countSolutions(List<int>.from(p), 2) != 1) {
          p[i] = bak;
        } else {
          remaining--;
          removed = true;
          break;
        }
      }
      if (!removed) break;
    }
    return p;
  }

  // ------------------------------------------------------------------ undo
  void _pushUndo() {
    _undoStack.add(_Snapshot(
      val: List<int>.from(val),
      wrong: List<bool>.from(wrong),
      notes: [for (final s in notes) Set<int>.of(s)],
      mistakes: mistakes,
      hinted: Set<int>.of(hinted),
    ));
    if (_undoStack.length > 400) _undoStack.removeAt(0);
  }

  /// Undo the last player action. Hinted (locked) cells are baked into every
  /// snapshot when the hint is placed, so undo can never remove a hint —
  /// it reverts the previous player action instead (RULES §12).
  bool undo() {
    if (_undoStack.isEmpty || !playing) return false;
    final s = _undoStack.removeLast();
    val = s.val;
    wrong = s.wrong;
    notes = s.notes;
    mistakes = s.mistakes;
    hinted = s.hinted;
    onEvent?.call(SudoEvent.undo);
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------ moves
  void _startTimer() {
    if (!timerRunning && playing) {
      timerRunning = true;
      onEvent?.call(SudoEvent.timerStarted);
    }
  }

  /// Place/remove a final digit. Returns 'correct' | 'wrong' | 'removed' |
  /// 'locked'. RULES §4–§5.
  String enterDigit(int i, int n) {
    if (!playing) return 'locked';
    if (isLocked(i)) {
      onEvent?.call(SudoEvent.invalid);
      return 'locked';
    }
    _pushUndo();
    _startTimer();
    if (val[i] == n && !wrong[i]) {
      // Tap again to clear own correct entry.
      val[i] = 0;
      notes[i].clear();
      onEvent?.call(SudoEvent.erase);
      notifyListeners();
      return 'removed';
    }
    val[i] = n;
    notes[i].clear();
    if (n == solution[i]) {
      wrong[i] = false;
      if (autoNoteCleanup) _clearNoteFromPeers(i, n);
      onEvent?.call(SudoEvent.correctEntry);
      notifyListeners();
      _afterChange();
      return 'correct';
    } else {
      wrong[i] = true;
      if (!relaxed && mistakeBudget > 0) {
        mistakes++;
        if (strictMode && mistakes >= mistakeBudget) {
          onEvent?.call(SudoEvent.wrongEntry);
          notifyListeners();
          _fail();
          return 'wrong';
        }
      }
      onEvent?.call(SudoEvent.wrongEntry);
      notifyListeners();
      _afterChange();
      return 'wrong';
    }
  }

  /// Toggle a pencil candidate (RULES §4). Notes are never validated.
  bool toggleNote(int i, int n) {
    if (!playing || isLocked(i)) return false;
    _pushUndo();
    _startTimer();
    if (notes[i].contains(n)) {
      notes[i].remove(n);
    } else {
      notes[i].add(n);
    }
    onEvent?.call(SudoEvent.note);
    notifyListeners();
    return true;
  }

  /// Erase a player digit / notes (RULES §4). Locked cells are rejected.
  bool erase(int i) {
    if (!playing || isLocked(i)) return false;
    if (val[i] == 0 && notes[i].isEmpty) return false;
    _pushUndo();
    _startTimer();
    val[i] = 0;
    wrong[i] = false;
    notes[i].clear();
    onEvent?.call(SudoEvent.erase);
    notifyListeners();
    return true;
  }

  /// Hint (RULES §7, §11): fills the selected empty cell — or, if none, a
  /// naked single else the fewest-candidate cell — with the correct digit
  /// and locks it. Limited to [hintLimit] per puzzle. Never undoable.
  int useHint(int sel) {
    if (!playing || hintsUsed >= hintLimit) return -1;
    var target = -1;
    if (sel >= 0 && sel < 81 && !isLocked(sel) && val[sel] == 0) {
      target = sel;
    } else {
      var bestCount = 99;
      for (var i = 0; i < 81; i++) {
        if (isLocked(i) || val[i] != 0) continue;
        final c = candidates(val, i);
        if (c.length == 1) {
          target = i;
          break;
        }
        if (c.length < bestCount) {
          bestCount = c.length;
          target = i;
        }
      }
    }
    if (target < 0) return -1;
    // Bake the hint into every undo snapshot: undo can never remove it.
    for (final s in _undoStack) {
      s.val[target] = solution[target];
      s.wrong[target] = false;
      s.notes[target].clear();
      s.hinted.add(target);
    }
    _startTimer();
    val[target] = solution[target];
    hinted.add(target);
    wrong[target] = false;
    notes[target].clear();
    _clearNoteFromPeers(target, solution[target]);
    hintsUsed++;
    onEvent?.call(SudoEvent.hint);
    notifyListeners();
    _afterChange();
    return target;
  }

  void _clearNoteFromPeers(int i, int n) {
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 9; k++) {
      notes[r * 9 + k].remove(n);
      notes[k * 9 + c].remove(n);
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        notes[(br + dr) * 9 + bc + dc].remove(n);
      }
    }
  }

  /// Remaining count of digit [n] (9 − placed).
  int remainingOf(int n) {
    var placed = 0;
    for (final v in val) {
      if (v == n) placed++;
    }
    return 9 - placed;
  }

  /// Peer-conflict scan for highlighting (RULES §7): returns indexes of
  /// cells conflicting with the digit at [i].
  List<int> conflictsOf(int i) {
    final out = <int>[];
    final n = val[i];
    if (n == 0) return out;
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 9; k++) {
      final a = r * 9 + k, b = k * 9 + c;
      if (a != i && val[a] == n) out.add(a);
      if (b != i && val[b] == n) out.add(b);
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        final j = (br + dr) * 9 + bc + dc;
        if (j != i && val[j] == n) out.add(j);
      }
    }
    return out;
  }

  bool _allCorrect() {
    for (var i = 0; i < 81; i++) {
      if (val[i] != solution[i]) return false;
    }
    return true;
  }

  void _afterChange() {
    if (playing && _allCorrect()) _win();
  }

  void _win() {
    phase = SudoPhase.won;
    timerRunning = false;
    _tick?.cancel();
    _tick = null;
    onEvent?.call(SudoEvent.win);
    notifyListeners();
  }

  void _fail() {
    phase = SudoPhase.failed;
    timerRunning = false;
    _tick?.cancel();
    _tick = null;
    onEvent?.call(SudoEvent.fail);
    notifyListeners();
  }

  /// Star rating (RULES §8).
  int stars() {
    if (mistakes == 0 && hintsUsed == 0) return 3;
    if (mistakes <= 2 && hintsUsed <= 1) return 2;
    return 1;
  }

  bool get hasAnyInput {
    for (var i = 0; i < 81; i++) {
      if (val[i] != start[i] || notes[i].isNotEmpty) return true;
    }
    return false;
  }

  // --------------------------------------------------------------- pause/Go
  void setPaused(bool v) {
    if (_disposed || over) return;
    if (v && phase == SudoPhase.playing) {
      phase = SudoPhase.paused;
      _tick?.cancel();
      _tick = null;
      notifyListeners();
    } else if (!v && phase == SudoPhase.paused) {
      phase = SudoPhase.playing;
      _startTimers();
      notifyListeners();
    }
  }

  /// Restart the same puzzle (RULES §4): givens only, mistakes/hints/timer
  /// reset.
  void restart() {
    if (_disposed || phase == SudoPhase.idle) return;
    val = List<int>.from(start);
    wrong = List.filled(81, false);
    notes = List.generate(81, (_) => <int>{});
    hinted = <int>{};
    mistakes = 0;
    hintsUsed = 0;
    seconds = 0;
    timerRunning = false;
    phase = SudoPhase.playing;
    _undoStack.clear();
    _startTimers();
    notifyListeners();
  }

  // ------------------------------------------------------------- timers/WD
  void _startTimers() {
    if (_disposed) return;
    _tick?.cancel();
    _watchdog?.cancel();
    _lastTickAt = DateTime.now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      if (phase == SudoPhase.playing && timerRunning) {
        seconds++;
        _lastTickAt = DateTime.now();
        notifyListeners();
      }
    });
    _watchdog = Timer.periodic(const Duration(seconds: 4), (_) => _recover());
  }

  /// Watchdog: repairs any inconsistent engine state. Respects pause.
  void _recover() {
    if (_disposed || paused || over) return;
    if (phase == SudoPhase.playing) {
      // Timer dead while it should run → force a tick.
      if (timerRunning &&
          DateTime.now().difference(_lastTickAt).inMilliseconds > 2500) {
        seconds++;
        _lastTickAt = DateTime.now();
        notifyListeners();
      }
      // Safety net: fully correct board must be won (can never stick).
      if (_allCorrect()) {
        _win();
        return;
      }
      // Safety net: strict-mode overflow must fail (can never stick).
      if (!relaxed &&
          strictMode &&
          mistakeBudget > 0 &&
          mistakes >= mistakeBudget) {
        _fail();
      }
    }
  }

  // ------------------------------------------------------------ persistence
  Map<String, dynamic> toJson() => {
        'v': 2,
        'diff': diffIndex,
        'relaxed': relaxed,
        'budget': mistakeBudget,
        'strict': strictMode,
        'autoCleanup': autoNoteCleanup,
        'daily': isDaily,
        'dailyKey': dailyKey,
        'solution': solution,
        'start': start,
        'val': val,
        'wrong': wrong,
        'notes': [for (final s in notes) s.toList()],
        'hinted': hinted.toList(),
        'mistakes': mistakes,
        'hintsUsed': hintsUsed,
        'seconds': seconds,
        'timerRunning': timerRunning,
        'phase': phase == SudoPhase.paused ? 'paused' : 'playing',
      };

  void fromJson(Map<String, dynamic> m) {
    diffIndex = (m['diff'] as int).clamp(0, sudoDifficulties.length - 1);
    relaxed = m['relaxed'] as bool? ?? false;
    mistakeBudget = m['mistakeBudget'] as int? ?? m['budget'] as int? ?? 3;
    strictMode = m['strict'] as bool? ?? false;
    autoNoteCleanup = m['autoCleanup'] as bool? ?? true;
    isDaily = m['daily'] as bool? ?? false;
    dailyKey = m['dailyKey'] as String? ?? '';
    solution = List<int>.from(m['solution'] as List);
    start = List<int>.from(m['start'] as List);
    val = List<int>.from(m['val'] as List);
    wrong = List<bool>.from(m['wrong'] as List);
    notes = [
      for (final l in (m['notes'] as List))
        Set<int>.of((l as List).map((e) => e as int))
    ];
    hinted = Set<int>.of((m['hinted'] as List? ?? []).map((e) => e as int));
    mistakes = m['mistakes'] as int;
    hintsUsed = m['hintsUsed'] as int;
    seconds = m['seconds'] as int;
    timerRunning = m['timerRunning'] as bool? ?? false;
    phase = SudoPhase.playing;
    _undoStack.clear();
    _startTimers();
    notifyListeners();
  }
}

class _Snapshot {
  _Snapshot({
    required this.val,
    required this.wrong,
    required this.notes,
    required this.mistakes,
    required this.hinted,
  });

  List<int> val;
  List<bool> wrong;
  List<Set<int>> notes;
  int mistakes;
  Set<int> hinted;
}
