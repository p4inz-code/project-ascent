"""Original music for Project Ascent, composed and rendered by code (numpy only, no samples, no outside material).

Thirteen loops: title, story, one per act (cinder, scrapyard, freezer, storm, forge, underworks, rift, core), boss,
endless and ending. Each track has its own key and mode, tempo, chord progression and instruments, built from the same
parts: a pad, a bass line, an arpeggio, a lead melody, drums, a noise "air" bed and a few sparse effects, brought in
section by section so a track grows over its loop and then thins out so that the loop point is seamless.

Seamless by construction: every layer is rendered with its release tails folded onto the start of the loop, and the
reverb, the filters and the noise beds are applied as CIRCULAR convolutions over the loop, so the last sample flows
into the first. Everything is seeded, so a track renders byte-identically every time.

    python tools/music_engine.py                  # all tracks -> audio/music/<name>.ogg
    python tools/music_engine.py cinder boss      # only these
    python tools/music_engine.py --check          # render short versions and print loudness and seam numbers
"""
import argparse
import math
import os
import subprocess
import sys
import tempfile
import wave
from shutil import which

import numpy as np

SR = 22050
TAIL_S = 3.0
TARGET_RMS_DB = -14.0     # every track is brought to this level, so the soundtrack never jumps between acts
PEAK_LIMIT = 0.89

SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11], "mixolydian": [0, 2, 4, 5, 7, 9, 10], "major": [0, 2, 4, 5, 7, 9, 11],
    "locrian": [0, 1, 3, 5, 6, 8, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11], "wholetone": [0, 2, 4, 6, 8, 10],
}
LAYER_GAIN = {"pad": 0.50, "bass": 0.80, "arp": 0.42, "lead": 0.55, "drums": 0.80, "air": 0.30, "fx": 0.50}
WET_LAYERS = ("pad", "arp", "lead", "fx")

# section mask per layer: 1 = plays in that quarter of the loop. The last bars always thin out (see _thin).
SECTIONS = {
    "pad": [1, 1, 1, 1], "bass": [1, 1, 1, 1], "air": [1, 1, 1, 1], "fx": [1, 1, 1, 1],
    "arp": [0, 1, 1, 1], "drums": [0, 1, 1, 1], "lead": [0, 0, 1, 1],
}

# name: spec. bars is the loop length in bars of 4 beats. prog lists the scale degree of each chord, one chord per
# chord_bars bars. Styles are described in the layer functions below.
TRACKS = {
    "title": dict(root=55, scale="dorian", bpm=84, bars=20, prog=[0, 5, 2, 6], pad="warm", bass="long", arp="pluck8",
                  lead="sparse", drums="none", air="wind", fx="stars", seed=11,
                  sections=dict(arp=[1, 1, 1, 1], lead=[0, 1, 1, 1])),
    "story": dict(root=45, scale="phrygian", bpm=72, bars=16, prog=[0, 1, 0, 6], chord_bars=2, pad="dark", bass="sub",
                  arp="glass", lead="sparse", drums="heart", air="rumble", fx="stars", seed=12,
                  sections=dict(arp=[0, 1, 1, 1], lead=[0, 0, 1, 1], drums=[0, 1, 1, 1])),
    "cinder": dict(root=50, scale="phrygian", bpm=108, bars=28, prog=[0, 0, 6, 5], pad="warm", bass="pulse8",
                   arp="sq16", lead="motif", drums="soft", air="rumble", fx="embers", seed=21),
    "scrapyard": dict(root=52, scale="minor", bpm=100, bars=28, prog=[0, 5, 6, 4], pad="dark", bass="walk",
                      arp="saw16", lead="motif", drums="break", air="hiss", fx="clank", seed=22),
    "freezer": dict(root=54, scale="dorian", bpm=84, bars=24, prog=[0, 3, 5, 4], pad="glass", bass="sub",
                    arp="glass", lead="sparse", drums="half", air="wind", fx="bells", seed=23),
    "storm": dict(root=57, scale="minor", bpm=128, bars=32, prog=[0, 5, 3, 4], pad="air", bass="drive16",
                  arp="saw16", lead="motif", drums="four", air="rain", fx="thunder", seed=24),
    "forge": dict(root=48, scale="harmonic", bpm=116, bars=28, prog=[0, 5, 4, 0], pad="dark", bass="walk",
                  arp="sq16", lead="brass", drums="forge", air="rumble", fx="anvil", seed=25),
    "underworks": dict(root=55, scale="minor", bpm=96, bars=28, prog=[0, 6, 5, 6], pad="air", bass="sub",
                       arp="pluck8", lead="sparse", drums="half", air="steam", fx="steam", seed=26),
    "rift": dict(root=58, scale="wholetone", bpm=112, bars=28, prog=[0, 2, 4, 1], pad="glass", bass="offbeat",
                 arp="sq16", lead="motif", drums="break", air="hiss", fx="warp", seed=27),
    "core": dict(root=52, scale="locrian", bpm=100, bars=28, prog=[0, 1, 0, 4], pad="dark", bass="walk",
                 arp="saw16", lead="brass", drums="heart", air="rumble", fx="heart", seed=28),
    "boss": dict(root=50, scale="harmonic", bpm=140, bars=28, prog=[0, 0, 5, 4], pad="dark", bass="drive16",
                 arp="saw16", lead="brass", drums="boss", air="hiss", fx="thunder", seed=31,
                 sections=dict(arp=[1, 1, 1, 1], drums=[1, 1, 1, 1], lead=[0, 1, 1, 1])),
    "endless": dict(root=55, scale="mixolydian", bpm=124, bars=32, prog=[0, 3, 4, 3], pad="air", bass="pulse8",
                    arp="sq16", lead="motif", drums="four", air="hiss", fx="stars", seed=32,
                    sections=dict(drums=[1, 1, 1, 1], arp=[1, 1, 1, 1], lead=[0, 1, 1, 1])),
    "ending": dict(root=48, scale="major", bpm=76, bars=20, prog=[0, 4, 5, 3], pad="warm", bass="long", arp="pluck8",
                   lead="sparse", drums="none", air="wind", fx="bells", seed=33,
                   sections=dict(arp=[1, 1, 1, 1], lead=[0, 1, 1, 1])),
}


# ---------------------------------------------------------------- small building blocks
def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def degree(scale, d):
    s = SCALES[scale]
    return s[d % len(s)] + 12 * (d // len(s))


def chord(spec, d, seventh=False):
    s = spec["scale"]
    ds = [d, d + 2, d + 4] + ([d + 6] if seventh else [])
    return [spec["root"] + degree(s, x) for x in ds]


def scale_notes(spec, lo, hi):
    """Every MIDI note of the track's scale between lo and hi."""
    pcs = {(spec["root"] + x) % 12 for x in SCALES[spec["scale"]]}
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def osc(kind, freq, n, pw=0.5, detune=0.0):
    t = np.arange(n, dtype=np.float64)
    ph = (t * (freq * 2.0 ** (detune / 1200.0)) / SR) % 1.0
    if kind == "saw":
        return 2.0 * ph - 1.0
    if kind == "square":
        return np.where(ph < pw, 1.0, -1.0)
    if kind == "tri":
        return 4.0 * np.abs(ph - 0.5) - 1.0
    return np.sin(2.0 * math.pi * ph)


def adsr(n, a, d, s, r):
    """n samples; attack a, decay d, sustain level s, release r (all in seconds; release fits inside n)."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    a = min(a, n)
    env = np.ones(n)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
    d = min(d, n - a)
    if d > 0:
        env[a:a + d] = np.linspace(1.0, s, d, endpoint=False)
    env[a + d:] = s
    r = min(r, n)
    if r > 0:
        env[n - r:] *= np.linspace(1.0, 0.0, r)
    return env


def fir_lp(x, fc, taps=97):
    k = np.sinc(2.0 * fc / SR * (np.arange(taps) - (taps - 1) / 2.0)) * np.hanning(taps)
    k /= k.sum()
    return np.convolve(x, k, mode="same")


def circular_filter(x, lo, hi, smooth=0.25):
    """Band-pass a loop-length signal by multiplying its spectrum, so it stays seamless. lo/hi in Hz."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    lo_s, hi_s = max(1.0, lo), hi
    mask = np.clip((f - lo_s * (1 - smooth)) / (lo_s * smooth + 1e-9), 0, 1) * np.clip((hi_s * (1 + smooth) - f) / (hi_s * smooth + 1e-9), 0, 1)
    return np.fft.irfft(spec * mask, n=len(x))


class Mix:
    """A stereo loop buffer of loop_n samples plus a tail that is folded back onto the start."""

    def __init__(self, loop_n, tail_n):
        self.loop_n, self.tail_n = loop_n, tail_n
        self.buf = np.zeros((loop_n + tail_n, 2))

    def add(self, start, sig, pan=0.0, gain=1.0):
        start = int(start)
        if start >= len(self.buf):
            return
        sig = sig[: len(self.buf) - start].copy()
        ramp = min(len(sig), int(0.002 * SR))      # 2 ms fade-in on everything: no clicks, also at the loop point
        if ramp > 0:
            sig[:ramp] *= np.linspace(0.0, 1.0, ramp)
        lg = gain * math.cos((pan + 1) * math.pi / 4)
        rg = gain * math.sin((pan + 1) * math.pi / 4)
        self.buf[start:start + len(sig), 0] += sig * lg
        self.buf[start:start + len(sig), 1] += sig * rg

    def folded(self):
        out = self.buf[: self.loop_n].copy()
        tail = self.buf[self.loop_n:]
        out[: len(tail)] += tail
        return out


def make_reverb(loop_n, decay=1.7, seed=5):
    rng = np.random.default_rng(seed)
    n = int(SR * decay * 1.6)
    t = np.arange(n) / SR
    irs = []
    for _ in range(2):
        ir = rng.standard_normal(n) * np.exp(-t / (decay / 3.0))
        ir = fir_lp(ir, 5200)
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))   # soft pre-delay onset
        ir /= np.sqrt((ir ** 2).sum()) + 1e-9
        irs.append(ir)
    return irs


def circ_reverb(stereo, irs, wet):
    n = len(stereo)
    out = np.zeros_like(stereo)
    for c in range(2):
        ir = np.zeros(n)
        ir[: len(irs[c])] = irs[c][:n]
        out[:, c] = np.fft.irfft(np.fft.rfft(stereo[:, c]) * np.fft.rfft(ir), n=n)
    return stereo * (1 - wet * 0.5) + out * wet


# ---------------------------------------------------------------- instruments
def note(kind, midi, dur_s, a=0.01, d=0.1, s=0.6, r=0.1, lp=None, detune=(0.0,), pw=0.5, sub=0.0):
    n = int(dur_s * SR) + int(r * SR)
    f = mtof(midi)
    sig = sum(osc(kind, f, n, pw, dt) for dt in detune) / len(detune)
    if sub:
        sig = sig + sub * osc("sine", f / 2.0, n)
    if lp:
        sig = fir_lp(sig, lp)
    return sig * adsr(n, a, d, s, r)


def kick(rng, tone=48.0, decay=9.0, length=0.35):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = tone + 120.0 * np.exp(-t * 30.0)
    ph = 2 * math.pi * np.cumsum(f) / SR
    return (np.sin(ph) * np.exp(-t * decay) + 0.25 * np.exp(-t * 90) * rng.standard_normal(n)) * 1.1


def snare(rng, tone=185.0):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = noise - fir_lp(noise, 1800)
    return noise * np.exp(-t * 20.0) * 0.8 + np.sin(2 * math.pi * tone * t) * np.exp(-t * 28.0) * 0.5


def hat(rng, open_=False, vol=1.0):
    n = int((0.22 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = noise - fir_lp(noise, 5500)
    return noise * np.exp(-t * (12.0 if open_ else 70.0)) * 0.45 * vol


def clap(rng):
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = fir_lp(noise - fir_lp(noise, 900), 5000)
    env = sum(np.exp(-np.maximum(t - o, 0) * 40.0) * (t >= o) for o in (0.0, 0.011, 0.022)) * np.exp(-t * 14)
    return noise * env * 0.7


def anvil(rng):
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    sig = sum(a * np.sin(2 * math.pi * f * t) * np.exp(-t * dc) for f, a, dc in
              ((510, 0.5, 6), (1033, 0.4, 9), (1476, 0.3, 12), (2570, 0.2, 16)))
    sig = sig + 0.5 * rng.standard_normal(n) * np.exp(-t * 120)
    return sig * 0.7


def bell(midi, length=2.2):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = mtof(midi)
    return sum(a * np.sin(2 * math.pi * f * r * t) * np.exp(-t * dc) for r, a, dc in
               ((1.0, 0.6, 1.6), (2.76, 0.35, 2.8), (5.4, 0.2, 4.5), (8.9, 0.1, 7.0))) * 0.5


# ---------------------------------------------------------------- the layers
def beat_n(spec):
    return SR * 60.0 / spec["bpm"]


def bar_n(spec):
    return beat_n(spec) * 4


def active(spec, layer, bar):
    secs = dict(SECTIONS)
    secs.update(spec.get("sections", {}))
    q = min(3, int(bar / (spec["bars"] / 4.0)))
    on = bool(secs[layer][q])
    # the last two bars breathe: the busy layers drop out so the loop returns to its quiet start
    if layer in ("drums", "lead", "arp") and bar >= spec["bars"] - 2:
        on = False
    return on


def chord_at(spec, bar):
    per = spec.get("chord_bars", 1)
    return spec["prog"][(bar // per) % len(spec["prog"])]


def render_pad(spec, mix, rng):
    style = spec["pad"]
    cfg = {"warm": ("saw", 1300, (-9, 0, 9), 0.9), "dark": ("saw", 650, (-6, 0, 6), 1.1),
           "glass": ("tri", 2600, (-4, 0, 4), 0.5), "air": ("square", 1500, (-8, 0, 8), 0.7)}[style]
    kind, lp, det, atk = cfg
    per = spec.get("chord_bars", 1)
    for bar in range(0, spec["bars"], per):
        d = chord_at(spec, bar)
        dur = per * bar_n(spec) / SR
        for i, m in enumerate(chord(spec, d)):
            sig = note(kind, m - (12 if style == "dark" and i == 0 else 0), dur, a=atk, d=0.4, s=0.8, r=1.2, lp=lp, detune=det, pw=0.3)
            mix.add(bar * bar_n(spec), sig, pan=(i - 1) * 0.45, gain=0.34)


def bass_pattern(style):
    """(step in 16ths within the bar, scale-degree offset from the chord root, length in 16ths)"""
    return {
        "long": [(0, 0, 16)],
        "sub": [(0, 0, 14), (8, 0, 6)],
        "pulse8": [(i * 2, 0 if i % 4 != 3 else 4, 2) for i in range(8)],
        "walk": [(0, 0, 3), (4, 0, 3), (6, 2, 2), (8, 4, 3), (12, 3, 2), (14, 2, 2)],
        "drive16": [(i, 0 if i % 8 not in (6, 7) else 4, 1) for i in range(16)],
        "offbeat": [(2, 0, 2), (6, 0, 2), (10, 4, 2), (14, 2, 2)],
    }[style]


def render_bass(spec, mix, rng):
    style = spec["bass"]
    step = beat_n(spec) / 4
    for bar in range(spec["bars"]):
        d = chord_at(spec, bar)
        for st, off, ln in bass_pattern(style):
            m = spec["root"] - 12 + degree(spec["scale"], d + off) - (12 if degree(spec["scale"], d + off) > 9 else 0)
            kind = "sine" if style in ("sub", "long") else "saw"
            sig = note(kind, m, ln * step / SR, a=0.006, d=0.12, s=0.7, r=0.05, lp=420 if kind == "saw" else None, sub=0.6 if kind == "saw" else 0.0)
            mix.add(bar * bar_n(spec) + st * step, sig, pan=0.0, gain=0.6 if style in ("sub", "long") else 0.45)


def render_arp(spec, mix, rng):
    style = spec["arp"]
    step = beat_n(spec) / 4
    kind, lp, ln, gap, oct_ = {
        "pluck8": ("tri", 3200, 3.0, 2, 12), "sq16": ("square", 2400, 1.6, 1, 12), "saw16": ("saw", 2200, 1.5, 1, 12),
        "glass": ("sine", 6000, 10.0, 4, 24),
    }[style]
    for bar in range(spec["bars"]):
        if not active(spec, "arp", bar):
            continue
        tones = chord(spec, chord_at(spec, bar), seventh=True)
        seq = [tones[0], tones[1], tones[2], tones[3], tones[2], tones[1]] if style != "glass" else tones
        for i in range(0, 16, gap):
            m = seq[(i // gap) % len(seq)] + oct_ + (12 if (i // gap) % 8 == 7 else 0)
            accent = 1.0 if i % 8 == 0 else 0.7
            sig = note(kind, m, ln * step / SR, a=0.004, d=0.09, s=0.25, r=0.08, lp=lp, pw=0.25 if kind == "square" else 0.5)
            mix.add(bar * bar_n(spec) + i * step, sig, pan=math.sin(i * 0.6) * 0.5, gain=0.4 * accent)


def make_motif(spec, rng):
    """A short seeded melody: (step in 16ths, scale note, length in 16ths), stepwise with a few leaps."""
    pool = scale_notes(spec, spec["root"] + 12, spec["root"] + 31)
    cur = rng.integers(2, len(pool) - 3)
    rhythm = [0, 3, 6, 8, 11, 14] if rng.random() < 0.5 else [0, 2, 4, 8, 10, 12]
    out = []
    for i, st in enumerate(rhythm):
        out.append((st, pool[cur], 3 if i % 2 == 0 else 2))
        cur += int(rng.choice([-2, -1, -1, 1, 1, 2, 3]))
        cur = int(np.clip(cur, 0, len(pool) - 1))
    return out


def render_lead(spec, mix, rng):
    style = spec["lead"]
    step = beat_n(spec) / 4
    motif = make_motif(spec, rng)
    kind, lp, atk, rel = {"sparse": ("tri", 2600, 0.06, 0.5), "motif": ("square", 2800, 0.01, 0.15), "brass": ("saw", 2000, 0.05, 0.2)}[style]
    for bar in range(spec["bars"]):
        if not active(spec, "lead", bar):
            continue
        if style == "sparse":
            tones = chord(spec, chord_at(spec, bar))
            for k, st in enumerate((0, 8)):
                m = tones[(k * 2 + bar) % 3] + 12
                sig = note(kind, m, 6.5 * step / SR, a=atk, d=0.2, s=0.7, r=rel, lp=lp, detune=(-5, 5))
                mix.add(bar * bar_n(spec) + st * step, sig, pan=0.2, gain=0.32)
            continue
        shift = (bar // 2) % 2
        for st, m, ln in motif:
            m2 = m + (2 if shift and st >= 8 else 0)
            sig = note(kind, m2, ln * step / SR, a=atk, d=0.1, s=0.7, r=rel, lp=lp, detune=(-6, 6), pw=0.5)
            mix.add(bar * bar_n(spec) + st * step, sig, pan=-0.2 if style == "brass" else 0.25, gain=0.3)


def render_drums(spec, mix, rng):
    style = spec["drums"]
    if style == "none":
        return
    step = beat_n(spec) / 4
    for bar in range(spec["bars"]):
        if not active(spec, "drums", bar):
            continue
        last_of_phrase = bar % 8 == 7
        for i in range(16):
            pos = bar * bar_n(spec) + i * step
            ev = []
            if style == "soft":
                if i in (0, 8): ev.append(("k", 0.8))
                if i % 4 == 2: ev.append(("h", 0.7))
                if i == 12: ev.append(("c", 0.5))
            elif style == "half":
                if i == 0: ev.append(("k", 0.9))
                if i == 8: ev.append(("s", 0.8))
                if i % 4 == 2: ev.append(("h", 0.5))
            elif style == "four":
                if i % 4 == 0: ev.append(("k", 0.9))
                if i in (4, 12): ev.append(("c", 0.7))
                if i % 4 == 2: ev.append(("o" if i == 14 else "h", 0.7))
            elif style == "break":
                if i in (0, 10): ev.append(("k", 0.9))
                if i in (4, 12): ev.append(("s", 0.8))
                if i % 2 == 0: ev.append(("h", 0.5 if i % 4 else 0.7))
                if i == 7 and rng.random() < 0.6: ev.append(("k", 0.5))
            elif style == "forge":
                if i in (0, 8): ev.append(("k", 0.9))
                if i in (4, 12): ev.append(("a", 0.8))
                if i % 4 == 2: ev.append(("h", 0.45))
            elif style == "heart":
                if i == 0: ev.append(("k", 0.95))
                if i == 3: ev.append(("k", 0.55))
                if i == 10 and bar % 2: ev.append(("h", 0.5))
            elif style == "boss":
                if i in (0, 3, 6, 10, 12): ev.append(("k", 0.9))
                if i in (4, 12): ev.append(("s", 0.85))
                if i % 2 == 0: ev.append(("h", 0.5))
                if last_of_phrase and i >= 12: ev.append(("s", 0.45 + 0.1 * (i - 12)))
            for kind, v in ev:
                sig = {"k": lambda: kick(rng, decay=7.0 if style == "heart" else 9.0, tone=42.0 if style == "heart" else 48.0),
                       "s": lambda: snare(rng), "h": lambda: hat(rng, False, 1.0), "o": lambda: hat(rng, True, 1.0),
                       "c": lambda: clap(rng), "a": lambda: anvil(rng)}[kind]()
                mix.add(pos, sig, pan={"k": 0.0, "s": 0.05, "h": 0.35, "o": 0.35, "c": -0.1, "a": -0.2}[kind], gain=v)


def render_air(spec, mix, rng):
    style = spec["air"]
    n = mix.loop_n
    noise = rng.standard_normal(n)
    lo, hi, amp, lfo_cycles = {"wind": (300, 1800, 0.35, 5), "rain": (2500, 9000, 0.30, 7), "hiss": (3500, 9500, 0.18, 4),
                               "rumble": (35, 180, 0.9, 3), "steam": (1500, 6500, 0.30, 9)}[style]
    bed = circular_filter(noise, lo, hi)
    bed /= np.abs(bed).max() + 1e-9
    t = np.arange(n) / n
    env = 0.65 + 0.35 * np.sin(2 * math.pi * lfo_cycles * t + 1.3)
    bed *= env * amp
    st = np.stack([bed, np.roll(bed, 311)], axis=1)
    mix.buf[:n] += st * 0.5


def render_fx(spec, mix, rng):
    style = spec["fx"]
    n_bars = spec["bars"]
    for bar in range(0, n_bars, 2):
        pos = bar * bar_n(spec)
        if style == "stars":
            for _ in range(2):
                m = int(rng.choice(scale_notes(spec, 84, 100)))
                mix.add(pos + rng.random() * bar_n(spec), note("sine", m, 0.4, a=0.005, d=0.3, s=0.0, r=0.6), pan=rng.uniform(-0.8, 0.8), gain=0.25)
        elif style == "embers":
            for _ in range(3):
                m = int(rng.choice(scale_notes(spec, 88, 100)))
                mix.add(pos + rng.random() * 2 * bar_n(spec), note("tri", m, 0.06, a=0.001, d=0.05, s=0.0, r=0.2), pan=rng.uniform(-0.8, 0.8), gain=0.2)
        elif style == "bells" and bar % 4 == 0:
            m = int(rng.choice(scale_notes(spec, 72, 90)))
            mix.add(pos + rng.random() * bar_n(spec), bell(m), pan=rng.uniform(-0.6, 0.6), gain=0.4)
        elif style == "thunder" and bar % 8 == 4:
            n = int(2.4 * SR)
            t = np.arange(n) / SR
            rumble = fir_lp(rng.standard_normal(n), 160) * np.exp(-t * 1.5) * np.minimum(t * 40, 1)
            mix.add(pos, rumble * 4.0, pan=rng.uniform(-0.5, 0.5), gain=0.5)
        elif style == "anvil" and bar % 4 == 2:
            mix.add(pos + beat_n(spec) * 2, anvil(rng), pan=0.3, gain=0.35)
        elif style == "clank" and bar % 2 == 1:
            mix.add(pos + beat_n(spec) * (1 + 2 * rng.integers(0, 2)), anvil(rng)[: int(0.3 * SR)], pan=rng.uniform(-0.7, 0.7), gain=0.25)
        elif style == "steam" and bar % 2 == 0:
            n = int(0.9 * SR)
            t = np.arange(n) / SR
            s = rng.standard_normal(n)
            s = fir_lp(s - fir_lp(s, 1500), 7000) * np.exp(-t * 3.0) * np.minimum(t * 60, 1)
            mix.add(pos + rng.random() * bar_n(spec), s, pan=rng.uniform(-0.8, 0.8), gain=0.5)
        elif style == "warp" and bar % 4 == 0:
            n = int(1.6 * SR)
            t = np.arange(n) / SR
            f = 300 * 2.0 ** (rng.choice([-1, 1]) * t * 1.5)
            sig = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.sin(math.pi * t / t[-1]) ** 2
            mix.add(pos, sig * 0.5, pan=rng.uniform(-0.7, 0.7), gain=0.35)
        elif style == "heart" and bar % 2 == 0:
            mix.add(pos + beat_n(spec) * 2, kick(rng, tone=38, decay=7.0, length=0.5), pan=0.0, gain=0.5)


LAYER_FUNCS = {"pad": render_pad, "bass": render_bass, "arp": render_arp, "lead": render_lead, "drums": render_drums,
               "air": render_air, "fx": render_fx}


# ---------------------------------------------------------------- render
def render_layers(name, bars=None):
    """The track's spec and each layer on its own (stereo loops of the same length), before mixing."""
    spec = dict(TRACKS[name])
    if bars:
        spec["bars"] = bars
    loop_n = int(round(bar_n(spec) * spec["bars"]))
    tail_n = int(TAIL_S * SR)
    layers = {}
    for layer, fn in LAYER_FUNCS.items():
        m = Mix(loop_n, tail_n)
        fn(spec, m, np.random.default_rng(spec["seed"] * 100 + len(layers)))
        layers[layer] = m.folded()
    return spec, layers


def render(name, bars=None):
    """One track as a seamless stereo loop (float array, loop_n x 2) with a normalised level."""
    spec, layers = render_layers(name, bars)
    loop_n = len(layers["pad"])
    irs = make_reverb(loop_n, seed=spec["seed"])
    dry = sum(layers[l] * LAYER_GAIN[l] for l in layers if l not in WET_LAYERS)
    wet = sum(layers[l] * LAYER_GAIN[l] for l in layers if l in WET_LAYERS)
    out = dry + circ_reverb(wet, irs, 0.55)
    # Even loudness across every track (the old loop sat at -13.4 dB RMS): scale to the target, soft-limit the peaks,
    # and repeat so the limiter does not pull the level below the target.
    for _ in range(4):
        rms = float(np.sqrt((out ** 2).mean())) + 1e-9
        out = out * (10 ** (TARGET_RMS_DB / 20.0) / rms)
        out = np.tanh(out * 1.1) / 1.1
    out *= min(1.0, PEAK_LIMIT / (np.abs(out).max() + 1e-9))
    return out.astype(np.float32)


def stats(x):
    rms = float(np.sqrt((x.astype(np.float64) ** 2).mean()))
    seam = float(np.abs(x[0] - x[-1]).max())
    neighbour = float(np.median(np.abs(np.diff(x, axis=0))).max()) + 1e-9
    return {"seconds": len(x) / SR, "peak": float(np.abs(x).max()), "rms_db": 20 * math.log10(rms + 1e-9),
            "seam_ratio": seam / neighbour}


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tracks", nargs="*")
    ap.add_argument("--check", action="store_true", help="render 8-bar versions and print loudness and seam numbers")
    ap.add_argument("--out", default=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music")))
    args = ap.parse_args()
    names = args.tracks or list(TRACKS)
    if args.check:
        for n in names:
            s = stats(render(n, bars=8))
            print("%-10s %5.1fs peak %.2f rms %.1f dB seam %.2f" % (n, s["seconds"], s["peak"], s["rms_db"], s["seam_ratio"]))
        return 0
    if not which("ffmpeg"):
        print("ffmpeg not found: cannot encode Ogg Vorbis", file=sys.stderr)
        return 1
    os.makedirs(args.out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for n in names:
            x = render(n)
            wav = os.path.join(tmp, n + ".wav")
            write_wav(wav, x)
            ogg = os.path.join(args.out, n + ".ogg")
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", ogg], check=True)
            s = stats(x)
            print("wrote %-10s %5.1fs  %4d KB  rms %.1f dB  seam %.2f" % (n + ".ogg", s["seconds"], os.path.getsize(ogg) // 1024, s["rms_db"], s["seam_ratio"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
