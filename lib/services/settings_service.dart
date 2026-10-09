import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/sumi_themes.dart';

/// Persisted settings + profile + stats for Sudoku. Survives app restarts.
///
/// Stores: profile name, audio toggles/volumes, gameplay assists
/// (mistake budget, strict mode, highlights, auto note cleanup), theme /
/// digit-style / grid-accent choices (incl. custom theme colors), Pro
/// unlock state, per-difficulty stats (solved, best time, streaks,
/// mistakes), and daily-puzzle completions.
class SudoSettings extends ChangeNotifier {
  static const _kName = 'sudoku_profile_name';
  static const _kMusic = 'sudoku_music_on';
  static const _kSfx = 'sudoku_sfx_on';
  static const _kVolume = 'sudoku_master_vol';
  static const _kMusicVol = 'sudoku_music_vol';
  static const _kBudget = 'sudoku_mistake_budget'; // 0 = off, else 3 or 5
  static const _kStrict = 'sudoku_strict';
  static const _kHlErr = 'sudoku_hl_err';
  static const _kHlRel = 'sudoku_hl_rel';
  static const _kHlSame = 'sudoku_hl_same';
  static const _kAutoNotes = 'sudoku_auto_notes';
  static const _kTheme = 'sudoku_theme_id';
  static const _kDigit = 'sudoku_digit_style';
  static const _kAccent = 'sudoku_grid_accent';
  static const _kIsPro = 'sudoku_is_pro';
  static const _kRelaxed = 'sudoku_relaxed';
  static const _kLastDiff = 'sudoku_last_diff';
  static const _kCustomPrefix = 'sudoku_custom_';
  static const _kDailyPrefix = 'sudoku_daily_'; // + dateKey -> stars
  static const _kDailyStreak = 'sudoku_daily_streak';
  static const _kDailyLast = 'sudoku_daily_last';

  String profileName = 'Player';
  bool musicOn = true;
  bool sfxOn = true;
  double masterVol = 0.8;
  double musicVol = 0.65;

  int mistakeBudget = 3;
  bool strictMode = false;
  bool highlightErrors = true;
  bool highlightRelated = true;
  bool highlightSameDigit = true;
  bool autoNoteCleanup = true;
  bool relaxedMode = false;
  int lastDiff = 1;

  String themeId = 'classic';
  String digitStyleId = 'sumi_print';
  String gridAccentId = 'sumi_grid';
  bool isPro = false;

  /// Custom theme colors (ARGB ints). Defaults mirror Classic Washi.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'canvas': 0xFFE5D5BC,
    'canvasDeep': 0xFFD9C6A5,
    'washi': 0xFFFAF6EE,
    'sumi': 0xFF1F1E1C,
    'vermilion': 0xFFC73E2E,
    'bamboo': 0xFFA67C48,
    'ochre': 0xFFD9A844,
    'walnut': 0xFF3C2E20,
  };

  // Per-difficulty stats, keyed by difficulty key (novice/easy/…).
  final Map<String, int> solved = {};
  final Map<String, int> bestTime = {};
  final Map<String, int> streak = {};
  final Map<String, int> bestStreak = {};
  final Map<String, int> totalMistakes = {};

  int dailyStreak = 0;
  String dailyLastKey = '';

  /// Builds the user-designed custom theme from stored colors.
  SumiThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    final sumi = c('sumi');
    final washi = c('washi');
    return SumiThemeDef(
      id: 'custom',
      name: 'My Creation',
      canvas: c('canvas'),
      canvasDeep: c('canvasDeep'),
      washi: washi,
      washiShade: Color.lerp(washi, sumi, 0.06) ?? washi,
      sumi: sumi,
      walnut: c('walnut'),
      vermilion: c('vermilion'),
      bamboo: c('bamboo'),
      bambooHi: Color.lerp(c('bamboo'), const Color(0xFFFFFFFF), 0.25) ??
          c('bamboo'),
      bambooDark: Color.lerp(c('bamboo'), const Color(0xFF000000), 0.3) ??
          c('bamboo'),
      ochre: c('ochre'),
      gold: Color.lerp(c('ochre'), const Color(0xFF000000), 0.15) ?? c('ochre'),
      relatedTint: Color.lerp(washi, c('bamboo'), 0.18) ?? washi,
      sameDigitTint: Color.lerp(washi, c('ochre'), 0.35) ?? washi,
      washLine: Color.lerp(washi, sumi, 0.25) ?? washi,
      free: true,
    );
  }

  SumiThemeDef themeDef() =>
      SumiThemes.byId(themeId, custom: customTheme, isPro: isPro);
  DigitStyle digitStyle() => DigitStyles.byId(digitStyleId, isPro: isPro);
  GridAccent gridAccent() => GridAccents.byId(gridAccentId, isPro: isPro);

  SharedPreferences? _prefs;
  bool _ready = false;

  Future<void> load() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    profileName = p.getString(_kName) ?? 'Player';
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    masterVol = p.getDouble(_kVolume) ?? 0.8;
    musicVol = p.getDouble(_kMusicVol) ?? 0.65;
    mistakeBudget = p.getInt(_kBudget) ?? 3;
    strictMode = p.getBool(_kStrict) ?? false;
    highlightErrors = p.getBool(_kHlErr) ?? true;
    highlightRelated = p.getBool(_kHlRel) ?? true;
    highlightSameDigit = p.getBool(_kHlSame) ?? true;
    autoNoteCleanup = p.getBool(_kAutoNotes) ?? true;
    relaxedMode = p.getBool(_kRelaxed) ?? false;
    lastDiff = (p.getInt(_kLastDiff) ?? 1).clamp(0, 4);
    themeId = p.getString(_kTheme) ?? 'classic';
    digitStyleId = p.getString(_kDigit) ?? 'sumi_print';
    gridAccentId = p.getString(_kAccent) ?? 'sumi_grid';
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    for (final d in ['novice', 'easy', 'medium', 'hard', 'expert']) {
      solved[d] = p.getInt('sudoku_solved_$d') ?? 0;
      bestTime[d] = p.getInt('sudoku_best_$d') ?? 0;
      streak[d] = p.getInt('sudoku_streak_$d') ?? 0;
      bestStreak[d] = p.getInt('sudoku_beststreak_$d') ?? 0;
      totalMistakes[d] = p.getInt('sudoku_mistakes_$d') ?? 0;
    }
    dailyStreak = p.getInt(_kDailyStreak) ?? 0;
    dailyLastKey = p.getString(_kDailyLast) ?? '';
    _ready = true;
  }

  Future<void> _persist(String key, Object v) async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    if (v is bool) await p.setBool(key, v);
    if (v is int) await p.setInt(key, v);
    if (v is double) await p.setDouble(key, v);
    if (v is String) await p.setString(key, v);
  }

  void _touch() => notifyListeners();

  // ------------------------------------------------------------- setters
  Future<void> setProfileName(String v) async {
    profileName = v.trim().isEmpty ? 'Player' : v.trim();
    await _persist(_kName, profileName);
    _touch();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    await _persist(_kMusic, v);
    _touch();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    await _persist(_kSfx, v);
    _touch();
  }

  Future<void> setMasterVol(double v) async {
    masterVol = v.clamp(0.0, 1.0);
    await _persist(_kVolume, masterVol);
    _touch();
  }

  Future<void> setMusicVol(double v) async {
    musicVol = v.clamp(0.0, 1.0);
    await _persist(_kMusicVol, musicVol);
    _touch();
  }

  Future<void> setMistakeBudget(int v) async {
    mistakeBudget = v;
    await _persist(_kBudget, v);
    _touch();
  }

  Future<void> setStrictMode(bool v) async {
    strictMode = v;
    await _persist(_kStrict, v);
    _touch();
  }

  Future<void> setHighlightErrors(bool v) async {
    highlightErrors = v;
    await _persist(_kHlErr, v);
    _touch();
  }

  Future<void> setHighlightRelated(bool v) async {
    highlightRelated = v;
    await _persist(_kHlRel, v);
    _touch();
  }

  Future<void> setHighlightSameDigit(bool v) async {
    highlightSameDigit = v;
    await _persist(_kHlSame, v);
    _touch();
  }

  Future<void> setAutoNoteCleanup(bool v) async {
    autoNoteCleanup = v;
    await _persist(_kAutoNotes, v);
    _touch();
  }

  Future<void> setRelaxedMode(bool v) async {
    relaxedMode = v;
    await _persist(_kRelaxed, v);
    _touch();
  }

  Future<void> setLastDiff(int v) async {
    lastDiff = v.clamp(0, 4);
    await _persist(_kLastDiff, lastDiff);
    _touch();
  }

  Future<void> setThemeId(String v) async {
    themeId = v;
    await _persist(_kTheme, v);
    _touch();
  }

  Future<void> setDigitStyleId(String v) async {
    digitStyleId = v;
    await _persist(_kDigit, v);
    _touch();
  }

  Future<void> setGridAccentId(String v) async {
    gridAccentId = v;
    await _persist(_kAccent, v);
    _touch();
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    await _persist(_kIsPro, v);
    _touch();
  }

  Future<void> setCustomColor(String key, int argb) async {
    customColors[key] = argb;
    await _persist('$_kCustomPrefix$key', argb);
    _touch();
  }

  // ----------------------------------------------------------------- stats
  /// Record a win. Returns true when the time is a new best for [diffKey].
  Future<bool> recordWin(String diffKey, int seconds, int mistakes) async {
    var newBest = false;
    solved[diffKey] = (solved[diffKey] ?? 0) + 1;
    streak[diffKey] = (streak[diffKey] ?? 0) + 1;
    totalMistakes[diffKey] = (totalMistakes[diffKey] ?? 0) + mistakes;
    if ((streak[diffKey] ?? 0) > (bestStreak[diffKey] ?? 0)) {
      bestStreak[diffKey] = streak[diffKey]!;
    }
    if ((bestTime[diffKey] ?? 0) == 0 || seconds < (bestTime[diffKey] ?? 0)) {
      bestTime[diffKey] = seconds;
      newBest = true;
    }
    await _persist('sudoku_solved_$diffKey', solved[diffKey]!);
    await _persist('sudoku_streak_$diffKey', streak[diffKey]!);
    await _persist('sudoku_beststreak_$diffKey', bestStreak[diffKey]!);
    await _persist('sudoku_mistakes_$diffKey', totalMistakes[diffKey]!);
    await _persist('sudoku_best_$diffKey', bestTime[diffKey]!);
    _touch();
    return newBest;
  }

  /// Record a failed/abandoned puzzle (streak resets).
  Future<void> recordFail(String diffKey) async {
    streak[diffKey] = 0;
    await _persist('sudoku_streak_$diffKey', 0);
    _touch();
  }

  /// Daily completion. Returns true when this is the first completion today.
  Future<bool> recordDaily(String dateKey, int stars) async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    final prev = p.getInt('$_kDailyPrefix$dateKey') ?? 0;
    final first = prev == 0;
    if (stars > prev) {
      await p.setInt('$_kDailyPrefix$dateKey', stars);
    }
    if (first) {
      // Streak continues only when the last completed day was yesterday.
      final today = DateTime.parse(dateKey);
      final last =
          dailyLastKey.isEmpty ? null : DateTime.tryParse(dailyLastKey);
      if (last != null && today.difference(last).inDays == 1) {
        dailyStreak++;
      } else if (last == null || today.difference(last).inDays > 1) {
        dailyStreak = 1;
      }
      dailyLastKey = dateKey;
      await _persist(_kDailyStreak, dailyStreak);
      await _persist(_kDailyLast, dailyLastKey);
    }
    _touch();
    return first;
  }

  int dailyStars(String dateKey) {
    return _prefs?.getInt('$_kDailyPrefix$dateKey') ?? 0;
  }

  Future<void> resetStats() async {
    for (final d in ['novice', 'easy', 'medium', 'hard', 'expert']) {
      solved[d] = 0;
      bestTime[d] = 0;
      streak[d] = 0;
      bestStreak[d] = 0;
      totalMistakes[d] = 0;
      await _persist('sudoku_solved_$d', 0);
      await _persist('sudoku_best_$d', 0);
      await _persist('sudoku_streak_$d', 0);
      await _persist('sudoku_beststreak_$d', 0);
      await _persist('sudoku_mistakes_$d', 0);
    }
    _touch();
  }

  /// Today's daily key: YYYY-MM-DD in the device's local timezone.
  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// Deterministic daily seed — same puzzle for every player, every day.
  static int dailySeed(String dateKey) {
    final d = DateTime.parse(dateKey);
    return d.year * 10000 + d.month * 100 + d.day;
  }
}
