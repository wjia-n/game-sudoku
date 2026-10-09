import 'package:flutter/material.dart';

import '../audio.dart';
import '../engine.dart';
import '../settings.dart';
import '../theme.dart';

/// Settings: wooden toggle discs, sliders, mistake budget, assist options,
/// per-difficulty stats, reset.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SettingsScreen({super.key, required this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = SudoSettings.instance;
  final audio = SudoAudio.instance;

  String _fmt(int v) =>
      '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 14),
            _section('SOUND  ·  音', [
              _toggleRow('Music', 'Calm shakuhachi loops', s.musicOn,
                  (v) async {
                await s.setMusic(v);
                await audio.refresh();
                setState(() {});
              }),
              _toggleRow('Sound effects', 'Brushes, paper & stamps', s.sfxOn,
                  (v) async {
                await s.setSfx(v);
                setState(() {});
              }),
              _sliderRow('Master volume', s.masterVol, (v) async {
                await s.setMasterVol(v);
                await audio.refresh();
                setState(() {});
              }),
              _sliderRow('Music volume', s.musicVol, (v) async {
                await s.setMusicVol(v);
                await audio.refresh();
                setState(() {});
              }),
            ]),
            const SizedBox(height: 12),
            _section('CRAFT RULES  ·  ルール', [
              _budgetRow(),
              _toggleRow('Strict mode',
                  'Reach the mistake limit and the puzzle ends', s.strictMode,
                  (v) async {
                await s.setStrictMode(v);
                setState(() {});
              }),
              _toggleRow(
                  'Highlight errors', 'Vermilion rings on wrong digits',
                  s.highlightErrors, (v) async {
                await s.setHighlightErrors(v);
                setState(() {});
              }),
              _toggleRow('Related cells',
                  'Tint row, column, box and matching digits',
                  s.highlightRelated, (v) async {
                await s.setHighlightRelated(v);
                setState(() {});
              }),
              _toggleRow('Auto clean notes',
                  'Placing a digit clears it from peer notes',
                  s.autoNoteCleanup, (v) async {
                await s.setAutoNoteCleanup(v);
                setState(() {});
              }),
            ]),
            const SizedBox(height: 12),
            _section('RECORDS  ·  記録', [
              for (var d = 0; d < sudoDifficulties.length; d++)
                _statRow(d),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () async {
                  await s.resetStats();
                  audio.click();
                  setState(() {});
                },
                child: const MicroLabel('RESET ALL RECORDS',
                    color: SudoColors.vermilion, weight: FontWeight.w700),
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        BambooToken(label: '‹', size: 38, onTap: widget.onBack),
        const SizedBox(width: 12),
        const BrushHeading('Settings', size: 24),
        const Spacer(),
        const HankoStamp(size: 40, glyph: '設', angle: 0.08),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return WashiSheet(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(title,
              size: 10.5, weight: FontWeight.w800, color: SudoColors.bambooDark),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleRow(String title, String sub, bool value,
      Future<void> Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: SudoColors.sumi,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontSize: 11.5,
                    color: SudoColors.walnut.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          WoodToggle(
            value: value,
            onChanged: (v) {
              audio.click();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String title, double value,
      Future<void> Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: SudoFonts.serif,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: SudoColors.sumi,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: SudoColors.bamboo,
              inactiveTrackColor: SudoColors.washiShade,
              thumbColor: SudoColors.bambooDark,
              overlayColor: SudoColors.bamboo.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              onChanged: (v) => onChanged(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetRow() {
    const options = [(3, '3'), (5, '5'), (0, 'OFF')];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mistake budget',
                  style: TextStyle(
                    fontFamily: SudoFonts.serif,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: SudoColors.sumi,
                  ),
                ),
                Text(
                  'Vermilion dots per puzzle',
                  style: TextStyle(
                    fontFamily: SudoFonts.sans,
                    fontSize: 11.5,
                    color: SudoColors.walnut,
                  ),
                ),
              ],
            ),
          ),
          for (final (v, label) in options)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () async {
                  audio.click();
                  await s.setMistakeBudget(v);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: s.mistakeBudget == v
                        ? SudoColors.vermilion
                        : SudoColors.washiShade,
                    border: Border.all(
                        color: s.mistakeBudget == v
                            ? SudoColors.vermilion
                            : SudoColors.washLine,
                        width: 1.4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: SudoFonts.sans,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: s.mistakeBudget == v
                          ? SudoColors.washi
                          : SudoColors.walnut,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statRow(int d) {
    final diff = sudoDifficulties[d];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            diff.ja,
            style: const TextStyle(
              fontFamily: SudoFonts.serif,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: SudoColors.vermilion,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            diff.name,
            style: const TextStyle(
              fontFamily: SudoFonts.sans,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: SudoColors.sumi,
            ),
          ),
          const Spacer(),
          Text(
            '${s.solved[d]} solved'
            '${s.bestTime[d] > 0 ? ' · best ${_fmt(s.bestTime[d])}' : ''}'
            '${s.bestStreak[d] > 0 ? ' · 🔥${s.bestStreak[d]}' : ''}',
            style: const TextStyle(
              fontFamily: SudoFonts.sans,
              fontSize: 11.5,
              color: SudoColors.walnut,
            ),
          ),
        ],
      ),
    );
  }
}
