import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sumi_themes.dart';
import '../widgets/sumi_widgets.dart';

/// Custom theme creator: pick canvas, paper, ink, seal, bamboo and accent
/// colors from curated washi-craft swatches. Saved as the 'custom' theme.
class CustomThemeScreen extends StatelessWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  static const _swatches = [
    0xFFFAF6EE, 0xFFF1E8D6, 0xFFE5D5BC, 0xFFD9C6A5, // papers
    0xFF1F1E1C, 0xFF3C2E20, 0xFF5A5A5A, 0xFF8A8A8A, // inks
    0xFFC73E2E, 0xFFA8231A, 0xFFB8452F, 0xFFB83A4E, // seals
    0xFFA67C48, 0xFF7A5A32, 0xFF5F7A35, 0xFF3E5A8A, // bamboo/woods
    0xFFD9A844, 0xFFC9962E, 0xFFC9A53A, 0xFF7A8B3F, // ochres
    0xFFDDE3C2, 0xFFF0D5D8, 0xFFD8DDE0, 0xFFC4CDD2, // tinted papers
    0xFF1C2438, 0xFF2A1F16, 0xFF20261A, 0xFF241C2E, // deep inks
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final t = settings.themeDef();
        const rows = [
          ('canvas', 'Tatami canvas'),
          ('washi', 'Washi paper'),
          ('sumi', 'Sumi ink'),
          ('vermilion', 'Seal vermilion'),
          ('bamboo', 'Bamboo wood'),
          ('ochre', 'Ochre wash'),
          ('walnut', 'Walnut text'),
          ('canvasDeep', 'Canvas shade'),
        ];
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
                        Text('Theme creator',
                            style: SumiType.display(24, t)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 30),
                      child: Column(
                        children: [
                          // Live preview.
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: settings.customTheme.washi,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: settings
                                      .customTheme.bambooDark,
                                  width: 2),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text('5',
                                    style: TextStyle(
                                        fontFamily: 'NotoSerif',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 40,
                                        color: settings
                                            .customTheme.sumi)),
                                const SizedBox(width: 14),
                                Container(
                                    width: 26,
                                    height: 26,
                                    color: settings
                                        .customTheme.vermilion),
                                const SizedBox(width: 14),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: settings
                                        .customTheme.bamboo,
                                  ),
                                  child: Center(
                                      child: Text('7',
                                          style: TextStyle(
                                              fontFamily:
                                                  'NotoSerif',
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 20,
                                              color: settings
                                                  .customTheme
                                                  .washi))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final r in rows)
                            _ColorRow(
                              theme: t,
                              label: r.$2,
                              current: settings.customColors[r.$1]!,
                              onPick: (c) {
                                audio.click();
                                settings.setCustomColor(r.$1, c);
                              },
                            ),
                          const SizedBox(height: 16),
                          WoodButton(
                            theme: t,
                            text: 'Use my theme',
                            icon: Icons.check,
                            primary: true,
                            onTap: () {
                              audio.click();
                              settings.setThemeId('custom');
                              Navigator.of(context).pop();
                            },
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

class _ColorRow extends StatelessWidget {
  final SumiThemeDef theme;
  final String label;
  final int current;
  final ValueChanged<int> onPick;
  const _ColorRow({
    required this.theme,
    required this.label,
    required this.current,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WashiCard(
        theme: theme,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(current),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.bambooDark),
                  ),
                ),
                const SizedBox(width: 10),
                Text(label, style: SumiType.body(15, theme)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in CustomThemeScreen._swatches)
                  GestureDetector(
                    onTap: () => onPick(c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c == current
                              ? theme.vermilion
                              : theme.washLine,
                          width: c == current ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
