import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings + per-difficulty stats for Sudoku (RULES.md §2, §8).
class SudoSettings {
  SudoSettings._();

  static final SudoSettings instance = SudoSettings._();

  // Audio.
  bool musicOn = true;
  bool sfxOn = true;
  double masterVol = 0.8;
  double musicVol = 0.65;

  // Gameplay assists.
  int mistakeBudget = 3; // 0 = off, else 3 or 5
  bool strictMode = false;
  bool highlightErrors = true;
  bool highlightRelated = true;
  bool autoNoteCleanup = true;

  // Per-difficulty stats: index = difficulty index (0..3).
  final List<int> solved = [0, 0, 0, 0];
  final List<int> bestTime = [0, 0, 0, 0];
  final List<int> streak = [0, 0, 0, 0];
  final List<int> bestStreak = [0, 0, 0, 0];
  final List<int> totalMistakes = [0, 0, 0, 0];

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    musicOn = p.getBool('sudo_music') ?? true;
    sfxOn = p.getBool('sudo_sfx') ?? true;
    masterVol = p.getDouble('sudo_master_vol') ?? 0.8;
    musicVol = p.getDouble('sudo_music_vol') ?? 0.65;
    mistakeBudget = p.getInt('sudo_mistake_budget') ?? 3;
    strictMode = p.getBool('sudo_strict') ?? false;
    highlightErrors = p.getBool('sudo_hl_err') ?? true;
    highlightRelated = p.getBool('sudo_hl_rel') ?? true;
    autoNoteCleanup = p.getBool('sudo_auto_notes') ?? true;
    for (var d = 0; d < 4; d++) {
      solved[d] = p.getInt('sudo_solved_$d') ?? 0;
      bestTime[d] = p.getInt('sudo_best_$d') ?? 0;
      streak[d] = p.getInt('sudo_streak_$d') ?? 0;
      bestStreak[d] = p.getInt('sudo_beststreak_$d') ?? 0;
      totalMistakes[d] = p.getInt('sudo_mistakes_$d') ?? 0;
    }
    _ready = true;
  }

  Future<void> _saveAudio() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('sudo_music', musicOn);
    await p.setBool('sudo_sfx', sfxOn);
    await p.setDouble('sudo_master_vol', masterVol);
    await p.setDouble('sudo_music_vol', musicVol);
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    await _saveAudio();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    await _saveAudio();
  }

  Future<void> setMasterVol(double v) async {
    masterVol = v.clamp(0.0, 1.0);
    await _saveAudio();
  }

  Future<void> setMusicVol(double v) async {
    musicVol = v.clamp(0.0, 1.0);
    await _saveAudio();
  }

  Future<void> _saveAssists() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('sudo_mistake_budget', mistakeBudget);
    await p.setBool('sudo_strict', strictMode);
    await p.setBool('sudo_hl_err', highlightErrors);
    await p.setBool('sudo_hl_rel', highlightRelated);
    await p.setBool('sudo_auto_notes', autoNoteCleanup);
  }

  Future<void> setMistakeBudget(int v) async {
    mistakeBudget = v;
    await _saveAssists();
  }

  Future<void> setStrictMode(bool v) async {
    strictMode = v;
    await _saveAssists();
  }

  Future<void> setHighlightErrors(bool v) async {
    highlightErrors = v;
    await _saveAssists();
  }

  Future<void> setHighlightRelated(bool v) async {
    highlightRelated = v;
    await _saveAssists();
  }

  Future<void> setAutoNoteCleanup(bool v) async {
    autoNoteCleanup = v;
    await _saveAssists();
  }

  /// Record a win on difficulty [d]. Returns true when the time is a new best.
  Future<bool> recordWin(int d, int seconds, int mistakes) async {
    final p = await SharedPreferences.getInstance();
    var newBest = false;
    solved[d]++;
    streak[d]++;
    totalMistakes[d] += mistakes;
    if (streak[d] > bestStreak[d]) bestStreak[d] = streak[d];
    if (bestTime[d] == 0 || seconds < bestTime[d]) {
      bestTime[d] = seconds;
      newBest = true;
    }
    await p.setInt('sudo_solved_$d', solved[d]);
    await p.setInt('sudo_streak_$d', streak[d]);
    await p.setInt('sudo_beststreak_$d', bestStreak[d]);
    await p.setInt('sudo_mistakes_$d', totalMistakes[d]);
    await p.setInt('sudo_best_$d', bestTime[d]);
    return newBest;
  }

  /// Record a failed/abandoned puzzle on difficulty [d] (streak resets).
  Future<void> recordFail(int d) async {
    final p = await SharedPreferences.getInstance();
    streak[d] = 0;
    await p.setInt('sudo_streak_$d', 0);
  }

  Future<void> resetStats() async {
    final p = await SharedPreferences.getInstance();
    for (var d = 0; d < 4; d++) {
      solved[d] = 0;
      bestTime[d] = 0;
      streak[d] = 0;
      bestStreak[d] = 0;
      totalMistakes[d] = 0;
      await p.setInt('sudo_solved_$d', 0);
      await p.setInt('sudo_best_$d', 0);
      await p.setInt('sudo_streak_$d', 0);
      await p.setInt('sudo_beststreak_$d', 0);
      await p.setInt('sudo_mistakes_$d', 0);
    }
  }
}
