import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Sudoku — all sounds synthesized in code as WAV
/// bytes, cached once. Stationery-craft palette: bamboo knocks, paper taps,
/// sumi brush strokes, pencil ticks, eraser rubs, a paper-lantern chime,
/// and the vermilion hanko stamp thump.
///
/// Reliability design (mirrors the exemplar):
/// - Music clips synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls can never
///   swallow a start or leave the player half-started — music is app-scoped
///   and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption resumes exactly
///   where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class SumiAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8; // master
  double musicVol = 0.65; // music fraction of master

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  SumiAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure({
    required bool musicOn,
    required bool sfxOn,
    required double volume,
    required double musicVol,
  }) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    this.volume = volume.clamp(0.0, 1.0);
    this.musicVol = musicVol.clamp(0.0, 1.0);
    _music.setVolume(musicOn ? this.volume * this.musicVol * 0.8 : 0.0);
    _sfx.setVolume(sfxOn ? this.volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02, double decayPow = 2.2}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, decayPow).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0,
      double attack = 0.02,
      double harmonics = 0.25,
      double decayPow = 2.2}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack, decayPow: decayPow) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Plucked-string-ish tone (koto flavor): bright attack, fast decay.
  List<double> _pluck(double freq, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final ph = 2 * pi * freq * t;
      out[i] = _env(i, n, attack: 0.004, decayPow: 3.0) *
          (sin(ph) +
              0.4 * sin(2 * ph) * exp(-t * 6) +
              0.2 * sin(3 * ph) * exp(-t * 10));
    }
    return out;
  }

  /// Breath noise (shakuhachi flavor) with slow swell.
  List<double> _breathPad(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      double v = 0;
      for (final f in freqs) {
        final vib = 1 + 0.004 * sin(2 * pi * 4.5 * t);
        v += sin(2 * pi * f * vib * t) + 0.25 * sin(2 * pi * f * 2 * vib * t);
      }
      v /= freqs.length * 1.25;
      final noise = _rand.nextDouble() * 2 - 1;
      lp = lp * 0.985 + noise * 0.015; // low-passed breath
      final swell = sin(pi * (i / n).clamp(0.0, 1.0));
      out[i] = (v * 0.8 + lp * 1.6) * (0.3 + 0.7 * swell);
    }
    return out;
  }

  List<double> _knock() {
    // Bamboo token knock.
    final n = (_rate * 0.13).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.9 * sin(2 * pi * 190 * t) * exp(-t * 32) +
              0.5 * sin(2 * pi * 380 * t) * exp(-t * 60) +
              0.2 * (_rand.nextDouble() * 2 - 1) * exp(-t * 130));
    }
    return out;
  }

  List<double> _paperTap() {
    // Soft paper tap for cell selection.
    final n = (_rate * 0.09).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final noise = _rand.nextDouble() * 2 - 1;
      lp = lp * 0.9 + noise * 0.1;
      out[i] = _env(i, n, attack: 0.003, decayPow: 3.5) *
          (lp * 1.4 + 0.4 * sin(2 * pi * 700 * t) * exp(-t * 80));
    }
    return out;
  }

  List<double> _brushStroke() {
    // Sumi brush: bristle sweep rising into a soft landing.
    final n = (_rate * 0.28).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = t / 0.28;
      final noise = _rand.nextDouble() * 2 - 1;
      lp = lp * (0.93 - 0.05 * f) + noise * (0.07 + 0.05 * f);
      out[i] = _env(i, n, attack: 0.25, decayPow: 1.6) * lp * 2.2;
    }
    return out;
  }

  List<double> _pencilTick() {
    // Pencil candidate tick.
    final n = (_rate * 0.07).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.002, decayPow: 4.0) *
          (0.7 * sin(2 * pi * 2400 * t) * exp(-t * 120) +
              0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 160));
    }
    return out;
  }

  List<double> _eraserRub() {
    // Eraser rub: banded noise, two strokes.
    final n = (_rate * 0.3).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final stroke = sin(pi * (t / 0.3).clamp(0.0, 1.0));
      final noise = _rand.nextDouble() * 2 - 1;
      lp = lp * 0.82 + noise * 0.18;
      out[i] = _env(i, n, attack: 0.08, decayPow: 1.4) * lp * 2.0 * stroke;
    }
    return out;
  }

  List<double> _dryScratch() {
    // Invalid move: dry brush scratch.
    final n = (_rate * 0.18).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.01, decayPow: 1.2) *
          ((_rand.nextDouble() * 2 - 1) * 0.5 +
              0.3 * sin(2 * pi * 160 * t));
    }
    return out;
  }

  List<double> _lanternChime() {
    // Paper-lantern hint chime: bell with slow decay.
    final n = (_rate * 0.7).round();
    final out = List<double>.filled(n, 0);
    for (final f in [880.0, 1320.5, 1760.0]) {
      final tone = _tone(f, 0.7, attack: 0.005, harmonics: 0.15, decayPow: 3.5);
      for (int i = 0; i < n && i < tone.length; i++) {
        out[i] += tone[i] * (f == 880.0 ? 0.6 : 0.2);
      }
    }
    return out;
  }

  List<double> _stampThump() {
    // Hanko stamp: deep paper thump.
    final n = (_rate * 0.22).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003, decayPow: 3.0) *
          (0.9 * sin(2 * pi * 95 * t) * exp(-t * 22) +
              0.4 * sin(2 * pi * 190 * t) * exp(-t * 40) +
              0.2 * (_rand.nextDouble() * 2 - 1) * exp(-t * 90));
    }
    return out;
  }

  List<double> _paperUnfurl() {
    // Puzzle start: paper sheet unfurling.
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = t / 0.5;
      final noise = _rand.nextDouble() * 2 - 1;
      lp = lp * (0.9 - 0.08 * f) + noise * (0.1 + 0.08 * f);
      out[i] = _env(i, n, attack: 0.3, decayPow: 1.8) * lp * 1.8;
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Koto-flavored pentatonic plucks over a soft drone, 14s loop.
        final drone = _breathPad([146.83, 220.0], 14.0);
        final plucks = [
          293.66, 329.63, 392.0, 440.0, 392.0, 329.63, 293.66, 246.94
        ];
        final n = (_rate * 14).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _pluck(plucks[k], 0.9);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.4;
          }
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Breath-pad chords, Am – F – C – G, 16s loop.
        final seq = [
          [220.0, 261.63, 329.63],
          [174.61, 220.0, 261.63],
          [261.63, 329.63, 392.0],
          [196.0, 246.94, 293.66],
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_breathPad(chord, 4.0));
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', _knock));
  Future<void> paper() => _play(_clip('paper', _paperTap));
  Future<void> brush() => _play(_clip('brush', _brushStroke));
  Future<void> note() => _play(_clip('note', _pencilTick));
  Future<void> erase() => _play(_clip('erase', _eraserRub));
  Future<void> undo() =>
      _play(_clip('undo', () => _tone(500, 0.18, freqEnd: 300)));
  Future<void> invalid() => _play(_clip('invalid', _dryScratch));
  Future<void> hint() => _play(_clip('hint', _lanternChime));
  Future<void> stamp() => _play(_clip('stamp', _stampThump));
  Future<void> start() => _play(_clip('start', _paperUnfurl));
  Future<void> win() async {
    await _play(_clip('win',
        () => _arp([523.25, 587.33, 659.25, 783.99, 1046.5], 0.18, 0.04)));
    await _play(_clip('stamp', _stampThump));
  }

  Future<void> lose() => _play(_clip(
      'lose', () => _arp([392.0, 349.23, 311.13, 261.63], 0.26, 0.05)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest
  /// request always wins; a start issued while an older one is in flight is
  /// never dropped. Re-requesting the current track just ensures audibility.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: only when the user turns music OFF.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
