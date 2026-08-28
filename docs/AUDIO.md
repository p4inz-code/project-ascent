# Project Ascent — Audio Provenance & Validation

This document records where every audio asset in Project Ascent comes from and
how it was validated. It exists so anyone can confirm that no copyrighted or
third-party sample was used: **all audio is procedurally synthesized from pure
math** and is original work of the project.

## Generation

`tools/generate_audio.py` is a self-contained, idempotent Python script (stdlib
+ NumPy only). It builds every stream from first principles — sine waves,
filtered noise, envelopes, and exponential decay curves — writes lossless WAV
files, and (where ffmpeg/libvorbis is available) encodes the music to Ogg
Vorbis. Running it twice reproduces byte-identical assets because every random
stream uses a hard-coded seed.

Assets under `audio/`:

- `audio/music/music_loop.ogg` — 16 s seamless music loop, 22050 Hz stereo,
  62 KB. The canonical build source `audio/music/music_loop.wav` (1.4 MB PCM) is
  gitignored along with its `.import`; the OGG is the shipped payload.
- `audio/sfx/*.wav` — ten one-shot effects (jump, land, wallslide, walljump,
  dash, death, respawn, goal, ui, restart), each 12–53 KB.

## Provenance table

| Asset | Synthesized from | Notes |
|---|---|---|
| `music_loop.ogg` | layered detuned sines + slow filtered-noise pad, seeded pseudorandom accents | elective harmonic movement; quiet, atmospheric, minor; fused crossfaded endpoints for a seamless loop |
| `jump.wav` | sine pitch sweep up + soft click | short, bright |
| `land.wav` | filtered noise burst + low thump | volume scaled by fall speed at runtime |
| `wallslide.wav` | loop-seamless band-pass hermit noise + 70 Hz rumble | played as a looping hiss while sliding |
| `walljump.wav` | noise whoosh + upward pitch sweep | distinct from a normal jump |
| `dash.wav` | fast filtered noise rush through a resonant sweep | one-shot |
| `death.wav` | descending pitch drop + glottal-stopped decay | fell below the kill plane |
| `respawn.wav` | soft rising swell | reserved; completes (goal) uses `goal` instead |
| `goal.wav` | two-note ascending chime, additive sines | goal completion |
| `ui.wav` | short muted blip | controls panel toggle |
| `restart.wav` | short mechanical two-step | manual R restart |

## Import / format decisions

- SFX WAV imports are set to **PCM** (`compress/mode=0`) rather than the default
  QOA-compressed format so one-shots decode instantly and losslessly; they route
  through a fixed round-robin pool and never allocate nodes per frame.
- Music is OGG Vorbis for a small payload (`AudioStreamOggVorbis.loop = true`).
- The wall-slide hiss stream is stored as a **loop-seamless one-shot** WAV. It is
  re-played on `finished` while sliding (a software loop) instead of relying on
  `AudioStreamWAV.LOOP_FORWARD`, which was observed to silently fail
  (`playing == false`) on this environment's audio backend. See
  `SESSION_HANDOFF.md → Audio Foundation`.

## Validation

Asset-level pass (NumPy + ffprobe):

- All ten SFX are non-silent (nonzero samples), 12–53 KB, 16-bit PCM mono 44100 Hz.
- Peaks below clipping: land was re-scaled ×0.62 and death ×0.55 to remove
  earlier clipping; music peak 0.839 (no clipping after OGG encode).
- `music_loop.ogg` duration verifies at ≈16.000 s with ffprobe.
- OGG encode stable: re-running the encode reproduces the loop.

Runtime pass (`tools/probe_audio.gd`, real window): 19/19 checks —
buses exist in order; default music (−20 dB) < sfx (−8 dB); autoplay gate
(no music before any input); music starts on first input; jump/land/dash/
wallslide (start + sustained re-arm past the one-shot)/walljump/restart/death/
goal all fire; the hiss stops after leaving the wall; volume keys lower/raise
buses; mute toggles the master; and the UI blip fires on the controls toggle.

Perceptual quality and balance (does it *sound* mixing, is the music too loud
relative to SFX on your speakers) cannot be verified from a headless/automated
harness — that remains a human playtest step.

## Licensing

No third-party audio, samples, fonts, or recordings are used. Every stream is
original procedural output of `tools/generate_audio.py`, so it carries only the
project's own (currently undecided) root license.
