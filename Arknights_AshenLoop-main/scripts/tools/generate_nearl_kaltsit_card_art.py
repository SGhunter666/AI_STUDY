from __future__ import annotations

import hashlib
import math
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
CARD_DATA_DIR = ROOT / "data" / "cards"
OUTPUT_DIR = ROOT / "assets" / "card_art"
WIDTH = 768
HEIGHT = 1024

Color = tuple[int, int, int, int]


def rgba(hex_color: str, alpha: int = 255) -> Color:
	hex_color = hex_color.lstrip("#")
	return (
		int(hex_color[0:2], 16),
		int(hex_color[2:4], 16),
		int(hex_color[4:6], 16),
		alpha,
	)


def stable_seed(value: str) -> int:
	return int(hashlib.sha256(value.encode("utf-8")).hexdigest()[:16], 16)


def parse_card(path: Path) -> dict:
	text = path.read_text(encoding="utf-8")

	def string_value(key: str, default: str = "") -> str:
		match = re.search(r'^%s = "(.*)"$' % re.escape(key), text, re.MULTILINE)
		return match.group(1) if match else default

	tags_match = re.search(r"^tags = PackedStringArray\((.*)\)$", text, re.MULTILINE)
	tags = re.findall(r'"([^"]+)"', tags_match.group(1)) if tags_match else []
	return {
		"id": string_value("id"),
		"name": string_value("display_name"),
		"type": string_value("card_type"),
		"description": string_value("description"),
		"rarity": string_value("rarity"),
		"tags": tags,
	}


def mix(a: Color, b: Color, t: float) -> Color:
	return (
		int(a[0] + (b[0] - a[0]) * t),
		int(a[1] + (b[1] - a[1]) * t),
		int(a[2] + (b[2] - a[2]) * t),
		int(a[3] + (b[3] - a[3]) * t),
	)


def gradient(top: Color, bottom: Color) -> Image.Image:
	img = Image.new("RGBA", (WIDTH, HEIGHT), top)
	pixels = img.load()
	for y in range(HEIGHT):
		t = y / float(HEIGHT - 1)
		line = mix(top, bottom, t)
		for x in range(WIDTH):
			pixels[x, y] = line
	return img


def blur_composite(base: Image.Image, layer: Image.Image, blur: int) -> None:
	base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def line_glow(img: Image.Image, start: tuple[int, int], end: tuple[int, int], glow: Color, core: Color, width: int) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.line((start, end), fill=glow, width=width + 26)
	blur_composite(img, layer, 18)
	draw = ImageDraw.Draw(img)
	draw.line((start, end), fill=core, width=width)
	draw.line((start, end), fill=(255, 255, 255, 150), width=max(2, width // 4))


def ellipse_glow(img: Image.Image, box: tuple[int, int, int, int], glow: Color, outline: Color, width: int) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.ellipse(box, outline=glow, width=width + 22)
	blur_composite(img, layer, 16)
	draw = ImageDraw.Draw(img)
	draw.ellipse(box, outline=outline, width=width)


def polygon_glow(img: Image.Image, points: list[tuple[int, int]], glow: Color, fill: Color, outline: Color | None = None) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.polygon(points, fill=glow)
	blur_composite(img, layer, 14)
	draw = ImageDraw.Draw(img)
	draw.polygon(points, fill=fill)
	if outline is not None:
		draw.line(points + [points[0]], fill=outline, width=6)


def add_frame(img: Image.Image, accent: Color, rarity: str, upgraded: bool) -> None:
	draw = ImageDraw.Draw(img)
	draw.rounded_rectangle((28, 28, WIDTH - 28, HEIGHT - 28), radius=42, outline=accent, width=8)
	draw.rounded_rectangle((52, 52, WIDTH - 52, HEIGHT - 52), radius=28, outline=(255, 255, 255, 70), width=2)
	if upgraded:
		for offset in (78, 118, 158):
			draw.line((WIDTH - offset, 64, WIDTH - 64, offset), fill=(255, 255, 255, 120), width=4)
	if rarity in {"Rare", "Legendary"} or "_l" in rarity.lower():
		ellipse_glow(img, (206, 130, 562, 486), accent, (255, 255, 255, 110), 5)


def add_texture_noise(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	for _ in range(52):
		x = rnd.randint(40, WIDTH - 40)
		y = rnd.randint(40, HEIGHT - 40)
		length = rnd.randint(34, 180)
		angle = rnd.uniform(-0.9, 0.9)
		end = (int(x + math.cos(angle) * length), int(y + math.sin(angle) * length))
		draw.line((x, y, end[0], end[1]), fill=(accent[0], accent[1], accent[2], rnd.randint(18, 58)), width=rnd.randint(1, 4))
	blur_composite(img, layer, 2)


def nearl_shield(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	x = rnd.randint(326, 420)
	y = rnd.randint(302, 388)
	points = [(x, y - 190), (x + 150, y - 94), (x + 120, y + 132), (x, y + 240), (x - 120, y + 132), (x - 150, y - 94)]
	polygon_glow(img, points, (255, 228, 120, 96), (235, 242, 232, 150), accent)
	draw = ImageDraw.Draw(img)
	draw.line((x, y - 138, x, y + 140), fill=(255, 228, 150, 190), width=9)
	draw.line((x - 74, y - 44, x + 74, y - 44), fill=(255, 255, 255, 120), width=5)


def nearl_lance(img: Image.Image, rnd: random.Random, accent: Color, strong: bool = False) -> None:
	angle = rnd.uniform(-0.84, -0.54)
	length = 850 if strong else 720
	cx, cy = rnd.randint(312, 430), rnd.randint(610, 720)
	dx, dy = math.cos(angle), math.sin(angle)
	start = (int(cx - dx * length * 0.45), int(cy - dy * length * 0.45))
	end = (int(cx + dx * length * 0.55), int(cy + dy * length * 0.55))
	line_glow(img, start, end, (255, 226, 118, 110), (255, 248, 214, 230), 22 if strong else 16)
	tip = [(end[0], end[1]), (int(end[0] - dy * 46 - dx * 86), int(end[1] + dx * 46 - dy * 86)), (int(end[0] + dy * 46 - dx * 86), int(end[1] - dx * 46 - dy * 86))]
	polygon_glow(img, tip, (255, 228, 132, 92), (255, 255, 238, 230), accent)


def nearl_radiance(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	center = (rnd.randint(330, 430), rnd.randint(260, 360))
	for radius in (72, 126, 188):
		ellipse_glow(img, (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius), (255, 226, 118, 74), accent, 4)
	for i in range(12):
		angle = math.tau * i / 12.0 + rnd.uniform(-0.08, 0.08)
		start = (int(center[0] + math.cos(angle) * 66), int(center[1] + math.sin(angle) * 66))
		end = (int(center[0] + math.cos(angle) * rnd.randint(230, 410)), int(center[1] + math.sin(angle) * rnd.randint(230, 410)))
		line_glow(img, start, end, (255, 226, 118, 72), (255, 250, 200, 160), 7)


def nearl_counter(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	draw = ImageDraw.Draw(img)
	for i in range(3):
		y = 394 + i * 112 + rnd.randint(-24, 24)
		points = [(180, y), (326, y - 70), (292, y - 12), (590, y - 12), (590, y + 12), (292, y + 12), (326, y + 70)]
		polygon_glow(img, points, (255, 232, 130, 70), (255, 242, 192, 120), accent)
		draw.line((190, y, 570, y), fill=(255, 255, 255, 115), width=4)


def kaltsit_mon3tr(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	x = rnd.randint(342, 432)
	y = rnd.randint(376, 468)
	body = [(x - 160, y + 158), (x - 92, y - 122), (x + 6, y - 186), (x + 122, y - 94), (x + 152, y + 176), (x + 34, y + 96)]
	polygon_glow(img, body, (80, 255, 205, 76), (21, 34, 38, 222), accent)
	for offset in (-110, -54, 20, 88):
		line_glow(img, (x + offset, y + 80), (x + offset + rnd.randint(-80, 80), y + 390), (82, 255, 205, 60), (175, 255, 232, 180), 8)
	draw = ImageDraw.Draw(img)
	draw.ellipse((x - 38, y - 58, x + 38, y + 18), fill=(169, 255, 230, 210))


def kaltsit_medical(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	cx, cy = rnd.randint(326, 430), rnd.randint(330, 430)
	draw = ImageDraw.Draw(img)
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	ld = ImageDraw.Draw(layer)
	ld.rounded_rectangle((cx - 54, cy - 176, cx + 54, cy + 176), radius=18, fill=(120, 255, 214, 90))
	ld.rounded_rectangle((cx - 176, cy - 54, cx + 176, cy + 54), radius=18, fill=(120, 255, 214, 90))
	blur_composite(img, layer, 18)
	draw.rounded_rectangle((cx - 42, cy - 148, cx + 42, cy + 148), radius=14, fill=(223, 255, 244, 180), outline=accent, width=5)
	draw.rounded_rectangle((cx - 148, cy - 42, cx + 148, cy + 42), radius=14, fill=(223, 255, 244, 180), outline=accent, width=5)


def kaltsit_command(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	draw = ImageDraw.Draw(img)
	for x in range(126, 674, 92):
		draw.line((x, 130, x + rnd.randint(-42, 42), 880), fill=(accent[0], accent[1], accent[2], 72), width=3)
	for y in range(160, 880, 88):
		draw.line((94, y, 674, y + rnd.randint(-26, 26)), fill=(accent[0], accent[1], accent[2], 58), width=3)
	for _ in range(8):
		cx = rnd.randint(144, 624)
		cy = rnd.randint(170, 810)
		ellipse_glow(img, (cx - 24, cy - 24, cx + 24, cy + 24), (88, 255, 214, 58), accent, 4)


def kaltsit_meltdown(img: Image.Image, rnd: random.Random) -> None:
	center = (rnd.randint(350, 430), rnd.randint(420, 520))
	for radius, alpha in ((240, 48), (158, 82), (74, 150)):
		ellipse_glow(img, (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius), (255, 92, 62, alpha), (255, 185, 118, min(220, alpha + 50)), 8)
	for i in range(10):
		angle = math.tau * i / 10.0 + rnd.uniform(-0.12, 0.12)
		end = (int(center[0] + math.cos(angle) * rnd.randint(240, 500)), int(center[1] + math.sin(angle) * rnd.randint(240, 500)))
		line_glow(img, center, end, (255, 82, 48, 64), (255, 190, 132, 170), rnd.randint(6, 12))


def add_type_badge(img: Image.Image, card: dict, accent: Color) -> None:
	draw = ImageDraw.Draw(img)
	type_name = card["type"]
	if type_name == "Attack":
		points = [(112, 782), (206, 704), (184, 828), (292, 858), (168, 880)]
		polygon_glow(img, points, (255, 255, 255, 48), (255, 255, 255, 120), accent)
	elif type_name == "Skill":
		draw.rounded_rectangle((104, 744, 268, 908), radius=28, outline=accent, width=8)
		draw.line((134, 826, 238, 826), fill=(255, 255, 255, 120), width=8)
		draw.line((186, 774, 186, 878), fill=(255, 255, 255, 120), width=8)
	else:
		ellipse_glow(img, (94, 728, 282, 916), (255, 255, 255, 42), accent, 6)


def add_variant_marks(img: Image.Image, card: dict, rnd: random.Random, accent: Color) -> None:
	draw = ImageDraw.Draw(img)
	seed = stable_seed(card["id"])
	for i in range(5):
		x = 520 + i * 28
		y = 782 + ((seed >> (i * 3)) & 7) * 16
		draw.rounded_rectangle((x, y, x + 16, y + 80), radius=7, fill=(accent[0], accent[1], accent[2], 112))
	if card["id"].endswith("_plus"):
		draw.polygon([(620, 98), (674, 126), (620, 154), (646, 126)], fill=(255, 255, 255, 180))


def render_nearl(card: dict) -> Image.Image:
	rnd = random.Random(stable_seed(card["id"]))
	accent = rgba("#ffe171", 230)
	img = gradient(rgba("#2a251f"), rgba("#f0e1b8", 118))
	add_texture_noise(img, rnd, accent)
	text = card["name"] + card["description"] + " ".join(card["tags"])
	if any(key in text for key in ("护盾", "防线", "壁垒", "守", "Shield", "Barrier")):
		nearl_shield(img, rnd, accent)
	if any(key in text for key in ("反击", "回击", "Counter")):
		nearl_counter(img, rnd, accent)
	if any(key in text for key in ("光耀", "耀", "辉", "Radiance", "Luminous")):
		nearl_radiance(img, rnd, accent)
	if card["type"] == "Attack" or any(key in text for key in ("斩", "枪", "锋", "Lance", "Strike")):
		nearl_lance(img, rnd, accent, "Legendary" in card["rarity"] or card["id"].endswith("_plus"))
	if all(key not in text for key in ("护盾", "反击", "光耀", "斩", "枪", "锋")):
		nearl_shield(img, rnd, accent)
		nearl_radiance(img, rnd, accent)
	add_type_badge(img, card, accent)
	add_variant_marks(img, card, rnd, accent)
	add_frame(img, accent, card["rarity"], card["id"].endswith("_plus"))
	return img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=120, threshold=4))


def render_kaltsit(card: dict) -> Image.Image:
	rnd = random.Random(stable_seed(card["id"]))
	accent = rgba("#7fffd8", 230)
	img = gradient(rgba("#111a1c"), rgba("#335a54", 130))
	add_texture_noise(img, rnd, accent)
	text = card["name"] + card["description"] + " ".join(card["tags"])
	if any(key in text for key in ("Mon3tr", "mon3tr", "融毁", "过载", "Overpressure", "Meltdown")):
		kaltsit_mon3tr(img, rnd, accent)
	if any(key in text for key in ("融毁", "熔毁", "meltdown", "Meltdown", "过压", "Overpressure")):
		kaltsit_meltdown(img, rnd)
	if any(key in text for key in ("治疗", "修复", "医疗", "完整性", "注射", "Surgery", "Repair", "Medical")):
		kaltsit_medical(img, rnd, accent)
	if any(key in text for key in ("指令", "协议", "调度", "校准", "Command", "Protocol", "Scheduling", "Calibration")) or card["type"] == "Skill":
		kaltsit_command(img, rnd, accent)
	if card["type"] == "Attack" and "Mon3tr" not in text:
		line_glow(img, (rnd.randint(110, 210), rnd.randint(780, 880)), (rnd.randint(520, 660), rnd.randint(180, 280)), (122, 255, 218, 90), (235, 255, 248, 220), 18)
	if all(key not in text for key in ("Mon3tr", "融毁", "治疗", "修复", "指令", "协议", "校准")):
		kaltsit_command(img, rnd, accent)
		kaltsit_medical(img, rnd, accent)
	add_type_badge(img, card, accent)
	add_variant_marks(img, card, rnd, accent)
	add_frame(img, accent, card["rarity"], card["id"].endswith("_plus"))
	return img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=125, threshold=4))


def main() -> None:
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	count = 0
	for path in sorted(CARD_DATA_DIR.glob("*.tres")):
		card = parse_card(path)
		card_id = card["id"]
		if card_id.startswith("nearl_"):
			render_nearl(card).save(OUTPUT_DIR / f"{card_id}.png")
			count += 1
		elif card_id.startswith("kaltsit_"):
			render_kaltsit(card).save(OUTPUT_DIR / f"{card_id}.png")
			count += 1
	print(f"GENERATED_NEARL_KALTSIT_CARD_ART: {count}")


if __name__ == "__main__":
	main()
