from __future__ import annotations

import hashlib
import math
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
CARD_DATA_DIR = ROOT / "data" / "cards"
MODULE_DATA_DIR = ROOT / "data" / "modules"
CARD_OUTPUT_DIR = ROOT / "assets" / "card_art"
MODULE_OUTPUT_DIR = ROOT / "assets" / "module_icons"

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


def parse_tres(path: Path) -> dict:
	text = path.read_text(encoding="utf-8")

	def string_value(key: str, default: str = "") -> str:
		match = re.search(r'^%s = "(.*)"$' % re.escape(key), text, re.MULTILINE)
		return match.group(1) if match else default

	tags_match = re.search(r"^tags = PackedStringArray\((.*)\)$", text, re.MULTILINE)
	tags = re.findall(r'"([^"]+)"', tags_match.group(1)) if tags_match else []

	return {
		"id": string_value("id"),
		"display_name": string_value("display_name"),
		"card_type": string_value("card_type"),
		"description": string_value("description"),
		"rarity": string_value("rarity"),
		"tags": tags,
	}


def lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


def mix(c1: Color, c2: Color, t: float) -> Color:
	return (
		int(lerp(c1[0], c2[0], t)),
		int(lerp(c1[1], c2[1], t)),
		int(lerp(c1[2], c2[2], t)),
		int(lerp(c1[3], c2[3], t)),
	)


def gradient(size: tuple[int, int], top: Color, bottom: Color) -> Image.Image:
	width, height = size
	image = Image.new("RGBA", size, top)
	pixels = image.load()
	for y in range(height):
		t = y / max(1, height - 1)
		line = mix(top, bottom, t)
		for x in range(width):
			pixels[x, y] = line
	return image


def blur_composite(base: Image.Image, layer: Image.Image, blur: int) -> None:
	base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def add_orb(img: Image.Image, center: tuple[int, int], radius: int, inner: Color, outer: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	x, y = center
	draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=outer)
	blur_composite(img, layer, max(8, radius // 3))
	draw = ImageDraw.Draw(img)
	inner_radius = max(18, radius // 2)
	draw.ellipse((x - inner_radius, y - inner_radius, x + inner_radius, y + inner_radius), fill=inner)


def add_line_glow(img: Image.Image, start: tuple[int, int], end: tuple[int, int], glow: Color, core: Color, width: int) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.line((start, end), fill=glow, width=width + 26)
	blur_composite(img, layer, 20)
	draw = ImageDraw.Draw(img)
	draw.line((start, end), fill=core, width=width)
	draw.line((start, end), fill=(255, 255, 255, 130), width=max(3, width // 6))


def add_arc(img: Image.Image, box: tuple[int, int, int, int], start: int, end: int, color: Color, width: int) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.arc(box, start=start, end=end, fill=color, width=width)
	blur_composite(img, layer, 4)


def add_reticle(img: Image.Image, center: tuple[int, int], radius: int, accent: Color) -> None:
	x, y = center
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=accent, width=10)
	draw.ellipse((x - radius // 2, y - radius // 2, x + radius // 2, y + radius // 2), outline=(255, 255, 255, 130), width=4)
	draw.line((x - radius - 40, y, x - radius + 24, y), fill=accent, width=10)
	draw.line((x + radius - 24, y, x + radius + 40, y), fill=accent, width=10)
	draw.line((x, y - radius - 40, x, y - radius + 24), fill=accent, width=10)
	draw.line((x, y + radius - 24, x, y + radius + 40), fill=accent, width=10)
	blur_composite(img, layer, 6)


def add_magazine(img: Image.Image, rect: tuple[int, int, int, int], body: Color, accent: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.rounded_rectangle(rect, radius=26, fill=body, outline=accent, width=8)
	inset = 18
	draw.rounded_rectangle((rect[0] + inset, rect[1] + inset, rect[2] - inset, rect[3] - inset), radius=18, outline=(255, 255, 255, 110), width=3)
	draw.rectangle((rect[0] + 28, rect[1] + 36, rect[2] - 28, rect[1] + 66), fill=accent)
	draw.rectangle((rect[0] + 32, rect[3] - 52, rect[2] - 32, rect[3] - 30), fill=accent)
	blur_composite(img, layer, 2)


def add_wing_pair(img: Image.Image, center: tuple[int, int], color: Color, glow: Color) -> None:
	x, y = center
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	left = [
		(x - 30, y),
		(x - 170, y - 96),
		(x - 248, y - 138),
		(x - 202, y - 26),
		(x - 250, y + 42),
		(x - 166, y + 8),
	]
	right = [(x + (x - px), py) for px, py in left]
	draw.polygon(left, fill=color)
	draw.polygon(right, fill=color)
	blur_composite(img, layer, 12)
	draw = ImageDraw.Draw(img)
	draw.polygon(left, fill=glow)
	draw.polygon(right, fill=glow)


def add_bullet_fan(img: Image.Image, origin: tuple[int, int], angle: float, count: int, core: Color, glow: Color, spread: float = 0.22) -> None:
	x, y = origin
	for index in range(count):
		if count == 1:
			t = 0.0
		else:
			t = (index / float(count - 1) - 0.5) * 2.0
		theta = angle + t * spread
		length = 350 + index * 28
		end = (int(x + math.cos(theta) * length), int(y + math.sin(theta) * length))
		add_line_glow(img, origin, end, glow, core, 22 - min(index, 8))


def add_motion_chevrons(img: Image.Image, center_y: int, color: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	for index in range(3):
		x = 160 + index * 150
		draw.polygon(
			[
				(x, center_y),
				(x + 82, center_y - 56),
				(x + 132, center_y - 56),
				(x + 48, center_y),
				(x + 132, center_y + 56),
				(x + 82, center_y + 56),
			],
			fill=color,
		)
	blur_composite(img, layer, 8)


def add_supply_box(img: Image.Image, rect: tuple[int, int, int, int], body: Color, accent: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.rounded_rectangle(rect, radius=30, fill=body, outline=accent, width=8)
	draw.line((rect[0] + 40, rect[1] + 40, rect[2] - 40, rect[3] - 40), fill=accent, width=8)
	draw.line((rect[2] - 40, rect[1] + 40, rect[0] + 40, rect[3] - 40), fill=accent, width=8)
	variable_inset = max(28, min(72, (rect[2] - rect[0]) // 4))
	draw.rectangle((rect[0] + variable_inset, rect[1] - 28, rect[2] - variable_inset, rect[1] + 24), fill=accent)
	blur_composite(img, layer, 4)


def add_halo(img: Image.Image, center: tuple[int, int], radius: int, color: Color, accent: Color) -> None:
	x, y = center
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=color, width=12)
	draw.ellipse((x - radius - 30, y - radius - 30, x + radius + 30, y + radius + 30), outline=accent, width=6)
	blur_composite(img, layer, 10)


def add_starburst(img: Image.Image, center: tuple[int, int], count: int, inner: int, outer: int, color: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	x, y = center
	for index in range(count):
		angle = math.tau * index / float(count)
		p1 = (int(x + math.cos(angle - 0.05) * inner), int(y + math.sin(angle - 0.05) * inner))
		p2 = (int(x + math.cos(angle) * outer), int(y + math.sin(angle) * outer))
		p3 = (int(x + math.cos(angle + 0.05) * inner), int(y + math.sin(angle + 0.05) * inner))
		draw.polygon((p1, p2, p3), fill=color)
	blur_composite(img, layer, 8)


def add_vignette(img: Image.Image) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	draw.rounded_rectangle((-40, -40, img.width + 40, img.height + 40), radius=72, outline=(0, 0, 0, 140), width=96)
	blur_composite(img, layer, 30)


def add_glass_panels(img: Image.Image, rnd: random.Random, accent: Color) -> None:
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	for _ in range(5):
		x = rnd.randint(-120, img.width - 80)
		y = rnd.randint(60, img.height - 260)
		w = rnd.randint(160, 340)
		h = rnd.randint(80, 220)
		draw.polygon(
			[
				(x, y),
				(x + w, y + rnd.randint(-20, 20)),
				(x + w - rnd.randint(30, 90), y + h),
				(x - rnd.randint(10, 60), y + h + rnd.randint(-10, 30)),
			],
			fill=(255, 255, 255, rnd.randint(12, 30)),
			outline=accent,
		)
	blur_composite(img, layer, 6)


def card_palette(card: dict) -> tuple[Color, Color, Color, Color]:
	card_type = card["card_type"]
	tags = set(card["tags"])
	description = card["description"]
	card_id = card["id"]

	if card_type in ("Status", "Curse"):
		return rgba("#101520"), rgba("#293750"), rgba("#7987a8"), rgba("#f2b45b")
	if "Burst" in tags or "Finisher" in tags or "Overheat" in description or "storm" in card_id:
		return rgba("#180f2f"), rgba("#4a153f"), rgba("#ff7352"), rgba("#ffd56a")
	if "Support" in tags or "Delivery" in description or "pl_" in card_id:
		return rgba("#0d2044"), rgba("#173b6d"), rgba("#8ed7ff"), rgba("#ffd56a")
	if "Reload" in tags or "AmmoGain" in tags or "AmmoUse" in tags:
		return rgba("#0a2144"), rgba("#173764"), rgba("#6cc7ff"), rgba("#ffd56a")
	if card_type == "Power":
		return rgba("#101c4a"), rgba("#32275e"), rgba("#b7cbff"), rgba("#ffde86")
	if "Mark" in tags:
		return rgba("#0d1d3a"), rgba("#1f355d"), rgba("#9de3ff"), rgba("#ffd56a")
	return rgba("#0d2044"), rgba("#18335f"), rgba("#73c9ff"), rgba("#ffc762")


def render_card(card: dict) -> Image.Image:
	rnd = random.Random(stable_seed(card["id"]))
	top, bottom, accent, gold = card_palette(card)
	img = gradient((WIDTH, HEIGHT), top, bottom)
	add_glass_panels(img, rnd, (255, 255, 255, 18))
	add_orb(
		img,
		(rnd.randint(220, 520), rnd.randint(220, 680)),
		rnd.randint(72, 124),
		(244, 251, 255, 235),
		accent,
	)

	card_id = card["id"]
	card_type = card["card_type"]
	tags = set(card["tags"])
	description = card["description"]

	if "Shot" in tags or "AmmoUse" in tags:
		add_bullet_fan(
			img,
			(rnd.randint(176, 260), rnd.randint(720, 820)),
			-rnd.uniform(0.9, 1.15),
			2 + ("MultiHit" in tags) * 2 + ("Burst" in tags) * 2,
			(233, 248, 255, 240),
			accent,
			spread=0.36 if "MultiHit" in tags or "Burst" in tags else 0.18,
		)
	if "Mark" in tags or any(key in card_id for key in ("target", "lock", "scope", "tag")):
		add_reticle(img, (rnd.randint(410, 560), rnd.randint(260, 430)), rnd.randint(86, 126), gold)
	if "Reload" in tags or "AmmoGain" in tags or any(key in card_id for key in ("reload", "mag", "belt")):
		add_magazine(
			img,
			(rnd.randint(88, 172), rnd.randint(180, 320), rnd.randint(246, 316), rnd.randint(620, 760)),
			(18, 38, 74, 220),
			gold,
		)
	if "Support" in tags or any(key in card_id for key in ("cover", "team", "delivery", "pl_", "supply")):
		add_supply_box(
			img,
			(rnd.randint(408, 470), rnd.randint(486, 560), rnd.randint(620, 690), rnd.randint(730, 812)),
			(22, 43, 78, 200),
			gold,
		)
		add_motion_chevrons(img, rnd.randint(300, 420), accent)
	if "Tempo" in tags or any(key in card_id for key in ("step", "glide", "rush", "tempo", "rapid", "fast")):
		add_motion_chevrons(img, rnd.randint(580, 760), accent)
	if "AOE" in tags or any(key in card_id for key in ("rain", "storm", "wide", "sweep", "barrage")):
		add_starburst(img, (rnd.randint(360, 520), rnd.randint(280, 440)), 10, 70, 248, gold)
	if "Finisher" in tags or any(key in card_id for key in ("final", "absolute", "execution", "critical")):
		add_line_glow(
			img,
			(rnd.randint(128, 208), rnd.randint(820, 900)),
			(rnd.randint(556, 654), rnd.randint(168, 260)),
			(255, 160, 120, 210),
			(255, 247, 220, 245),
			48,
		)
	if card_type == "Power" or any(key in card_id for key in ("halo", "angel", "heaven", "skyline")):
		add_halo(img, (rnd.randint(300, 470), rnd.randint(190, 300)), rnd.randint(82, 124), gold, (255, 255, 255, 80))
		add_wing_pair(img, (rnd.randint(340, 430), rnd.randint(270, 360)), (255, 245, 210, 170), (255, 221, 138, 235))
	if card_type in ("Status", "Curse"):
		add_line_glow(img, (120, 220), (620, 760), (120, 140, 200, 90), (166, 181, 220, 150), 24)
		add_reticle(img, (534, 268), 70, (180, 120, 120, 190))

	frame = Image.new("RGBA", img.size, (0, 0, 0, 0))
	frame_draw = ImageDraw.Draw(frame)
	frame_draw.rounded_rectangle((16, 16, WIDTH - 16, HEIGHT - 16), radius=36, outline=(220, 244, 255, 210), width=8)
	frame_draw.rounded_rectangle((34, 34, WIDTH - 34, HEIGHT - 34), radius=28, outline=(255, 255, 255, 38), width=2)
	img.alpha_composite(frame)
	add_vignette(img)
	return img


def module_palette(module_id: str) -> tuple[str, str, str]:
	if any(key in module_id for key in ("permit", "halo", "heaven")):
		return "#183560", "#0a1625", "#ffd76a"
	if any(key in module_id for key in ("scope", "hunter", "calibrator")):
		return "#17344e", "#0a1825", "#ffcf6d"
	return "#17354f", "#0a1724", "#ffd76a"


def module_icon_content(module_id: str) -> str:
	if "magazine" in module_id:
		return """
  <rect x="96" y="58" width="64" height="140" rx="18" fill="#10243f" stroke="#9fe5ff" stroke-width="8"/>
  <rect x="108" y="74" width="40" height="18" rx="6" fill="#ffd76a"/>
  <rect x="112" y="166" width="32" height="12" rx="4" fill="#ffd76a"/>
"""
	if "light_stock" in module_id:
		return """
  <path d="M68 150h82l26-26h28v24h-20l-22 34H68z" fill="#122741" stroke="#9fe5ff" stroke-width="8" stroke-linejoin="round"/>
  <circle cx="90" cy="170" r="8" fill="#ffd76a"/>
"""
	if "fast_feeder" in module_id or "loader" in module_id:
		return """
  <rect x="66" y="120" width="78" height="22" rx="10" fill="#9fe5ff"/>
  <rect x="92" y="78" width="54" height="74" rx="16" fill="#10243f" stroke="#9fe5ff" stroke-width="8"/>
  <path d="M142 172l34-34m0 0h-22m22 0v22" stroke="#ffd76a" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
"""
	if "scope" in module_id or "hunter" in module_id:
		return """
  <circle cx="128" cy="128" r="56" fill="none" stroke="#9fe5ff" stroke-width="10"/>
  <circle cx="128" cy="128" r="22" fill="none" stroke="#ffd76a" stroke-width="8"/>
  <path d="M48 128h34M174 128h34M128 48v34M128 174v34" stroke="#9fe5ff" stroke-width="10" stroke-linecap="round"/>
  %s
""" % (
			'<path d="M154 94l18 18-54 54h-26v-26z" fill="#ffd76a" opacity="0.9"/>' if "hunter" in module_id else ""
		)
	if "invoice" in module_id or "beacon" in module_id:
		return """
  <rect x="72" y="62" width="112" height="132" rx="18" fill="#122741" stroke="#9fe5ff" stroke-width="8"/>
  <path d="M98 96h60M98 124h44M98 152h56" stroke="#eaf8ff" stroke-width="10" stroke-linecap="round"/>
  <path d="M128 40v48M96 72l32-32 32 32" stroke="#ffd76a" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
"""
	if "suppressor" in module_id:
		return """
  <rect x="58" y="110" width="94" height="36" rx="18" fill="#122741" stroke="#9fe5ff" stroke-width="8"/>
  <rect x="152" y="118" width="34" height="20" rx="10" fill="#ffd76a"/>
  <path d="M196 100q20 28 0 56M214 88q28 40 0 80" fill="none" stroke="#9fe5ff" stroke-width="8" stroke-linecap="round"/>
"""
	if "pouch" in module_id:
		return """
  <path d="M86 74h84l12 34v74a18 18 0 0 1-18 18H92a18 18 0 0 1-18-18v-74z" fill="#122741" stroke="#9fe5ff" stroke-width="8" stroke-linejoin="round"/>
  <path d="M98 74c0-18 12-28 30-28h0c18 0 30 10 30 28" fill="none" stroke="#ffd76a" stroke-width="8"/>
"""
	if "calibrator" in module_id or "chainfire" in module_id:
		return """
  <circle cx="90" cy="92" r="12" fill="#ffd76a"/>
  <circle cx="166" cy="92" r="12" fill="#ffd76a"/>
  <circle cx="128" cy="156" r="14" fill="#9fe5ff"/>
  <path d="M90 92h76M90 92l38 64M166 92l-38 64" stroke="#eaf8ff" stroke-width="8" stroke-linecap="round"/>
  <path d="M128 52v28M60 188l34-20M196 188l-34-20" stroke="#9fe5ff" stroke-width="8" stroke-linecap="round"/>
"""
	if "tempo" in module_id:
		return """
  <path d="M70 154l34-60h36l-30 52h76l-34 60h-36l30-52z" fill="#ffd76a"/>
  <path d="M56 98h54M146 98h54M40 128h44M172 128h44" stroke="#9fe5ff" stroke-width="8" stroke-linecap="round"/>
"""
	if "permit" in module_id:
		return """
  <path d="M128 56l18 28 34 6-24 22 6 36-34-18-34 18 6-36-24-22 34-6z" fill="none" stroke="#ffd76a" stroke-width="10" stroke-linejoin="round"/>
  <path d="M68 176h120" stroke="#9fe5ff" stroke-width="10" stroke-linecap="round"/>
"""
	if "halo" in module_id or "heaven" in module_id:
		return """
  <ellipse cx="128" cy="88" rx="56" ry="24" fill="none" stroke="#ffd76a" stroke-width="10"/>
  <path d="M84 154l44-52 44 52" fill="none" stroke="#9fe5ff" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M78 174l20-40M178 174l-20-40" stroke="#eaf8ff" stroke-width="8" stroke-linecap="round"/>
"""
	return """
  <circle cx="128" cy="128" r="58" fill="none" stroke="#9fe5ff" stroke-width="10"/>
  <circle cx="128" cy="128" r="18" fill="#ffd76a"/>
"""


def render_module_svg(module: dict) -> str:
	top, bottom, gold = module_palette(module["id"])
	content = module_icon_content(module["id"])
	return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{top}"/>
      <stop offset="100%" stop-color="{bottom}"/>
    </linearGradient>
  </defs>
  <rect x="16" y="16" width="224" height="224" rx="36" fill="url(#bg)" stroke="#c9f1ff" stroke-width="6"/>
  <rect x="28" y="28" width="200" height="200" rx="28" fill="#e5f7ff" opacity="0.08"/>
  {content.replace('#ffd76a', gold)}
</svg>
"""


def generate_card_assets() -> int:
	CARD_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	count = 0
	for path in sorted(CARD_DATA_DIR.glob("ex_*.tres")):
		if path.stem.endswith("_plus"):
			continue
		card = parse_tres(path)
		if not card["id"]:
			continue
		image = render_card(card)
		output_path = CARD_OUTPUT_DIR / ("%s.png" % card["id"])
		image.save(output_path)
		count += 1
	return count


def generate_module_assets() -> int:
	MODULE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	count = 0
	for path in sorted(MODULE_DATA_DIR.glob("ex_*.tres")):
		module = parse_tres(path)
		if not module["id"]:
			continue
		output_path = MODULE_OUTPUT_DIR / ("%s.svg" % module["id"])
		output_path.write_text(render_module_svg(module), encoding="utf-8")
		count += 1
	return count


def main() -> None:
	card_count = generate_card_assets()
	module_count = generate_module_assets()
	print("Generated %d Exusiai card arts and %d module icons." % (card_count, module_count))


if __name__ == "__main__":
	main()
