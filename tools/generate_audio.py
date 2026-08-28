#!/usr/bin/env python3
"""Generate all of Project Ascent's audio assets procedurally.

Every asset is synthesized here (original work, no external sample, no third
party license involved) and written as 16-bit PCM WAV. The music loop is
additionally encoded to Ogg Vorbis by ffmpeg for a small payload size; the short
one-shots are kept as PCM WAV so they trigger instantly with no decode latency.

This script is the authoritative provenance record for the audio: because the
files are generated, their "source / license" is the generator itself plus the
engine features it relies on. See docs/AUDIO.md for the full provenance record.

Requirements: Python 3 with numpy (used only at build time, not at runtime) and
``ffmpeg`` on PATH for the Ogg Vorbis encode.

Usage:
    python tools/generate_audio.py [--out <project_root/audio>]

The script is idempotent: it regenerates the same bytes for the same inputs, so
a re-run reproduces byte-identical WAV files.
"""

import argparse
import math
import os
import subprocess
import sys

import numpy as np

MUSIC_SR = 22050.0
SFX_SR = 44100.0
MUSIC_BEATS = 32          # beats in the loop (120 BPM => 16.0 s)
MUSIC_LOOP_SECONDS = 16.0
MUSIC_BPM = 120.0
SEAM_FADE_SECONDS = 0.45  # global fade at both ends to guarantee a silent loop seam

STREAM = np.int16


def _write_wav(path: str, data: np.ndarray, sr: float) -> None:
    """Write a single/multi channel float array in [-1,1] to a PCM16 WAV."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype(STREAM)
    if pcm.ndim == 1:
        pcm = pcm.reshape(-1, 1)
    channels = pcm.shape[1]
    import wave
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(int(sr))
        w.writeframes(pcm.tobytes(order="C"))


# ---------------------------------------------------------------------------
# Music: a 16 s seamless cool/atmospheric pad loop ("drift").
# ---------------------------------------------------------------------------

def _t(music: bool, sec: float) -> np.ndarray:
    n = int(round((MUSIC_SR if music else SFX_SR) * sec))
    return np.linspace(0.0, sec, n, endpoint=False)


def _sine(freq: float, t: np.ndarray, phase: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * math.pi * freq * t + phase)


def _seam_fade(n: int, sr: float) -> np.ndarray:
    """Ramp to 0 at both ends so the loop point is silent."""
    f = np.ones(n)
    k = int(round(sr * SEAM_FADE_SECONDS))
    if k > 1:
        ramp = np.sin(np.linspace(0.0, math.pi, k) * 0.5)  # 0->1 smooth
        f[:k] *= ramp
        f[-k:] *= ramp[::-1]
    return f


def _music_stereo() -> np.ndarray:
    sr = MUSIC_SR
    n = int(round(sr * MUSIC_LOOP_SECONDS))
    t = np.linspace(0.0, MUSIC_LOOP_SECONDS, n, endpoint=False)
    dt = 1.0 / sr
    l = np.zeros(n)
    r = np.zeros(n)

    # --- deep drone (A1 + A2). Integer-cycle in the loop keeps it steady. ---
    drone_l = 0.10 * _sine(55.0, t) + 0.07 * _sine(110.0, t)
    drone_r = 0.10 * _sine(54.9, t, 0.4) + 0.07 * _sine(110.4, t, 0.8)

    # Very slow amplitude swell (2 cycles over the loop -> seamless). One
    # instance per channel slightly out of phase for movement.
    swell_l = 0.5 + 0.5 * np.sin(2.0 * math.pi * (2.0 / MUSIC_LOOP_SECONDS) * t)
    swell_r = 0.5 + 0.5 * np.sin(2.0 * math.pi * (2.0 / MUSIC_LOOP_SECONDS) * t - 1.2)
    l += drone_l * (0.7 + 0.3 * swell_l)
    r += drone_r * (0.7 + 0.3 * swell_r)

    # --- chord pad (A minor add 9): A3 C4 E4 B3, slow attack shimmer. ---
    pad_notes = [(220.0, 0.045), (261.63, 0.035), (329.63, 0.040), (246.94, 0.030)]
    # Detune each note slightly per channel for width.
    for freq, amp in pad_notes:
        vib = 1.0 + 0.0012 * np.sin(2.0 * math.pi * (4.0 / MUSIC_LOOP_SECONDS) * t)
        l += amp * _sine(freq, t, 0.2) * vib * swell_l
        r += amp * _sine(freq * 1.0015, t, 1.7) * vib * swell_r

    # --- air noise bed, very low level, for "space". ---
    rng = np.random.default_rng(2026)
    noise = rng.normal(0.0, 1.0, n)
    # Simple one-pole low pass to knock the harshness down.
    noise_lp = np.empty(n)
    a = 0.997
    acc = 0.0
    for i in range(n):
        acc = a * acc + (1.0 - a) * noise[i]
        noise_lp[i] = acc
    air = 0.02 * noise_lp
    l += air * swell_l
    r += air * swell_r

    # --- sub pulse on the beat (gentle energy during traversal). ---
    # One soft thump per beat, 120 BPM => 8 pulses in 16 s.
    beat = 60.0 / MUSIC_BPM          # 0.5 s
    pulse = np.zeros(n)
    for b in range(MUSIC_BEATS):
        start = int(round(b * beat * sr))
        end = min(n, int(round((b * beat + 0.35) * sr)))
        if start >= n:
            break
        seg_t = t[start:end] - t[start]
        env = np.sin(np.pi * seg_t / 0.35) ** 2
        pulse[start:end] += 0.055 * _sine(110.0, seg_t, 0.0) * env
    l += pulse
    r += pulse

    # --- high sparkle shimmer (sparse, soft). ---
    spark_t = [1.5, 4.75, 8.25, 11.75, 14.5]
    for ts in spark_t:
        start = int(round(ts * sr))
        dur = 1.3
        end = min(n, int(round((ts + dur) * sr)))
        if start >= n:
            continue
        seg_t = t[start:end] - t[start]
        env = np.sin(np.pi * seg_t / dur) ** 2
        l[start:end] += 0.016 * _sine(659.26, seg_t) * env
        r[start:end] += 0.016 * _sine(880.0, seg_t, 0.5) * env

    mix = np.stack([l, r], axis=1)
    mix *= 0.9
    # Normalize to a consistent loudness then apply the seam fade.
    peak = np.max(np.abs(mix)) or 1.0
    mix = mix / peak * 0.85
    mix *= _seam_fade(n, sr)[:, None]
    return mix


# ---------------------------------------------------------------------------
# SFX helpers (short one-shots, mono).
# ---------------------------------------------------------------------------

def _env_ar(n, sr, a, r, curve=2.0):
    """Attack/release envelope (0->1->0), exponential-ish."""
    t = np.linspace(0.0, n / sr, n, endpoint=False)
    a_n = max(1, int(round(a * sr)))
    r_n = max(1, int(round(r * sr)))
    env = np.ones(n)
    if a_n < n:
        env[:a_n] = (np.linspace(0.0, 1.0, a_n) ** curve)
    else:
        env[:] = np.linspace(0.0, 1.0, n) ** curve
    if r_n < n:
        env[-r_n:] *= (np.linspace(1.0, 0.0, r_n) ** curve)
    return env


def _fade_cos(n, a=0.004):
    f = np.ones(n)
    k = max(1, int(round(a * SFX_SR)))
    f[:k] = np.sin(np.linspace(0.0, math.pi, k) * 0.5)
    # avoid click on the tail by rely on natural decay; no forced tail fade.
    return f


def _sfx_jump():
    sr = SFX_SR
    dur = 0.16
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    f = np.linspace(300.0, 620.0, n)
    phase = 2.0 * math.pi * np.cumsum(f) / sr
    s = np.sin(phase) * _env_ar(n, sr, 0.004, 0.14)
    s += 0.5 * np.sin(phase * 2.0) * _env_ar(n, sr, 0.002, 0.05)
    return (s * 0.65 * _fade_cos(n)).astype(np.float64)


def _sfx_land():
    sr = SFX_SR
    dur = 0.14
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    thud = _sine(95.0, t) * _env_ar(n, sr, 0.002, 0.12, 1.0)
    thud += 0.5 * _sine(190.0, t) * _env_ar(n, sr, 0.002, 0.07, 1.0)
    rng = np.random.default_rng(1)
    noise = rng.normal(0.0, 1.0, n)
    # low-passed click for the contact.
    a = 0.86
    acc = 0.0
    lp = np.empty(n)
    for i in range(n):
        acc = a * acc + (1.0 - a) * noise[i]
        lp[i] = acc
    body = thud + 0.35 * lp * _env_ar(n, sr, 0.001, 0.04)
    return (body * 0.62 * _fade_cos(n)).astype(np.float64)


def _sfx_wallslide():
    """Continuous looping hiss + low rumble. Noise loops silently, so the
    AudioStreamPlayer can loop it with no seams."""
    sr = SFX_SR
    dur = 0.6
    n = int(round(sr * dur))
    rng = np.random.default_rng(7)
    noise = rng.normal(0.0, 1.0, n)
    # band pass feel: low pass then subtract heavily-low-passed (a simple hum).
    a = 0.90
    acc = 0.0
    hp = np.empty(n)
    lpass = np.empty(n)
    lacc = 0.0
    for i in range(n):
        lacc = 0.997 * lacc + 0.003 * noise[i]
        hp[i] = noise[i] - lacc
        acc = 0.90 * acc + 0.10 * hp[i]
        lpass[i] = acc
    rumble = _sine(70.0, np.linspace(0.0, dur, n, endpoint=False)) * 0.5
    s = lpass * 0.5 + rumble * 0.4
    return (s * 0.5).astype(np.float64)


def _sfx_walljump():
    sr = SFX_SR
    dur = 0.16
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    f = np.linspace(240.0, 520.0, n)
    phase = 2.0 * math.pi * np.cumsum(f) / sr
    s = np.sin(phase) * _env_ar(n, sr, 0.004, 0.13)
    s += 0.4 * np.sin(phase * 1.5) * _env_ar(n, sr, 0.002, 0.05)
    return (s * 0.7 * _fade_cos(n)).astype(np.float64)


def _sfx_dash():
    sr = SFX_SR
    dur = 0.22
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    rng = np.random.default_rng(11)
    noise = rng.normal(0.0, 1.0, n)
    # whoosh: high-passed noise with swelling then falling envelope + pitch rise.
    a = 0.86
    acc = 0.0
    lacc = 0.0
    hp = np.empty(n)
    for i in range(n):
        lacc = 0.995 * lacc + 0.005 * noise[i]
        acc = 0.86 * acc + 0.14 * noise[i]
        hp[i] = acc
    env = np.sin(np.pi * t / dur) ** 1.5
    whoosh = hp * env
    sweep_f = np.linspace(420.0, 900.0, n)
    ph = 2.0 * math.pi * np.cumsum(sweep_f) / sr
    tone = 0.5 * np.sin(ph) * env
    return ((whoosh * 0.9 + tone) * 0.6).astype(np.float64)


def _sfx_death():
    sr = SFX_SR
    dur = 0.42
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    f = np.linspace(520.0, 90.0, n)
    ph = 2.0 * math.pi * np.cumsum(f) / sr
    tone = np.sin(ph) * (np.sin(np.pi * t / dur) ** 1.4)
    rng = np.random.default_rng(13)
    noise = rng.normal(0.0, 1.0, n)
    a = 0.7
    acc = 0.0
    lp = np.empty(n)
    for i in range(n):
        acc = a * acc + (1.0 - a) * noise[i]
        lp[i] = acc
    impact = lp * _env_ar(n, sr, 0.002, 0.1, 1.0) * 0.5
    return ((tone * 0.8 + impact) * 0.55).astype(np.float64)


def _sfx_respawn():
    sr = SFX_SR
    dur = 0.3
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    s = (_sine(440.0, t) * 0.5 + _sine(660.0, t) * 0.4
         + _sine(880.0, t) * 0.25)
    s = s * (np.sin(np.pi * t / dur) ** 1.6)
    return (s * 0.5).astype(np.float64)


def _sfx_goal():
    sr = SFX_SR
    dur = 0.6
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    notes = [(523.25, 0.0), (659.26, 0.09), (783.99, 0.18), (1046.5, 0.27)]
    s = np.zeros(n)
    for freq, delay in notes:
        start = int(round(delay * sr))
        d = min(dur - delay, 0.5)
        seg_t = t[start:n] - t[start]
        m = n - start
        env = np.zeros(m)
        env[:] = np.sin(np.pi * np.linspace(0.0, d, m, endpoint=False) / d) ** 2
        s[start:] += 0.16 * _sine(freq, seg_t) * env
    s += 0.06 * _sine(1568.0, t) * np.sin(np.pi * t / dur) ** 2
    return (s * 0.9).astype(np.float64)


def _sfx_ui():
    sr = SFX_SR
    dur = 0.07
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    s = _sine(880.0, t) * (np.sin(np.pi * t / dur) ** 1.5)
    return (s * 0.4 * _fade_cos(n)).astype(np.float64)


def _sfx_restart():
    sr = SFX_SR
    dur = 0.18
    n = int(round(sr * dur))
    t = np.linspace(0.0, dur, n, endpoint=False)
    s = (_sine(392.0, t) * 0.6 + _sine(523.25, t) * 0.4) \
        * (np.sin(np.pi * t / dur) ** 1.5)
    return (s * 0.45).astype(np.float64)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

SFX_BUILDERS = {
    "jump": _sfx_jump,
    "land": _sfx_land,
    "wallslide": _sfx_wallslide,
    "walljump": _sfx_walljump,
    "dash": _sfx_dash,
    "death": _sfx_death,
    "respawn": _sfx_respawn,
    "goal": _sfx_goal,
    "ui": _sfx_ui,
    "restart": _sfx_restart,
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None,
                    help="Project root (defaults to the repo root next to tools)")
    args = ap.parse_args()

    if args.out:
        root = args.out
    else:
        root = os.path.normpath(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), ".."))
    sfx_dir = os.path.join(root, "audio", "sfx")
    music_dir = os.path.join(root, "audio", "music")

    for name, builder in SFX_BUILDERS.items():
        data = builder()
        path = os.path.join(sfx_dir, name + ".wav")
        _write_wav(path, data, SFX_SR)
        print("wrote", os.path.relpath(path, root))

    music_stereo = _music_stereo()
    music_wav = os.path.join(music_dir, "music_loop.wav")
    _write_wav(music_wav, music_stereo, MUSIC_SR)
    print("wrote", os.path.relpath(music_wav, root))

    # Encode the music to Ogg Vorbis for a small payload. Keep the WAV as the
    # canonical build source but it need not ship.
    music_ogg = os.path.join(music_dir, "music_loop.ogg")
    if shutil_which("ffmpeg"):
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-i", music_wav, "-c:a", "libvorbis", "-q:a", "3",
             music_ogg], check=True)
        print("wrote", os.path.relpath(music_ogg, root))
    else:
        print("ffmpeg not found; Ogg encode skipped (music_loop.ogg missing)",
              file=sys.stderr)
    return 0


def shutil_which(name: str):
    from shutil import which
    return which(name)


if __name__ == "__main__":
    sys.exit(main())
