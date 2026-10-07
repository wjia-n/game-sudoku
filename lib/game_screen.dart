import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
/// Sudoku — solo number logic: difficulty chooser, notes, hints, 3-strike mistakes.
class SudokuScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const SudokuScreen({super.key, required this.players, required this.callbacks});
  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}
class _Diff {
  const _Diff(this.name, this.emoji, this.givens, this.key);
  final String name, emoji, key;
  final int givens;
}const _diffs = [
  _Diff('Easy', '😌', 40, 'easy'),
  _Diff('Medium', '🙂', 32, 'medium'),
  _Diff('Hard', '🤯', 26, 'hard'),
];
List<int> _cands(List<int> g, int i) {
  final used = List.filled(10, false);
  final r = i ~/ 9, c = i % 9;
  for (var k = 0; k < 9; k++) { used[g[r * 9 + k]] = true; used[g[k * 9 + c]] = true; }
  final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
  for (var dr = 0; dr < 3; dr++) {
    for (var dc = 0; dc < 3; dc++) { used[g[(br + dr) * 9 + bc + dc]] = true; }
  }
  return [for (var n = 1; n <= 9; n++) if (!used[n]) n];
}
int _countSolutions(List<int> g, int limit) {
  var count = 0;
  void solve() {
    if (count >= limit) return;
    var bi = -1;
    List<int>? bc;
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final c = _cands(g, i);
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
class _SudokuScreenState extends State<SudokuScreen> {
  int? diffIndex;
  List<int> sol = List.filled(81, 0), val = List.filled(81, 0);
  List<bool> given = List.filled(81, false);
  List<Set<int>> notes = List.generate(81, (_) => <int>{});
  int sel = -1, mistakes = 0, hints = 3, seconds = 0, wrongAt = -1;
  bool notesMode = false, over = false, generating = false;
  final Map<String, int> best = {};
  final rnd = Random();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _loadBest();
  }
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final d in _diffs) { best[d.key] = p.getInt('sudoku_best_${d.key}') ?? 0; }
    });
  }
  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  void _startGame(int i) {
    setState(() {
      diffIndex = i;
      generating = true;
      over = false;
      sel = -1;
      notesMode = false;
      mistakes = 0;
      hints = 3;
      seconds = 0;
      wrongAt = -1;
    });
    Future(() {
      final s = _genSolved();
      final puzzle = _dig(s, _diffs[i].givens);
      if (!mounted) return;
      timer?.cancel();
      setState(() {
        sol = s;
        val = puzzle;
        given = [for (var v = 0; v < 81; v++) puzzle[v] != 0];
        notes = List.generate(81, (_) => <int>{});
        generating = false;
      });
      timer = Timer.periodic(const Duration(seconds: 1),
          (_) { if (!over && mounted) setState(() => seconds++); });
      Sfx.click();
    });
  }
  List<int> _genSolved() {
    final g = List.filled(81, 0);
    bool fill(int pos) {
      if (pos == 81) return true;
      for (final n in _cands(g, pos)..shuffle(rnd)) {
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
    final order = List.generate(81, (i) => i)..shuffle(rnd);
    var remaining = 81;
    for (final i in order) {
      if (remaining <= givens) break;
      final backup = p[i];
      p[i] = 0;
      if (_countSolutions(List<int>.from(p), 2) != 1) { p[i] = backup; } else { remaining--; }
    }
    return p;
  }
  void _tapCell(int i) {
    if (over || generating || diffIndex == null) return;
    Sfx.tap();
    setState(() => sel = (sel == i) ? -1 : i);
  }
  void _clearNoteFromPeers(int i, int n) {
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 9; k++) {
      notes[r * 9 + k].remove(n);
      notes[k * 9 + c].remove(n);
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) { notes[(br + dr) * 9 + bc + dc].remove(n); }
    }
  }
  void _tapNumber(int n) {
    if (over || generating || sel < 0 || given[sel]) return;
    if (notesMode) {
      setState(() => notes[sel].contains(n) ? notes[sel].remove(n) : notes[sel].add(n));
      Sfx.tap();
      return;
    }
    if (val[sel] == n) {
      setState(() => val[sel] = 0);
      Sfx.tap();
      return;
    }
    if (n == sol[sel]) {
      setState(() {
        val[sel] = n;
        notes[sel].clear();
        _clearNoteFromPeers(sel, n);
      });
      Sfx.move();
      _checkWin();
    } else {
      setState(() {
        mistakes++;
        wrongAt = sel;
      });
      Sfx.lose();
      Future.delayed(const Duration(milliseconds: 450),
          () { if (mounted) setState(() => wrongAt = -1); });
      if (mistakes >= 3) _gameOver();
    }
  }
  void _useHint() {
    if (over || generating || hints <= 0) return;
    final target =
        (sel >= 0 && !given[sel] && val[sel] == 0) ? sel : val.indexWhere((v) => v == 0);
    if (target < 0) return;
    setState(() {
      val[target] = sol[target];
      given[target] = true;
      notes[target].clear();
      hints--;
    });
    Sfx.click();
    _checkWin();
  }
  void _checkWin() {
    for (var i = 0; i < 81; i++) {
      if (val[i] != sol[i]) return;
    }
    over = true;
    timer?.cancel();
    Sfx.win();
    _saveBest();
    widget.callbacks.finish(
      headline: 'Puzzle crushed in ${_fmt(seconds)}! 🎉',
      subline: 'Clean solve on ${_diffs[diffIndex!].name} — your brain deserves a snack. 🧠✨',
    );
  }
  Future<void> _saveBest() async {
    final key = _diffs[diffIndex!].key;
    final p = await SharedPreferences.getInstance();
    final prev = p.getInt('sudoku_best_$key') ?? 0;
    if (prev == 0 || seconds < prev) {
      await p.setInt('sudoku_best_$key', seconds);
      if (mounted) setState(() => best[key] = seconds);
    }
  }
  void _gameOver() {
    over = true;
    timer?.cancel();
    Sfx.lose();
    final done = [for (var i = 0; i < 81; i++) if (val[i] == sol[i]) i].length;
    widget.callbacks.finish(
      headline: 'Three strikes — puzzle wins! 😅',
      subline:
          'You nailed $done/81 cells on ${_diffs[diffIndex!].name}. Shake it off and go again!',
    );
  }
  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    if (diffIndex == null) return _chooser(t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(children: [
        _hud(t),
        const SizedBox(height: 8),
        Expanded(child: Center(child: _board(t))),
        const SizedBox(height: 10),
        _actions(t),
        const SizedBox(height: 10),
        _numpad(t),
        const SizedBox(height: 4),
      ]),
    );
  }
  Widget _chooser(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔢', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text('Sudoku showdown!',
            style: TextStyle(color: t.text, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Pick a difficulty, hero.',
            style: TextStyle(color: t.muted, fontSize: 14)),
        const SizedBox(height: 20),
        Row(
          children: [
            for (var i = 0; i < _diffs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => _startGame(i),
                  child: Container(
                    margin: EdgeInsets.only(
                        left: i == 0 ? 0 : 6, right: i == _diffs.length - 1 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        gradient: t.headerGradient,
                        borderRadius: t.radius,
                        boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(children: [
                      Text(_diffs[i].emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 4),
                      Text(_diffs[i].name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      Text('${_diffs[i].givens} givens', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('🏆 ${(best[_diffs[i].key] ?? 0) > 0 ? _fmt(best[_diffs[i].key]!) : '—'}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Fresh puzzle every time, always one unique solution ✨',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.muted, fontSize: 12)),
      ]),
    );
  }
  Widget _hud(GameTheme t) {
    final style = TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('⏱ ${_fmt(seconds)}', style: style),
      Text(_diffs[diffIndex!].name, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
      Text('❌ $mistakes/3', style: style.copyWith(color: mistakes > 0 ? const Color(0xFFE5484D) : t.text)),
    ]);
  }
  Color _cellBg(int i, GameTheme t) {
    if (i == wrongAt) return const Color(0xFFE5484D).withValues(alpha: 0.55);
    final selVal = sel >= 0 ? val[sel] : 0;
    final r = i ~/ 9, c = i % 9, sr = sel ~/ 9, sc = sel % 9;
    if (i == sel) return t.primary.withValues(alpha: 0.4);
    if (selVal != 0 && val[i] == selVal) return t.primary.withValues(alpha: 0.28);
    if (sel >= 0 && (r == sr || c == sc || (r ~/ 3 == sr ~/ 3 && c ~/ 3 == sc ~/ 3))) return t.primary.withValues(alpha: 0.1);
    return t.surface;
  }
  Widget _board(GameTheme t) {
    if (generating) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: t.primary),
        const SizedBox(height: 12),
        Text('Cooking up a fresh puzzle… 🍳', style: TextStyle(color: t.muted)),
      ]);
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: t.radius,
          border: Border.all(color: t.primary.withValues(alpha: 0.4), width: 2),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9),
          itemCount: 81,
          itemBuilder: (_, i) {
            final r = i ~/ 9, c = i % 9;
            return GestureDetector(
              onTap: () => _tapCell(i),
              child: Container(
                decoration: BoxDecoration(
                  color: _cellBg(i, t),
                  border: Border(
                    right: BorderSide(
                        color: t.primary.withValues(alpha: 0.35),
                        width: (c == 2 || c == 5) ? 2.2 : 0.6),
                    bottom: BorderSide(
                        color: t.primary.withValues(alpha: 0.35),
                        width: (r == 2 || r == 5) ? 2.2 : 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: val[i] != 0
                    ? Text('${val[i]}',
                        style: TextStyle(fontSize: 20, fontWeight: given[i] ? FontWeight.w800 : FontWeight.w600, color: given[i] ? t.text : t.primary))
                    : notes[i].isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.all(2),
                            child: Text((notes[i].toList()..sort()).join(),
                                style: TextStyle(fontSize: 9, color: t.muted, fontWeight: FontWeight.w700)),
                          ),
              ),
            );
          },
        ),
      ),
    );
  }
  Widget _actions(GameTheme t) {
    Widget chip(String label, bool on, VoidCallback tap) => GestureDetector(
          onTap: () {
            Sfx.click();
            tap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? t.primary.withValues(alpha: 0.9) : t.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.primary.withValues(alpha: 0.5)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? (t.dark ? Colors.black : Colors.white) : t.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      chip(notesMode ? '✏️ Notes ON' : '✏️ Notes', notesMode,
          () => setState(() => notesMode = !notesMode)),
      chip('💡 Hint ×$hints', hints > 0, _useHint),
      chip('🔄 New', true, () {
        timer?.cancel();
        setState(() {
          diffIndex = null;
          over = false;
        });
      }),
    ]);
  }
  Widget _numpad(GameTheme t) {
    final counts = List.filled(10, 9);
    for (final v in val) {
      if (v > 0) counts[v]--;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var n = 1; n <= 9; n++)
          GestureDetector(
            onTap: counts[n] > 0 ? () => _tapNumber(n) : null,
            child: Opacity(
              opacity: counts[n] > 0 ? 1 : 0.3,
              child: Container(
                width: 36,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: counts[n] > 0 ? t.headerGradient : null,
                  color: counts[n] > 0 ? null : t.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900)),
                  Text('${counts[n]}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}
