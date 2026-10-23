from __future__ import annotations

import math
from pathlib import Path
from typing import Callable

from PIL import Image, ImageChops, ImageDraw, ImageFilter


WIDTH = 768
HEIGHT = 1024
ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "assets" / "card_art"


Color = tuple[int, int, int, int]


def rgba(hex_color: str, alpha: int = 255) -> Color:
    hex_color = hex_color.lstrip("#")
    return (
        int(hex_color[0:2], 16),
        int(hex_color[2:4], 16),
        int(hex_color[4:6], 16),
        alpha,
    )


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1: Color, c2: Color, t: float) -> Color:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
        int(lerp(c1[3], c2[3], t)),
    )


def gradient_background(size: tuple[int, int], top: Color, bottom: Color, accent: Color) -> Image.Image:
    width, height = size
    img = Image.new("RGBA", size, top)
    pixels = img.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        line = mix(top, bottom, t)
        for x in range(width):
            pixels[x, y] = line

    accent_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    accent_draw = ImageDraw.Draw(accent_layer)
    accent_draw.polygon(
        [
            (int(width * 0.58), -30),
            (width + 50, 0),
            (width + 50, int(height * 0.42)),
            (int(width * 0.28), int(height * 0.12)),
        ],
        fill=accent,
    )
    accent_draw.polygon(
        [
            (-50, int(height * 0.64)),
            (int(width * 0.34), int(height * 0.36)),
            (int(width * 0.54), height + 50),
            (-50, height + 50),
        ],
        fill=(255, 255, 255, 18),
    )
    accent_layer = accent_layer.filter(ImageFilter.GaussianBlur(28))
    return Image.alpha_composite(img, accent_layer)


def apply_vignette(img: Image.Image, strength: int = 110) -> Image.Image:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle((0, 0, img.width, img.height), fill=(0, 0, 0, 0))
    draw.rounded_rectangle(
        (-40, -40, img.width + 40, img.height + 40),
        radius=48,
        outline=(0, 0, 0, strength),
        width=92,
    )
    overlay = overlay.filter(ImageFilter.GaussianBlur(32))
    return Image.alpha_composite(img, overlay)


def glow_line(layer: Image.Image, points: list[tuple[int, int]], width: int, color: Color, blur: int = 24) -> None:
    draw = ImageDraw.Draw(layer)
    draw.line(points, fill=color, width=width, joint="curve")
    if blur > 0:
        blurred = layer.filter(ImageFilter.GaussianBlur(blur))
        layer.alpha_composite(blurred)


def add_orb(img: Image.Image, center: tuple[int, int], radius: int, inner: Color, outer: Color) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=outer)
    layer = layer.filter(ImageFilter.GaussianBlur(max(radius // 3, 8)))
    img.alpha_composite(layer)
    draw = ImageDraw.Draw(img)
    draw.ellipse((x - radius // 2, y - radius // 2, x + radius // 2, y + radius // 2), fill=inner)


def add_shards(img: Image.Image, color: Color, count: int = 6, angle_shift: float = 0.0) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx = img.width // 2
    cy = img.height // 2
    for index in range(count):
        angle = angle_shift + (math.pi * 2.0 / count) * index
        dx = math.cos(angle)
        dy = math.sin(angle)
        inner = 120 + index * 12
        outer = 360 + index * 10
        spread = 18 + index * 2
        points = [
            (int(cx + dx * inner - dy * spread), int(cy + dy * inner + dx * spread)),
            (int(cx + dx * outer), int(cy + dy * outer)),
            (int(cx + dx * inner + dy * spread), int(cy + dy * inner - dx * spread)),
        ]
        draw.polygon(points, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(layer)


def add_frame(img: Image.Image, border: Color) -> None:
    frame = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle(
        (16, 16, img.width - 16, img.height - 16),
        radius=34,
        outline=border,
        width=8,
    )
    draw.rounded_rectangle(
        (34, 34, img.width - 34, img.height - 34),
        radius=28,
        outline=(255, 255, 255, 36),
        width=2,
    )
    frame = frame.filter(ImageFilter.GaussianBlur(1))
    img.alpha_composite(frame)


def add_support_grid(img: Image.Image, color: Color) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    nodes = [
        (186, 250),
        (562, 236),
        (220, 566),
        (540, 612),
        (382, 442),
    ]
    for start in range(len(nodes)):
        for end in range(start + 1, len(nodes)):
            draw.line((nodes[start], nodes[end]), fill=color, width=8)
    for x, y in nodes:
        draw.ellipse((x - 26, y - 26, x + 26, y + 26), fill=(255, 255, 255, 235))
        draw.ellipse((x - 12, y - 12, x + 12, y + 12), fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def add_scan_arc(img: Image.Image, box: tuple[int, int, int, int], color: Color, width: int) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.arc(box, start=210, end=320, fill=color, width=width)
    draw.arc((box[0] + 60, box[1] + 60, box[2] - 60, box[3] - 60), start=220, end=300, fill=(255, 255, 255, 130), width=max(width // 2, 4))
    layer = layer.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(layer)


def add_slash(img: Image.Image, start: tuple[int, int], end: tuple[int, int], color: Color, glow: Color, width: int = 34) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line((start, end), fill=glow, width=width + 22)
    layer = layer.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(layer)
    draw = ImageDraw.Draw(img)
    draw.line((start, end), fill=color, width=width)
    draw.line((start, end), fill=(255, 255, 255, 130), width=max(width // 5, 3))


def add_card_silhouettes(img: Image.Image, color: Color) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cards = [
        (240, 250, -16),
        (365, 210, 9),
        (470, 290, 18),
    ]
    for x, y, tilt in cards:
        draw.rounded_rectangle((x, y, x + 168, y + 238), radius=20, fill=color)
        draw.rounded_rectangle((x + 10, y + 12, x + 158, y + 226), radius=16, outline=(255, 255, 255, 120), width=3)
    layer = layer.rotate(-4, resample=Image.Resampling.BICUBIC, center=(384, 440))
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(layer)


def add_text_band(img: Image.Image, band_color: Color) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon(
        [
            (-40, img.height - 214),
            (img.width, img.height - 304),
            (img.width + 50, img.height - 92),
            (-50, img.height),
        ],
        fill=band_color,
    )
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(layer)


def motif_arts_bolt(img: Image.Image) -> None:
    add_orb(img, (286, 664), 96, rgba("#f2fdff"), rgba("#45d5ff", 210))
    add_slash(img, (156, 760), (602, 296), rgba("#d5f7ff"), rgba("#2bd1ff", 180), 42)
    add_slash(img, (250, 860), (654, 420), rgba("#c8f8ff"), rgba("#6b67ff", 120), 18)


def motif_barrier_formula(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    hexagon = [(384, 190), (578, 318), (578, 568), (384, 694), (190, 568), (190, 318)]
    draw.polygon(hexagon, fill=rgba("#99ebff", 48), outline=rgba("#bff8ff"), width=12)
    draw.polygon([(384, 252), (516, 340), (516, 522), (384, 610), (252, 522), (252, 340)], fill=rgba("#f4feff", 148))
    for radius in (220, 290):
        draw.ellipse((384 - radius, 442 - radius, 384 + radius, 442 + radius), outline=rgba("#7fe0ff", 90), width=6)
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(layer)


def motif_blast_countdown(img: Image.Image) -> None:
    add_orb(img, (392, 448), 128, rgba("#fff7d9"), rgba("#ff9d34", 220))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((264, 326, 520, 582), fill=rgba("#ffb14e", 220), outline=rgba("#fff7d9"), width=8)
    draw.rectangle((372, 220, 412, 330), fill=rgba("#40211c"))
    draw.polygon([(372, 220), (414, 220), (430, 170), (356, 170)], fill=rgba("#fff2cf"))
    for offset in range(3):
        x0 = 286 + offset * 74
        draw.rounded_rectangle((x0, 670, x0 + 52, 788), radius=18, fill=rgba("#ff7043", 220))
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(layer)


def motif_burn_will(img: Image.Image) -> None:
    add_orb(img, (382, 508), 144, rgba("#fff9cf"), rgba("#ff6439", 220))
    add_shards(img, rgba("#ffbf4b", 190), count=7, angle_shift=0.2)
    add_text_band(img, rgba("#520000", 78))


def motif_command_sync(img: Image.Image) -> None:
    add_support_grid(img, rgba("#72f6ff", 220))
    add_slash(img, (154, 846), (644, 188), rgba("#f7feff"), rgba("#5ef8ff", 96), 12)


def motif_discipline_note(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((220, 180, 548, 780), radius=34, fill=rgba("#f4ead6", 232))
    for y in range(248, 700, 72):
        draw.line((274, y, 500, y), fill=rgba("#4f5f6a", 110), width=5)
    draw.line((252, 340, 526, 636), fill=rgba("#ff7b53"), width=28)
    draw.line((526, 340, 252, 636), fill=rgba("#fff0b0"), width=16)
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(layer)


def motif_echo_conduit(img: Image.Image) -> None:
    add_orb(img, (282, 552), 118, rgba("#ecfcff"), rgba("#59ddff", 210))
    for radius in (146, 210, 282):
        add_scan_arc(img, (282 - radius, 552 - radius, 282 + radius, 552 + radius), rgba("#72e8ff", 180), 12)
    add_slash(img, (328, 560), (664, 468), rgba("#d8faff"), rgba("#7b79ff", 80), 24)


def motif_emergency_shield(img: Image.Image) -> None:
    motif_barrier_formula(img)
    add_slash(img, (112, 810), (292, 620), rgba("#d6fbff"), rgba("#57d3ff", 120), 20)
    add_slash(img, (656, 812), (476, 620), rgba("#d6fbff"), rgba("#57d3ff", 120), 20)


def motif_focus_pulse(img: Image.Image) -> None:
    add_orb(img, (228, 604), 74, rgba("#f8ffff"), rgba("#53d3ff", 192))
    add_slash(img, (188, 660), (690, 402), rgba("#ffffff"), rgba("#38deff", 170), 26)
    add_slash(img, (268, 692), (668, 506), rgba("#fff6c8"), rgba("#7b69ff", 88), 12)


def motif_guided_fire(img: Image.Image) -> None:
    add_orb(img, (246, 610), 78, rgba("#fcffff"), rgba("#67deff", 175))
    add_orb(img, (310, 744), 48, rgba("#f6ffff"), rgba("#6ca7ff", 140))
    add_slash(img, (222, 632), (650, 358), rgba("#fefefe"), rgba("#51dfff", 120), 22)
    add_slash(img, (314, 742), (680, 514), rgba("#ffffff"), rgba("#6d75ff", 100), 18)


def motif_hesitation(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    shadow = [(222, 238), (472, 238), (540, 412), (384, 756), (214, 566)]
    draw.polygon(shadow, fill=rgba("#1e1a3a", 190))
    draw.polygon([(316, 238), (580, 238), (646, 412), (474, 756), (304, 566)], fill=rgba("#8291ff", 88))
    for x in (262, 352, 442, 532):
        draw.line((x, 210, x - 58, 812), fill=rgba("#f8fbff", 150), width=8)
    layer = layer.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(layer)


def motif_mind_alignment(img: Image.Image) -> None:
    for radius in (96, 166, 236, 320):
        add_scan_arc(img, (384 - radius, 440 - radius, 384 + radius, 440 + radius), rgba("#73ebff", 180), 10)
    add_orb(img, (384, 442), 80, rgba("#f8ffff"), rgba("#79deff", 210))
    add_text_band(img, rgba("#1d3d5d", 92))


def motif_overclock_arts(img: Image.Image) -> None:
    add_orb(img, (390, 446), 126, rgba("#fffad7"), rgba("#66ddff", 180))
    add_shards(img, rgba("#ff7648", 160), count=9, angle_shift=0.1)
    add_slash(img, (208, 812), (598, 282), rgba("#ffffff"), rgba("#5be3ff", 110), 26)


def motif_panic_static(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for row in range(11):
        y = 148 + row * 64
        draw.rectangle((94 + (row % 3) * 36, y, 694 - (row % 2) * 44, y + 30), fill=rgba("#b4b2ff", 58 + row * 10))
    for col in range(5):
        x = 122 + col * 118
        draw.rectangle((x, 180, x + 22, 842), fill=rgba("#ff52b0", 52 + col * 18))
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_pulse_scan(img: Image.Image) -> None:
    add_card_silhouettes(img, rgba("#7fe6ff", 74))
    add_scan_arc(img, (62, 206, 708, 852), rgba("#7ce8ff", 220), 18)
    add_slash(img, (232, 756), (574, 366), rgba("#fbffff"), rgba("#7ce8ff", 70), 10)


def motif_rescue_corridor(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon(
        [(214, 164), (554, 164), (676, 862), (92, 862)],
        fill=rgba("#fff6d8", 210),
    )
    draw.polygon(
        [(286, 250), (484, 250), (558, 814), (210, 814)],
        fill=rgba("#83e1ff", 122),
    )
    draw.ellipse((244, 650, 314, 814), fill=rgba("#22304d", 200))
    draw.ellipse((454, 616, 530, 820), fill=rgba("#22304d", 200))
    layer = layer.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(layer)


def motif_resonance_burst(img: Image.Image) -> None:
    add_orb(img, (384, 482), 120, rgba("#ffffff"), rgba("#76e2ff", 175))
    add_shards(img, rgba("#7ce8ff", 160), count=10, angle_shift=0.05)
    for radius in (170, 240):
        add_scan_arc(img, (384 - radius, 482 - radius, 384 + radius, 482 + radius), rgba("#d5fcff", 130), 10)


def motif_signal_relay(img: Image.Image) -> None:
    add_support_grid(img, rgba("#8fe9ff", 220))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon([(372, 242), (394, 242), (442, 684), (324, 684)], fill=rgba("#f3fcff", 214))
    layer = layer.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(layer)


def motif_tactical_calm(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for y in (264, 374, 490, 608):
        draw.arc((154, y - 96, 614, y + 96), 180, 360, fill=rgba("#9eefff", 180), width=12)
    draw.polygon([(384, 198), (444, 324), (384, 450), (324, 324)], fill=rgba("#f0fdff", 180))
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(layer)


def motif_tactical_reorder(img: Image.Image) -> None:
    add_card_silhouettes(img, rgba("#9eeaff", 90))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.arc((162, 382, 542, 772), 210, 322, fill=rgba("#ffe998", 220), width=24)
    draw.polygon([(514, 476), (610, 512), (548, 596)], fill=rgba("#ffe998", 220))
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(layer)


def motif_resonance_mark(img: Image.Image) -> None:
    add_orb(img, (384, 468), 84, rgba("#fbffff"), rgba("#7fe4ff", 190))
    for radius in (96, 166, 236):
        add_scan_arc(img, (384 - radius, 468 - radius, 384 + radius, 468 + radius), rgba("#95f0ff", 180), 12)
    add_shards(img, rgba("#d0fcff", 120), count=6, angle_shift=0.36)


def motif_channel_pulse(img: Image.Image) -> None:
    add_orb(img, (384, 654), 92, rgba("#fafdff"), rgba("#79e7ff", 180))
    add_slash(img, (384, 860), (384, 230), rgba("#fefefe"), rgba("#63dfff", 150), 24)
    for radius in (112, 188):
        add_scan_arc(img, (384 - radius, 654 - radius, 384 + radius, 654 + radius), rgba("#8beeff", 140), 10)


def motif_command_order(img: Image.Image) -> None:
    add_support_grid(img, rgba("#87efff", 220))
    add_card_silhouettes(img, rgba("#d8fbff", 62))
    add_text_band(img, rgba("#214566", 88))


def motif_command_overflow(img: Image.Image) -> None:
    add_support_grid(img, rgba("#9ef6ff", 235))
    add_card_silhouettes(img, rgba("#e6fcff", 78))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for radius, alpha in ((150, 210), (228, 160), (306, 110)):
        draw.arc((384 - radius, 472 - radius, 384 + radius, 472 + radius), 204, 336, fill=rgba("#ffe7a0", alpha), width=18)
    draw.polygon([(612, 422), (708, 478), (622, 548)], fill=rgba("#ffe7a0", 220))
    draw.line((174, 756, 612, 422), fill=rgba("#f8ffff", 170), width=12)
    draw.line((238, 812, 674, 500), fill=rgba("#9ef6ff", 150), width=10)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)
    add_text_band(img, rgba("#162f57", 98))


def motif_overload_sigils(img: Image.Image) -> None:
    add_orb(img, (384, 432), 120, rgba("#fff8dd"), rgba("#ff7447", 175))
    add_shards(img, rgba("#ffb562", 200), count=8, angle_shift=0.1)
    add_slash(img, (164, 830), (620, 256), rgba("#fffef0"), rgba("#68e6ff", 90), 24)


def motif_aoe_wave(img: Image.Image) -> None:
    add_orb(img, (384, 554), 92, rgba("#fbffff"), rgba("#69ddff", 170))
    for radius in (120, 206, 292):
        add_scan_arc(img, (384 - radius, 554 - radius, 384 + radius, 554 + radius), rgba("#a0f1ff", 190), 14)
    add_text_band(img, rgba("#1c3b61", 92))


def motif_crowned_resolve(img: Image.Image) -> None:
    add_orb(img, (384, 458), 94, rgba("#fffbe4"), rgba("#ffc25c", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    crown = [(252, 490), (306, 356), (384, 448), (462, 356), (516, 490), (516, 594), (252, 594)]
    draw.polygon(crown, fill=rgba("#fff0a8", 210), outline=rgba("#fffdf4"), width=8)
    layer = layer.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(layer)


def motif_resonance_harvest(img: Image.Image) -> None:
    add_orb(img, (384, 520), 86, rgba("#fbffff"), rgba("#6fe7ff", 200))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    nodes = [(174, 300), (606, 278), (180, 720), (594, 736), (384, 182)]
    for x, y in nodes:
        draw.line((x, y, 384, 520), fill=rgba("#a3f6ff", 180), width=10)
        draw.ellipse((x - 28, y - 28, x + 28, y + 28), fill=rgba("#e9fdff", 220), outline=rgba("#b8fbff"), width=4)
    draw.ellipse((274, 410, 494, 630), outline=rgba("#d3feff", 150), width=10)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)
    add_shards(img, rgba("#d9feff", 120), count=7, angle_shift=0.18)


def motif_harmonic_dominion(img: Image.Image) -> None:
    add_orb(img, (384, 430), 102, rgba("#fbffff"), rgba("#6fd0ff", 185))
    for radius in (126, 206, 288):
        add_scan_arc(img, (384 - radius, 430 - radius, 384 + radius, 430 + radius), rgba("#96efff", 170), 14)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    crown = [(238, 318), (304, 214), (384, 302), (464, 214), (530, 318), (520, 404), (248, 404)]
    draw.polygon(crown, fill=rgba("#f7edc0", 180), outline=rgba("#fffbee"), width=8)
    draw.line((240, 660, 528, 660), fill=rgba("#b0f7ff", 110), width=12)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_sevenfold_echo(img: Image.Image) -> None:
    add_orb(img, (248, 612), 72, rgba("#faffff"), rgba("#77deff", 180))
    for index in range(7):
        radius = 86 + index * 34
        add_scan_arc(img, (248 - radius, 612 - radius, 248 + radius, 612 + radius), rgba("#9cf3ff", max(70, 190 - index * 14)), 10)
    add_slash(img, (300, 642), (666, 484), rgba("#efffff"), rgba("#7b88ff", 110), 18)
    add_slash(img, (326, 744), (668, 606), rgba("#efffff"), rgba("#7b88ff", 84), 12)


def motif_unified_battleplan(img: Image.Image) -> None:
    add_support_grid(img, rgba("#89f0ff", 220))
    add_card_silhouettes(img, rgba("#e5fcff", 64))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.arc((146, 284, 622, 760), 208, 330, fill=rgba("#ffe9a4", 220), width=24)
    draw.polygon([(558, 500), (650, 536), (584, 616)], fill=rgba("#ffe9a4", 220))
    draw.rectangle((340, 200, 428, 312), fill=rgba("#f7fcff", 210), outline=rgba("#c4f7ff"), width=6)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_controlled_overload(img: Image.Image) -> None:
    motif_barrier_formula(img)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for angle in range(0, 360, 60):
        radians = math.radians(angle)
        x = 384 + math.cos(radians) * 180
        y = 450 + math.sin(radians) * 180
        draw.line((384, 450, int(x), int(y)), fill=rgba("#ffb778", 170), width=10)
    draw.polygon([(384, 242), (470, 450), (384, 658), (298, 450)], fill=rgba("#fff6dd", 100), outline=rgba("#ffd18b"), width=8)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)
    add_shards(img, rgba("#ff8656", 120), count=6, angle_shift=0.1)


def motif_voice_of_the_leader(img: Image.Image) -> None:
    add_orb(img, (384, 354), 88, rgba("#fffce9"), rgba("#ffc76c", 180))
    add_support_grid(img, rgba("#8cefff", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for y in (260, 352, 444):
        draw.line((180, y, 588, y), fill=rgba("#fff0bb", 140), width=10)
    draw.polygon([(384, 164), (432, 266), (384, 368), (336, 266)], fill=rgba("#fff9de", 180))
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(layer)


def motif_ashes_remember(img: Image.Image) -> None:
    add_orb(img, (388, 626), 112, rgba("#fff3d6"), rgba("#ff8151", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x, y in [(204, 286), (574, 232), (162, 650), (602, 712), (384, 176)]:
        draw.ellipse((x - 18, y - 18, x + 18, y + 18), fill=rgba("#fff0d0", 130))
        draw.line((x, y, 388, 626), fill=rgba("#ffb98f", 120), width=8)
    draw.arc((132, 262, 620, 852), 210, 336, fill=rgba("#ffd49f", 170), width=18)
    layer = layer.filter(ImageFilter.GaussianBlur(7))
    img.alpha_composite(layer)
    add_text_band(img, rgba("#5c1f1b", 98))


def motif_final_directive(img: Image.Image) -> None:
    add_support_grid(img, rgba("#8defff", 190))
    add_orb(img, (384, 454), 88, rgba("#faffff"), rgba("#71dfff", 175))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    triangle_up = [(384, 236), (512, 470), (256, 470)]
    triangle_down = [(384, 674), (540, 414), (228, 414)]
    draw.polygon(triangle_up, fill=rgba("#fff5d8", 74), outline=rgba("#fff4c4"), width=8)
    draw.polygon(triangle_down, fill=rgba("#7adfff", 56), outline=rgba("#c8fbff"), width=8)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_absolute_resonance(img: Image.Image) -> None:
    add_orb(img, (384, 470), 118, rgba("#fcffff"), rgba("#7ce0ff", 190))
    for radius in (142, 214, 292):
        add_scan_arc(img, (384 - radius, 470 - radius, 384 + radius, 470 + radius), rgba("#b2f6ff", 185), 14)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x, y in [(384, 158), (614, 470), (384, 782), (154, 470)]:
        draw.line((384, 470, x, y), fill=rgba("#d2fdff", 150), width=10)
        draw.ellipse((x - 22, y - 22, x + 22, y + 22), fill=rgba("#ffffff", 200))
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_landship_wide_order(img: Image.Image) -> None:
    add_support_grid(img, rgba("#8fefff", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    bridge = [(168, 662), (610, 662), (560, 820), (218, 820)]
    draw.polygon(bridge, fill=rgba("#f1ead1", 170), outline=rgba("#fff5d4"), width=8)
    for x in (244, 340, 436, 532):
        draw.rectangle((x, 560, x + 52, 662), fill=rgba("#d8fbff", 120), outline=rgba("#a7f6ff"), width=4)
    draw.arc((182, 280, 590, 768), 210, 330, fill=rgba("#ffe8aa", 200), width=18)
    layer = layer.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(layer)


def motif_ember_judgement(img: Image.Image) -> None:
    add_orb(img, (384, 286), 78, rgba("#fff9de"), rgba("#ff9c4a", 200))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    beam = [(350, 188), (418, 188), (468, 712), (300, 712)]
    draw.polygon(beam, fill=rgba("#fff2d5", 190), outline=rgba("#ffcf7d"), width=8)
    draw.ellipse((236, 640, 532, 892), outline=rgba("#ffc774", 180), width=18)
    draw.arc((180, 596, 588, 952), 200, 340, fill=rgba("#ff8660", 150), width=12)
    layer = layer.filter(ImageFilter.GaussianBlur(7))
    img.alpha_composite(layer)


def motif_unstable_resonance(img: Image.Image) -> None:
    add_orb(img, (384, 470), 104, rgba("#fbffff"), rgba("#6ddfff", 185))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    crack_paths = [
        [(298, 292), (374, 406), (312, 540), (432, 710)],
        [(500, 258), (404, 420), (474, 570), (352, 780)],
    ]
    for path in crack_paths:
        draw.line(path, fill=rgba("#ffffff", 180), width=10, joint="curve")
        draw.line(path, fill=rgba("#5ee1ff", 90), width=22, joint="curve")
    draw.ellipse((210, 296, 558, 644), outline=rgba("#a9f3ff", 150), width=12)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_mental_noise(img: Image.Image) -> None:
    motif_panic_static(img)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for y in range(220, 820, 74):
        draw.arc((136, y - 44, 642, y + 44), 188, 352, fill=rgba("#f0d7ff", 120), width=10)
    draw.rectangle((196, 422, 572, 574), outline=rgba("#fff0ff", 120), width=8)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_command_delay(img: Image.Image) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((242, 214, 526, 842), radius=34, outline=rgba("#e7ecff", 180), width=12)
    draw.polygon([(288, 292), (478, 292), (430, 448), (336, 448)], fill=rgba("#f6f7ff", 110))
    draw.polygon([(336, 608), (430, 608), (478, 764), (288, 764)], fill=rgba("#cbd5ff", 90))
    draw.line((384, 448, 384, 608), fill=rgba("#fffafe", 170), width=10)
    draw.line((274, 196, 538, 104), fill=rgba("#ff97aa", 160), width=20)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_ashen_guilt(img: Image.Image) -> None:
    add_orb(img, (392, 412), 84, rgba("#fff0e2"), rgba("#ff8a72", 160))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.arc((172, 220, 612, 748), 204, 340, fill=rgba("#ffd0c4", 150), width=18)
    draw.polygon([(384, 332), (470, 486), (426, 690), (342, 690), (298, 486)], fill=rgba("#fff5ef", 110), outline=rgba("#ffd4cc"), width=8)
    for x, y in [(278, 720), (336, 770), (402, 816), (468, 760), (520, 708)]:
        draw.ellipse((x - 16, y - 16, x + 16, y + 16), fill=rgba("#ff9f84", 130))
    layer = layer.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(layer)


def motif_shattered_focus(img: Image.Image) -> None:
    add_orb(img, (384, 468), 88, rgba("#fbffff"), rgba("#7bcfff", 160))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((190, 274, 578, 662), outline=rgba("#dff6ff", 180), width=12)
    shards = [
        [(354, 284), (410, 450), (328, 478)],
        [(470, 350), (446, 514), (574, 532)],
        [(258, 520), (384, 470), (302, 662)],
        [(404, 520), (470, 700), (582, 608)],
    ]
    for shard in shards:
        draw.polygon(shard, fill=rgba("#f0fdff", 120), outline=rgba("#d0f7ff"), width=4)
    draw.line((256, 304, 520, 630), fill=rgba("#ffffff", 160), width=8)
    draw.line((540, 286, 246, 700), fill=rgba("#ffffff", 120), width=6)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_guard_pulse(img: Image.Image) -> None:
    motif_barrier_formula(img)
    add_orb(img, (384, 710), 64, rgba("#fbffff"), rgba("#69dfff", 150))
    add_scan_arc(img, (222, 368, 546, 692), rgba("#c9fbff", 160), 12)
    add_scan_arc(img, (270, 416, 498, 644), rgba("#e2fdff", 130), 8)


def motif_mental_tuning(img: Image.Image) -> None:
    add_orb(img, (384, 472), 86, rgba("#faffff"), rgba("#7be1ff", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x in (272, 384, 496):
        draw.line((x, 232, x, 748), fill=rgba("#d7fbff", 150), width=12)
        draw.arc((x - 84, 268, x + 84, 436), 200, 340, fill=rgba("#a8f2ff", 150), width=10)
        draw.arc((x - 84, 544, x + 84, 712), 20, 160, fill=rgba("#a8f2ff", 150), width=10)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_field_command(img: Image.Image) -> None:
    add_support_grid(img, rgba("#8cefff", 190))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((268, 260, 500, 492), outline=rgba("#fff0bc", 180), width=12)
    draw.line((384, 212, 384, 540), fill=rgba("#fff4cf", 180), width=10)
    draw.line((220, 376, 548, 376), fill=rgba("#fff4cf", 180), width=10)
    draw.rectangle((324, 582, 444, 760), fill=rgba("#effcff", 130), outline=rgba("#c7f8ff"), width=6)
    layer = layer.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(layer)


def motif_focused_ray(img: Image.Image) -> None:
    add_orb(img, (250, 668), 60, rgba("#faffff"), rgba("#66ddff", 180))
    add_slash(img, (260, 678), (686, 422), rgba("#ffffff"), rgba("#56dfff", 180), 18)
    add_slash(img, (294, 700), (704, 478), rgba("#fff4cc"), rgba("#79a0ff", 84), 8)
    add_scan_arc(img, (204, 550, 340, 786), rgba("#b4f6ff", 120), 8)


def motif_tactical_briefing(img: Image.Image) -> None:
    add_card_silhouettes(img, rgba("#d8fbff", 76))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((244, 198, 528, 760), radius=28, fill=rgba("#f2ead5", 150), outline=rgba("#fff4d5"), width=8)
    for y in range(282, 666, 72):
        draw.line((292, y, 480, y), fill=rgba("#5b7482", 110), width=6)
    draw.arc((142, 356, 628, 842), 214, 326, fill=rgba("#ffeaa7", 200), width=20)
    draw.polygon([(550, 458), (644, 496), (578, 580)], fill=rgba("#ffeaa7", 210))
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_bloodline_casting(img: Image.Image) -> None:
    add_orb(img, (446, 416), 86, rgba("#fff7de"), rgba("#ff7a57", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line((232, 736, 552, 258), fill=rgba("#fff7e3", 150), width=18)
    draw.line((250, 764, 570, 286), fill=rgba("#ffb06f", 120), width=30)
    draw.ellipse((204, 662, 310, 820), fill=rgba("#3b1724", 200), outline=rgba("#ffd0c5"), width=6)
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(layer)
    add_shards(img, rgba("#ff9d77", 120), count=6, angle_shift=0.24)


def motif_arc_sliver(img: Image.Image) -> None:
    add_orb(img, (308, 666), 66, rgba("#fbffff"), rgba("#67deff", 160))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.arc((152, 346, 682, 876), 236, 312, fill=rgba("#ecffff", 220), width=34)
    draw.arc((220, 418, 650, 850), 238, 308, fill=rgba("#72e1ff", 120), width=14)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_mind_pressure(img: Image.Image) -> None:
    add_orb(img, (384, 476), 78, rgba("#fbffff"), rgba("#85d9ff", 150))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for pad in (0, 34, 74, 118):
        draw.rounded_rectangle((188 + pad, 282 + pad, 580 - pad, 674 - pad), radius=44, outline=rgba("#ffd0ce", max(70, 180 - pad)), width=10)
    draw.line((230, 330, 538, 638), fill=rgba("#ff866f", 120), width=10)
    draw.line((538, 330, 230, 638), fill=rgba("#ff866f", 120), width=10)
    layer = layer.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(layer)


def motif_harmonic_cut(img: Image.Image) -> None:
    add_orb(img, (250, 634), 58, rgba("#fbffff"), rgba("#63deff", 160))
    add_slash(img, (196, 692), (674, 366), rgba("#ffffff"), rgba("#55dfff", 150), 22)
    add_slash(img, (232, 754), (706, 462), rgba("#fffad8"), rgba("#7aa0ff", 90), 14)
    add_scan_arc(img, (300, 272, 700, 672), rgba("#c8fbff", 80), 8)


def motif_pressure_wave(img: Image.Image) -> None:
    add_orb(img, (216, 560), 56, rgba("#fbffff"), rgba("#6bdfff", 150))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for width, alpha in ((26, 190), (18, 140), (10, 110)):
        draw.arc((116, 330, 794, 1008), 250, 302, fill=rgba("#d8fdff", alpha), width=width)
    draw.polygon([(250, 496), (706, 384), (706, 620)], fill=rgba("#9cf2ff", 110))
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_echo_lattice(img: Image.Image) -> None:
    add_orb(img, (384, 462), 82, rgba("#faffff"), rgba("#69deff", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x in (242, 314, 384, 454, 526):
        draw.line((x, 248, x, 676), fill=rgba("#c6fbff", 130), width=8)
    for y in (274, 360, 446, 532, 618):
        draw.line((214, y, 554, y), fill=rgba("#c6fbff", 130), width=8)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(layer)


def motif_resonant_insight(img: Image.Image) -> None:
    add_orb(img, (384, 470), 64, rgba("#fbffff"), rgba("#7fe4ff", 180))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    eye = [(176, 470), (384, 280), (592, 470), (384, 660)]
    draw.polygon(eye, fill=rgba("#dffcff", 76), outline=rgba("#d3fbff"), width=10)
    for radius in (120, 192):
        add_scan_arc(img, (384 - radius, 470 - radius, 384 + radius, 470 + radius), rgba("#9cf1ff", 150), 10)
    layer = layer.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(layer)


def motif_grand_equation(img: Image.Image) -> None:
    add_orb(img, (384, 474), 84, rgba("#fffde9"), rgba("#79ddff", 165))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((210, 300, 558, 648), outline=rgba("#c1fbff", 140), width=10)
    draw.line((384, 220, 384, 728), fill=rgba("#fff2bd", 170), width=10)
    draw.line((196, 474, 572, 474), fill=rgba("#fff2bd", 170), width=10)
    draw.arc((252, 342, 516, 606), 210, 330, fill=rgba("#9defff", 140), width=10)
    layer = layer.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(layer)


def motif_final_vector(img: Image.Image) -> None:
    add_orb(img, (418, 338), 78, rgba("#fff7dc"), rgba("#ff8754", 170))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon([(378, 156), (452, 314), (494, 736), (342, 736)], fill=rgba("#fff6e3", 150), outline=rgba("#ffd59a"), width=8)
    draw.line((220, 822, 582, 214), fill=rgba("#67dcff", 110), width=22)
    draw.line((242, 842, 604, 234), fill=rgba("#fef6d8", 110), width=10)
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(layer)


def motif_default_card(img: Image.Image) -> None:
    add_card_silhouettes(img, rgba("#a3ebff", 84))
    add_orb(img, (384, 438), 92, rgba("#f8ffff"), rgba("#7edfff", 176))
    add_scan_arc(img, (174, 230, 594, 650), rgba("#a9efff", 150), 12)


CARD_DEFS: dict[str, dict[str, object]] = {
    "default_card": {"colors": ("#12213a", "#21456d", "#4e8fbe"), "motif": motif_default_card, "frame": "#b7f4ff"},
    "arts_bolt": {"colors": ("#0c2038", "#1b4476", "#244f8e"), "motif": motif_arts_bolt, "frame": "#75efff"},
    "barrier_formula": {"colors": ("#09273b", "#1c5878", "#53a6cc"), "motif": motif_barrier_formula, "frame": "#abf2ff"},
    "blast_countdown": {"colors": ("#3b0f12", "#7d2918", "#c7511c"), "motif": motif_blast_countdown, "frame": "#ffc36e"},
    "burn_will": {"colors": ("#321010", "#7b2416", "#ff6d2c"), "motif": motif_burn_will, "frame": "#ffd38f"},
    "command_sync": {"colors": ("#101938", "#1e3f74", "#2e7eb9"), "motif": motif_command_sync, "frame": "#9aeeff"},
    "discipline_note": {"colors": ("#211314", "#603131", "#b15b43"), "motif": motif_discipline_note, "frame": "#ffe6c5"},
    "echo_conduit": {"colors": ("#16163a", "#284788", "#5cc4ff"), "motif": motif_echo_conduit, "frame": "#a4efff"},
    "emergency_shield": {"colors": ("#13243a", "#28586d", "#57b6d3"), "motif": motif_emergency_shield, "frame": "#c1f8ff"},
    "focus_pulse": {"colors": ("#111a40", "#283f84", "#3263c2"), "motif": motif_focus_pulse, "frame": "#97efff"},
    "guided_fire": {"colors": ("#112347", "#264c7c", "#4d7dc9"), "motif": motif_guided_fire, "frame": "#b2f4ff"},
    "hesitation": {"colors": ("#1b1831", "#35224a", "#574371"), "motif": motif_hesitation, "frame": "#c8dcff"},
    "mind_alignment": {"colors": ("#0f2340", "#214c7c", "#60c6e9"), "motif": motif_mind_alignment, "frame": "#a8f2ff"},
    "overclock_arts": {"colors": ("#291328", "#5a244e", "#ff7347"), "motif": motif_overclock_arts, "frame": "#ffe1a4"},
    "panic_static": {"colors": ("#120b1d", "#381441", "#7a2f8a"), "motif": motif_panic_static, "frame": "#efbbff"},
    "pulse_scan": {"colors": ("#0e2235", "#214067", "#2f7da7"), "motif": motif_pulse_scan, "frame": "#a7f0ff"},
    "rescue_corridor": {"colors": ("#1f1d34", "#4f4b75", "#b7a66e"), "motif": motif_rescue_corridor, "frame": "#fff1bc"},
    "resonance_burst": {"colors": ("#162043", "#234c81", "#4caed7"), "motif": motif_resonance_burst, "frame": "#b8f9ff"},
    "resonance_mark": {"colors": ("#112342", "#254a7d", "#4fb4d2"), "motif": motif_resonance_mark, "frame": "#b9f6ff"},
    "signal_relay": {"colors": ("#14224a", "#244577", "#3985bd"), "motif": motif_signal_relay, "frame": "#b4f6ff"},
    "tactical_calm": {"colors": ("#18313d", "#225969", "#6cc4b7"), "motif": motif_tactical_calm, "frame": "#cffdfd"},
    "tactical_reorder": {"colors": ("#16253d", "#284c76", "#f0bc5a"), "motif": motif_tactical_reorder, "frame": "#fff3c8"},
    "guard_pulse": {"colors": ("#0d2639", "#225775", "#58a8cf"), "motif": motif_guard_pulse, "frame": "#c6f8ff"},
    "mental_tuning": {"colors": ("#102241", "#224d7a", "#63c5e7"), "motif": motif_mental_tuning, "frame": "#aef2ff"},
    "field_command": {"colors": ("#132447", "#24497a", "#3b7fb7"), "motif": motif_field_command, "frame": "#b8f6ff"},
    "focused_ray": {"colors": ("#101a3f", "#27427e", "#3e84d0"), "motif": motif_focused_ray, "frame": "#a7efff"},
    "tactical_briefing": {"colors": ("#16253d", "#274b73", "#c0a35b"), "motif": motif_tactical_briefing, "frame": "#fff0bc"},
    "bloodline_casting": {"colors": ("#311010", "#7a2418", "#cc4f2f"), "motif": motif_bloodline_casting, "frame": "#ffd79e"},
    "channel_pulse": {"colors": ("#101f3d", "#234778", "#49a9d2"), "motif": motif_channel_pulse, "frame": "#b5f5ff"},
    "stabilize_line": {"colors": ("#13263a", "#28576f", "#7ec3de"), "motif": motif_emergency_shield, "frame": "#d2fbff"},
    "arc_sliver": {"colors": ("#0d203c", "#214475", "#3f7dc0"), "motif": motif_arc_sliver, "frame": "#a0efff"},
    "mind_pressure": {"colors": ("#211433", "#53304b", "#c65b62"), "motif": motif_mind_pressure, "frame": "#ffd6cb"},
    "harmonic_cut": {"colors": ("#132142", "#20497d", "#488fd4"), "motif": motif_harmonic_cut, "frame": "#aff2ff"},
    "pressure_wave": {"colors": ("#10223d", "#224a79", "#57a8d0"), "motif": motif_pressure_wave, "frame": "#bcf7ff"},
    "echo_lattice": {"colors": ("#161b3d", "#2a4a88", "#55c5ff"), "motif": motif_echo_lattice, "frame": "#b5f6ff"},
    "resonant_insight": {"colors": ("#12243d", "#25486f", "#6ec8d9"), "motif": motif_resonant_insight, "frame": "#cff8ff"},
    "crowned_resolve": {"colors": ("#3c2210", "#8b5a1c", "#e3b04e"), "motif": motif_crowned_resolve, "frame": "#fff0b0"},
    "grand_equation": {"colors": ("#172041", "#284a7d", "#57b0da"), "motif": motif_grand_equation, "frame": "#c3f8ff"},
    "final_vector": {"colors": ("#231528", "#5d2248", "#c74e47"), "motif": motif_final_vector, "frame": "#ffe1b4"},
    "overclock_casting": {"colors": ("#291226", "#612449", "#ff7549"), "motif": motif_overload_sigils, "frame": "#ffe0ab"},
    "measured_blast": {"colors": ("#25131c", "#6d2328", "#dc6738"), "motif": motif_burn_will, "frame": "#ffd79c"},
    "clear_intent": {"colors": ("#0f243b", "#23486f", "#7cd0e0"), "motif": motif_pulse_scan, "frame": "#d2fbff"},
    "phase_tap": {"colors": ("#12223d", "#204772", "#55abd0"), "motif": motif_resonance_mark, "frame": "#bdf6ff"},
    "split_tone": {"colors": ("#101d42", "#22457d", "#4d8ed8"), "motif": motif_guided_fire, "frame": "#a8f0ff"},
    "coordinated_strike": {"colors": ("#132240", "#27466e", "#4ea0c5"), "motif": motif_command_order, "frame": "#b9f7ff"},
    "rhodes_formation": {"colors": ("#112340", "#24466f", "#58adc9"), "motif": motif_command_order, "frame": "#c5fbff"},
    "desperate_focus": {"colors": ("#2f111d", "#7b2330", "#d35f57"), "motif": motif_burn_will, "frame": "#ffd4c0"},
    "crisis_surge": {"colors": ("#22142e", "#56305a", "#de6a58"), "motif": motif_overclock_arts, "frame": "#ffd8b2"},
    "arc_collapse": {"colors": ("#1d172c", "#56284f", "#ff7850"), "motif": motif_overload_sigils, "frame": "#ffe0b0"},
    "controlled_detonation": {"colors": ("#321415", "#7f281d", "#df6b3e"), "motif": motif_blast_countdown, "frame": "#ffd8a1"},
    "thought_acceleration": {"colors": ("#102440", "#234b79", "#79cfe4"), "motif": motif_mind_alignment, "frame": "#c6fbff"},
    "widened_spectrum": {"colors": ("#10233c", "#234b77", "#57b1ce"), "motif": motif_aoe_wave, "frame": "#cdf8ff"},
    "tactical_network": {"colors": ("#132342", "#264a76", "#5da9cb"), "motif": motif_command_order, "frame": "#c2fbff"},
    "command_overflow": {"colors": ("#142440", "#2a4e79", "#d2ae65"), "motif": motif_command_overflow, "frame": "#fff2c5"},
    "chain_reaction": {"colors": ("#112343", "#244b7d", "#5ab1db"), "motif": motif_aoe_wave, "frame": "#c3f8ff"},
    "emergency_order": {"colors": ("#14233f", "#274a73", "#d2ab64"), "motif": motif_command_order, "frame": "#fff1c2"},
    "dobermann_drill_order": {"colors": ("#23161b", "#6a2f2a", "#ce7852"), "motif": motif_tactical_reorder, "frame": "#ffe1bd"},
    "exusiai_cover_fire": {"colors": ("#111e44", "#25477f", "#4f93d7"), "motif": motif_guided_fire, "frame": "#b8f4ff"},
    "precise_break": {"colors": ("#10203e", "#234880", "#4ca2da"), "motif": motif_focus_pulse, "frame": "#b7f4ff"},
    "resonance_field": {"colors": ("#10233f", "#254876", "#64b6d8"), "motif": motif_resonance_mark, "frame": "#c4f8ff"},
    "prism_shatter": {"colors": ("#152347", "#264c82", "#5db7df"), "motif": motif_resonance_burst, "frame": "#c6fbff"},
    "medical_evac_route": {"colors": ("#172539", "#36586d", "#8eb8c7"), "motif": motif_rescue_corridor, "frame": "#eefcff"},
    "elite_coordination": {"colors": ("#18213e", "#2a4a77", "#7db6d2"), "motif": motif_command_order, "frame": "#d2fbff"},
    "tactical_encirclement": {"colors": ("#152141", "#264a7b", "#63a8d1"), "motif": motif_guided_fire, "frame": "#c1f8ff"},
    "harmonic_spike": {"colors": ("#112143", "#21467b", "#56a5d7"), "motif": motif_guided_fire, "frame": "#bdf6ff"},
    "reckless_invocation": {"colors": ("#301319", "#7a241f", "#e26c40"), "motif": motif_overload_sigils, "frame": "#ffd7a0"},
    "ace_last_stand": {"colors": ("#1b2338", "#3c556d", "#9fc5d2"), "motif": motif_rescue_corridor, "frame": "#eefcff"},
    "black_ring_method": {"colors": ("#23142d", "#5a2450", "#cf5e52"), "motif": motif_overload_sigils, "frame": "#ffe1b4"},
    "survival_reflex": {"colors": ("#1d2537", "#456072", "#9ec3cb"), "motif": motif_rescue_corridor, "frame": "#f0fcff"},
    "will_transfusion": {"colors": ("#152243", "#284b7d", "#70c7e7"), "motif": motif_mind_alignment, "frame": "#c8fbff"},
    "mirrored_wave": {"colors": ("#182045", "#294b84", "#6bc7ff"), "motif": motif_echo_conduit, "frame": "#c6f7ff"},
    "last_argument": {"colors": ("#2b1625", "#6e2337", "#d55f54"), "motif": motif_overclock_arts, "frame": "#ffd7b1"},
    "terminal_appeal": {"colors": ("#27131f", "#6d2430", "#d36b4f"), "motif": motif_burn_will, "frame": "#ffd7ae"},
    "ashes_to_ashes": {"colors": ("#2a1320", "#65253d", "#dc6c4b"), "motif": motif_aoe_wave, "frame": "#ffe0b2"},
    "frequency_lock": {"colors": ("#112240", "#244a79", "#57b2d2"), "motif": motif_resonance_mark, "frame": "#c2f8ff"},
    "strategic_rotation": {"colors": ("#16253d", "#284a72", "#c3a35c"), "motif": motif_tactical_reorder, "frame": "#fff0bf"},
    "forbidden_formula": {"colors": ("#29131e", "#6e2433", "#d96845"), "motif": motif_overclock_arts, "frame": "#ffd8a8"},
    "unstable_channel": {"colors": ("#101f3d", "#244778", "#52abd4"), "motif": motif_channel_pulse, "frame": "#baf7ff"},
    "collapse_frequency": {"colors": ("#152245", "#254a82", "#61b8dc"), "motif": motif_resonance_burst, "frame": "#c6fbff"},
    "feedback_loop": {"colors": ("#162043", "#2a4c86", "#65c8ff"), "motif": motif_echo_conduit, "frame": "#c7f8ff"},
    "blaze_forward_breach": {"colors": ("#2b1617", "#7a2a22", "#e17a44"), "motif": motif_aoe_wave, "frame": "#ffdcb0"},
    "greythroat_suppression": {"colors": ("#122243", "#274881", "#5ea3da"), "motif": motif_guided_fire, "frame": "#bdf6ff"},
    "frostleaf_delay_field": {"colors": ("#11253a", "#2b5d75", "#8fd2e4"), "motif": motif_tactical_calm, "frame": "#defdff"},
    "pain_for_power": {"colors": ("#2a131d", "#722537", "#d9655c"), "motif": motif_burn_will, "frame": "#ffd2c2"},
    "burn": {"colors": ("#301013", "#7f2918", "#e16f35"), "motif": motif_blast_countdown, "frame": "#ffd59b"},
    "nerve_burn": {"colors": ("#29131d", "#6f2431", "#de6740"), "motif": motif_burn_will, "frame": "#ffd8ab"},
    "overloaded_nerves": {"colors": ("#1f1026", "#4d1d3f", "#9a4b62"), "motif": motif_panic_static, "frame": "#f1cbff"},
    "sealed_chimera": {"colors": ("#241429", "#5a2650", "#c7635d"), "motif": motif_overload_sigils, "frame": "#ffe0b8"},
    "zero_range_cast": {"colors": ("#11203f", "#254983", "#5bb1e2"), "motif": motif_focus_pulse, "frame": "#c7f8ff"},
    "singing_fracture": {"colors": ("#142044", "#274984", "#65b9e7"), "motif": motif_guided_fire, "frame": "#c5f8ff"},
    "voice_of_the_team": {"colors": ("#132341", "#274973", "#6bb1ce"), "motif": motif_command_order, "frame": "#d2fbff"},
    "shared_burden": {"colors": ("#1d2138", "#45546e", "#9eb8c9"), "motif": motif_rescue_corridor, "frame": "#edfaff"},
    "forbidden_crown": {"colors": ("#2c1826", "#6a2444", "#d26b55"), "motif": motif_crowned_resolve, "frame": "#ffe0b2"},
    "chimera_protocol": {"colors": ("#181e43", "#2d4883", "#6cc7ff"), "motif": motif_resonance_burst, "frame": "#c6f7ff"},
    "the_cost_of_mercy": {"colors": ("#1b233a", "#3d546d", "#b4c7d6"), "motif": motif_rescue_corridor, "frame": "#f1fcff"},
    "resonance_harvest": {"colors": ("#112240", "#25497d", "#68c4e7"), "motif": motif_resonance_harvest, "frame": "#c7fbff"},
    "harmonic_dominion": {"colors": ("#171f43", "#354d8a", "#69bfff"), "motif": motif_harmonic_dominion, "frame": "#c8f7ff"},
    "sevenfold_echo": {"colors": ("#161f43", "#2c4e88", "#77cfff"), "motif": motif_sevenfold_echo, "frame": "#cdf8ff"},
    "unified_battleplan": {"colors": ("#15243f", "#284c75", "#d1b066"), "motif": motif_unified_battleplan, "frame": "#fff0c3"},
    "controlled_overload": {"colors": ("#241726", "#582848", "#c96e5d"), "motif": motif_controlled_overload, "frame": "#ffe1ba"},
    "voice_of_the_leader": {"colors": ("#17233f", "#294a77", "#d2ba7c"), "motif": motif_voice_of_the_leader, "frame": "#fff0bf"},
    "ashes_remember": {"colors": ("#26141d", "#6a2437", "#d96d4e"), "motif": motif_ashes_remember, "frame": "#ffdcb2"},
    "final_directive": {"colors": ("#16233c", "#284b74", "#caa55e"), "motif": motif_final_directive, "frame": "#fff0bd"},
    "absolute_resonance": {"colors": ("#171f44", "#2b4b82", "#78d1ff"), "motif": motif_absolute_resonance, "frame": "#d0faff"},
    "landship_wide_order": {"colors": ("#18243c", "#2d4f73", "#d9b975"), "motif": motif_landship_wide_order, "frame": "#fff2c6"},
    "ember_judgement": {"colors": ("#2b151c", "#7a2430", "#e06f43"), "motif": motif_ember_judgement, "frame": "#ffd8aa"},
    "unstable_resonance": {"colors": ("#12213f", "#25497c", "#63b8dd"), "motif": motif_unstable_resonance, "frame": "#c5f9ff"},
    "mental_noise": {"colors": ("#171125", "#401b46", "#8a3da2"), "motif": motif_mental_noise, "frame": "#f0c6ff"},
    "command_delay": {"colors": ("#1b1831", "#40315c", "#9f87c7"), "motif": motif_command_delay, "frame": "#dfd4ff"},
    "ashen_guilt": {"colors": ("#24141d", "#5c2236", "#a84d57"), "motif": motif_ashen_guilt, "frame": "#ffd3de"},
    "shattered_focus": {"colors": ("#16192d", "#32406a", "#92b4d4"), "motif": motif_shattered_focus, "frame": "#e5f2ff"},
}


def render_card(card_id: str, drawer: Callable[[Image.Image], None], colors: tuple[str, str, str], frame_color: str) -> Image.Image:
    base = gradient_background((WIDTH, HEIGHT), rgba(colors[0]), rgba(colors[1]), rgba(colors[2], 118))
    drawer(base)
    add_frame(base, rgba(frame_color, 220))
    base = apply_vignette(base)
    return base


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for card_id, config in CARD_DEFS.items():
        image = render_card(
            card_id,
            config["motif"],  # type: ignore[arg-type]
            config["colors"],  # type: ignore[arg-type]
            config["frame"],  # type: ignore[arg-type]
        )
        image.save(OUTPUT_DIR / f"{card_id}.png")


if __name__ == "__main__":
    main()
