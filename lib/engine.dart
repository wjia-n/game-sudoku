import 'dart:math';

/// Difficulty levels per RULES.md §2.
class SudoDifficulty {
  const SudoDifficulty(this.name, this.ja, this.givens, this.key);

  final String name;
  final String ja; // kanji seal mark
  final int givens;
  final String key;
}

const sudoDifficulties = [
  SudoDifficulty('Easy', '易', 38, 'easy'),
  SudoDifficulty('Medium', '中', 32, 'medium'),
  SudoDifficulty('Hard', '難', 28, 'hard'),
  SudoDifficulty('Expert', '極', 24, 'expert'),
];

/// Core Sudoku engine: puzzle generation (guaranteed unique solution),
/// candidate logic, undo, mistakes, hints, win detection.
/// Kept from the original implementation; extended per RULES.md.
class SudokuEngine {
  SudokuEngine({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  List<int> solution = List.filled(81, 0);
  List<int> start = List.filled(81, 0); // initial givens
  List<int> val = List.filled(81, 0);
  List<bool> wrong = List.filled(81, false); // error cells (placed digits)
  List<Set<int>> notes = List.generate(81, (_) => <int>{});

  int mistakes = 0;
  int hintsUsed = 0;
  int seconds = 0;
  bool timerRunning = false;
  bool won = false;
  bool failed = false;

  final List<_Snapshot> _undoStack = [];

  bool get hasUndo => _undoStack.isNotEmpty;

  // ------------------------------------------------------------------ gen
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
      for (final n in candidates(g, pos)..shuffle(_rng)) {
        g[pos] = n;
        if (fill(pos + 1)) return true;
        g[pos] = 0;
      }
      return false;
    }

    fill(0);
    return g;
  }

  List<int> _dig(List<int> s, int givens) {
    final p = List<int>.from(s);
    final order = List.generate(81, (i) => i)..shuffle(_rng);
    var remaining = 81;
    for (final i in order) {
      if (remaining <= givens) break;
      final backup = p[i];
      p[i] = 0;
      if (countSolutions(List<int>.from(p), 2) != 1) {
        p[i] = backup;
      } else {
        remaining--;
      }
    }
    return p;
  }

  /// Generate a fresh puzzle of difficulty [diffIndex].
  void newGame(int diffIndex) {
    final s = _genSolved();
    final puzzle = _dig(s, sudoDifficulties[diffIndex].givens);
    solution = s;
    start = puzzle;
    val = List<int>.from(puzzle);
    wrong = List.filled(81, false);
    notes = List.generate(81, (_) => <int>{});
    mistakes = 0;
    hintsUsed = 0;
    seconds = 0;
    timerRunning = false;
    won = false;
    failed = false;
    _undoStack.clear();
  }

  bool isGiven(int i) => start[i] != 0;

  // ----------------------------------------------------------------- undo
  void _pushUndo() {
    _undoStack.add(_Snapshot(
      val: List<int>.from(val),
      wrong: List<bool>.from(wrong),
      notes: [for (final s in notes) Set<int>.of(s)],
      mistakes: mistakes,
    ));
    if (_undoStack.length > 400) _undoStack.removeAt(0);
  }

  /// Undo the last player action. Locked (hinted/given) cells are never
  /// reverted — undo skips them by restoring snapshots taken before they
  /// were placed.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    final s = _undoStack.removeLast();
    val = s.val;
    wrong = s.wrong;
    notes = s.notes;
    mistakes = s.mistakes;
    return true;
  }

  // ---------------------------------------------------------------- moves
  /// Place/remove a final digit. Returns:
  /// - 'correct' when the digit matches the solution,
  /// - 'wrong' when it does not (a mistake; digit stays as visible error),
  /// - 'removed' when tapping the same digit clears it.
  String enterDigit(int i, int n, {required bool autoNoteCleanup}) {
    if (start[i] != 0 || won || failed) return 'locked';
    _pushUndo();
    _startTimer();
    if (val[i] == n && !wrong[i]) {
      // Tap again to clear own correct entry.
      val[i] = 0;
      notes[i].clear();
      return 'removed';
    }
    val[i] = n;
    notes[i].clear();
    if (n == solution[i]) {
      wrong[i] = false;
      if (autoNoteCleanup) _clearNoteFromPeers(i, n);
      return 'correct';
    } else {
      wrong[i] = true;
      mistakes++;
      return 'wrong';
    }
  }

  /// Toggle a pencil candidate. Returns true if notes changed.
  bool toggleNote(int i, int n) {
    if (start[i] != 0 || won || failed) return false;
    _pushUndo();
    _startTimer();
    if (notes[i].contains(n)) {
      notes[i].remove(n);
    } else {
      notes[i].add(n);
    }
    return true;
  }

  /// Erase a player digit / notes. Returns true if something changed.
  bool erase(int i) {
    if (start[i] != 0 || won || failed) return false;
    if (val[i] == 0 && notes[i].isEmpty) return false;
    _pushUndo();
    _startTimer();
    val[i] = 0;
    wrong[i] = false;
    notes[i].clear();
    return true;
  }

  /// Hint: fill the selected empty cell (or a cell solvable by naked
  /// single, else fewest candidates) with the solution digit and lock it.
  /// Hinted cells are locked like givens — never undone/erased.
  /// Returns the filled index, or -1 if none.
  int useHint(int sel) {
    if (won || failed) return -1;
    int target = -1;
    if (sel >= 0 && start[sel] == 0 && val[sel] == 0) {
      target = sel;
    } else {
      // Prefer a naked single to teach technique.
      int bestCount = 99;
      for (var i = 0; i < 81; i++) {
        if (start[i] != 0 || val[i] != 0) continue;
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
    _startTimer();
    val[target] = solution[target];
    start[target] = solution[target]; // locked like a given
    wrong[target] = false;
    notes[target].clear();
    _clearNoteFromPeers(target, solution[target]);
    hintsUsed++;
    return target;
  }

  void _startTimer() {
    timerRunning = true;
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

  /// Remaining count of digit [n] (9 - placed).
  int remainingOf(int n) {
    var placed = 0;
    for (final v in val) {
      if (v == n) placed++;
    }
    return 9 - placed;
  }

  bool checkWin() {
    for (var i = 0; i < 81; i++) {
      if (val[i] != solution[i]) return false;
    }
    won = true;
    return true;
  }

  /// Star rating per RULES.md §8.
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

  // ------------------------------------------------------------ persistence
  Map<String, dynamic> toJson(int diffIndex) => {
        'v': 1,
        'diff': diffIndex,
        'solution': solution,
        'start': start,
        'val': val,
        'wrong': wrong,
        'notes': [for (final s in notes) s.toList()],
        'mistakes': mistakes,
        'hintsUsed': hintsUsed,
        'seconds': seconds,
        'timerRunning': timerRunning,
      };

  void fromJson(Map<String, dynamic> m) {
    solution = List<int>.from(m['solution'] as List);
    start = List<int>.from(m['start'] as List);
    val = List<int>.from(m['val'] as List);
    wrong = List<bool>.from(m['wrong'] as List);
    notes = [
      for (final l in (m['notes'] as List))
        Set<int>.of((l as List).map((e) => e as int))
    ];
    mistakes = m['mistakes'] as int;
    hintsUsed = m['hintsUsed'] as int;
    seconds = m['seconds'] as int;
    timerRunning = m['timerRunning'] as bool;
    won = false;
    failed = false;
    _undoStack.clear();
  }
}

class _Snapshot {
  _Snapshot({
    required this.val,
    required this.wrong,
    required this.notes,
    required this.mistakes,
  });

  final List<int> val;
  final List<bool> wrong;
  final List<Set<int>> notes;
  final int mistakes;
}
