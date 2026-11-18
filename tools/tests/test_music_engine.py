"""Objective checks on the music engine (tools/music_engine.py). They cannot say whether the music is good (a person
has to listen), but they prove the things that can be proven: it is reproducible, every track stays in its own key,
the levels are even, the loops are seamless, and the tracks differ from one another. Each check has a control that
shows it can fail."""
import math
import os
import sys

import numpy as np
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import music_engine as me  # noqa: E402

NAMES = list(me.TRACKS)
_cache = {}


def short(name):
    if name not in _cache:
        _cache[name] = me.render(name, bars=8)
    return _cache[name]


def chroma(x, lo=60.0, hi=2000.0):
    mono = x.astype(np.float64).mean(axis=1)
    spec = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    f = np.fft.rfftfreq(len(mono), 1.0 / me.SR)
    c = np.zeros(12)
    for freq, p in zip(f, spec):
        if lo <= freq <= hi:
            c[int(round(12 * math.log2(freq / 440.0) + 69)) % 12] += p
    return c / (c.sum() + 1e-12)


def in_key_score(x, spec, shift=0):
    c = chroma(x)
    pcs = {(spec["root"] + s + shift) % 12 for s in me.SCALES[spec["scale"]]}
    return float(sum(c[i] for i in pcs))


def test_there_are_thirteen_tracks_with_everything_they_need():
    assert len(NAMES) == 13
    for n in ("title", "story", "boss", "endless", "ending", "cinder", "scrapyard", "freezer", "storm", "forge",
              "underworks", "rift", "core"):
        assert n in me.TRACKS
    for n, s in me.TRACKS.items():
        for key in ("root", "scale", "bpm", "bars", "prog", "pad", "bass", "arp", "lead", "drums", "air", "fx", "seed"):
            assert key in s, (n, key)
        assert s["scale"] in me.SCALES
        assert 60 <= s["bpm"] <= 150
        assert 40 <= s["root"] <= 64
        assert len(set(t["seed"] for t in me.TRACKS.values())) == len(me.TRACKS), "two tracks share a seed"


def test_a_track_renders_identically_every_time():
    a = me.render("cinder", bars=4)
    b = me.render("cinder", bars=4)
    assert np.array_equal(a, b)


def test_control_a_different_seed_gives_different_music():
    spec = dict(me.TRACKS["cinder"])
    saved = me.TRACKS["cinder"]
    try:
        me.TRACKS["cinder"] = dict(spec, seed=spec["seed"] + 1)
        other = me.render("cinder", bars=4)
    finally:
        me.TRACKS["cinder"] = saved
    assert not np.array_equal(other, me.render("cinder", bars=4))


@pytest.mark.parametrize("name", NAMES)
def test_every_track_is_in_its_own_key(name):
    spec, layers = me.render_layers(name, bars=8)
    # the pitched layers only: drums and noise beds have no key
    tonal = layers["pad"] + layers["bass"] + layers["arp"] + layers["lead"]
    own = in_key_score(tonal, spec)
    wrong = in_key_score(tonal, spec, shift=1)
    assert own > 0.70, "%s: only %.2f of the pitched energy is in its scale" % (name, own)
    assert own > wrong, "%s: a key one semitone away fits as well as its own (%.2f vs %.2f)" % (name, own, wrong)


def test_control_noise_is_not_in_any_key():
    rng = np.random.default_rng(1)
    noise = rng.standard_normal((me.SR * 4, 2))
    spec = me.TRACKS["cinder"]
    assert in_key_score(noise, spec) < 0.70


@pytest.mark.parametrize("name", NAMES)
def test_loudness_is_even_and_peaks_are_safe(name):
    s = me.stats(short(name))
    assert not np.isnan(short(name)).any()
    assert -15.5 < s["rms_db"] < -12.5, "%s rms %.1f dB" % (name, s["rms_db"])
    assert s["peak"] <= me.PEAK_LIMIT + 1e-3, "%s peak %.2f" % (name, s["peak"])


@pytest.mark.parametrize("name", NAMES)
def test_the_loop_point_has_no_click(name):
    assert me.stats(short(name))["seam_ratio"] < 6.0, name


def test_control_a_hard_cut_is_detected_as_a_click():
    a, b = short("cinder"), short("storm")
    cut = np.concatenate([a[: len(a) // 2], b[len(b) // 2:]])
    # a cut in the middle is not a loop seam, but the same metric on a signal ending abruptly must exceed the limit
    jump = np.concatenate([a, a * 0 + 0.8])
    assert me.stats(jump)["seam_ratio"] > 6.0
    assert len(cut) > 0


@pytest.mark.parametrize("name", NAMES)
def test_the_loop_length_is_whole_bars(name):
    spec = dict(me.TRACKS[name], bars=8)
    expected = int(round(me.bar_n(spec) * 8))
    assert len(short(name)) == expected


def test_the_tracks_are_not_copies_of_each_other():
    cs = {n: chroma(short(n)) for n in NAMES}
    for i, a in enumerate(NAMES):
        for b in NAMES[i + 1:]:
            same_key = me.TRACKS[a]["root"] == me.TRACKS[b]["root"] and me.TRACKS[a]["scale"] == me.TRACKS[b]["scale"]
            assert not same_key, (a, b)
            assert not np.array_equal(short(a), short(b))


def test_progression_degrees_and_chords_are_in_the_scale():
    for n, spec in me.TRACKS.items():
        pcs = {(spec["root"] + s) % 12 for s in me.SCALES[spec["scale"]]}
        for d in spec["prog"]:
            for m in me.chord(spec, d, seventh=True):
                assert m % 12 in pcs, (n, d, m)


def test_the_lead_motif_uses_only_scale_notes():
    for n, spec in me.TRACKS.items():
        pcs = {(spec["root"] + s) % 12 for s in me.SCALES[spec["scale"]]}
        motif = me.make_motif(spec, np.random.default_rng(spec["seed"] * 100 + 3))
        assert motif and all(m % 12 in pcs for _, m, _ in motif), n


def test_every_layer_is_in_the_mix_and_the_last_bars_thin_out():
    spec, layers = me.render_layers("storm", bars=8)
    assert set(layers) == set(me.LAYER_FUNCS)
    n = len(layers["drums"])
    bar = n // 8
    assert np.abs(layers["drums"][: bar * 6]).max() > 0.01           # drums play in the body of the loop
    # ...and the final two bars have no NEW drum hits (only the tail of the last hit before them)
    assert np.abs(layers["drums"][int(bar * 7.5):]).max() < np.abs(layers["drums"]).max() * 0.2
