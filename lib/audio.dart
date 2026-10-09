import 'package:audioplayers/audioplayers.dart';

import 'settings.dart';

/// Central audio for Sudoku: synthesized stationery-craft SFX
/// (tools/gen_audio.py) + looping shakuhachi/koto-flavored music.
/// Toggles and volumes take effect immediately.
class SudoAudio {
  SudoAudio._();

  static final SudoAudio instance = SudoAudio._();

  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();

  bool _ready = false;
  String? _currentTrack;

  Future<void> init() async {
    if (_ready) return;
    await _music.setReleaseMode(ReleaseMode.loop);
    _ready = true;
  }

  void _applyVolumes() {
    final s = SudoSettings.instance;
    _music.setVolume((s.masterVol * s.musicVol * 0.8).clamp(0.0, 1.0));
  }

  Future<void> playMusic(String asset) async {
    if (!_ready) return;
    final s = SudoSettings.instance;
    if (!s.musicOn) return;
    if (_currentTrack == asset) return;
    _currentTrack = asset;
    try {
      _applyVolumes();
      await _music.play(AssetSource(asset));
    } catch (_) {
      _currentTrack = null;
    }
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _music.stop();
    } catch (_) {}
  }

  /// Re-apply toggle/volume state (call after settings change).
  Future<void> refresh() async {
    final s = SudoSettings.instance;
    if (!s.musicOn) {
      await stopMusic();
    } else {
      _applyVolumes();
      if (_currentTrack != null) {
        final t = _currentTrack!;
        _currentTrack = null;
        await playMusic(t);
      }
    }
  }

  Future<void> _play(String asset, {double vol = 1.0}) async {
    if (!_ready) return;
    final s = SudoSettings.instance;
    if (!s.sfxOn) return;
    try {
      await _sfx.setVolume((s.masterVol * vol).clamp(0.0, 1.0));
      await _sfx.play(AssetSource(asset));
    } catch (_) {}
  }

  /// Wooden UI token tap.
  Future<void> click() => _play('audio/click.wav');

  /// Cell selection — paper tap.
  Future<void> paper() => _play('audio/paper.wav', vol: 0.8);

  /// Correct digit entry — sumi brush stroke.
  Future<void> brush() => _play('audio/brush.wav');

  /// Pencil note tick.
  Future<void> note() => _play('audio/note.wav', vol: 0.9);

  /// Eraser rub.
  Future<void> erase() => _play('audio/erase.wav', vol: 0.9);

  /// Undo — brush lifted back.
  Future<void> undo() => _play('audio/undo.wav', vol: 0.9);

  /// Invalid move — dry brush scratch.
  Future<void> invalid() => _play('audio/invalid.wav', vol: 0.85);

  /// Hint — paper lantern chime.
  Future<void> hint() => _play('audio/hint.wav');

  /// Hanko stamp thump.
  Future<void> stamp() => _play('audio/stamp.wav');

  /// Puzzle start — paper unfurl.
  Future<void> start() => _play('audio/start.wav');

  /// Victory — hanko + pentatonic celebration.
  Future<void> win() => _play('audio/win.wav');

  /// Failure — quiet ink fade.
  Future<void> lose() => _play('audio/lose.wav');

  void dispose() {
    _sfx.dispose();
    _music.dispose();
  }
}
