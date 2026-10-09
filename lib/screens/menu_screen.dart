import 'dart:math';
import 'package:flutter/material.dart';

import '../audio.dart';
import '../engine.dart';
import '../settings.dart';
import '../theme.dart';

/// Main menu: washi title card, bamboo difficulty tiles with vermilion
/// enso ring, continue slip, settings token, stats.
class MenuScreen extends StatelessWidget {
  final bool hasSave;
  final VoidCallback onPlay; // start selected difficulty (default medium)
  final void Function(int diff) onPlayDiff;
  final VoidCallback onResume;
  final VoidCallback onOpenSettings;

  const MenuScreen({
    super.key,
    required this.hasSave,
    required this.onPlay,
    required this.onPlayDiff,
    required this.onResume,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final s = SudoSettings.instance;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _titleCard(context),
              const SizedBox(height: 18),
              if (hasSave) ...[
                _continueSlip(context),
                const SizedBox(height: 14),
              ],
              const MicroLabel('選ぶ  CHOOSE YOUR CRAFT'),
              const SizedBox(height: 10),
              _difficultyRow(context, s),
              const SizedBox(height: 16),
              _settingsToken(context),
              const SizedBox(height: 18),
              _howTo(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleCard(BuildContext context) {
    return WashiSheet(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '数独',
                style: TextStyle(
                  fontFamily: SudoFonts.serif,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SudoColors.walnut,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'SUDOKU',
                style: TextStyle(
                  fontFamily: SudoFonts.serif,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: SudoColors.sumi,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'A quiet puzzle, inked by hand.',
                style: TextStyle(
                  fontFamily: SudoFonts.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SudoColors.walnut.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          const HankoStamp(size: 58),
        ],
      ),
    );
  }

  Widget _continueSlip(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SudoAudio.instance.click();
        onResume();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: SudoColors.washi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SudoColors.vermilion.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
                color: SudoColors.shadowBrown(0.16),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.brush, size: 18, color: SudoColors.vermilion),
            SizedBox(width: 8),
            MicroLabel('CONTINUE  ·  筆を続ける',
                color: SudoColors.vermilion, weight: FontWeight.w700),
          ],
        ),
      ),
    );
  }

  Widget _difficultyRow(BuildContext context, SudoSettings s) {
    return Row(
      children: [
        for (var i = 0; i < sudoDifficulties.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 5, right: i == 3 ? 0 : 5),
              child: _DiffTile(
                diff: sudoDifficulties[i],
                solved: s.solved[i],
                best: s.bestTime[i],
                onTap: () {
                  SudoAudio.instance.start();
                  onPlayDiff(i);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _settingsToken(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BambooToken(
          label: '⚙',
          size: 46,
          onTap: () {
            SudoAudio.instance.click();
            onOpenSettings();
          },
        ),
        const SizedBox(width: 14),
        const MicroLabel('SETTINGS  ·  設定'),
      ],
    );
  }

  Widget _howTo(BuildContext context) {
    return WashiSheet(
      radius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrushHeading('How to play', size: 16),
          const SizedBox(height: 8),
          _howLine('Tap a cell, then a bamboo token (1–9).'),
          _howLine('Each row, column and 3×3 box holds 1–9 once.'),
          _howLine('Use ✎ notes for pencil candidates on hard ones.'),
          _howLine('Mistakes are brushed in vermilion — erase to fix.'),
          _howLine('Stuck? The lantern reveals one true digit.'),
        ],
      ),
    );
  }

  Widget _howLine(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('・ ',
              style: TextStyle(
                  fontFamily: SudoFonts.serif,
                  color: SudoColors.vermilion,
                  fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              t,
              style: const TextStyle(
                fontFamily: SudoFonts.sans,
                fontSize: 12.5,
                color: SudoColors.walnut,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffTile extends StatefulWidget {
  final SudoDifficulty diff;
  final int solved;
  final int best;
  final VoidCallback onTap;

  const _DiffTile({
    required this.diff,
    required this.solved,
    required this.best,
    required this.onTap,
  });

  @override
  State<_DiffTile> createState() => _DiffTileState();
}

class _DiffTileState extends State<_DiffTile> {
  bool _pressed = false;

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [SudoColors.bambooHi, SudoColors.bamboo],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SudoColors.bambooDark, width: 1.8),
            boxShadow:
                _pressed ? [] : SudoColors.tokenShadows,
          ),
          child: CustomPaint(
            painter: _EnsoRingPainter(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.diff.ja,
                  style: const TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: SudoColors.sumi,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.diff.name,
                  style: const TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SudoColors.sumi,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.solved > 0
                      ? '✓ ${widget.solved}'
                      : '${widget.diff.givens} given',
                  style: TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: SudoColors.walnut.withValues(alpha: 0.8),
                  ),
                ),
                if (widget.best > 0)
                  Text(
                    'best ${_fmt(widget.best)}',
                    style: TextStyle(
                      fontFamily: SudoFonts.sans,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: SudoColors.walnut.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vermilion enso selection ring (open brush circle).
class _EnsoRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(13);
    final paint = Paint()
      ..color = SudoColors.vermilion.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2, cy = size.height / 2;
    final r = min(size.width, size.height) * 0.46;
    final path = Path();
    const segs = 26;
    const gap = 0.5; // enso opening
    for (var i = 0; i <= segs; i++) {
      final a = -pi / 2 + gap + i / segs * (2 * pi - gap * 2);
      final rr = r + (rng.nextDouble() - 0.5) * 2.5;
      final p = Offset(cx + cos(a) * rr, cy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
