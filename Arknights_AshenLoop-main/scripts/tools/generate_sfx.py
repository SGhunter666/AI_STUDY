#!/usr/bin/env python3
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path("assets/sfx")


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def adsr(total: int, attack: float, decay: float, sustain: float, release: float) -> list[float]:
    attack_n = max(1, int(total * attack))
    decay_n = max(1, int(total * decay))
    release_n = max(1, int(total * release))
    sustain_n = max(0, total - attack_n - decay_n - release_n)
    envelope: list[float] = []
    for i in range(attack_n):
        envelope.append(i / max(1, attack_n))
    for i in range(decay_n):
        t = i / max(1, decay_n)
        envelope.append(1.0 + (sustain - 1.0) * t)
    envelope.extend([sustain] * sustain_n)
    for i in range(release_n):
        t = i / max(1, release_n)
        envelope.append(sustain * (1.0 - t))
    if len(envelope) < total:
        envelope.extend([0.0] * (total - len(envelope)))
    return envelope[:total]


def sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def triangle(freq: float, t: float) -> float:
    x = (t * freq) % 1.0
    return 4.0 * abs(x - 0.5) - 1.0


def square(freq: float, t: float) -> float:
    return 1.0 if sine(freq, t) >= 0.0 else -1.0


def noise(_: float, __: float) -> float:
    return random.uniform(-1.0, 1.0)


def lowpass(samples: list[float], cutoff_hz: float) -> list[float]:
    if not samples:
        return samples
    dt = 1.0 / SAMPLE_RATE
    rc = 1.0 / (2.0 * math.pi * max(1.0, cutoff_hz))
    alpha = dt / (rc + dt)
    out: list[float] = []
    prev = 0.0
    for sample in samples:
        prev = prev + alpha * (sample - prev)
        out.append(prev)
    return out


def highpass(samples: list[float], cutoff_hz: float) -> list[float]:
    if not samples:
        return samples
    dt = 1.0 / SAMPLE_RATE
    rc = 1.0 / (2.0 * math.pi * max(1.0, cutoff_hz))
    alpha = rc / (rc + dt)
    out: list[float] = []
    prev_y = 0.0
    prev_x = samples[0]
    for sample in samples:
        prev_y = alpha * (prev_y + sample - prev_x)
        prev_x = sample
        out.append(prev_y)
    return out


def render_tone(
    duration: float,
    freq_start: float,
    freq_end: float | None = None,
    amp: float = 0.5,
    wave_kind: str = "sine",
    attack: float = 0.02,
    decay: float = 0.10,
    sustain: float = 0.45,
    release: float = 0.20,
) -> list[float]:
    total = max(1, int(SAMPLE_RATE * duration))
    env = adsr(total, attack, decay, sustain, release)
    generator = {
        "sine": sine,
        "triangle": triangle,
        "square": square,
        "noise": noise,
    }[wave_kind]
    samples: list[float] = []
    for i in range(total):
        progress = i / max(1, total - 1)
        freq = freq_start if freq_end is None else freq_start + (freq_end - freq_start) * progress
        t = i / SAMPLE_RATE
        sample = generator(freq, t) * env[i] * amp
        samples.append(sample)
    return samples


def mix(layers: list[list[float]]) -> list[float]:
    if not layers:
        return []
    total = max(len(layer) for layer in layers)
    out = [0.0] * total
    for layer in layers:
        for i, sample in enumerate(layer):
            out[i] += sample
    peak = max(0.001, max(abs(v) for v in out))
    normalize = 0.92 / peak
    return [clamp(v * normalize) for v in out]


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            frames.extend(struct.pack("<h", int(clamp(sample) * 32767)))
        wav.writeframes(bytes(frames))


def stone_click() -> list[float]:
    base = render_tone(0.09, 220, 120, 0.55, "triangle", 0.005, 0.08, 0.15, 0.30)
    tick = render_tone(0.03, 1800, 1200, 0.18, "square", 0.0, 0.04, 0.0, 0.50)
    air = highpass(render_tone(0.045, 0, 0, 0.07, "noise", 0.0, 0.10, 0.0, 0.45), 2400)
    return mix([base, tick, air])


def ui_open() -> list[float]:
    a = render_tone(0.22, 740, 980, 0.22, "sine", 0.02, 0.08, 0.55, 0.35)
    b = render_tone(0.26, 1110, 1480, 0.16, "triangle", 0.01, 0.08, 0.42, 0.40)
    c = highpass(render_tone(0.16, 0, 0, 0.05, "noise", 0.0, 0.10, 0.0, 0.40), 1800)
    return mix([a, b, c])


def card_draw() -> list[float]:
    whoosh = highpass(render_tone(0.14, 0, 0, 0.22, "noise", 0.0, 0.24, 0.08, 0.34), 1400)
    spark = render_tone(0.10, 900, 1380, 0.14, "triangle", 0.0, 0.14, 0.0, 0.38)
    return mix([whoosh, spark])


def card_select() -> list[float]:
    ping = render_tone(0.11, 880, 1180, 0.28, "triangle", 0.0, 0.10, 0.24, 0.40)
    air = highpass(render_tone(0.05, 0, 0, 0.06, "noise", 0.0, 0.12, 0.0, 0.48), 2600)
    return mix([ping, air])


def card_play() -> list[float]:
    swipe = highpass(render_tone(0.16, 0, 0, 0.26, "noise", 0.0, 0.18, 0.06, 0.42), 950)
    body = render_tone(0.08, 280, 180, 0.22, "triangle", 0.0, 0.12, 0.14, 0.40)
    return mix([swipe, body])


def support_play() -> list[float]:
    c1 = render_tone(0.32, 523, 523, 0.18, "triangle", 0.02, 0.08, 0.55, 0.35)
    c2 = render_tone(0.30, 659, 659, 0.15, "triangle", 0.02, 0.08, 0.55, 0.35)
    c3 = render_tone(0.28, 784, 784, 0.11, "sine", 0.02, 0.08, 0.48, 0.36)
    return mix([c1, c2, c3])


def attack_hit() -> list[float]:
    punch = render_tone(0.10, 190, 72, 0.68, "triangle", 0.0, 0.10, 0.08, 0.42)
    crack = highpass(render_tone(0.055, 0, 0, 0.26, "noise", 0.0, 0.16, 0.0, 0.44), 1100)
    return mix([punch, crack])


def resonance_apply() -> list[float]:
    a = render_tone(0.20, 680, 980, 0.18, "sine", 0.0, 0.08, 0.36, 0.42)
    b = render_tone(0.18, 980, 1460, 0.15, "triangle", 0.0, 0.08, 0.34, 0.42)
    sparkle = highpass(render_tone(0.09, 0, 0, 0.05, "noise", 0.0, 0.14, 0.0, 0.40), 3200)
    return mix([a, b, sparkle])


def resonance_burst() -> list[float]:
    ring = render_tone(0.28, 1220, 520, 0.22, "triangle", 0.0, 0.08, 0.34, 0.46)
    pulse = render_tone(0.18, 240, 90, 0.42, "sine", 0.0, 0.10, 0.14, 0.42)
    shatter = highpass(render_tone(0.12, 0, 0, 0.16, "noise", 0.0, 0.12, 0.0, 0.50), 1900)
    return mix([ring, pulse, shatter])


def explosion_warn() -> list[float]:
    first = render_tone(0.12, 980, 980, 0.34, "square", 0.0, 0.10, 0.22, 0.32)
    second = render_tone(0.10, 1240, 1240, 0.30, "square", 0.0, 0.10, 0.22, 0.32)
    gap = [0.0] * int(0.05 * SAMPLE_RATE)
    return mix([first + gap + second])


def explosion_boom() -> list[float]:
    boom = lowpass(render_tone(0.36, 92, 40, 0.86, "noise", 0.0, 0.18, 0.18, 0.44), 260)
    crack = highpass(render_tone(0.10, 0, 0, 0.22, "noise", 0.0, 0.10, 0.0, 0.40), 1500)
    tail = render_tone(0.24, 140, 64, 0.26, "triangle", 0.0, 0.16, 0.12, 0.44)
    return mix([boom, crack, tail])


def end_turn() -> list[float]:
    seal = render_tone(0.16, 360, 210, 0.24, "triangle", 0.0, 0.12, 0.20, 0.34)
    ping = render_tone(0.10, 780, 640, 0.12, "sine", 0.02, 0.10, 0.20, 0.34)
    return mix([seal, ping])


def victory() -> list[float]:
    n1 = render_tone(0.46, 523, 523, 0.16, "triangle", 0.02, 0.08, 0.56, 0.28)
    n2 = render_tone(0.46, 659, 659, 0.15, "triangle", 0.06, 0.08, 0.54, 0.28)
    n3 = render_tone(0.54, 784, 988, 0.18, "sine", 0.10, 0.10, 0.58, 0.26)
    return mix([n1, n2, n3])


def defeat() -> list[float]:
    n1 = render_tone(0.40, 440, 330, 0.20, "triangle", 0.02, 0.08, 0.44, 0.34)
    n2 = render_tone(0.48, 330, 220, 0.20, "sine", 0.08, 0.08, 0.38, 0.36)
    noise_tail = lowpass(render_tone(0.26, 0, 0, 0.08, "noise", 0.0, 0.12, 0.0, 0.44), 800)
    return mix([n1, n2, noise_tail])


def shop_open() -> list[float]:
    coin = render_tone(0.18, 1080, 1560, 0.20, "triangle", 0.0, 0.08, 0.20, 0.42)
    warm = render_tone(0.24, 620, 820, 0.14, "sine", 0.02, 0.08, 0.44, 0.40)
    return mix([coin, warm])


def rest_open() -> list[float]:
    warm = render_tone(0.34, 392, 523, 0.18, "triangle", 0.02, 0.10, 0.54, 0.32)
    soft = render_tone(0.30, 523, 659, 0.12, "sine", 0.04, 0.08, 0.42, 0.36)
    return mix([warm, soft])


def reward_open() -> list[float]:
    reveal = render_tone(0.26, 720, 1120, 0.20, "triangle", 0.02, 0.08, 0.48, 0.36)
    shimmer = highpass(render_tone(0.14, 0, 0, 0.07, "noise", 0.0, 0.12, 0.0, 0.42), 2600)
    return mix([reveal, shimmer])


def main() -> None:
    random.seed(42)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sounds = {
        "ui_click.wav": stone_click(),
        "ui_open.wav": ui_open(),
        "card_draw.wav": card_draw(),
        "card_select.wav": card_select(),
        "card_play.wav": card_play(),
        "support_play.wav": support_play(),
        "attack_hit.wav": attack_hit(),
        "resonance_apply.wav": resonance_apply(),
        "resonance_burst.wav": resonance_burst(),
        "explosion_warn.wav": explosion_warn(),
        "explosion_boom.wav": explosion_boom(),
        "end_turn.wav": end_turn(),
        "victory.wav": victory(),
        "defeat.wav": defeat(),
        "shop_open.wav": shop_open(),
        "rest_open.wav": rest_open(),
        "reward_open.wav": reward_open(),
    }
    for filename, samples in sounds.items():
        write_wav(OUTPUT_DIR / filename, samples)
    print(f"Generated {len(sounds)} SFX into {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
