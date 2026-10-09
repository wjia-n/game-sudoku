import 'package:flutter/material.dart';

/// Theme, digit-style and grid-accent catalogs for Sudoku.
///
/// Every theme stays inside the Japanese stationery-craft material world
/// (washi paper, sumi ink, bamboo, vermilion seal) — the variety comes
/// from different papers, inks, woods and seal tones. No neon, no glow.
class SumiThemeDef {
  final String id;
  final String name;
  final Color canvas; // tatami backdrop
  final Color canvasDeep;
  final Color washi; // board sheet
  final Color washiShade;
  final Color sumi; // givens / grid rules
  final Color walnut; // notes / metadata
  final Color vermilion; // seal / active / errors
  final Color bamboo; // number tokens
  final Color bambooHi;
  final Color bambooDark;
  final Color ochre; // selection wash
  final Color gold; // stars
  final Color relatedTint; // related row/col/box tint
  final Color sameDigitTint; // identical-digit tint
  final Color washLine; // thin cell borders
  final bool free; // false = PRO only

  const SumiThemeDef({
    required this.id,
    required this.name,
    required this.canvas,
    required this.canvasDeep,
    required this.washi,
    required this.washiShade,
    required this.sumi,
    required this.walnut,
    required this.vermilion,
    required this.bamboo,
    required this.bambooHi,
    required this.bambooDark,
    required this.ochre,
    required this.gold,
    required this.relatedTint,
    required this.sameDigitTint,
    required this.washLine,
    required this.free,
  });

  Color get boxLine => sumi;
  Color get errorWash => vermilion.withValues(alpha: 0.16);
  Color get selWash => ochre.withValues(alpha: 0.30);
}

class SumiThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'bamboo',
    'mist',
    'persimmon',
  ];

  static const List<SumiThemeDef> all = [
    // ------------------------------------------------------------ FREE
    SumiThemeDef(
      id: 'classic',
      name: 'Classic Washi',
      canvas: Color(0xFFE5D5BC),
      canvasDeep: Color(0xFFD9C6A5),
      washi: Color(0xFFFAF6EE),
      washiShade: Color(0xFFF1E8D6),
      sumi: Color(0xFF1F1E1C),
      walnut: Color(0xFF3C2E20),
      vermilion: Color(0xFFC73E2E),
      bamboo: Color(0xFFA67C48),
      bambooHi: Color(0xFFC29B63),
      bambooDark: Color(0xFF7A5A32),
      ochre: Color(0xFFD9A844),
      gold: Color(0xFFC9962E),
      relatedTint: Color(0xFFEFE3CC),
      sameDigitTint: Color(0xFFEAD9AE),
      washLine: Color(0xFFB9A98D),
      free: true,
    ),
    SumiThemeDef(
      id: 'bamboo',
      name: 'Bamboo Grove',
      canvas: Color(0xFFDDE3C2),
      canvasDeep: Color(0xFFC9D1A8),
      washi: Color(0xFFF7F4E6),
      washiShade: Color(0xFFEAE5CE),
      sumi: Color(0xFF232A1E),
      walnut: Color(0xFF3A422C),
      vermilion: Color(0xFFB8452F),
      bamboo: Color(0xFF7A8B3F),
      bambooHi: Color(0xFF9AA95E),
      bambooDark: Color(0xFF5A6830),
      ochre: Color(0xFFC9A53A),
      gold: Color(0xFFB08A24),
      relatedTint: Color(0xFFE8EAD0),
      sameDigitTint: Color(0xFFDDE3B0),
      washLine: Color(0xFFA8B088),
      free: true,
    ),
    SumiThemeDef(
      id: 'mist',
      name: 'Morning Mist',
      canvas: Color(0xFFD8DDE0),
      canvasDeep: Color(0xFFC3CACF),
      washi: Color(0xFFF6F7F5),
      washiShade: Color(0xFFE8EBE9),
      sumi: Color(0xFF23272B),
      walnut: Color(0xFF3A4046),
      vermilion: Color(0xFFB0413A),
      bamboo: Color(0xFF7E8B96),
      bambooHi: Color(0xFF9DABB6),
      bambooDark: Color(0xFF5C666F),
      ochre: Color(0xFFC2A24A),
      gold: Color(0xFFA8842F),
      relatedTint: Color(0xFFE4E9EB),
      sameDigitTint: Color(0xFFD6DEE2),
      washLine: Color(0xFFA6AFB6),
      free: true,
    ),
    SumiThemeDef(
      id: 'persimmon',
      name: 'Persimmon Dye',
      canvas: Color(0xFFEFD3B8),
      canvasDeep: Color(0xFFE3BE9E),
      washi: Color(0xFFFBF3E8),
      washiShade: Color(0xFFF3E4CF),
      sumi: Color(0xFF2A1F16),
      walnut: Color(0xFF4A3524),
      vermilion: Color(0xFFC0392B),
      bamboo: Color(0xFFB4692E),
      bambooHi: Color(0xFFD0864A),
      bambooDark: Color(0xFF8A4E22),
      ochre: Color(0xFFD9A03A),
      gold: Color(0xFFBE8626),
      relatedTint: Color(0xFFF5E3CB),
      sameDigitTint: Color(0xFFF0D3A8),
      washLine: Color(0xFFC4A181),
      free: true,
    ),
    // ------------------------------------------------------------- PRO
    SumiThemeDef(
      id: 'indigo',
      name: 'Indigo Dye',
      canvas: Color(0xFFB9C2D4),
      canvasDeep: Color(0xFFA2ACC2),
      washi: Color(0xFFF2F4F8),
      washiShade: Color(0xFFE2E7EF),
      sumi: Color(0xFF1C2438),
      walnut: Color(0xFF2E3850),
      vermilion: Color(0xFFC73E2E),
      bamboo: Color(0xFF3E5A8A),
      bambooHi: Color(0xFF5A78A8),
      bambooDark: Color(0xFF2C4270),
      ochre: Color(0xFFD9A844),
      gold: Color(0xFFC9962E),
      relatedTint: Color(0xFFDEE4F0),
      sameDigitTint: Color(0xFFC9D6EC),
      washLine: Color(0xFF93A0B8),
      free: false,
    ),
    SumiThemeDef(
      id: 'matcha',
      name: 'Matcha Bowl',
      canvas: Color(0xFFCBD8B4),
      canvasDeep: Color(0xFFB5C49A),
      washi: Color(0xFFF5F7EA),
      washiShade: Color(0xFFE6EAD2),
      sumi: Color(0xFF20261A),
      walnut: Color(0xFF333B26),
      vermilion: Color(0xFFB8452F),
      bamboo: Color(0xFF5F7A35),
      bambooHi: Color(0xFF7D9850),
      bambooDark: Color(0xFF475E28),
      ochre: Color(0xFFC9A53A),
      gold: Color(0xFFA8842F),
      relatedTint: Color(0xFFE2E8CC),
      sameDigitTint: Color(0xFFD2DCAE),
      washLine: Color(0xFF9AA87E),
      free: false,
    ),
    SumiThemeDef(
      id: 'sakura',
      name: 'Sakura Paper',
      canvas: Color(0xFFF0D5D8),
      canvasDeep: Color(0xFFE4BCC2),
      washi: Color(0xFFFBF4F2),
      washiShade: Color(0xFFF2E2DE),
      sumi: Color(0xFF2B2024),
      walnut: Color(0xFF463038),
      vermilion: Color(0xFFB83A4E),
      bamboo: Color(0xFFB47A86),
      bambooHi: Color(0xFFCF99A4),
      bambooDark: Color(0xFF8E5A66),
      ochre: Color(0xFFD9A844),
      gold: Color(0xFFC9962E),
      relatedTint: Color(0xFFF5E4E6),
      sameDigitTint: Color(0xFFF0CDD4),
      washLine: Color(0xFFC6A0A6),
      free: false,
    ),
    SumiThemeDef(
      id: 'charcoal',
      name: 'Charcoal Night',
      canvas: Color(0xFF3A3835),
      canvasDeep: Color(0xFF2C2A28),
      washi: Color(0xFF4A4640),
      washiShade: Color(0xFF3E3A35),
      sumi: Color(0xFFF2EDE2),
      walnut: Color(0xFFD8D2C4),
      vermilion: Color(0xFFE05A3E),
      bamboo: Color(0xFFA67C48),
      bambooHi: Color(0xFFC29B63),
      bambooDark: Color(0xFF7A5A32),
      ochre: Color(0xFFE0B44A),
      gold: Color(0xFFD9A844),
      relatedTint: Color(0xFF55504A),
      sameDigitTint: Color(0xFF655E52),
      washLine: Color(0xFF6E675C),
      free: false,
    ),
    SumiThemeDef(
      id: 'cinnabar',
      name: 'Cinnabar Seal',
      canvas: Color(0xFFE8C4B8),
      canvasDeep: Color(0xFFDAAB9E),
      washi: Color(0xFFFAF1EA),
      washiShade: Color(0xFFF0DDD2),
      sumi: Color(0xFF2A1C16),
      walnut: Color(0xFF4A2E22),
      vermilion: Color(0xFFA8231A),
      bamboo: Color(0xFF8A4A2E),
      bambooHi: Color(0xFFA86644),
      bambooDark: Color(0xFF683622),
      ochre: Color(0xFFD9A03A),
      gold: Color(0xFFBE8626),
      relatedTint: Color(0xFFF2DCD2),
      sameDigitTint: Color(0xFFEAC2B2),
      washLine: Color(0xFFBE9484),
      free: false,
    ),
    SumiThemeDef(
      id: 'riverstone',
      name: 'River Stone',
      canvas: Color(0xFFC4CDD2),
      canvasDeep: Color(0xFFACB7BE),
      washi: Color(0xFFF1F4F4),
      washiShade: Color(0xFFE0E6E6),
      sumi: Color(0xFF1F2A30),
      walnut: Color(0xFF33424A),
      vermilion: Color(0xFFB8452F),
      bamboo: Color(0xFF4E6E78),
      bambooHi: Color(0xFF6B8B95),
      bambooDark: Color(0xFF3A545E),
      ochre: Color(0xFFC9A53A),
      gold: Color(0xFFA8842F),
      relatedTint: Color(0xFFDCE4E6),
      sameDigitTint: Color(0xFFC2D4D8),
      washLine: Color(0xFF8EA0A8),
      free: false,
    ),
    SumiThemeDef(
      id: 'goldenhour',
      name: 'Golden Hour',
      canvas: Color(0xFFF0DCAE),
      canvasDeep: Color(0xFFE4C992),
      washi: Color(0xFFFBF6E8),
      washiShade: Color(0xFFF2E8CC),
      sumi: Color(0xFF2A2014),
      walnut: Color(0xFF4A3A22),
      vermilion: Color(0xFFC0392B),
      bamboo: Color(0xFFB07E2E),
      bambooHi: Color(0xFFCB9A4A),
      bambooDark: Color(0xFF8A5F22),
      ochre: Color(0xFFD9A03A),
      gold: Color(0xFFBE8626),
      relatedTint: Color(0xFFF4E6C4),
      sameDigitTint: Color(0xFFEED9A0),
      washLine: Color(0xFFC6A878),
      free: false,
    ),
    SumiThemeDef(
      id: 'plum',
      name: 'Plum Ink',
      canvas: Color(0xFFD8C8DE),
      canvasDeep: Color(0xFFC2AECD),
      washi: Color(0xFFF6F1F8),
      washiShade: Color(0xFFE8DFEE),
      sumi: Color(0xFF241C2E),
      walnut: Color(0xFF3A2E48),
      vermilion: Color(0xFFB83A4E),
      bamboo: Color(0xFF7A5A8E),
      bambooHi: Color(0xFF9778AA),
      bambooDark: Color(0xFF5C4270),
      ochre: Color(0xFFD9A844),
      gold: Color(0xFFC9962E),
      relatedTint: Color(0xFFE6DCEC),
      sameDigitTint: Color(0xFFD4C2DE),
      washLine: Color(0xFFA48EB2),
      free: false,
    ),
    SumiThemeDef(
      id: 'moss',
      name: 'Moss Garden',
      canvas: Color(0xFFBECBA6),
      canvasDeep: Color(0xFFA8B98E),
      washi: Color(0xFFF2F4E8),
      washiShade: Color(0xFFE2E6D0),
      sumi: Color(0xFF1E2418),
      walnut: Color(0xFF303824),
      vermilion: Color(0xFFB8452F),
      bamboo: Color(0xFF556E38),
      bambooHi: Color(0xFF718A52),
      bambooDark: Color(0xFF40542C),
      ochre: Color(0xFFC9A53A),
      gold: Color(0xFFA8842F),
      relatedTint: Color(0xFFDDE4C8),
      sameDigitTint: Color(0xFFC8D4A8),
      washLine: Color(0xFF8EA078),
      free: false,
    ),
    SumiThemeDef(
      id: 'winter',
      name: 'Winter Paper',
      canvas: Color(0xFFD2DCE4),
      canvasDeep: Color(0xFFBCC8D4),
      washi: Color(0xFFF8FAFC),
      washiShade: Color(0xFFEAF0F4),
      sumi: Color(0xFF1E262E),
      walnut: Color(0xFF323C46),
      vermilion: Color(0xFFB0413A),
      bamboo: Color(0xFF5E7E94),
      bambooHi: Color(0xFF7C9AB0),
      bambooDark: Color(0xFF466078),
      ochre: Color(0xFFC2A24A),
      gold: Color(0xFFA8842F),
      relatedTint: Color(0xFFE2EAF0),
      sameDigitTint: Color(0xFFCCDEEA),
      washLine: Color(0xFF9AABB8),
      free: false,
    ),
  ];

  static SumiThemeDef byId(String id,
      {required SumiThemeDef custom, required bool isPro}) {
    if (id == 'custom') return custom;
    for (final t in all) {
      if (t.id == id) {
        if (!t.free && !isPro) return all.first; // locked → fallback
        return t;
      }
    }
    return all.first;
  }

  static bool isFree(String id) => freeThemeIds.contains(id) || id == 'custom';
}

// ---------------------------------------------------------------------------
/// Digit styles: how the 1–9 numerals are drawn. Same two bundled fonts,
/// varied by weight / slant / spacing — no extra font files.
class DigitStyle {
  final String id;
  final String name;
  final String fontFamily; // 'NotoSerif' | 'Manrope'
  final FontWeight weight;
  final bool italic;
  final double letterSpacing;
  final bool free;

  const DigitStyle({
    required this.id,
    required this.name,
    required this.fontFamily,
    required this.weight,
    required this.italic,
    required this.letterSpacing,
    required this.free,
  });
}

class DigitStyles {
  static const List<DigitStyle> all = [
    DigitStyle(
        id: 'sumi_print',
        name: 'Sumi Print',
        fontFamily: 'NotoSerif',
        weight: FontWeight.w700,
        italic: false,
        letterSpacing: 0,
        free: true),
    DigitStyle(
        id: 'brush_hand',
        name: 'Brush Hand',
        fontFamily: 'NotoSerif',
        weight: FontWeight.w400,
        italic: false,
        letterSpacing: 0,
        free: true),
    DigitStyle(
        id: 'clean_gothic',
        name: 'Clean Gothic',
        fontFamily: 'Manrope',
        weight: FontWeight.w700,
        italic: false,
        letterSpacing: 0,
        free: true),
    DigitStyle(
        id: 'round_maru',
        name: 'Round Maru',
        fontFamily: 'Manrope',
        weight: FontWeight.w500,
        italic: false,
        letterSpacing: 1.5,
        free: true),
    DigitStyle(
        id: 'ink_mincho',
        name: 'Ink Mincho',
        fontFamily: 'NotoSerif',
        weight: FontWeight.w600,
        italic: true,
        letterSpacing: 0,
        free: false),
    DigitStyle(
        id: 'calligrapher',
        name: 'Calligrapher',
        fontFamily: 'NotoSerif',
        weight: FontWeight.w400,
        italic: true,
        letterSpacing: 0.5,
        free: false),
    DigitStyle(
        id: 'bold_block',
        name: 'Bold Block',
        fontFamily: 'Manrope',
        weight: FontWeight.w800,
        italic: false,
        letterSpacing: 0,
        free: false),
    DigitStyle(
        id: 'paper_whisper',
        name: 'Paper Whisper',
        fontFamily: 'NotoSerif',
        weight: FontWeight.w300,
        italic: false,
        letterSpacing: 2.0,
        free: false),
    DigitStyle(
        id: 'ledger',
        name: 'Ledger Sans',
        fontFamily: 'Manrope',
        weight: FontWeight.w600,
        italic: false,
        letterSpacing: 3.0,
        free: false),
  ];

  static DigitStyle byId(String id, {required bool isPro}) {
    for (final d in all) {
      if (d.id == id) {
        if (!d.free && !isPro) return all.first;
        return d;
      }
    }
    return all.first;
  }
}

// ---------------------------------------------------------------------------
/// Grid accents: how the board's rules and frame are drawn.
class GridAccent {
  final String id;
  final String name;
  final double boxLineWidth; // 3×3 dividers
  final double cellLineWidth; // cell dividers
  final bool doubleFrame; // extra outer frame
  final bool roundedSheet; // deckled rounded board
  final bool free;

  const GridAccent({
    required this.id,
    required this.name,
    required this.boxLineWidth,
    required this.cellLineWidth,
    required this.doubleFrame,
    required this.roundedSheet,
    required this.free,
  });
}

class GridAccents {
  static const List<GridAccent> all = [
    GridAccent(
        id: 'sumi_grid',
        name: 'Sumi Grid',
        boxLineWidth: 2.5,
        cellLineWidth: 1.0,
        doubleFrame: false,
        roundedSheet: false,
        free: true),
    GridAccent(
        id: 'thin_wash',
        name: 'Thin Wash',
        boxLineWidth: 1.5,
        cellLineWidth: 0.5,
        doubleFrame: false,
        roundedSheet: false,
        free: true),
    GridAccent(
        id: 'bamboo_frame',
        name: 'Bamboo Frame',
        boxLineWidth: 2.0,
        cellLineWidth: 1.0,
        doubleFrame: true,
        roundedSheet: false,
        free: true),
    GridAccent(
        id: 'double_rule',
        name: 'Double Rule',
        boxLineWidth: 3.5,
        cellLineWidth: 1.0,
        doubleFrame: true,
        roundedSheet: false,
        free: false),
    GridAccent(
        id: 'deckled',
        name: 'Deckled Edge',
        boxLineWidth: 2.0,
        cellLineWidth: 1.0,
        doubleFrame: false,
        roundedSheet: true,
        free: false),
    GridAccent(
        id: 'minimal',
        name: 'Minimal Dots',
        boxLineWidth: 2.0,
        cellLineWidth: 0.0,
        doubleFrame: false,
        roundedSheet: false,
        free: false),
  ];

  static GridAccent byId(String id, {required bool isPro}) {
    for (final a in all) {
      if (a.id == id) {
        if (!a.free && !isPro) return all.first;
        return a;
      }
    }
    return all.first;
  }
}
