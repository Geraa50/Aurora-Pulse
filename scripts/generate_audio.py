"""Generate Aurora Pulse music and SFX assets.

The sounds are intentionally soft: short glassy UI feedback and a quiet
ambient loop that matches the game's northern-lights style guide.

Run:
    python scripts/generate_audio.py
"""

from __future__ import annotations

import math
import random
import wave
from array import array
from pathlib import Path

SAMPLE_RATE = 44_100
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "audio"


def _clamp(value: float) -> float:
    return max(-1.0, min(1.0, value))


def _write_wav(path: Path, samples: list[float], channels: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = array("h", (int(_clamp(s) * 32767) for s in samples))
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())
    print(f"  -> {path.relative_to(ROOT)}")


def _env(t: float, attack: float, release: float, duration: float) -> float:
    if t < attack:
        return t / max(attack, 0.001)
    tail_start = max(attack, duration - release)
    if t > tail_start:
        return max(0.0, (duration - t) / max(release, 0.001))
    return 1.0


def _tone(
    freq: float,
    duration: float,
    amp: float,
    *,
    attack: float = 0.006,
    release: float = 0.06,
    wave_shape: str = "sine",
) -> list[float]:
    count = int(SAMPLE_RATE * duration)
    out: list[float] = []
    phase = random.random() * math.tau
    for i in range(count):
        t = i / SAMPLE_RATE
        e = _env(t, attack, release, duration)
        if wave_shape == "triangle":
            raw = 2.0 / math.pi * math.asin(math.sin(math.tau * freq * t + phase))
        else:
            raw = math.sin(math.tau * freq * t + phase)
        out.append(raw * amp * e)
    return out


def _mix(layers: list[list[float]]) -> list[float]:
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, sample in enumerate(layer):
            out[i] += sample
    peak = max(max(abs(s) for s in out), 1.0)
    return [s / peak * 0.92 for s in out]


def _delay(samples: list[float], delay_ms: float, gain: float) -> list[float]:
    offset = int(SAMPLE_RATE * delay_ms / 1000.0)
    out = samples[:] + [0.0] * offset
    for i, sample in enumerate(samples):
        if i + offset < len(out):
            out[i + offset] += sample * gain
    return out


def _save_sfx(name: str, layers: list[list[float]], gain: float = 1.0) -> None:
    samples = [s * gain for s in _mix(layers)]
    _write_wav(OUT / "sfx" / f"{name}.wav", samples)


def make_sfx() -> None:
    # Soft glass tap: tiny bell with a second overtone.
    _save_sfx(
        "tile_tap",
        [
            _tone(880, 0.13, 0.42, attack=0.002, release=0.11),
            _tone(1760, 0.10, 0.18, attack=0.001, release=0.08),
        ],
        gain=0.42,
    )

    # Blocked tile: restrained low thud with a muted high tick.
    _save_sfx(
        "tile_blocked",
        [
            _tone(146, 0.18, 0.36, attack=0.001, release=0.16, wave_shape="triangle"),
            _tone(520, 0.07, 0.10, attack=0.001, release=0.06),
        ],
        gain=0.42,
    )

    # Match: small upward shimmer, the most rewarding regular interaction.
    match = _mix(
        [
            _tone(659.25, 0.42, 0.24, attack=0.008, release=0.34),
            _tone(987.77, 0.46, 0.20, attack=0.018, release=0.38),
            _tone(1318.51, 0.52, 0.16, attack=0.035, release=0.42),
        ]
    )
    _write_wav(OUT / "sfx" / "triple_match.wav", _delay(match, 95, 0.18))

    # Fail: descending, soft wobble rather than an aggressive error beep.
    fail = _mix(
        [
            _tone(440, 0.15, 0.22, attack=0.004, release=0.11),
            _tone(330, 0.20, 0.20, attack=0.035, release=0.14),
            _tone(247, 0.25, 0.14, attack=0.07, release=0.18),
        ]
    )
    _write_wav(OUT / "sfx" / "triple_fail.wav", fail)

    # Main menu / UI buttons: warm, lower than tile interactions.
    _save_sfx(
        "ui_button",
        [
            _tone(523.25, 0.12, 0.28, attack=0.002, release=0.10),
            _tone(784.00, 0.10, 0.12, attack=0.003, release=0.08),
        ],
        gain=0.36,
    )

    # Level complete: wider version of the match shimmer.
    complete = _mix(
        [
            _tone(392.00, 1.12, 0.20, attack=0.025, release=0.90),
            _tone(587.33, 1.18, 0.18, attack=0.080, release=0.88),
            _tone(783.99, 1.24, 0.16, attack=0.130, release=0.92),
            _tone(1174.66, 1.30, 0.12, attack=0.200, release=0.95),
        ]
    )
    _write_wav(OUT / "sfx" / "level_complete.wav", _delay(complete, 180, 0.16))


def make_music() -> None:
    duration = 32.0
    count = int(SAMPLE_RATE * duration)
    left: list[float] = []
    right: list[float] = []

    # C# minor / aurora-like pad. Harmonic motion is slow to keep the puzzle calm.
    chords = [
        (138.59, 164.81, 207.65),
        (110.00, 164.81, 220.00),
        (123.47, 184.99, 246.94),
        (103.83, 155.56, 207.65),
    ]

    for i in range(count):
        t = i / SAMPLE_RATE
        chord = chords[int(t / 8.0) % len(chords)]
        local = t % 8.0
        chord_env = _env(local, 1.8, 2.6, 8.0)
        shimmer_env = 0.5 + 0.5 * math.sin(math.tau * t / 13.0)

        pad = 0.0
        for n, freq in enumerate(chord):
            detune = 0.004 * (n + 1)
            pad += math.sin(math.tau * freq * (1.0 - detune) * t) * 0.12
            pad += math.sin(math.tau * freq * (1.0 + detune) * t) * 0.12

        bell = 0.0
        if int(t * 2) % 8 == 0:
            bell_freq = chord[2] * 4.0
            bell = math.sin(math.tau * bell_freq * t) * 0.035 * shimmer_env

        breath = math.sin(math.tau * 0.07 * t) * 0.025
        noise = (random.random() - 0.5) * 0.004
        sample = (pad * chord_env + bell + breath + noise) * 0.42

        pan = math.sin(math.tau * t / 17.0) * 0.18
        left.append(sample * (1.0 - pan))
        right.append(sample * (1.0 + pan))

    # Short equal-power crossfade makes the WAV safe to loop.
    fade = int(SAMPLE_RATE * 3.0)
    for i in range(fade):
        a = i / fade
        b = 1.0 - a
        left[i] = left[i] * a + left[-fade + i] * b
        right[i] = right[i] * a + right[-fade + i] * b

    stereo: list[float] = []
    peak = max(max(abs(s) for s in left), max(abs(s) for s in right), 1.0)
    for l, r in zip(left, right):
        stereo.extend((l / peak * 0.65, r / peak * 0.65))

    _write_wav(OUT / "music" / "aurora_ambient_loop.wav", stereo, channels=2)


def main() -> None:
    random.seed(20260523)
    make_music()
    make_sfx()


if __name__ == "__main__":
    main()
