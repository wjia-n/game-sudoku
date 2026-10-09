#!/usr/bin/env python3
"""Generate all audio for Sudoku (Japanese stationery craft identity).

Physical, crafted sounds: wooden token taps, sumi brush strokes on washi
paper, hanko stamp thumps, eraser rubs, bamboo chimes. Music loops are
calm pentatonic shakuhachi/koto-flavored drones — meditative, no synths
that read as electronic. 44.1kHz mono 16-bit WAV.
"""
import math
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   'assets', 'audio')
os.makedirs(OUT, exist_ok=True)

rng = np.random.default_rng(42)


def save(name, sig):
    sig = np.clip(sig, -1, 1)
    sig = (sig * 0.78 * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(sig.tobytes())
    print('wrote', name, f'{len(sig) / SR:.2f}s')


def env_ad(n, a, d, peak=1.0):
    e = np.ones(n)
    na = max(1, int(a * SR))
    nd = max(1, int(d * SR))
    e[:na] = np.linspace(0, 1, na)
    if nd >= n:
        e *= np.linspace(1, 0, n)
    else:
        e[n - nd:] = np.linspace(1, 0, nd)
    return e * peak


def tone(freq, dur, peak=0.7, attack=0.004, harmonics=(1.0, 0.35, 0.12)):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for i, h in enumerate(harmonics):
        sig += h * np.sin(2 * math.pi * freq * (i + 1) * t)
    sig *= env_ad(n, attack, dur - attack, peak)
    return sig


def lowpass(sig, alpha=0.06):
    """Simple one-pole lowpass for paper/brush body."""
    y = np.zeros_like(sig)
    acc = 0.0
    for i, x in enumerate(sig):
        acc += alpha * (x - acc)
        y[i] = acc
    return y


def wood_knock(freq=190.0, dur=0.12, peak=0.9):
    """Aged bamboo / wooden token tap."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * math.pi * freq * t) * np.exp(-t * 32)
    body += 0.4 * np.sin(2 * math.pi * freq * 2.7 * t) * np.exp(-t * 45)
    snap = rng.standard_normal(n) * np.exp(-t * 300) * 0.4
    return (body + snap) * peak


def paper_rustle(dur=0.25, peak=0.5):
    """Dry washi paper rustle: band-ish filtered noise burst."""
    n = int(dur * SR)
    noise = rng.standard_normal(n)
    sig = lowpass(noise, 0.35) - 0.4 * lowpass(noise, 0.04)
    return sig * env_ad(n, 0.01, dur - 0.01, peak)


def brush_stroke(dur=0.22, peak=0.55):
    """Sumi brush pressed and drawn across paper."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # sweeping pressure envelope: press, draw, lift
    press = np.sin(math.pi * np.clip(t / dur, 0, 1)) ** 1.5
    sig = lowpass(noise, 0.09) * press
    # slight tonal whistling of the brush hairs
    sig += 0.08 * np.sin(2 * math.pi * 900 * t) * press * np.exp(-t * 6)
    return sig * peak


def stamp_thump(peak=0.95):
    """Hanko seal pressed into paper: low thud + breath."""
    dur = 0.3
    n = int(dur * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * math.pi * 82 * t) * np.exp(-t * 26)
    thud += 0.5 * np.sin(2 * math.pi * 160 * t) * np.exp(-t * 40)
    breath = rng.standard_normal(n) * np.exp(-t * 120) * 0.18
    return (thud + breath) * peak


def mix(*sigs):
    """Pad all signals to the longest and sum them."""
    n = max(len(s) for s in sigs)
    out = np.zeros(n)
    for s in sigs:
        out[:len(s)] += s
    return out


def seq(notes, note_dur, gap=0.0, peak=0.6, harm=(1.0, 0.4, 0.15)):
    total = int((note_dur + gap) * len(notes) * SR)
    sig = np.zeros(total)
    for i, f in enumerate(notes):
        t = tone(f, note_dur, peak, harmonics=harm)
        s = int(i * (note_dur + gap) * SR)
        sig[s:s + len(t)] += t
    return sig


# --- SFX -------------------------------------------------------------------
# click: wooden UI token tap
save('click.wav', wood_knock(210, 0.1, 0.8))

# paper: soft cell selection tap (paper + faint wood)
save('paper.wav', mix(paper_rustle(0.12, 0.5), 0.5 * wood_knock(320, 0.06, 0.4)))

# brush: digit entry — ink brush stroke on washi
save('brush.wav', mix(brush_stroke(0.2, 0.6), 0.35 * wood_knock(420, 0.05, 0.3)))

# note: pencil tick — short dry tick
n = int(0.05 * SR)
t = np.arange(n) / SR
pencil = rng.standard_normal(n) * np.exp(-t * 420) * 0.7
save('note.wav', pencil)

# erase: eraser rub across paper
n = int(0.3 * SR)
t = np.arange(n) / SR
noise = rng.standard_normal(n)
rub = lowpass(noise, 0.22) * (np.sin(math.pi * np.clip(t / 0.3, 0, 1)) ** 0.7)
save('erase.wav', rub * 0.55)

# undo: brush lifted backwards (reversed stroke)
save('undo.wav', brush_stroke(0.16, 0.5)[::-1].copy())

# invalid: dry brush scratch — rejected move
n = int(0.16 * SR)
t = np.arange(n) / SR
noise = rng.standard_normal(n)
scratch = lowpass(noise, 0.5) * env_ad(n, 0.005, 0.15, 1.0)
scratch += 0.25 * np.sin(2 * math.pi * 240 * t) * env_ad(n, 0.005, 0.15, 1.0)
save('invalid.wav', scratch * 0.6)

# hint: paper lantern chime — soft wooden wind chime
save('hint.wav', mix(wood_knock(660, 0.5, 0.55), 0.6 * wood_knock(990, 0.7, 0.4)))

# stamp: hanko completion thump
save('stamp.wav', stamp_thump())

# start: puzzle unfurls — paper + rising brush sweep
start = paper_rustle(0.35, 0.45)
start = mix(start, 0.7 * brush_stroke(0.3, 0.4))
save('start.wav', mix(start, 0.5 * seq([392.0, 523.25], 0.18, 0.05, 0.4)))

# win: victory — hanko stamp then pentatonic celebration (D F G A C)
win = np.zeros(int(2.6 * SR))
stamp = stamp_thump()
win[:len(stamp)] += stamp
mel = seq([587.33, 698.46, 784.0, 880.0, 1046.5, 1174.66],
          0.28, 0.02, 0.5, harm=(1.0, 0.3, 0.1))
off = int(0.35 * SR)
win[off:off + len(mel)] += mel * 0.8
save('win.wav', win)

# lose: quiet ink fade — descending soft strokes
lose = mix(seq([440.0, 392.0, 329.63], 0.5, 0.05, 0.45, harm=(1.0, 0.25, 0.08)),
          0.4 * brush_stroke(1.4, 0.35))
save('lose.wav', lose)

# --- Music loops -------------------------------------------------------------
# Pentatonic palette: D major-ish / A minor pentatonic (shakuhachi/koto flavor)
PENTA = [293.66, 329.63, 369.99, 440.0, 493.88, 587.33, 659.25]


def airy_pad(freqs, dur, peak=0.16):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for f in freqs:
        sig += np.sin(2 * math.pi * f * t + rng.uniform(0, 6.28)) * 0.5
        sig += np.sin(2 * math.pi * f * 2.003 * t) * 0.12
    # slow breathing amplitude
    breath = 0.7 + 0.3 * np.sin(2 * math.pi * 0.12 * t)
    sig *= breath
    sig *= env_ad(n, 2.0, 2.0, peak / max(1, len(freqs)))
    return sig


def koto_pluck(freq, dur=1.6, peak=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * math.pi * freq * t) * np.exp(-t * 4.5)
    sig += 0.5 * np.sin(2 * math.pi * freq * 2.0 * t) * np.exp(-t * 6)
    snap = rng.standard_normal(n) * np.exp(-t * 500) * 0.15
    return (sig + snap) * env_ad(n, 0.003, dur - 0.003, peak)


# menu: 16s calm loop — airy drone + sparse plucks
DUR = 16.0
menu = airy_pad([146.83, 220.0, 293.66], DUR, peak=0.5)
menu += airy_pad([293.66, 369.99, 440.0], DUR, peak=0.3)
pluck_times = [1.5, 5.0, 9.0, 12.5]
pluck_notes = [587.33, 493.88, 659.25, 440.0]
for pt, pn in zip(pluck_times, pluck_notes):
    pl = koto_pluck(pn, 2.2, 0.22)
    s = int(pt * SR)
    menu[s:s + len(pl)] += pl
# loop-safe crossfade of the last 2s into the first 2s
n2 = int(2.0 * SR)
tail = menu[-n2:].copy()
menu[:n2] = menu[:n2] * 0.5 + tail * 0.5
save('music_menu.wav', menu)

# game: 24s loop — slightly deeper drone + gentle koto pattern
DUR = 24.0
game = airy_pad([130.81, 196.0, 261.63], DUR, peak=0.45)
game += airy_pad([261.63, 329.63, 392.0], DUR, peak=0.25)
pattern = [(2.0, 440.0), (4.5, 392.0), (7.0, 329.63), (10.0, 440.0),
           (13.5, 493.88), (16.0, 440.0), (19.0, 329.63), (21.5, 392.0)]
for pt, pn in pattern:
    pl = koto_pluck(pn, 2.6, 0.18)
    s = int(pt * SR)
    seg = game[s:s + len(pl)]
    game[s:s + len(seg)] += pl[:len(seg)]
n2 = int(2.0 * SR)
tail = game[-n2:].copy()
game[:n2] = game[:n2] * 0.5 + tail * 0.5
save('music_game.wav', game)

print('done')
