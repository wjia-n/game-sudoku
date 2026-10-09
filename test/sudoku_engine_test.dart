import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/engine/sudoku_engine.dart';

void main() {
  group('Generation (RULES.md §2, §7, §11)', () {
    test('every difficulty yields exact givens and a unique solution', () {
      for (var d = 0; d < sudoDifficulties.length; d++) {
        final e = SudokuEngine(rng: Random(1234 + d));
        e.newGame(d);
        final givens =
            e.start.where((v) => v != 0).length;
        expect(givens, sudoDifficulties[d].givens,
            reason: '${sudoDifficulties[d].name} givens');
        expect(SudokuEngine.countSolutions(List<int>.from(e.start), 2), 1,
            reason: '${sudoDifficulties[d].name} unique solution');
        // Solution is a valid completed grid.
        for (var i = 0; i < 81; i++) {
          expect(SudokuEngine.candidates(e.solution, i), isEmpty,
              reason: 'solution complete at $i');
        }
        e.dispose();
      }
    });

    test('seeded generation is deterministic (daily puzzle)', () {
      final a = SudokuEngine(rng: Random(999));
      a.newGame(3, seed: 20261009);
      final b = SudokuEngine(rng: Random(1));
      b.newGame(3, seed: 20261009);
      expect(a.start, b.start);
      expect(a.solution, b.solution);
      a.dispose();
      b.dispose();
    });
  });

  group('Moves (RULES.md §4, §5)', () {
    test('fresh puzzle: locked givens, 0 mistakes, timer idle', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1); // Easy: 38 givens
      expect(e.mistakes, 0);
      expect(e.hintsUsed, 0);
      expect(e.seconds, 0);
      expect(e.timerRunning, false);
      expect(e.phase, SudoPhase.playing);
      e.dispose();
    });

    test('legal entry: correct digit, no mistake', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      final r = e.enterDigit(i, e.solution[i]);
      expect(r, 'correct');
      expect(e.mistakes, 0);
      expect(e.val[i], e.solution[i]);
      expect(e.timerRunning, true); // timer starts on first input
      e.dispose();
    });

    test('given lock: rejected', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v != 0);
      final before = e.val[i];
      expect(e.enterDigit(i, 5), 'locked');
      expect(e.val[i], before);
      expect(e.mistakes, 0);
      e.dispose();
    });

    test('wrong entry: mistake +1, vermilion error stays', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      final wrongDigit = e.solution[i] % 9 + 1;
      expect(e.enterDigit(i, wrongDigit), 'wrong');
      expect(e.mistakes, 1);
      expect(e.wrong[i], true);
      expect(e.val[i], wrongDigit); // digit remains until erased
      e.dispose();
    });

    test('mistake limit (default mode): continues, star capped', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1, budget: 3, strict: false);
      var made = 0;
      for (var i = 0; i < 81 && made < 3; i++) {
        if (e.start[i] != 0) continue;
        final wd = e.solution[i] % 9 + 1;
        if (e.enterDigit(i, wd) == 'wrong') made++;
      }
      expect(e.mistakes, 3);
      expect(e.phase, SudoPhase.playing); // not a loss in default mode
      expect(e.stars(), 1);
      e.dispose();
    });

    test('strict mode: mistake limit fails the puzzle', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1, budget: 3, strict: true);
      var made = 0;
      for (var i = 0; i < 81 && made < 3; i++) {
        if (e.start[i] != 0) continue;
        final wd = e.solution[i] % 9 + 1;
        if (e.enterDigit(i, wd) == 'wrong') made++;
      }
      expect(e.phase, SudoPhase.failed);
      e.dispose();
    });

    test('relaxed mode: mistakes not counted', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1, relaxedMode: true, budget: 3, strict: true);
      final i = e.start.indexWhere((v) => v == 0);
      final wd = e.solution[i] % 9 + 1;
      expect(e.enterDigit(i, wd), 'wrong');
      expect(e.mistakes, 0);
      expect(e.phase, SudoPhase.playing);
      e.dispose();
    });
  });

  group('Notes / erase / undo (RULES.md §4, §12)', () {
    test('notes mode: toggle 3 and 7, re-toggle removes', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      expect(e.toggleNote(i, 3), true);
      expect(e.toggleNote(i, 7), true);
      expect(e.notes[i], {3, 7});
      expect(e.toggleNote(i, 3), true);
      expect(e.notes[i], {7});
      e.dispose();
    });

    test('erase clears digit', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      e.enterDigit(i, e.solution[i]);
      expect(e.erase(i), true);
      expect(e.val[i], 0);
      e.dispose();
    });

    test('undo chain restores givens', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final empties =
          [for (var i = 0; i < 81; i++) if (e.start[i] == 0) i];
      e.enterDigit(empties[0], e.solution[empties[0]]);
      e.enterDigit(empties[1], e.solution[empties[1]]);
      expect(e.undo(), true);
      expect(e.val[empties[1]], 0);
      expect(e.undo(), true);
      expect(e.val[empties[0]], 0);
      expect(e.hasUndo, false);
      e.dispose();
    });

    test('undo can never remove a hinted cell', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final empties =
          [for (var i = 0; i < 81; i++) if (e.start[i] == 0) i];
      e.enterDigit(empties[0], e.solution[empties[0]]);
      final hintedAt = e.useHint(empties[1]);
      expect(hintedAt, greaterThanOrEqualTo(0));
      e.enterDigit(empties[2], e.solution[empties[2]]);
      // Undo the last entry…
      expect(e.undo(), true);
      expect(e.val[empties[2]], 0);
      // …the hint survives every undo back to the start.
      while (e.undo()) {}
      expect(e.val[hintedAt], e.solution[hintedAt]);
      expect(e.isLocked(hintedAt), true);
      e.dispose();
    });
  });

  group('Hints (RULES.md §7, §11)', () {
    test('hint fills selected empty cell, locks it, counts', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      final t = e.useHint(i);
      expect(t, i);
      expect(e.val[i], e.solution[i]);
      expect(e.isLocked(i), true);
      expect(e.hintsUsed, 1);
      // Locked: cannot erase or undo away.
      expect(e.erase(i), false);
      e.dispose();
    });

    test('hint limit enforced', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      for (var k = 0; k < 3; k++) {
        expect(e.useHint(-1), greaterThanOrEqualTo(0));
      }
      expect(e.useHint(-1), -1);
      expect(e.hintsUsed, 3);
      e.dispose();
    });

    test('hint prefers a naked single when none selected', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final t = e.useHint(-1);
      expect(t, greaterThanOrEqualTo(0));
      expect(e.val[t], e.solution[t]);
      e.dispose();
    });
  });

  group('Win / stars (RULES.md §8, §9)', () {
    test('win path: fill all correctly → won, 3 stars', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(0); // Novice: fast to fill
      for (var i = 0; i < 81; i++) {
        if (e.start[i] == 0) e.enterDigit(i, e.solution[i]);
      }
      expect(e.phase, SudoPhase.won);
      expect(e.timerRunning, false);
      expect(e.stars(), 3);
      e.dispose();
    });

    test('2 stars with ≤2 mistakes and ≤1 hint', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(0);
      final empties =
          [for (var i = 0; i < 81; i++) if (e.start[i] == 0) i];
      final wd = e.solution[empties[0]] % 9 + 1;
      e.enterDigit(empties[0], wd); // 1 mistake
      e.erase(empties[0]);
      e.useHint(empties[1]); // 1 hint
      for (final i in empties) {
        if (e.val[i] == 0) e.enterDigit(i, e.solution[i]);
      }
      expect(e.phase, SudoPhase.won);
      expect(e.stars(), 2);
      e.dispose();
    });
  });

  group('Pause / restart (RULES.md §4, §13)', () {
    test('pause freezes input and timer; resume continues', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      e.enterDigit(i, e.solution[i]);
      e.setPaused(true);
      expect(e.phase, SudoPhase.paused);
      expect(e.enterDigit(i, e.solution[i]), 'locked');
      e.setPaused(false);
      expect(e.phase, SudoPhase.playing);
      e.dispose();
    });

    test('restart resets to givens', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(1);
      final i = e.start.indexWhere((v) => v == 0);
      e.enterDigit(i, e.solution[i]);
      e.toggleNote(i, 4);
      e.restart();
      expect(e.val, e.start);
      expect(e.mistakes, 0);
      expect(e.seconds, 0);
      expect(e.phase, SudoPhase.playing);
      e.dispose();
    });

    test('save/restore round-trips', () {
      final e = SudokuEngine(rng: Random(7));
      e.newGame(2, budget: 5, strict: true);
      final i = e.start.indexWhere((v) => v == 0);
      e.enterDigit(i, e.solution[i]);
      final j = [for (var k = 0; k < 81; k++) if (e.start[k] == 0) k][1];
      e.toggleNote(j, 4);
      final json = e.toJson();
      final f = SudokuEngine()..fromJson(json);
      expect(f.val, e.val);
      expect(f.mistakes, e.mistakes);
      expect(f.diffIndex, 2);
      expect(f.mistakeBudget, 5);
      expect(f.strictMode, true);
      expect(f.notes
          .asMap()
          .entries
          .every((en) => en.value.containsAll(e.notes[en.key])), true);
      e.dispose();
      f.dispose();
    });
  });
}
