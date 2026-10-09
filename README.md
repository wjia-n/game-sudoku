# Sudoku — Washi & Sumi Craft

A serene, physical-craft Sudoku for Android. Japanese stationery-craft
(*bunbōgu*) art direction: warm washi paper grid, hand-inked sumi
brush-stroke cell borders, pencil-draft candidate notes vs brushed final
digits, bamboo number-pad tokens, and a vermilion hanko stamp on victory.

Package: `com.gameswajiha.sudoku`

## Features

- **Engine-owned game state** (`lib/engine/sudoku_engine.dart`): puzzle
  generation with guaranteed unique solutions, symmetric-pair clue removal
  with exact given counts, difficulty calibration for Hard/Expert, notes
  mode, hints (limited, locked), mistake tracking, strict mode, undo that
  can never erase a hint, win/fail detection. Engine-owned timer +
  watchdog — stuck states are impossible by construction.
- **5 difficulties** (Novice 45, Easy 38, Medium 32, Hard 28, Expert 24
  givens) + **Daily puzzle** (one shared seeded puzzle per day, streak
  tracking) + **Timed / Relaxed** modes.
- **Animations everywhere**: number entry pop, conflict shake, hint reveal,
  related/same-digit highlighting, hand-drawn error circles, paper-confetti
  win celebration with hanko stamp press.
- **Synthesized audio** (no asset files): bamboo knocks, paper taps, sumi
  brush strokes, pencil ticks, eraser rubs, lantern chime, hanko thump,
  koto/breath-pad music. App-scoped music that never silently dies,
  lifecycle pause/resume, full toggles + volumes.
- **14 washi themes** (4 free + 10 PRO + custom theme creator), **9 digit
  styles**, **6 grid accents** — all persisted.
- **Persisted profile** (renameable), per-difficulty stats (solved, best
  time, streaks, mistakes), daily completions.
- **Sudoku PRO** via `in_app_purchase`: `sudokupro` (one-time), `sudokucoffee`
  / `sudokuchocolate` (tips). Free-vs-Pro comparison screen; graceful
  "available after store setup" state until products exist in Play Console.

## Rules

See `~/workspace/game-factory/stitch-batch5/sudoku/RULES.md` — the
authoritative rules document. The engine enforces it; if they ever diverge,
the implementation is fixed, not the rules.

## Build

```sh
flutter pub get
flutter analyze
flutter build appbundle --release
```

CI (`.github/workflows/build.yml`) builds signed APK + AAB on tag push.
