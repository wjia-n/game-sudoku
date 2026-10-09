import 'package:flutter/material.dart';
import '../engine/sudoku_engine.dart';
import '../navigation.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/sumi_themes.dart';
import '../widgets/name_edit_dialog.dart';
import '../widgets/sumi_widgets.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: profile, continue, 5 difficulties, daily puzzle, timed /
/// relaxed mode, stats at a glance, settings + PRO entry points.
class MenuScreen extends StatefulWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  final StoreService? store;

  const MenuScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.store,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Map<String, dynamic>? _save;

  @override
  void initState() {
    super.initState();
    _checkSave();
  }

  Future<void> _checkSave() async {
    final save = await GameScreen.loadSave();
    if (mounted) setState(() => _save = save);
  }

  void _resume() {
    final save = _save;
    if (save == null) return;
    setState(() => _save = null);
    ResumeHelper.resume(
      context,
      audio: widget.audio,
      settings: widget.settings,
      store: widget.store ?? StoreService(),
      save: save,
    );
    // Re-check when we come back (game may have saved again).
    Future.delayed(const Duration(milliseconds: 500), _checkSave);
  }

  void _start(int diff,
      {bool daily = false, String dateKey = '', int? seed}) {
    widget.audio.click();
    widget.audio.startGameMusic();
    widget.settings.setLastDiff(diff);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
          diffIndex: diff,
          daily: daily,
          dateKey: dateKey,
          seed: seed,
        ),
      ),
    )
        .then((_) {
      widget.audio.startMenuMusic();
      _checkSave();
    });
  }

  void _openSettings() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  void _editName() {
    final t = widget.settings.themeDef();
    showDialog(
      context: context,
      builder: (_) => NameEditDialog(
        theme: t,
        settings: widget.settings,
        audio: widget.audio,
        hintText: 'e.g. Ink Master',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final t = widget.settings.themeDef();
        final dateKey = SudoSettings.todayKey();
        final dailyDone = widget.settings.dailyStars(dateKey) > 0;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: TatamiBackdrop(
            theme: t,
            child: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top bar: settings + PRO.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WoodToken(
                          theme: t,
                          size: 46,
                          onTap: _openSettings,
                          child: Icon(Icons.settings,
                              color: t.washi, size: 22),
                        ),
                        if (!widget.settings.isPro)
                          GestureDetector(
                            onTap: _openPro,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: t.gold,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: t.walnut.withValues(alpha: 0.3),
                                    offset: const Offset(0, 3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text('GO PRO',
                                  style: SumiType.label(13, t,
                                      color: t.washi)),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: t.vermilion.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: t.vermilion),
                            ),
                            child: Text('✦ PRO',
                                style: SumiType.label(13, t,
                                    color: t.vermilion)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Logo + name.
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: t.walnut.withValues(alpha: 0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/sudoku_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => CustomPaint(
                          painter: SudokuLogoPainter(t),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Sudoku', style: SumiType.display(44, t)),
                    Text('WASHI & SUMI CRAFT',
                        style: SumiType.label(11, t)),
                    const SizedBox(height: 10),
                    // Profile name (renameable, persisted).
                    GestureDetector(
                      onTap: _editName,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.washi,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: t.washLine.withValues(alpha: 0.7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.brush,
                                size: 15,
                                color: t.walnut.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            Text(widget.settings.profileName,
                                style: SumiType.body(16, t)),
                            const SizedBox(width: 4),
                            Icon(Icons.edit,
                                size: 13,
                                color: t.walnut.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Continue.
                    if (_save != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: WoodButton(
                          theme: t,
                          text: 'Continue puzzle',
                          icon: Icons.play_arrow,
                          primary: true,
                          onTap: _resume,
                        ),
                      ),
                    // Timed / Relaxed toggle.
                    WashiCard(
                      theme: t,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ModeChip(
                            theme: t,
                            label: '⏱ Timed',
                            selected: !widget.settings.relaxedMode,
                            onTap: () {
                              widget.audio.click();
                              widget.settings.setRelaxedMode(false);
                            },
                          ),
                          const SizedBox(width: 10),
                          _ModeChip(
                            theme: t,
                            label: '🍵 Relaxed',
                            selected: widget.settings.relaxedMode,
                            onTap: () {
                              widget.audio.click();
                              widget.settings.setRelaxedMode(true);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('NEW PUZZLE',
                          style: SumiType.label(13, t)),
                    ),
                    const SizedBox(height: 8),
                    // Daily puzzle tile.
                    _DailyTile(
                      theme: t,
                      done: dailyDone,
                      stars: widget.settings.dailyStars(dateKey),
                      streak: widget.settings.dailyStreak,
                      onTap: () => _start(3,
                          daily: true,
                          dateKey: dateKey,
                          seed: SudoSettings.dailySeed(dateKey)),
                    ),
                    const SizedBox(height: 10),
                    // Difficulty tiles.
                    for (int d = 0; d < sudoDifficulties.length; d++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DifficultyTile(
                          theme: t,
                          diff: sudoDifficulties[d],
                          selected: widget.settings.lastDiff == d,
                          bestTime: widget.settings
                                  .bestTime[sudoDifficulties[d].key] ??
                              0,
                          streak: widget.settings
                                  .streak[sudoDifficulties[d].key] ??
                              0,
                          solved: widget.settings
                                  .solved[sudoDifficulties[d].key] ??
                              0,
                          onTap: () => _start(d),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      widget.settings.relaxedMode
                          ? 'Relaxed: no mistakes counted, no timer pressure — just ink.'
                          : 'Timed: mistakes count toward your star rating.',
                      style: SumiType.micro(12, t),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  final SumiThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? theme.vermilion : theme.washiShade,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? theme.vermilion : theme.washLine),
        ),
        child: Text(label,
            style: SumiType.label(13, theme,
                color: selected ? theme.washi : theme.walnut)),
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  final SumiThemeDef theme;
  final bool done;
  final int stars;
  final int streak;
  final VoidCallback onTap;
  const _DailyTile(
      {required this.theme,
      required this.done,
      required this.streak,
      required this.stars,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: t.vermilion.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.vermilion, width: 1.5),
        ),
        child: Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Puzzle', style: SumiType.body(17, t)),
                  Text(
                    done
                        ? 'Completed — ${'★' * stars}${'☆' * (3 - stars)}'
                        : 'One shared puzzle, new every day',
                    style: SumiType.micro(12, t),
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Text('🔥 $streak', style: SumiType.label(12, t)),
              ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 16, color: t.vermilion),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  final SumiThemeDef theme;
  final SudoDifficulty diff;
  final bool selected;
  final int bestTime;
  final int streak;
  final int solved;
  final VoidCallback onTap;
  const _DifficultyTile({
    required this.theme,
    required this.diff,
    required this.selected,
    required this.bestTime,
    required this.streak,
    required this.solved,
    required this.onTap,
  });

  static String _fmt(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: t.washi,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? t.vermilion : t.washLine.withValues(alpha: 0.6),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: t.walnut.withValues(alpha: 0.10),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // Kanji seal.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? t.vermilion : t.bamboo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(diff.ja,
                    style: TextStyle(
                        fontFamily: 'NotoSerif',
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: t.washi)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(diff.name, style: SumiType.body(17, t)),
                  Text(
                    '${diff.givens} givens'
                    '${bestTime > 0 ? ' · best ${_fmt(bestTime)}' : ''}'
                    '${solved > 0 ? ' · $solved solved' : ''}',
                    style: SumiType.micro(12, t),
                  ),
                ],
              ),
            ),
            if (streak > 1)
              Text('🔥$streak', style: SumiType.label(12, t)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 15, color: t.bambooDark),
          ],
        ),
      ),
    );
  }
}
