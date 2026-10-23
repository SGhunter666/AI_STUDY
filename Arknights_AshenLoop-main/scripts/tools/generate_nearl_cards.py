#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CARD_OUT = ROOT / "data" / "cards"
MODULE_OUT = ROOT / "data" / "modules"
CHARM_OUT = ROOT / "data" / "charms"


def esc(value: str) -> str:
	return value.replace("\\", "\\\\").replace('"', '\\"')


def eff(effect_type: str, amount: int = 0, target: str = "self", amount_2: int = 0, condition: str = "", status_id: str = "", tag: str = "") -> dict:
	return {
		"effect_type": effect_type,
		"amount": amount,
		"amount_2": amount_2,
		"target": target,
		"condition": condition,
		"status_id": status_id,
		"tag": tag,
	}


def eblock(effect: dict, index: int) -> str:
	lines = [
		f'[sub_resource type="Resource" id="{index}"]',
		'script = ExtResource("2")',
		f'effect_type = "{esc(effect["effect_type"])}"',
		f'amount = {int(effect.get("amount", 0))}',
		f'amount_2 = {int(effect.get("amount_2", 0))}',
		f'target = "{esc(effect.get("target", "self"))}"',
	]
	if effect.get("condition"):
		lines.append(f'condition = "{esc(effect["condition"])}"')
	if effect.get("status_id"):
		lines.append(f'status_id = "{esc(effect["status_id"])}"')
	if effect.get("tag"):
		lines.append(f'tag = "{esc(effect["tag"])}"')
	return "\n".join(lines)


def write_card(card: dict) -> None:
	effects = card["effects"]
	load_steps = 3 + len(effects)
	blocks = [
		f'[gd_resource type="Resource" script_class="CardData" load_steps={load_steps} format=3]',
		"",
		'[ext_resource type="Script" path="res://scripts/data/CardData.gd" id="1"]',
		'[ext_resource type="Script" path="res://scripts/data/EffectData.gd" id="2"]',
		"",
	]
	for i, effect in enumerate(effects, 1):
		blocks.append(eblock(effect, i))
		blocks.append("")
	effect_refs = ", ".join(f'SubResource("{i}")' for i in range(1, len(effects) + 1))
	blocks.extend([
		"[resource]",
		'script = ExtResource("1")',
		f'id = "{esc(card["id"])}"',
		f'display_name = "{esc(card["name"])}"',
		f'cost = {int(card["cost"])}',
		f'card_type = "{esc(card["type"])}"',
		'tags = PackedStringArray(' + ",".join(f'"{esc(tag)}"' for tag in card["tags"]) + ')',
		f'description = "{esc(card["desc"])}"',
		f'rarity = "{esc(card["rarity"])}"',
		"exhausts = false",
		f'upgraded_id = "{esc(card.get("upgraded_id", ""))}"',
		f'effects = [{effect_refs}]',
		"conditional_effects = []",
	])
	(CARD_OUT / f'{card["id"]}.tres').write_text("\n".join(blocks) + "\n", encoding="utf-8")


def card(code: str, slug: str, name: str, cost: int, ctype: str, tags: list[str], desc: str, rarity: str, effects: list[dict], plus_desc: str, plus_effects: list[dict]) -> list[dict]:
	card_id = f"nearl_{code.lower()}_{slug}"
	plus_id = f"{card_id}_plus"
	base = {
		"id": card_id,
		"name": name,
		"cost": cost,
		"type": ctype,
		"tags": tags,
		"desc": desc,
		"rarity": rarity,
		"effects": effects,
		"upgraded_id": plus_id,
	}
	plus = {
		"id": plus_id,
		"name": name + "+",
		"cost": cost,
		"type": ctype,
		"tags": tags,
		"desc": plus_desc,
		"rarity": rarity,
		"effects": plus_effects,
		"upgraded_id": "",
	}
	return [base, plus]


def starter_cards() -> list[dict]:
	cards: list[dict] = []
	cards += card("b01", "knight_strike", "骑士斩击", 1, "Attack", ["Knight"], "造成 6 点伤害。", "Starter", [eff("damage", 6, "enemy")], "造成 8 点伤害。", [eff("damage", 8, "enemy")])
	cards += card("b02", "guard_pulse", "守护脉冲", 1, "Skill", ["Shield", "Barrier"], "获得 5 点护盾。", "Starter", [eff("block", 5)], "获得 7 点护盾。", [eff("block", 7)])
	cards += card("b03", "radiant_strike", "耀光斩击", 1, "Attack", ["Knight", "Radiance", "Heal"], "造成 5 点伤害。若拥有护盾，恢复 1 点生命。", "Starter", [eff("damage", 5, "enemy"), eff("heal", 1, condition="player_has_block")], "造成 7 点伤害。若拥有护盾，恢复 1 点生命。", [eff("damage", 7, "enemy"), eff("heal", 1, condition="player_has_block")])
	cards += card("b04", "radiant_oath", "光耀誓言", 1, "Power", ["Radiance", "Vow"], "获得 1 层光耀。", "Starter", [eff("gain_radiance", 1)], "获得 1 层光耀。获得 2 点护盾。", [eff("gain_radiance", 1), eff("block", 2)])
	cards += card("b05", "counter_guard", "反击守势", 1, "Skill", ["Counter", "Knight"], "本回合获得反击 3。", "Starter", [eff("gain_counter", 3)], "本回合获得反击 5。", [eff("gain_counter", 5)])
	cards += card("b06", "shield_advance", "持盾推进", 1, "Attack", ["Shield", "Knight", "Barrier"], "造成 4 点伤害。获得 3 点护盾。", "Starter", [eff("damage", 4, "enemy"), eff("block", 3)], "造成 5 点伤害。获得 4 点护盾。", [eff("damage", 5, "enemy"), eff("block", 4)])
	cards += card("b07", "hold_the_line", "坚守阵线", 2, "Skill", ["Shield", "Barrier"], "获得 9 点护盾。本回合受到的下一次伤害减少 1。", "Starter", [eff("block", 9), eff("reduce_next_damage", 1)], "获得 12 点护盾。本回合受到的下一次伤害减少 1。", [eff("block", 12), eff("reduce_next_damage", 1)])
	cards += card("b08", "luminous_command", "耀光指令", 1, "Skill", ["Radiance", "Shield", "Draw"], "抽 1 张牌。若拥有光耀，获得 3 点护盾。", "Starter", [eff("draw", 1), eff("block", 3, condition="player_has_radiance")], "抽 1 张牌。若拥有光耀，获得 5 点护盾。", [eff("draw", 1), eff("block", 5, condition="player_has_radiance")])
	cards += card("b09", "clear_bulwark", "明澈壁垒", 1, "Skill", ["Shield", "Barrier"], "获得 4 点护盾。本回合获得反击 2。", "Starter", [eff("block", 4), eff("gain_counter", 2)], "获得 5 点护盾。本回合获得反击 3。", [eff("block", 5), eff("gain_counter", 3)])
	cards += card("b10", "modest_glow", "微光守则", 1, "Skill", ["Radiance", "Shield"], "若拥有护盾，获得 1 层光耀；否则获得 4 点护盾。", "Starter", [eff("gain_radiance", 1, condition="player_has_block"), eff("block", 4, condition="not_player_has_block")], "若拥有护盾，获得 1 层光耀并获得 3 点护盾；否则获得 5 点护盾。", [eff("gain_radiance", 1, condition="player_has_block"), eff("block", 3, condition="player_has_block"), eff("block", 5, condition="not_player_has_block")])
	return cards


COMMON = [
	("c01", "steady_cut", "沉稳斩击", 1, "Attack", ["Knight"], "造成 6 点伤害；若拥有护盾，额外造成 2 点伤害。", [eff("damage_if_block_bonus", 6, "enemy", 2)], "造成 8 点伤害；若拥有护盾，额外造成 3 点伤害。", [eff("damage_if_block_bonus", 8, "enemy", 3)]),
	("c02", "small_guard", "小盾架势", 1, "Skill", ["Shield", "Barrier"], "获得 4 点护盾。本回合获得反击 2。", [eff("block", 4), eff("gain_counter", 2)], "获得 5 点护盾。本回合获得反击 3。", [eff("block", 5), eff("gain_counter", 3)]),
	("c03", "counter_posture", "反击姿态", 1, "Skill", ["Counter"], "本回合获得反击 4。", [eff("gain_counter", 4)], "本回合获得反击 6。", [eff("gain_counter", 6)]),
	("c04", "glow_guard", "微光护卫", 2, "Skill", ["Shield", "Radiance"], "获得 8 点护盾。获得 1 层光耀。", [eff("block", 8), eff("gain_radiance", 1)], "获得 10 点护盾。获得 1 层光耀。", [eff("block", 10), eff("gain_radiance", 1)]),
	("c05", "protected_thrust", "护身突刺", 2, "Attack", ["Knight", "Heal"], "造成 10 点伤害。若拥有护盾，恢复 2 点生命。", [eff("damage", 10, "enemy"), eff("heal", 2, condition="player_has_block")], "造成 13 点伤害。若拥有护盾，恢复 2 点生命。", [eff("damage", 13, "enemy"), eff("heal", 2, condition="player_has_block")]),
	("c06", "line_guard", "战线护持", 1, "Skill", ["Shield"], "获得 5 点护盾。", [eff("block", 5)], "获得 7 点护盾。", [eff("block", 7)]),
	("c07", "vow_step", "誓约步伐", 1, "Skill", ["Radiance", "Vow"], "获得 1 层光耀。", [eff("gain_radiance", 1)], "获得 1 层光耀。本回合获得反击 2。", [eff("gain_radiance", 1), eff("gain_counter", 2)]),
	("c08", "shield_bash", "盾击", 1, "Attack", ["Shield", "Knight"], "造成 4 点伤害。获得 4 点护盾。", [eff("damage", 4, "enemy"), eff("block", 4)], "造成 6 点伤害。获得 5 点护盾。", [eff("damage", 6, "enemy"), eff("block", 5)]),
	("c09", "returning_light", "回光", 1, "Skill", ["Counter", "Radiance"], "若拥有光耀，本回合获得反击 4；否则获得反击 2。", [eff("gain_counter", 4, condition="player_has_radiance"), eff("gain_counter", 2, condition="not_player_has_radiance")], "若拥有光耀，本回合获得反击 6；否则获得反击 3。", [eff("gain_counter", 6, condition="player_has_radiance"), eff("gain_counter", 3, condition="not_player_has_radiance")]),
	("c10", "barrier_prayer", "壁垒祷言", 2, "Skill", ["Shield", "Barrier"], "获得 9 点护盾。", [eff("block", 9)], "获得 12 点护盾。", [eff("block", 12)]),
]


def generated_rarity_cards(prefix: str, rarity: str, start: int, count: int, names: list[str]) -> list[dict]:
	result: list[dict] = []
	for offset in range(count):
		idx = start + offset
		code = f"{prefix}{idx:02d}"
		name = names[offset % len(names)]
		pattern = offset % 6
		if rarity == "Common":
			cost = 1 if pattern in [0, 1, 2, 4] else 2
			if pattern == 0:
				result += card(code, f"shield_line_{idx:02d}", name, cost, "Skill", ["Shield", "Barrier"], "获得 4 点护盾。本回合获得反击 2。", rarity, [eff("block", 4), eff("gain_counter", 2)], "获得 5 点护盾。本回合获得反击 3。", [eff("block", 5), eff("gain_counter", 3)])
			elif pattern == 1:
				result += card(code, f"counter_order_{idx:02d}", name, cost, "Skill", ["Counter", "Knight"], "本回合获得反击 4。", rarity, [eff("gain_counter", 4)], "本回合获得反击 6。", [eff("gain_counter", 6)])
			elif pattern == 2:
				result += card(code, f"radiant_guard_{idx:02d}", name, cost, "Skill", ["Radiance", "Shield"], "获得 1 层光耀。若拥有护盾，获得 3 点护盾。", rarity, [eff("gain_radiance", 1), eff("block", 3, condition="player_has_block")], "获得 1 层光耀。若拥有护盾，获得 5 点护盾。", [eff("gain_radiance", 1), eff("block", 5, condition="player_has_block")])
			elif pattern == 3:
				result += card(code, f"knight_cut_{idx:02d}", name, cost, "Attack", ["Knight"], "造成 8 点伤害；若拥有护盾，额外造成 2 点伤害。", rarity, [eff("damage_if_block_bonus", 8, "enemy", 2)], "造成 11 点伤害；若拥有护盾，额外造成 3 点伤害。", [eff("damage_if_block_bonus", 11, "enemy", 3)])
			elif pattern == 4:
				result += card(code, f"luminous_help_{idx:02d}", name, cost, "Attack", ["Knight", "Heal"], "造成 5 点伤害。若拥有护盾，恢复 1 点生命。", rarity, [eff("damage", 5, "enemy"), eff("heal", 1, condition="player_has_block")], "造成 7 点伤害。若拥有护盾，恢复 2 点生命。", [eff("damage", 7, "enemy"), eff("heal", 2, condition="player_has_block")])
			else:
				result += card(code, f"field_vow_{idx:02d}", name, cost, "Power", ["Radiance", "Vow"], "获得 1 层光耀。获得 4 点护盾。", rarity, [eff("gain_radiance", 1), eff("block", 4)], "获得 1 层光耀。获得 6 点护盾。", [eff("gain_radiance", 1), eff("block", 6)])
		elif rarity == "Uncommon":
			cost = 1 if pattern in [1, 2] else 2
			if pattern == 0:
				result += card(code, f"guarded_counter_{idx:02d}", name, cost, "Skill", ["Shield", "Counter"], "获得 7 点护盾。本回合获得反击 5。", rarity, [eff("block", 7), eff("gain_counter", 5)], "获得 9 点护盾。本回合获得反击 7。", [eff("block", 9), eff("gain_counter", 7)])
			elif pattern == 1:
				result += card(code, f"radiance_check_{idx:02d}", name, cost, "Skill", ["Radiance", "Counter"], "若拥有至少 2 层光耀，本回合获得反击 6；否则获得反击 3。", rarity, [eff("gain_counter", 6, condition="player_radiance_gte:2"), eff("gain_counter", 3, condition="not_player_radiance_gte:2")], "若拥有至少 2 层光耀，本回合获得反击 8；否则获得反击 4。", [eff("gain_counter", 8, condition="player_radiance_gte:2"), eff("gain_counter", 4, condition="not_player_radiance_gte:2")])
			elif pattern == 2:
				result += card(code, f"bright_edge_{idx:02d}", name, cost, "Attack", ["Knight", "Radiance"], "造成 7 点伤害，额外造成等同光耀层数的伤害。", rarity, [eff("damage_plus_radiance", 7, "enemy", 1)], "造成 9 点伤害，额外造成等同光耀层数的伤害。", [eff("damage_plus_radiance", 9, "enemy", 1)])
			elif pattern == 3:
				result += card(code, f"shielded_assault_{idx:02d}", name, cost, "Attack", ["Shield", "Knight"], "造成 9 点伤害。若本回合获得过护盾，额外造成 4 点伤害。", rarity, [eff("damage", 9, "enemy"), eff("damage", 4, "enemy", condition="gained_block_this_turn")], "造成 12 点伤害。若本回合获得过护盾，额外造成 5 点伤害。", [eff("damage", 12, "enemy"), eff("damage", 5, "enemy", condition="gained_block_this_turn")])
			elif pattern == 4:
				result += card(code, f"radiant_bulwark_{idx:02d}", name, cost, "Skill", ["Radiance", "Shield"], "获得 1 层光耀。获得 7 点护盾。", rarity, [eff("gain_radiance", 1), eff("block", 7)], "获得 1 层光耀。获得 10 点护盾。", [eff("gain_radiance", 1), eff("block", 10)])
			else:
				result += card(code, f"oath_engine_{idx:02d}", name, cost, "Power", ["Vow", "Radiance"], "获得 1 层光耀。本回合获得反击 4。", rarity, [eff("gain_radiance", 1), eff("gain_counter", 4)], "获得 1 层光耀。本回合获得反击 6。", [eff("gain_radiance", 1), eff("gain_counter", 6)])
		elif rarity == "Rare":
			cost = 2 if pattern in [0, 1, 2, 4] else 3
			if pattern == 0:
				result += card(code, f"great_counter_{idx:02d}", name, cost, "Skill", ["Counter", "Radiance"], "本回合获得反击 9；若拥有至少 3 层光耀，获得 5 点护盾。", rarity, [eff("gain_counter", 9), eff("block", 5, condition="player_radiance_gte:3")], "本回合获得反击 12；若拥有至少 3 层光耀，获得 7 点护盾。", [eff("gain_counter", 12), eff("block", 7, condition="player_radiance_gte:3")])
			elif pattern == 1:
				result += card(code, f"high_wall_{idx:02d}", name, cost, "Skill", ["Shield", "Counter", "Barrier"], "获得 14 点护盾。本回合获得反击 8。", rarity, [eff("block", 14), eff("gain_counter", 8)], "获得 17 点护盾。本回合获得反击 10。", [eff("block", 17), eff("gain_counter", 10)])
			elif pattern == 2:
				result += card(code, f"radiant_lance_{idx:02d}", name, cost, "Attack", ["Knight", "Radiance"], "造成 12 点伤害，额外造成等同光耀层数的伤害。", rarity, [eff("damage_plus_radiance", 12, "enemy", 1)], "造成 15 点伤害，额外造成等同光耀层数的伤害。", [eff("damage_plus_radiance", 15, "enemy", 1)])
			elif pattern == 3:
				result += card(code, f"mercy_counter_{idx:02d}", name, cost, "Attack", ["Counter", "Heal"], "造成 14 点伤害。若拥有护盾，恢复 2 点生命。本回合获得反击 5。", rarity, [eff("damage", 14, "enemy"), eff("heal", 2, condition="player_has_block"), eff("gain_counter", 5)], "造成 18 点伤害。若拥有护盾，恢复 3 点生命。本回合获得反击 6。", [eff("damage", 18, "enemy"), eff("heal", 3, condition="player_has_block"), eff("gain_counter", 6)])
			elif pattern == 4:
				result += card(code, f"vow_core_{idx:02d}", name, cost, "Power", ["Vow", "Radiance", "Counter"], "获得 1 层光耀。本回合获得反击 7。", rarity, [eff("gain_radiance", 1), eff("gain_counter", 7)], "获得 1 层光耀。本回合获得反击 10。", [eff("gain_radiance", 1), eff("gain_counter", 10)])
			else:
				result += card(code, f"last_defense_{idx:02d}", name, cost, "Skill", ["Shield", "Barrier"], "获得 16 点护盾。本回合受到的下一次伤害减少 2。", rarity, [eff("block", 16), eff("reduce_next_damage", 2)], "获得 20 点护盾。本回合受到的下一次伤害减少 3。", [eff("block", 20), eff("reduce_next_damage", 3)])
		else:
			cost = 3
			if pattern == 0:
				result += card(code, f"legend_wall_{idx:02d}", name, cost, "Skill", ["Shield", "Counter", "Barrier"], "获得 16 点护盾。本回合获得反击 14。", rarity, [eff("block", 16), eff("gain_counter", 14)], "获得 20 点护盾。本回合获得反击 18。", [eff("block", 20), eff("gain_counter", 18)])
			elif pattern == 1:
				result += card(code, f"solar_lance_{idx:02d}", name, cost, "Attack", ["Knight", "Radiance"], "造成 18 点伤害。若拥有护盾，额外造成光耀层数 ×2 的伤害。", rarity, [eff("damage_plus_radiance", 18, "enemy", 2, condition="player_has_block")], "造成 23 点伤害。若拥有护盾，额外造成光耀层数 ×2 的伤害。", [eff("damage_plus_radiance", 23, "enemy", 2, condition="player_has_block")])
			elif pattern == 2:
				result += card(code, f"oath_finale_{idx:02d}", name, cost, "Power", ["Vow", "Radiance", "Counter"], "获得 1 层光耀。本回合获得反击 12。", rarity, [eff("gain_radiance", 1), eff("gain_counter", 12)], "获得 1 层光耀。本回合获得反击 16。", [eff("gain_radiance", 1), eff("gain_counter", 16)])
			elif pattern == 3:
				result += card(code, f"radiant_bastion_{idx:02d}", name, cost, "Skill", ["Shield", "Radiance"], "获得 15 点护盾。获得 1 层光耀。", rarity, [eff("block", 15), eff("gain_radiance", 1)], "获得 19 点护盾。获得 1 层光耀。", [eff("block", 19), eff("gain_radiance", 1)])
			elif pattern == 4:
				result += card(code, f"knight_answer_{idx:02d}", name, cost, "Attack", ["Knight", "Counter"], "造成 20 点伤害。本回合获得反击 8。", rarity, [eff("damage", 20, "enemy"), eff("gain_counter", 8)], "造成 26 点伤害。本回合获得反击 10。", [eff("damage", 26, "enemy"), eff("gain_counter", 10)])
			else:
				result += card(code, f"radiant_vow_{idx:02d}", name, cost, "Power", ["Vow", "Radiance", "Shield"], "获得 1 层光耀。获得 12 点护盾。", rarity, [eff("gain_radiance", 1), eff("block", 12)], "获得 1 层光耀。获得 16 点护盾。", [eff("gain_radiance", 1), eff("block", 16)])
	return result


def all_cards() -> list[dict]:
	result = starter_cards()
	common_names = ["守线", "反击命令", "微光壁", "骑士短击", "救援余辉", "护盾交错"]
	result += sum((card(*entry, "Common") for entry in []), [])
	for item in COMMON:
		code, slug, name, cost, ctype, tags, desc, effects, plus_desc, plus_effects = item
		result += card(code, slug, name, cost, ctype, tags, desc, "Common", effects, plus_desc, plus_effects)
	result += generated_rarity_cards("c", "Common", 11, 20, common_names)
	result += generated_rarity_cards("u", "Uncommon", 1, 24, ["盾线折返", "光耀回环", "明骑突击", "防线合击", "誓言回声", "耀光壁垒"])
	result += generated_rarity_cards("r", "Rare", 1, 20, ["大骑士守势", "日冕壁垒", "灼光枪", "仁慈反击", "誓约核心", "最后防线"])
	result += generated_rarity_cards("l", "Legendary", 1, 8, ["耀骑士壁垒", "日耀长枪", "终誓", "光辉堡垒", "骑士的回答", "不灭誓约"])
	base_count = len([c for c in result if not c["id"].endswith("_plus")])
	if base_count != 92:
		raise RuntimeError(f"Nearl base card count must be 92, got {base_count}")
	return result


MODULES = [
	("nearl_m01_first_guard", "初盾徽记", "Common", "每回合第一次触发临光被动时，额外护盾再 +2。"),
	("nearl_m02_counter_edge", "反击锋缘", "Common", "反击伤害 +1。"),
	("nearl_m03_opening_barrier", "开场壁垒", "Common", "战斗第一回合开始时获得 4 点护盾。"),
	("nearl_m04_dawn_oath", "黎明誓约", "Common", "战斗第一回合开始时获得 1 层光耀。"),
	("nearl_m05_first_counter_block", "回击护臂", "Common", "每场战斗第一次反击后获得 4 点护盾。"),
	("nearl_m06_low_hp_counter", "残线锋芒", "Common", "生命不高于 40% 时，反击伤害 +2。"),
	("nearl_m07_shield_draft", "盾牌调度", "Uncommon", "奖励中更容易出现临光护盾牌。"),
	("nearl_m08_counter_draft", "反击调度", "Uncommon", "奖励中更容易出现临光反击牌。"),
	("nearl_m09_first_radiance_draw", "初光记录", "Uncommon", "每场战斗第一次获得光耀时抽 1 张牌。"),
	("nearl_m10_broken_shield_counter", "碎盾回击", "Uncommon", "每回合第一次护盾被击破时，本回合获得反击 3。"),
	("nearl_m11_boss_bulwark", "强敌壁垒", "Rare", "Boss 战第一回合开始时额外获得 8 点护盾。"),
	("nearl_m12_upgraded_counter", "精修护手", "Rare", "升级牌给予反击时，反击额外 +1。"),
	("nearl_m13_counter_heal", "暖光回响", "Rare", "每回合第一次反击后恢复 1 点生命。"),
	("nearl_m14_high_radiance_guard", "高光护阵", "Rare", "拥有至少 4 层光耀时，获得护盾额外 +1。"),
	("nearl_m15_full_radiance_counter", "满辉锋线", "Legendary", "满 5 层光耀时，反击伤害额外 +2。"),
	("nearl_m16_first_counter_guard", "终局护誓", "Legendary", "每场战斗第一次打出反击牌时，额外获得 4 点护盾。"),
]


CHARMS = [
	("nearl_h01_kazimierz_badge", "卡西米尔徽章", "战斗开始时获得 3 点护盾。"),
	("nearl_h02_oath_pin", "誓约别针", "每场战斗第一次获得光耀时，额外获得 2 点护盾。"),
	("nearl_h03_guard_lantern", "守夜提灯", "护盾牌奖励权重提高。"),
	("nearl_h04_counter_spur", "反击马刺", "反击牌奖励权重提高。"),
	("nearl_h05_radiant_shard", "耀光碎片", "光耀牌奖励权重提高。"),
	("nearl_h06_last_line", "最后阵线", "低生命时更容易获得护盾与反击牌。"),
	("nearl_h07_warm_glow", "温光缎带", "反击后小回复构筑更稳定。"),
	("nearl_h08_knight_seal", "骑士封印", "高光耀时反击构筑更容易成型。"),
]


def write_module(module_id: str, name: str, rarity: str, desc: str) -> None:
	text = "\n".join([
		'[gd_resource type="Resource" script_class="ModuleData" load_steps=2 format=3]',
		"",
		'[ext_resource type="Script" path="res://scripts/data/ModuleData.gd" id="1"]',
		"",
		"[resource]",
		'script = ExtResource("1")',
		f'id = "{esc(module_id)}"',
		f'display_name = "{esc(name)}"',
		f'rarity = "{esc(rarity)}"',
		f'description = "{esc(desc)}"',
	]) + "\n"
	(MODULE_OUT / f"{module_id}.tres").write_text(text, encoding="utf-8")


def write_charm(charm_id: str, name: str, desc: str) -> None:
	text = "\n".join([
		'[gd_resource type="Resource" script_class="CharmData" load_steps=2 format=3]',
		"",
		'[ext_resource type="Script" path="res://scripts/data/CharmData.gd" id="1"]',
		"",
		"[resource]",
		'script = ExtResource("1")',
		f'id = "{esc(charm_id)}"',
		f'display_name = "{esc(name)}"',
		f'description = "{esc(desc)}"',
		'slot_type = "charm"',
	]) + "\n"
	(CHARM_OUT / f"{charm_id}.tres").write_text(text, encoding="utf-8")


def main() -> None:
	CARD_OUT.mkdir(parents=True, exist_ok=True)
	MODULE_OUT.mkdir(parents=True, exist_ok=True)
	CHARM_OUT.mkdir(parents=True, exist_ok=True)
	for card_data in all_cards():
		write_card(card_data)
	for module in MODULES:
		write_module(*module)
	for charm in CHARMS:
		write_charm(*charm)


if __name__ == "__main__":
	main()
