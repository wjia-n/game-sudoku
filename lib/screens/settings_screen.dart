import 'package:flutter/material.dart';
import '../engine/sudoku_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/sumi_themes.dart';
import '../widgets/sumi_widgets.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Settings: profile, audio, gameplay assists, themes, digit styles,
/// grid accents, custom theme creator, stats, reset.
class SettingsScreen extends StatelessWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  final StoreService? store;
  const SettingsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      this.store});

  void _applyAudio() {
    audio.configure(
      musicOn: settings.musicOn,
      sfxOn: settings.sfxOn,
      volume: settings.masterVol,
      musicVol: settings.musicVol,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final t = settings.themeDef();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: TatamiBackdrop(
            theme: t,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                    child: Row(
                      children: [
                        WoodToken(
                          theme: t,
                          size: 42,
                          onTap: () {
                            audio.click();
                            Navigator.of(context).pop();
                          },
                          child: Icon(Icons.arrow_back,
                              color: t.washi, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Settings',
                            style: SumiType.display(26, t)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Section(theme: t, title: 'PROFILE', children: [
                            _NameRow(
                                theme: t,
                                settings: settings,
                                audio: audio),
                          ]),
                          _Section(theme: t, title: 'SOUND', children: [
                            _ToggleRow(
                              theme: t,
                              label: 'Music',
                              value: settings.musicOn,
                              onChanged: (v) {
                                settings.setMusic(v);
                                audio.configure(
                                  musicOn: v,
                                  sfxOn: settings.sfxOn,
                                  volume: settings.masterVol,
                                  musicVol: settings.musicVol,
                                );
                                if (v) audio.startMenuMusic();
                              },
                            ),
                            _ToggleRow(
                              theme: t,
                              label: 'Sound effects',
                              value: settings.sfxOn,
                              onChanged: (v) {
                                settings.setSfx(v);
                                _applyAudio();
                                audio.click();
                              },
                            ),
                            _SliderRow(
                              theme: t,
                              label: 'Master volume',
                              value: settings.masterVol,
                              onChanged: (v) {
                                settings.setMasterVol(v);
                                _applyAudio();
                              },
                            ),
                            _SliderRow(
                              theme: t,
                              label: 'Music volume',
                              value: settings.musicVol,
                              onChanged: (v) {
                                settings.setMusicVol(v);
                                _applyAudio();
                              },
                            ),
                          ]),
                          _Section(theme: t, title: 'GAMEPLAY', children: [
                            _CycleRow<int>(
                              theme: t,
                              label: 'Mistake budget',
                              value: settings.mistakeBudget,
                              options: const [0, 3, 5],
                              labels: const ['Off', '3', '5'],
                              onChanged: (v) =>
                                  settings.setMistakeBudget(v),
                            ),
                            _ToggleRow(
                              theme: t,
                              label: 'Strict mode',
                              subtitle:
                                  'Reach the mistake limit and the puzzle fails',
                              value: settings.strictMode,
                              onChanged: (v) =>
                                  settings.setStrictMode(v),
                            ),
                            _ToggleRow(
                              theme: t,
                              label: 'Highlight errors',
                              value: settings.highlightErrors,
                              onChanged: (v) =>
                                  settings.setHighlightErrors(v),
                            ),
                            _ToggleRow(
                              theme: t,
                              label: 'Highlight related cells',
                              value: settings.highlightRelated,
                              onChanged: (v) =>
                                  settings.setHighlightRelated(v),
                            ),
                            _ToggleRow(
                              theme: t,
                              label: 'Highlight same digits',
                              value: settings.highlightSameDigit,
                              onChanged: (v) =>
                                  settings.setHighlightSameDigit(v),
                            ),
                            _ToggleRow(
                              theme: t,
                              label: 'Auto-clean pencil notes',
                              subtitle:
                                  'Placing a digit clears it from peer notes',
                              value: settings.autoNoteCleanup,
                              onChanged: (v) =>
                                  settings.setAutoNoteCleanup(v),
                            ),
                          ]),
                          _Section(theme: t, title: 'THEMES', children: [
                            _ThemeGrid(
                                theme: t,
                                settings: settings,
                                audio: audio),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                audio.click();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomThemeScreen(
                                      audio: audio,
                                      settings: settings,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: t.washiShade,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: t.bamboo, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.palette,
                                        color: t.bambooDark, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                          'Custom theme creator',
                                          style:
                                              SumiType.body(15, t)),
                                    ),
                                    Icon(Icons.arrow_forward_ios,
                                        size: 14, color: t.bambooDark),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                          _Section(
                              theme: t,
                              title: 'DIGIT STYLES',
                              children: [
                                _DigitGrid(
                                    theme: t,
                                    settings: settings,
                                    audio: audio),
                              ]),
                          _Section(theme: t, title: 'GRID ACCENTS', children: [
                            _AccentGrid(
                                theme: t,
                                settings: settings,
                                audio: audio),
                          ]),
                          _Section(theme: t, title: 'STATISTICS', children: [
                            for (final d in sudoDifficulties)
                              _StatRow(
                                theme: t,
                                label: d.name,
                                solved:
                                    settings.solved[d.key] ?? 0,
                                best: settings.bestTime[d.key] ?? 0,
                                streak:
                                    settings.streak[d.key] ?? 0,
                              ),
                            _StatRow(
                              theme: t,
                              label: 'Daily streak',
                              solved: settings.dailyStreak,
                              best: 0,
                              streak: 0,
                              hideBest: true,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  audio.click();
                                  settings.resetStats();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        'Statistics cleared.',
                                        style: SumiType.body(14, t)),
                                    backgroundColor: t.walnut,
                                    behavior:
                                        SnackBarBehavior.floating,
                                  ));
                                },
                                child: Text('Reset statistics',
                                    style: SumiType.label(12, t,
                                        color: t.vermilion)),
                              ),
                            ),
                          ]),
                          if (!settings.isPro)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 6),
                              child: Center(
                                child: WoodButton(
                                  theme: t,
                                  text: 'Sudoku PRO',
                                  icon: Icons.star,
                                  primary: true,
                                  onTap: () {
                                    audio.click();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProScreen(
                                          audio: audio,
                                          settings: settings,
                                          store: store,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text('Sudoku · Washi & Sumi Craft · v2.0',
                                style: SumiType.micro(11, t)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
class _Section extends StatelessWidget {
  final SumiThemeDef theme;
  final String title;
  final List<Widget> children;
  const _Section(
      {required this.theme, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: WashiCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: SumiType.label(12, theme)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  final SumiThemeDef theme;
  final SudoSettings settings;
  final SumiAudio audio;
  const _NameRow(
      {required this.theme,
      required this.settings,
      required this.audio});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final ctrl =
            TextEditingController(text: settings.profileName);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: theme.washi,
            title:
                Text('Your name', style: SumiType.display(20, theme)),
            content: TextField(
              controller: ctrl,
              maxLength: 16,
              autofocus: true,
              style: SumiType.body(17, theme),
              onSubmitted: (_) => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel',
                    style: SumiType.label(13, theme)),
              ),
              TextButton(
                onPressed: () {
                  settings.setProfileName(ctrl.text);
                  audio.click();
                  Navigator.of(context).pop();
                },
                child: Text('Save',
                    style: SumiType.label(13, theme)),
              ),
            ],
          ),
        );
      },
      child: Row(
        children: [
          Expanded(
              child: Text('Display name',
                  style: SumiType.body(15, theme))),
          Text(settings.profileName,
              style: SumiType.body(15, theme)),
          const SizedBox(width: 6),
          Icon(Icons.edit, size: 14, color: theme.bambooDark),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final SumiThemeDef theme;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.theme,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SumiType.body(15, theme)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: SumiType.micro(11, theme)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: value ? theme.vermilion : theme.washLine,
                border: Border.all(color: theme.bambooDark),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      theme.bambooHi,
                      theme.bambooDark
                    ]),
                  ),
                  child: value
                      ? Center(
                          child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.washi)))
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final SumiThemeDef theme;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label, style: SumiType.body(15, theme))),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
              activeColor: theme.vermilion,
              inactiveColor: theme.washLine,
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleRow<T> extends StatelessWidget {
  final SumiThemeDef theme;
  final String label;
  final T value;
  final List<T> options;
  final List<String> labels;
  final ValueChanged<T> onChanged;
  const _CycleRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: SumiType.body(15, theme))),
          Row(
            children: [
              for (int k = 0; k < options.length; k++)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => onChanged(options[k]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: options[k] == value
                            ? theme.vermilion
                            : theme.washiShade,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: options[k] == value
                                ? theme.vermilion
                                : theme.washLine),
                      ),
                      child: Text(labels[k],
                          style: SumiType.label(12, theme,
                              color: options[k] == value
                                  ? theme.washi
                                  : theme.walnut)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  final SumiThemeDef theme;
  final SudoSettings settings;
  final SumiAudio audio;
  const _ThemeGrid(
      {required this.theme,
      required this.settings,
      required this.audio});

  @override
  Widget build(BuildContext context) {
    final items = [
      ...SumiThemes.all,
      settings.customTheme,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, k) {
        final td = items[k];
        final selected = settings.themeId == td.id;
        final locked = !td.free && !settings.isPro;
        return GestureDetector(
          onTap: () {
            audio.click();
            if (locked) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('PRO theme — unlock in Sudoku PRO.',
                    style: SumiType.body(14, theme)),
                backgroundColor: theme.walnut,
                behavior: SnackBarBehavior.floating,
              ));
              return;
            }
            settings.setThemeId(td.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? theme.vermilion : theme.washLine,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      color: td.washi,
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text('5',
                              style: TextStyle(
                                  fontFamily: 'NotoSerif',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 30,
                                  color: td.sumi)),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                                width: 12,
                                height: 12,
                                color: td.vermilion),
                          ),
                          if (locked)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                color: theme.sumi
                                    .withValues(alpha: 0.35),
                              ),
                              child: const Center(
                                  child: Text('🔒',
                                      style:
                                          TextStyle(fontSize: 22))),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.vermilion
                        : theme.washiShade,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8)),
                  ),
                  child: Text(td.name,
                      style: SumiType.micro(10, theme,
                          color: selected
                              ? theme.washi
                              : theme.walnut),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DigitGrid extends StatelessWidget {
  final SumiThemeDef theme;
  final SudoSettings settings;
  final SumiAudio audio;
  const _DigitGrid(
      {required this.theme,
      required this.settings,
      required this.audio});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: DigitStyles.all.length,
      itemBuilder: (_, k) {
        final d = DigitStyles.all[k];
        final selected = settings.digitStyleId == d.id;
        final locked = !d.free && !settings.isPro;
        return GestureDetector(
          onTap: () {
            audio.click();
            if (locked) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('PRO digit style — unlock in Sudoku PRO.',
                    style: SumiType.body(14, theme)),
                backgroundColor: theme.walnut,
                behavior: SnackBarBehavior.floating,
              ));
              return;
            }
            settings.setDigitStyleId(d.id);
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.washiShade,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? theme.vermilion : theme.washLine,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('789',
                        style: SumiType.digit(26, theme, d,
                            given: true)),
                    Text(d.name,
                        style: SumiType.micro(10, theme)),
                  ],
                ),
                if (locked)
                  const Positioned(
                      right: 6,
                      top: 6,
                      child: Text('🔒',
                          style: TextStyle(fontSize: 14))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccentGrid extends StatelessWidget {
  final SumiThemeDef theme;
  final SudoSettings settings;
  final SumiAudio audio;
  const _AccentGrid(
      {required this.theme,
      required this.settings,
      required this.audio});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: GridAccents.all.length,
      itemBuilder: (_, k) {
        final a = GridAccents.all[k];
        final selected = settings.gridAccentId == a.id;
        final locked = !a.free && !settings.isPro;
        return GestureDetector(
          onTap: () {
            audio.click();
            if (locked) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('PRO grid accent — unlock in Sudoku PRO.',
                    style: SumiType.body(14, theme)),
                backgroundColor: theme.walnut,
                behavior: SnackBarBehavior.floating,
              ));
              return;
            }
            settings.setGridAccentId(a.id);
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.washiShade,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? theme.vermilion : theme.washLine,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(44, 44),
                      painter: _MiniGridPainter(theme, a),
                    ),
                    const SizedBox(height: 4),
                    Text(a.name,
                        style: SumiType.micro(10, theme)),
                  ],
                ),
                if (locked)
                  const Positioned(
                      right: 6,
                      top: 6,
                      child: Text('🔒',
                          style: TextStyle(fontSize: 14))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  final SumiThemeDef theme;
  final GridAccent accent;
  _MiniGridPainter(this.theme, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final p = Paint()
      ..color = theme.sumi
      ..strokeWidth = 1.2;
    for (int k = 0; k <= 3; k++) {
      canvas.drawLine(Offset(k * cell, 0),
          Offset(k * cell, size.height), p);
      canvas.drawLine(Offset(0, k * cell),
          Offset(size.width, k * cell), p);
    }
    if (accent.doubleFrame) {
      canvas.drawRect(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          Paint()
            ..color = theme.bambooDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGridPainter old) => false;
}

class _StatRow extends StatelessWidget {
  final SumiThemeDef theme;
  final String label;
  final int solved;
  final int best;
  final int streak;
  final bool hideBest;
  const _StatRow({
    required this.theme,
    required this.label,
    required this.solved,
    required this.best,
    required this.streak,
    this.hideBest = false,
  });

  @override
  Widget build(BuildContext context) {
    String fmt(int s) {
      final m = s ~/ 60, sec = s % 60;
      return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: SumiType.body(14, theme))),
          Text('$solved solved', style: SumiType.micro(12, theme)),
          const SizedBox(width: 10),
          if (!hideBest)
            Text(best > 0 ? 'best ${fmt(best)}' : '—',
                style: SumiType.micro(12, theme)),
          if (!hideBest) const SizedBox(width: 10),
          if (streak > 1) Text('🔥$streak', style: SumiType.micro(12, theme)),
        ],
      ),
    );
  }
}
