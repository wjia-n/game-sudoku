import 'dart:math';
import 'package:flutter/material.dart';

/// "Washi & Sumi Craft" design system (from Stitch project
/// projects/14041371528868558485 — design system
/// assets/69f18d5b5b5241a6af580dfa6ca4e885).
///
/// Japanese stationery craft: washi paper sheets, hand-inked sumi
/// brushwork, aged bamboo tokens, vermilion hanko seals on a tatami canvas.
/// Pseudo-3D physical feel via layered ambient shadows — no neon, no glow.
class SudoColors {
  SudoColors._();

  /// Sumi charcoal — locked givens, calligraphic numerals, structural rules.
  static const Color sumi = Color(0xFF1F1E1C);

  /// Vermilion shudan seal — completion stamp, errors, active highlight.
  static const Color vermilion = Color(0xFFC73E2E);

  /// Aged bamboo — number-pad tokens, toggles, helpers, grid framing.
  static const Color bamboo = Color(0xFFA67C48);

  /// Bamboo highlight — light wood highlights.
  static const Color bambooHi = Color(0xFFC29B63);

  /// Dark bamboo — token rims, pressed edges.
  static const Color bambooDark = Color(0xFF7A5A32);

  /// Tatami matting canvas.
  static const Color tatami = Color(0xFFE5D5BC);

  /// Tatami depth shade.
  static const Color tatamiDeep = Color(0xFFD9C6A5);

  /// Unbleached washi cream — board sheet and card surfaces.
  static const Color washi = Color(0xFFFAF6EE);

  /// Washi shadow edge.
  static const Color washiShade = Color(0xFFF1E8D6);

  /// Walnut ink — pencil candidate notes, metadata, timers.
  static const Color walnut = Color(0xFF3C2E20);

  /// Ochre wash — selected-cell wash.
  static const Color ochre = Color(0xFFD9A844);

  /// Gold ochre — star rating brush marks.
  static const Color gold = Color(0xFFC9962E);

  /// Soft shadow brown ambience.
  static Color shadowBrown(double a) =>
      const Color(0xFF3C2E20).withValues(alpha: a);

  /// Pale paper tint for related cells.
  static const Color relatedTint = Color(0xFFEFE3CC);

  /// Stronger tint for identical digits.
  static const Color sameDigitTint = Color(0xFFEAD9AE);

  /// Thin wash cell lines.
  static const Color washLine = Color(0xFFB9A98D);

  static List<BoxShadow> get paperShadows => [
        BoxShadow(
            color: shadowBrown(0.10), blurRadius: 4, offset: const Offset(0, 2)),
        BoxShadow(
            color: shadowBrown(0.10), blurRadius: 24, offset: const Offset(0, 8)),
        BoxShadow(
            color: shadowBrown(0.08), blurRadius: 32, offset: const Offset(0, 16)),
      ];

  static List<BoxShadow> get tokenShadows => [
        BoxShadow(
            color: shadowBrown(0.18), blurRadius: 6, offset: const Offset(0, 3)),
        BoxShadow(
            color: shadowBrown(0.10), blurRadius: 14, offset: const Offset(0, 7)),
      ];
}

class SudoFonts {
  SudoFonts._();

  /// Noto Serif — puzzle digits, headlines, body (calligraphic strokes).
  static const String serif = 'NotoSerif';

  /// Manrope — micro-labels, timers, system chrome.
  static const String sans = 'Manrope';
}

/// Layer 0 — tatami canvas with woven-fiber warmth, drawn procedurally.
class TatamiBackground extends StatelessWidget {
  final Widget child;

  const TatamiBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SudoColors.tatami, SudoColors.tatamiDeep],
        ),
      ),
      child: CustomPaint(
        painter: _TatamiWeavePainter(),
        child: child,
      ),
    );
  }
}

class _TatamiWeavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    // Woven fiber strands: faint horizontal + vertical hairlines.
    final hPaint = Paint()
      ..color = const Color(0xFFCDBB99).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    final vPaint = Paint()
      ..color = const Color(0xFFF3EAD6).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    const step = 9.0;
    for (double y = step / 2; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }
    for (double x = step / 2; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), vPaint);
    }
    // Subtle fiber flecks for handmade warmth.
    final fleck = Paint()..color = const Color(0xFFBCA87F).withValues(alpha: 0.25);
    for (var i = 0; i < 140; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), 0.8 + rng.nextDouble() * 1.2, fleck);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Layer 1 — a washi paper sheet with multi-stop ambient shadow and
/// deckled-feeling edges.
class WashiSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow>? shadows;

  const WashiSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SudoColors.washi,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SudoColors.washLine.withValues(alpha: 0.45)),
        boxShadow: shadows ?? SudoColors.paperShadows,
      ),
      child: child,
    );
  }
}

/// Small pinned washi slip used for HUD stats.
class WashiSlip extends StatelessWidget {
  final Widget child;
  final double width;

  const WashiSlip({super.key, required this.child, this.width = 104});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SudoColors.washi,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SudoColors.washLine.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: SudoColors.shadowBrown(0.16),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Center(child: child),
    );
  }
}

/// Bamboo number token — carved numeral, wood grain, press-in animation.
class BambooToken extends StatefulWidget {
  final String label;
  final String? sub;
  final double size;
  final bool enabled;
  final VoidCallback? onTap;

  const BambooToken({
    super.key,
    required this.label,
    this.sub,
    this.size = 40,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<BambooToken> createState() => _BambooTokenState();
}

class _BambooTokenState extends State<BambooToken> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.32,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: SizedBox(
            width: s,
            height: widget.sub == null ? s : s + 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [SudoColors.bambooHi, SudoColors.bamboo],
                    ),
                    border: Border.all(
                        color: SudoColors.bambooDark,
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside),
                    boxShadow: _pressed
                        ? [
                            BoxShadow(
                                color: SudoColors.shadowBrown(0.2),
                                blurRadius: 3,
                                offset: const Offset(0, 1))
                          ]
                        : SudoColors.tokenShadows,
                  ),
                  child: CustomPaint(
                    painter: _WoodGrainPainter(
                        base: SudoColors.bambooDark.withValues(alpha: 0.25)),
                    child: Center(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: SudoFonts.serif,
                          fontWeight: FontWeight.w700,
                          fontSize: s * 0.44,
                          color: SudoColors.sumi,
                          shadows: const [
                            Shadow(
                                color: Color(0x66FFFFFF),
                                offset: Offset(0, 1),
                                blurRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.sub!,
                    style: TextStyle(
                      fontFamily: SudoFonts.sans,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: SudoColors.walnut.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final Color base;

  _WoodGrainPainter({required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(21);
    final paint = Paint()
      ..color = base
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    // Gentle curved grain lines across the disc.
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.2 + 0.2 * i) + rng.nextDouble() * 4;
      final path = Path()
        ..moveTo(size.width * 0.12, y)
        ..quadraticBezierTo(size.width * 0.5, y + 3.5 - rng.nextDouble() * 7,
            size.width * 0.88, y + rng.nextDouble() * 3);
      canvas.drawPath(path, paint);
    }
    // Turned-wood rim highlight arc.
    final rim = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.28)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(
            center: size.center(Offset.zero), radius: size.width / 2 - 5),
        -2.4,
        1.5,
        false,
        rim);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wooden toggle disc with vermilion ON dot.
class WoodToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  const WoodToggle(
      {super.key, required this.value, required this.onChanged, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size * 1.9,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          gradient: LinearGradient(
            colors: value
                ? [SudoColors.bambooHi, SudoColors.bamboo]
                : [
                    SudoColors.washiShade,
                    const Color(0xFFE3D4B8),
                  ],
          ),
          border: Border.all(color: SudoColors.bambooDark, width: 1.6),
          boxShadow: [
            BoxShadow(
                color: SudoColors.shadowBrown(0.18),
                blurRadius: 5,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: size - 7,
                height: size - 7,
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [SudoColors.bambooHi, SudoColors.bambooDark],
                  ),
                  border: Border.all(
                      color: SudoColors.sumi.withValues(alpha: 0.55), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: SudoColors.shadowBrown(0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: value
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SudoColors.vermilion,
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0x66C73E2E),
                                  blurRadius: 3,
                                  offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vermilion hanko seal stamped at a slight angle, with pressed edges.
class HankoStamp extends StatelessWidget {
  final double size;
  final String glyph;
  final double angle;

  const HankoStamp(
      {super.key, this.size = 64, this.glyph = '完', this.angle = -0.09});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: Size.square(size),
        painter: _HankoPainter(glyph: glyph),
      ),
    );
  }
}

class _HankoPainter extends CustomPainter {
  final String glyph;

  _HankoPainter({required this.glyph});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(3);
    // Uneven pressed seal paste: slightly jittered square edges.
    final seal = Paint()
      ..color = SudoColors.vermilion.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final jittered = Path();
    const n = 10;
    final w = size.width, h = size.height;
    for (var side = 0; side < 4; side++) {
      for (var i = 0; i <= n; i++) {
        final t = i / n;
        final j = (rng.nextDouble() - 0.5) * 3.2;
        late Offset p;
        switch (side) {
          case 0:
            p = Offset(t * w, j);
            break;
          case 1:
            p = Offset(w + j, t * h);
            break;
          case 2:
            p = Offset(w - t * w, h + j);
            break;
          default:
            p = Offset(j, h - t * h);
        }
        if (side == 0 && i == 0) {
          jittered.moveTo(p.dx, p.dy);
        } else {
          jittered.lineTo(p.dx, p.dy);
        }
      }
    }
    jittered.close();
    canvas.drawPath(jittered, seal);
    // Pressed texture: darker blotches.
    final blotch = Paint()
      ..color = const Color(0xFF9E2B1F).withValues(alpha: 0.35);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
          Offset(rng.nextDouble() * w, rng.nextDouble() * h),
          1.5 + rng.nextDouble() * 4,
          blotch);
    }
    // White kanji character carved out.
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: SudoFonts.serif,
          fontWeight: FontWeight.w700,
          fontSize: w * 0.52,
          color: SudoColors.washi.withValues(alpha: 0.96),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset((w - tp.width) / 2, (h - tp.height) / 2 - h * 0.02));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hand-inked sumi grid: thin wash cell lines, dense 3x3 box strokes with
/// slight dry-brush wobble.
class SumiGridPainter extends CustomPainter {
  final double animation; // 0..1 reveal sweep on board appearance

  SumiGridPainter({this.animation = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(11);
    final cell = size.width / 9;
    final wash = Paint()
      ..color = SudoColors.washLine.withValues(alpha: 0.85)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final sumi = Paint()
      ..color = SudoColors.sumi.withValues(alpha: 0.9)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    Path wobbleLine(Offset a, Offset b, double amp) {
      final path = Path()..moveTo(a.dx, a.dy);
      const segs = 6;
      for (var i = 1; i <= segs; i++) {
        final t = i / segs;
        final nx = a.dx + (b.dx - a.dx) * t;
        final ny = a.dy + (b.dy - a.dy) * t;
        final off = (rng.nextDouble() - 0.5) * amp;
        // Perpendicular wobble.
        final dx = b.dx - a.dx, dy = b.dy - a.dy;
        final len = sqrt(dx * dx + dy * dy);
        path.lineTo(nx - dy / len * off, ny + dx / len * off);
      }
      return path;
    }

    // Thin wash cell lines.
    for (var i = 1; i < 9; i++) {
      final heavy = i == 3 || i == 6;
      if (heavy) continue;
      final p = i * cell;
      if (p / size.width > animation) continue;
      canvas.drawPath(
          wobbleLine(Offset(p, 0), Offset(p, size.height), 1.2), wash);
      canvas.drawPath(
          wobbleLine(Offset(0, p), Offset(size.width, p), 1.2), wash);
    }
    // Dense sumi 3x3 box strokes.
    for (final i in [3, 6]) {
      final p = i * cell;
      if (p / size.width > animation) continue;
      canvas.drawPath(
          wobbleLine(Offset(p, 2), Offset(p, size.height - 2), 2.0), sumi);
      canvas.drawPath(
          wobbleLine(Offset(2, p), Offset(size.width - 2, p), 2.0), sumi);
    }
    // Outer brush frame.
    final frame = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(6)));
    canvas.drawPath(frame,
        Paint()
          ..color = SudoColors.sumi.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant SumiGridPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

/// Warm ochre wash behind the selected cell; vermilion brush ring on errors.
class CellHighlightPainter extends CustomPainter {
  final bool selected;
  final bool related;
  final bool sameDigit;
  final bool error;

  CellHighlightPainter(
      {this.selected = false,
      this.related = false,
      this.sameDigit = false,
      this.error = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (related || sameDigit) {
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = sameDigit
                ? SudoColors.sameDigitTint.withValues(alpha: 0.85)
                : SudoColors.relatedTint.withValues(alpha: 0.6));
    }
    if (selected) {
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = SudoColors.ochre.withValues(alpha: 0.38));
    }
    if (error) {
      final rng = Random(5);
      final ring = Paint()
        ..color = SudoColors.vermilion.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final path = Path();
      const segs = 12;
      final cx = size.width / 2, cy = size.height / 2;
      final r = size.width * 0.42;
      for (var i = 0; i <= segs; i++) {
        final a = i / segs * 2 * pi;
        final rr = r + (rng.nextDouble() - 0.5) * 3;
        final p = Offset(cx + cos(a) * rr, cy + sin(a) * rr);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ring);
    }
  }

  @override
  bool shouldRepaint(covariant CellHighlightPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.related != related ||
      oldDelegate.sameDigit != sameDigit ||
      oldDelegate.error != error;
}

/// Brushed star rating marks (gold ochre brush strokes).
class BrushStars extends StatelessWidget {
  final int stars; // 0..3
  final double size;

  const BrushStars({super.key, required this.stars, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: CustomPaint(
              size: Size.square(size),
              painter: _StarPainter(filled: i < stars),
            ),
          ),
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  final bool filled;

  _StarPainter({required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(9);
    final path = Path();
    const spikes = 5;
    final cx = size.width / 2, cy = size.height / 2;
    final ro = size.width * 0.48, ri = size.width * 0.22;
    for (var i = 0; i < spikes * 2; i++) {
      final a = -pi / 2 + i * pi / spikes;
      final r = (i.isEven ? ro : ri) * (1 + (rng.nextDouble() - 0.5) * 0.08);
      final p = Offset(cx + cos(a) * r, cy + sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (filled) {
      canvas.drawPath(
          path, Paint()..color = SudoColors.gold.withValues(alpha: 0.95));
      canvas.drawPath(
          path,
          Paint()
            ..color = SudoColors.sumi.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    } else {
      canvas.drawPath(
          path,
          Paint()
            ..color = SudoColors.washLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Section heading in brushed serif.
class BrushHeading extends StatelessWidget {
  final String text;
  final double size;
  final Color color;

  const BrushHeading(this.text,
      {super.key, this.size = 22, this.color = SudoColors.sumi});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: SudoFonts.serif,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Micro-label in Manrope (system chrome only).
class MicroLabel extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;

  const MicroLabel(this.text,
      {super.key,
      this.size = 11,
      this.color = SudoColors.walnut,
      this.weight = FontWeight.w600});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: SudoFonts.sans,
        fontWeight: weight,
        fontSize: size,
        color: color,
        letterSpacing: 0.8,
      ),
    );
  }
}
