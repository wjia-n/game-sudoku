import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const SudokuApp());

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.cozyPaper,
      title: 'Sudoku',
      tagline: 'The number puzzle that eats boredom for breakfast. Pick a difficulty, hero!',
      emoji: '🔢',
      slug: 'sudoku',
      howToPlay:
          '• Tap a cell, then tap a number (1–9) to fill it.\n• Every row, column and 3×3 box must hold 1–9 exactly once.\n• Toggle ✏️ notes mode for pencil marks on tricky cells.\n• 3 mistakes and the puzzle wins — ouch!\n• Stuck? You get 3 hints per game. Use them wisely.',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => SudokuScreen(players: players, callbacks: cb),
    );
  }
}
