import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/sumi_themes.dart';

// ---------------------------------------------------------------------------
// Shared stationery-craft widgets: tatami backdrop, washi cards, wooden
// token buttons, the original Sudoku logo painter, hanko victory stamp.
// ---------------------------------------------------------------------------

/// Text styles bound to the art direction (DESIGN.md §3).
class SumiType {
  static TextStyle display(double size, SumiThemeDef t, {Color? color}) =>
      TextStyle(
        fontFamily: 'NotoSerif',
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color ?? t.sumi,
        height: 1.15,
      );

  static TextStyle body(double size, SumiThemeDef t, {Color? color}) =>
      TextStyle(
        fontFamily: 'NotoSerif',
        fontWeight: FontWeight.w400,
        fontSize: size,
        color: color ?? t.walnut,
        height: 1.35,
      );

  static TextStyle label(double size, SumiThemeDef t, {Color? color}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: 1.2,
        color: color ?? t.walnut,
      );

  static TextStyle micro(double size, SumiThemeDef t, {Color? color}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
        fontSize: size,
        letterSpacing: 0.6,
        color: color ?? t.walnut.withValues(alpha: 0.75),
      );

  /// A puzzle digit in the chosen digit style.
  static TextStyle digit(
    double size,
    SumiThemeDef t,
    DigitStyle style, {
    required bool given,
    Color? override,
  }) =>
      TextStyle(
        fontFamily: style.fontFamily,
        fontWeight: given ? FontWeight.w700 : style.weight,
        fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: style.letterSpacing,
        fontSize: size,
        color: override ?? (given ? t.sumi : t.walnut),
        height: 1.0,
      );
}

/// Tatami canvas backdrop with a subtle woven-fiber feel.
class TatamiBackdrop extends StatelessWidget {
  final SumiThemeDef theme;
  final Widget child;
  const TatamiBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.canvas, theme.canvasDeep],
        ),
      ),
      child: CustomPaint(
        painter: _FiberPainter(theme.canvasDeep),
        child: child,
      ),
    );
  }
}

class _FiberPainter extends CustomPainter {
  final Color line;
  _FiberPainter(this.line);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = line.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 14.0;
    for (double y = step / 2; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _FiberPainter old) => old.line != line;
}

/// Elevated washi paper card with multi-stop ambient shadow.
class WashiCard extends StatelessWidget {
  final SumiThemeDef theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const WashiCard({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.washi,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: theme.washLine.withValues(alpha: 0.6), width: 1),
        boxShadow: [
          BoxShadow(
              color: theme.walnut.withValues(alpha: 0.10),
              offset: const Offset(0, 2),
              blurRadius: 4),
          BoxShadow(
              color: theme.walnut.withValues(alpha: 0.08),
              offset: const Offset(0, 8),
              blurRadius: 24),
          BoxShadow(
              color: theme.walnut.withValues(alpha: 0.06),
              offset: const Offset(0, 16),
              blurRadius: 32),
        ],
      ),
      child: child,
    );
  }
}

/// Wooden token button (bamboo number pad / action tokens).
class WoodToken extends StatefulWidget {
  final SumiThemeDef theme;
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final bool selected;
  final bool disabled;
  const WoodToken({
    super.key,
    required this.theme,
    required this.child,
    this.onTap,
    this.size = 52,
    this.selected = false,
    this.disabled = false,
  });

  @override
  State<WoodToken> createState() => _WoodTokenState();
}

class _WoodTokenState extends State<WoodToken> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.disabled ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Opacity(
          opacity: widget.disabled ? 0.45 : 1.0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.bambooHi, t.bamboo, t.bambooDark],
              ),
              border: Border.all(
                color: widget.selected ? t.vermilion : t.bambooDark,
                width: widget.selected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: t.walnut.withValues(alpha: 0.28),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
                if (widget.selected)
                  BoxShadow(
                    color: t.vermilion.withValues(alpha: 0.35),
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Wooden pill button for primary actions.
class WoodButton extends StatelessWidget {
  final SumiThemeDef theme;
  final String text;
  final VoidCallback onTap;
  final bool primary;
  final IconData? icon;
  const WoodButton({
    super.key,
    required this.theme,
    required this.text,
    required this.onTap,
    this.primary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: primary
                ? [t.vermilion, Color.lerp(t.vermilion, t.sumi, 0.25)!]
                : [t.bambooHi, t.bambooDark],
          ),
          border: Border.all(
              color: primary
                  ? t.vermilion.withValues(alpha: 0.4)
                  : t.bambooDark,
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: t.walnut.withValues(alpha: 0.3),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: t.washi),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: SumiType.label(15, t, color: t.washi),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vermilion hanko completion stamp (victory), pressed at a slight angle.
class HankoStamp extends StatelessWidget {
  final SumiThemeDef theme;
  final double size;
  final String kanji;
  const HankoStamp(
      {super.key, required this.theme, this.size = 92, this.kanji = '完'});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.vermilion,
          borderRadius: BorderRadius.circular(size * 0.12),
          border: Border.all(
              color: theme.washi.withValues(alpha: 0.85),
              width: size * 0.045),
          boxShadow: [
            BoxShadow(
              color: theme.walnut.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            kanji,
            style: TextStyle(
              fontFamily: 'NotoSerif',
              fontWeight: FontWeight.w700,
              fontSize: size * 0.52,
              color: theme.washi,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Original Sudoku logo, drawn in code (washi sheet + sumi 3×3 grid +
/// vermilion seal dot). Fits the Stitch art direction; no stock, no AI.
class SudokuLogoPainter extends CustomPainter {
  final SumiThemeDef theme;
  SudokuLogoPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = Random(7);
    // Washi sheet.
    final sheet = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.18));
    canvas.drawRRect(
        sheet,
        Paint()
          ..color = theme.washi
          ..style = PaintingStyle.fill);
    // Paper grain flecks.
    final fleck = Paint()..color = theme.washLine.withValues(alpha: 0.25);
    for (int k = 0; k < 40; k++) {
      canvas.drawCircle(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          1 + rnd.nextDouble() * 2,
          fleck);
    }
    // Sumi 3×3 grid with hand wobble.
    final m = w * 0.16;
    final cell = (w - m * 2) / 3;
    final line = Paint()
      ..color = theme.sumi
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    for (int k = 0; k <= 3; k++) {
      final x = m + k * cell;
      final y = m + k * cell;
      canvas.drawLine(
          Offset(x + (rnd.nextDouble() - 0.5) * 2, m),
          Offset(x + (rnd.nextDouble() - 0.5) * 2, h - m),
          line);
      canvas.drawLine(
          Offset(m, y + (rnd.nextDouble() - 0.5) * 2),
          Offset(w - m, y + (rnd.nextDouble() - 0.5) * 2),
          line);
    }
    // Brushed digits.
    const digits = ['5', '3', '9'];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int k = 0; k < 3; k++) {
      tp.text = TextSpan(
        text: digits[k],
        style: TextStyle(
          fontFamily: 'NotoSerif',
          fontWeight: FontWeight.w700,
          fontSize: cell * 0.62,
          color: k == 1 ? theme.vermilion : theme.sumi,
          height: 1.0,
        ),
      );
      tp.layout();
      tp.paint(
          canvas,
          Offset(m + k * cell + (cell - tp.width) / 2,
              m + k * cell + (cell - tp.height) / 2 - cell * 0.04));
    }
    // Vermilion seal dot, bottom-right.
    canvas.drawCircle(
        Offset(w - m * 0.9, h - m * 0.9), w * 0.075, Paint()..color = theme.vermilion);
    // Sheet edge + shadow.
    canvas.drawRRect(
        sheet,
        Paint()
          ..color = theme.walnut.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012);
  }

  @override
  bool shouldRepaint(covariant SudokuLogoPainter old) =>
      old.theme.id != theme.id;
}

/// Paper-confetti burst for the win celebration.
class ConfettiPainter extends CustomPainter {
  final SumiThemeDef theme;
  final double progress; // 0..1
  ConfettiPainter(this.theme, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final colors = [theme.vermilion, theme.washi, theme.ochre, theme.bambooHi];
    for (int k = 0; k < 60; k++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final dist = (0.15 + 0.85 * progress) *
          (size.width * 0.5) *
          (0.4 + rnd.nextDouble() * 0.6);
      final x = size.width / 2 + cos(angle) * dist;
      final y = size.height / 2 + sin(angle) * dist * 0.8;
      final s = 5 + rnd.nextDouble() * 8;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + progress * 6);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.6),
          Paint()
            ..color =
                colors[k % colors.length].withValues(alpha: 1 - progress * 0.6));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) =>
      old.progress != progress;
}
