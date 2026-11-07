#!/usr/bin/env python3
"""Compose and render the three background loops: town, field, dungeon.

    python3 tools/prepare_music.py            # writes assets/audio/music/{town,field,dungeon}.ogg
    python3 tools/prepare_music.py --check    # also prints loop-seam and level measurements

Everything is synthesized (numpy only; ffmpeg encodes the Ogg). The music is composed in code, so the
result is reproducible and has no third-party audio. Seamless looping is structural: every note is written
into a buffer of exactly one loop length, tails that run past the end wrap onto the start, and the reverb and
delay are circular, so the last sample flows into the first the same way the song flows from bar to bar.
"""
import argparse
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "music")
TARGET_RMS = 0.085  # about -21 dBFS; the game plays music well under effects


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


class Loop:
    """A stereo buffer of exactly one loop. Writes that pass the end wrap to the start."""

    def __init__(self, seconds: float):
        self.n = int(round(seconds * SR))
        self.buf = np.zeros((self.n, 2))

    def add(self, at: float, mono: np.ndarray, pan: float = 0.0, gain: float = 1.0) -> None:
        left = np.cos((pan + 1.0) * np.pi / 4.0) * gain
        right = np.sin((pan + 1.0) * np.pi / 4.0) * gain
        start = int(round(at * SR)) % self.n
        size = len(mono)
        first = min(size, self.n - start)
        self.buf[start:start + first, 0] += mono[:first] * left
        self.buf[start:start + first, 1] += mono[:first] * right
        if first < size:
            rest = size - first
            self.buf[:rest, 0] += mono[first:] * left
            self.buf[:rest, 1] += mono[first:] * right


# ───────── instruments (mono) ─────────

def _t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def pluck(freq: float, decay: float = 1.4, vel: float = 0.5) -> np.ndarray:
    """Lute / harp: a few harmonics with faster-dying upper partials."""
    t = _t(decay * 2.2)
    out = np.zeros_like(t)
    for k in range(1, 9):
        if freq * k > 9000:
            break
        out += (1.0 / k ** 1.25) * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (2.2 + 1.7 * k) / decay)
    out *= np.minimum(1.0, t / 0.003)
    return out * vel


def flute(freq: float, seconds: float, vel: float = 0.5, rng=None) -> np.ndarray:
    """Soft breathy lead with gentle vibrato that blooms after the attack."""
    rng = rng or np.random.default_rng(1)
    total = seconds + 0.25
    t = _t(total)
    vib = 0.004 * np.minimum(1.0, t / 0.5) * np.sin(2 * np.pi * 5.1 * t)
    phase = np.cumsum(2 * np.pi * freq * (1.0 + vib) / SR)
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.07 * np.sin(3 * phase)
    breath = rng.normal(0, 1, len(t))
    breath = np.convolve(breath, np.ones(5) / 5, mode="same") * 0.05
    env = np.minimum(1.0, t / 0.09) * np.where(t < seconds, 1.0, np.exp(-(t - seconds) / 0.07))
    return (tone + breath) * env * vel


def pad(freqs, seconds: float, vel: float = 0.3, attack: float = 0.9, release: float = 1.2) -> np.ndarray:
    """Slow strings-like chord: detuned soft saws."""
    t = _t(seconds + release)
    out = np.zeros_like(t)
    for f in freqs:
        for cents in (-4, 0, 4):
            ff = f * 2 ** (cents / 1200)
            for k in range(1, 7):
                out += np.sin(2 * np.pi * ff * k * t + k) / k ** 1.4
    env = np.minimum(1.0, t / attack) * np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 3.5 / release))
    return out * env * vel / (3 * len(freqs))


def bass(freq: float, seconds: float, vel: float = 0.6) -> np.ndarray:
    t = _t(seconds + 0.3)
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)
    env = np.minimum(1.0, t / 0.01) * np.where(t < seconds, np.exp(-t * 1.6), np.exp(-seconds * 1.6) * np.exp(-(t - seconds) / 0.08))
    return tone * env * vel


def drum(low: float = 55.0, high: float = 120.0, vel: float = 0.5, decay: float = 13.0, length: float = 0.5) -> np.ndarray:
    """Soft frame drum / tom: a falling sine with a short skin click."""
    t = _t(length)
    freq = low + (high - low) * np.exp(-t * 24)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * decay)
    click = np.random.default_rng(7).normal(0, 1, len(t)) * np.exp(-t * 220) * 0.18
    return (tone + click) * vel


def shaker(vel: float = 0.15) -> np.ndarray:
    t = _t(0.09)
    noise = np.random.default_rng(11).normal(0, 1, len(t))
    noise = np.diff(noise, prepend=0.0)  # tilt toward the highs
    return noise * np.exp(-t * 55) * vel * np.minimum(1.0, t / 0.004)


def bell(freq: float, vel: float = 0.35, decay: float = 2.6) -> np.ndarray:
    """Hand bell: inharmonic partials with long, separately decaying tails."""
    t = _t(decay * 2.4)
    out = np.zeros_like(t)
    for ratio, amp, fall in ((1.0, 1.0, 1.0), (2.76, 0.5, 1.8), (5.4, 0.25, 2.6), (8.93, 0.12, 3.6)):
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * fall / decay * 2.0)
    return out * np.minimum(1.0, t / 0.002) * vel


def circular_noise(n: int, cutoff_hz: float, seed: int) -> np.ndarray:
    """Band-limited noise that is itself periodic over n samples (so it loops without a seam)."""
    spectrum = np.fft.rfft(np.random.default_rng(seed).normal(0, 1, n))
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    spectrum *= 1.0 / (1.0 + (freqs / cutoff_hz) ** 4)
    out = np.fft.irfft(spectrum, n)
    return out / np.max(np.abs(out))


# ───────── effects (circular, so they never break the loop) ─────────

def reverb(loop: Loop, seconds: float, wet: float, seed: int = 3) -> None:
    n = loop.n
    length = min(int(seconds * SR), n - 1)
    out = np.zeros_like(loop.buf)
    for ch in range(2):
        rng = np.random.default_rng(seed + ch)
        t = np.arange(length) / SR
        ir = rng.normal(0, 1, length) * np.exp(-t * 6.9 / seconds)  # -60 dB at `seconds`
        ir = np.convolve(ir, np.ones(6) / 6, mode="same")  # roll off the highs
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        ir /= np.sqrt(np.sum(ir ** 2))
        padded = np.zeros(n)
        padded[:length] = ir
        out[:, ch] = np.fft.irfft(np.fft.rfft(loop.buf[:, ch]) * np.fft.rfft(padded), n)
    loop.buf = loop.buf * (1.0 - wet * 0.5) + out * wet * 0.9


def delay(loop: Loop, seconds: float, feedback: float, mix: float) -> None:
    """Ping-pong echo made of circular shifts."""
    shift = int(seconds * SR)
    echo = np.zeros_like(loop.buf)
    current = loop.buf.copy()
    for i in range(4):
        current = np.roll(current[:, ::-1], shift, axis=0) * feedback
        echo += current
    loop.buf = loop.buf + echo * mix


def finish(loop: Loop) -> np.ndarray:
    audio = loop.buf - loop.buf.mean(axis=0)
    audio *= TARGET_RMS / np.sqrt(np.mean(audio ** 2))
    audio = np.tanh(audio * 1.4) / 1.4  # soft ceiling, never hard-clips
    peak = np.max(np.abs(audio))
    if peak > 0.9:
        audio *= 0.9 / peak
    return audio


# ───────── songs ─────────

def town() -> np.ndarray:
    """G major, 92 bpm, 16 bars (41.7s): a warm folk lute with a small flute tune."""
    bpm, bars = 92.0, 16
    beat = 60.0 / bpm
    loop = Loop(bars * 4 * beat)
    rng = np.random.default_rng(21)
    chords = {
        "G": (43, [55, 59, 62]), "D": (38, [57, 62, 66]), "Em": (40, [55, 59, 64]), "C": (48, [55, 60, 64]),
        "Bm": (47, [54, 59, 62]), "Am": (45, [57, 60, 64]),
    }
    progression = ["G", "D", "Em", "C", "G", "D", "C", "D", "G", "Bm", "Em", "C", "Am", "D", "C", "D"]
    arp = [0, 2, 1, 2, 0, 2, 1, 2]
    for bar, name in enumerate(progression):
        root, triad = chords[name]
        t0 = bar * 4 * beat
        loop.add(t0, pad([n - 12 for n in triad], 4 * beat, vel=0.22, attack=0.5, release=0.8), pan=0.0)
        loop.add(t0, bass(hz(root), 1.8 * beat, 0.55), pan=-0.1)
        loop.add(t0 + 2 * beat, bass(hz(root), 1.8 * beat, 0.45), pan=-0.1)
        for i, idx in enumerate(arp):
            accent = 0.62 if i in (0, 4) else 0.42
            loop.add(t0 + i * 0.5 * beat, pluck(hz(triad[idx]), 1.2, accent), pan=0.25 if i % 2 else -0.15)
        loop.add(t0, drum(vel=0.34), pan=0.0)
        loop.add(t0 + 2 * beat, drum(vel=0.26), pan=0.0)
        for i in range(8):
            if i % 2 == 1:
                loop.add(t0 + i * 0.5 * beat, shaker(0.16), pan=0.35)
    tune = [
        (0, 71, 2), (2, 74, 1), (3, 71, 1), (4, 69, 2), (6, 74, 2), (8, 76, 2), (10, 74, 1), (11, 71, 1),
        (12, 71, 2), (14, 69, 1), (15, 67, 1), (16, 67, 1), (17, 71, 1), (18, 74, 2), (20, 74, 2), (22, 71, 1),
        (23, 69, 1), (24, 67, 2), (26, 71, 1), (27, 76, 1), (28, 74, 2), (30, 69, 2),
        (32, 79, 2), (34, 76, 1), (35, 74, 1), (36, 71, 2), (38, 74, 2), (40, 76, 2), (42, 71, 1), (43, 67, 1),
        (44, 76, 1), (45, 74, 1), (46, 71, 2), (48, 69, 2), (50, 72, 1), (51, 76, 1), (52, 74, 2), (54, 69, 1),
        (55, 66, 1), (56, 67, 2), (58, 71, 1), (59, 72, 1), (60, 74, 2), (62, 71, 1), (63, 69, 1),
    ]
    for b, note, length in tune:
        loop.add(b * beat, flute(hz(note), length * beat * 0.92, 0.42, rng), pan=0.18)
    reverb(loop, 1.8, 0.24)
    return finish(loop)


def field() -> np.ndarray:
    """A minor, 78 bpm, 16 bars (49.2s): open and airy, with harp arpeggios and a long horn line."""
    bpm, bars = 78.0, 16
    beat = 60.0 / bpm
    loop = Loop(bars * 4 * beat)
    rng = np.random.default_rng(22)
    chords = {
        "Am": (45, [57, 60, 64]), "G": (43, [55, 59, 62]), "F": (41, [53, 57, 60]), "Em": (40, [55, 59, 64]),
        "E": (40, [52, 56, 59]), "C": (48, [55, 60, 64]),
    }
    progression = ["Am", "G", "F", "G", "Am", "Em", "F", "E", "Am", "F", "C", "G", "Am", "F", "G", "E"]
    arp = [0, 1, 2, 3, 2, 1, 2, 1]
    for bar, name in enumerate(progression):
        root, triad = chords[name]
        t0 = bar * 4 * beat
        notes = triad + [triad[0] + 12]
        loop.add(t0, pad(triad, 4 * beat, vel=0.4, attack=1.1, release=1.4), pan=-0.2)
        loop.add(t0, pad([n - 12 for n in triad], 4 * beat, vel=0.22, attack=1.4, release=1.4), pan=0.2)
        loop.add(t0, bass(hz(root), 3.2 * beat, 0.5), pan=0.0)
        loop.add(t0 + 3 * beat, bass(hz(root + 7), 0.9 * beat, 0.25), pan=0.0)
        for i, idx in enumerate(arp):
            loop.add(t0 + i * 0.5 * beat, pluck(hz(notes[idx] + 12), 1.8, 0.34 if i % 4 == 0 else 0.22), pan=-0.5 + 0.14 * i)
        loop.add(t0, drum(low=50, high=105, vel=0.28, length=0.6), pan=0.0)
        loop.add(t0 + 2 * beat, drum(low=60, high=125, vel=0.2, length=0.4), pan=0.1)
        loop.add(t0 + 3.5 * beat, shaker(0.1), pan=0.3)
    tune = [
        (0, 76, 3), (3, 74, 1), (4, 72, 2), (6, 71, 2), (8, 69, 3), (11, 72, 1), (12, 74, 2), (14, 71, 2),
        (16, 72, 2), (18, 76, 2), (20, 79, 3), (23, 76, 1), (24, 77, 2), (26, 76, 1), (27, 72, 1), (28, 71, 2),
        (30, 68, 2), (32, 69, 2), (34, 72, 2), (36, 72, 2), (38, 69, 2), (40, 76, 3), (43, 72, 1), (44, 74, 2),
        (46, 71, 2), (48, 72, 2), (50, 76, 2), (52, 77, 2), (54, 76, 1), (55, 72, 1), (56, 74, 2), (58, 71, 2),
        (60, 76, 2), (62, 71, 2),
    ]
    for b, note, length in tune:
        loop.add(b * beat, flute(hz(note), length * beat * 0.95, 0.38, rng), pan=0.2)
    delay(loop, beat * 0.75, 0.38, 0.22)
    reverb(loop, 2.6, 0.34)
    return finish(loop)


def dungeon() -> np.ndarray:
    """D minor, 54 bpm, 12 bars (53.3s): a low drone, a slow heartbeat, sparse bells, a mournful flute."""
    bpm, bars = 54.0, 12
    beat = 60.0 / bpm
    loop = Loop(bars * 4 * beat)
    rng = np.random.default_rng(23)
    chords = {
        "Dm": [50, 53, 57], "Bb": [46, 53, 58], "Gm": [50, 55, 58], "A": [57, 61, 64],
    }
    progression = ["Dm", "Dm", "Bb", "Bb", "Dm", "Dm", "Gm", "Gm", "Dm", "Dm", "Bb", "A"]
    for bar, name in enumerate(progression):
        t0 = bar * 4 * beat
        loop.add(t0, pad(chords[name], 4 * beat, vel=0.4, attack=1.8, release=2.2), pan=0.0)
        loop.add(t0, drum(low=38, high=70, vel=0.5, decay=9.0, length=0.8), pan=0.0)
        loop.add(t0 + 0.75 * beat, drum(low=34, high=60, vel=0.28, decay=9.0, length=0.7), pan=0.0)
    t = np.arange(loop.n) / SR
    span = loop.n / SR
    drone = np.zeros(loop.n)
    for freq, amp, lfo in ((hz(38), 1.0, 1), (hz(45), 0.6, 2), (hz(50), 0.3, 3)):
        cycles = round(freq * span)
        drone += amp * np.sin(2 * np.pi * cycles * t / span) * (0.75 + 0.25 * np.sin(2 * np.pi * lfo * t / span))
    loop.add(0.0, drone, pan=0.0, gain=0.16)
    wind = circular_noise(loop.n, 700.0, 5) * (0.5 + 0.5 * np.cos(2 * np.pi * 2 * t / span - 1.0))
    loop.add(0.0, wind, pan=0.0, gain=0.05)
    bells = [(0, 74), (5, 69), (8.5, 77), (13, 72), (18, 70), (22, 74), (27, 69), (31, 65), (35.5, 72), (40, 77), (44, 70), (46.5, 69)]
    for i, (b, note) in enumerate(bells):
        loop.add(b * beat, bell(hz(note), 0.32, 2.8), pan=-0.5 if i % 2 else 0.5)
    tune = [(16, 62, 4), (20, 65, 3), (23, 64, 1), (24, 62, 6), (40, 65, 4), (44, 64, 2), (46, 62, 2)]
    for b, note, length in tune:
        loop.add(b * beat, flute(hz(note), length * beat * 0.95, 0.3, rng), pan=-0.1)
    delay(loop, beat * 1.5, 0.45, 0.3)
    reverb(loop, 4.2, 0.5)
    return finish(loop)


SONGS = {"town": town, "field": field, "dungeon": dungeon}


# ───────── output and measurements ─────────

def write_wav(path: str, audio: np.ndarray) -> None:
    pcm = (np.clip(audio, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def seam_report(name: str, audio: np.ndarray) -> None:
    """The wrap step should look like any other sample step; report it against the typical step."""
    step = np.abs(np.diff(audio, axis=0))
    wrap = np.abs(audio[0] - audio[-1])
    typical = np.percentile(step, 99.5, axis=0)
    rms = 20 * np.log10(np.sqrt(np.mean(audio ** 2)))
    peak = 20 * np.log10(np.max(np.abs(audio)))
    print("%-8s %5.1fs  rms %5.1f dBFS  peak %5.1f dBFS  wrap step L/R %.5f/%.5f  (99.5%% of steps <= %.5f/%.5f)" % (
        name, len(audio) / SR, rms, peak, wrap[0], wrap[1], typical[0], typical[1]))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="print loop-seam and level measurements")
    parser.add_argument("--quality", default="3.5", help="libvorbis -q:a value")
    args = parser.parse_args()
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, compose in SONGS.items():
            audio = compose()
            if args.check:
                seam_report(name, audio)
            wav = os.path.join(tmp, name + ".wav")
            write_wav(wav, audio)
            target = os.path.join(OUT, name + ".ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", args.quality, target], check=True)
            print("wrote %s (%d KB)" % (os.path.relpath(target, ROOT), os.path.getsize(target) // 1024))


if __name__ == "__main__":
    main()
