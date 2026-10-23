#!/usr/bin/env python3
from __future__ import annotations

import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "tmp" / "kaltsit_spec.txt"
OUT = ROOT / "data" / "cards"


RARITY_BY_PREFIX = {
	"B": "Starter",
	"C": "Common",
	"U": "Uncommon",
	"R": "Rare",
	"L": "Legendary",
	"S": "Status",
}

BALANCE_OVERRIDES = {
	"KS_C07": ("Mon3tr deals 8 damage", "10"),
	"KS_C08": ("Mon3tr deals 6 damage to all enemies", "8"),
	"KS_C09": ("Mon3tr deals 4 damage twice", "5 twice"),
	"KS_C25": ("Kal’tsit deals 5, then Mon3tr deals 5", "6 + 6"),
	"KS_U06": ("Mon3tr deals 4 damage three times", "5 three times"),
	"KS_U07": ("Mon3tr deals 14. If in Meltdown, apply 1 Weak", "17"),
	"KS_U22": ("Mon3tr deals 16, then loses 1 Integrity", "19"),
	"KS_R10": ("Mon3tr deals 20, then loses 2 Integrity", "24"),
	"KS_R12": ("Only usable in Meltdown. Mon3tr deals 12 to all enemies", "15"),
	"KS_R19": ("Mon3tr deals 12 twice. If in Meltdown, third hit", "14 per hit"),
	"KS_L01": ("Mon3tr deals 20 damage to all enemies", "24"),
	"KS_L05": ("If Integrity >= 5, Mon3tr deals 36. Otherwise repair to 10 and deal 20", "44 / 24"),
}

LOW_INTEGRITY_DAMAGE_NOTE = "完整性≤2时伤害降低。"


def mon3tr_damage_note(desc: str, applies: bool = True) -> str:
	if not applies:
		return desc
	if "Mon3tr" not in desc or ("造成" not in desc and "伤害" not in desc):
		return desc
	return append_low_integrity_note(desc)


def append_low_integrity_note(desc: str) -> str:
	if LOW_INTEGRITY_DAMAGE_NOTE in desc:
		return desc
	return desc.rstrip("。") + "（" + LOW_INTEGRITY_DAMAGE_NOTE + "）"


def esc(value: str) -> str:
	return value.replace("\\", "\\\\").replace('"', '\\"')


def slugify(name: str) -> str:
	value = unicodedata.normalize("NFKD", name)
	value = value.replace("’", "").replace("'", "")
	value = re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_").lower()
	return value or "card"


def numbers(text: str) -> list[int]:
	return [int(match.group(0)) for match in re.finditer(r"\d+", text)]


def tags_from_text(name: str, effect: str, card_type: str, rarity: str) -> list[str]:
	joined = f"{name} {effect}"
	tags: list[str] = []
	def add(tag: str) -> None:
		if tag not in tags:
			tags.append(tag)

	if card_type == "Attack":
		add("Scalpel")
	if rarity in ["Status", "Curse"]:
		add(rarity)
	if "Mon3tr" in joined:
		add("Mon3tr")
	if "Command" in joined or "指令" in joined:
		add("Command")
	if "Medical" in joined or "Heal" in joined or "Treatment" in joined or "Clinical" in joined or "Care" in joined or "Surgery" in joined or "Infusion" in joined:
		add("Medical")
	if "Heal" in joined or "治疗" in joined:
		add("Heal")
	if "Repair" in joined or "Integrity" in joined or "完整性" in joined:
		add("Repair")
	if "Meltdown" in joined or "融毁" in joined:
		add("Meltdown")
	if "Protocol" in joined or card_type == "Power":
		add("Protocol")
	if "Block" in joined:
		add("Block")
	if "Draw" in joined or "draw" in joined:
		add("Draw")
	if "all enemies" in joined:
		add("AOE")
	if "twice" in joined or "three times" in joined:
		add("MultiHit")
	if "overflow" in joined.lower():
		add("Overflow")
	if "Emergency" in joined or "Crisis" in joined:
		add("Emergency")
	return tags


def resource_id(code: str, en_name: str) -> str:
	prefix = code.split("_", 1)[1][0].lower()
	return f"kaltsit_{prefix}{code[-2:]}_{slugify(en_name)}"


def eff(effect_type: str, amount: int = 0, target: str = "enemy", amount_2: int = 0, status_id: str = "", tag: str = "", condition: str = "") -> dict:
	return {
		"effect_type": effect_type,
		"amount": amount,
		"amount_2": amount_2,
		"target": target,
		"status_id": status_id,
		"tag": tag,
		"condition": condition,
	}


def condition_for_text(text: str) -> str:
	parts: list[str] = []
	if re.search(r"Integrity\s*<=\s*2", text) or "Critical Integrity" in text:
		parts.append("mon3tr_integrity_lte:2")
	elif re.search(r"Integrity\s*<=\s*3", text):
		parts.append("mon3tr_integrity_lte:3")
	elif re.search(r"Integrity\s*<=\s*5", text):
		parts.append("mon3tr_integrity_lte:5")
	if re.search(r"Integrity\s*>=\s*8", text):
		parts.append("mon3tr_integrity_gte:8")
	if "HP <= 40%" in text:
		parts.append("player_hp_lte_percent:40")
	elif "HP <= 50%" in text:
		parts.append("player_hp_lte_percent:50")
	if "in Meltdown" in text or "Only usable in Meltdown" in text:
		parts.append("mon3tr_meltdown")
	if "Medical was played this turn" in text:
		parts.append("played_medical_this_turn_gte:1")
	if "Command" in text and "was drawn" not in text and "First Command" not in text and "next Command" not in text and "Command card" not in text and "played this turn" in text:
		parts.append("played_command_this_turn_gte:1")
	if "Mon3tr was repaired this turn" in text:
		parts.append("mon3tr_repaired_this_turn")
	if "HP was healed this turn" in text:
		parts.append("hp_healed_this_turn")
	if "hand size <= 2" in text:
		parts.append("hand_size_lte:2")
	return "&".join(parts)


def effects_from_text(text: str) -> tuple[list[dict], list[dict]]:
	base: list[dict] = []
	conditional: list[dict] = []
	condition = condition_for_text(text)
	nums = numbers(text)

	def target_list() -> list[dict]:
		return conditional if condition else base

	if "take 2 damage" in text or "Drawn: take 2 damage" in text:
		base.append(eff("lose_hp", 2, "self"))
	elif "First Command this turn costs +1" in text:
		base.append(eff("set_next_tag_cost_delta", 1, "self", tag="Command"))
	elif "First Medical this turn has effect -3" in text:
		base.append(eff("set_mon3tr_repair_bonus", -3, "self"))
	elif "Next Mon3tr attack this turn deals -4" in text:
		base.append(eff("set_mon3tr_next_attack_bonus", -4, "self"))
	elif "Draw 1 fewer card" in text:
		base.append(eff("set_meta_value", -1, "self", status_id="next_turn_hand_size"))
	elif "Ethical Echo" in text:
		base.append(eff("lose_hp", 1, "self", condition="hp_healed_this_turn"))

	if "Repair Mon3tr to max" in text or "repair to 10" in text:
		base.append(eff("repair_mon3tr_to_max", 0, "self"))

	if "Enter Meltdown directly" in text or "enter Meltdown" in text or "enter Meltdown;" in text:
		target_list().append(eff("enter_kaltsit_meltdown", 0, "self"))

	if "base max Integrity +" in text:
		base.append(eff("set_mon3tr_max_bonus", nums[-1] if nums else 2, "self"))
	elif "Meltdown max Integrity becomes" in text:
		base.append(eff("set_meta_value", nums[0] if nums else 18, "self", status_id="mon3tr_meltdown_max_override"))
	elif "Mon3tr max Integrity becomes" in text:
		base.append(eff("set_meta_value", nums[0] if nums else 20, "self", status_id="mon3tr_meltdown_max_override"))

	if "Turn-start Mon3tr auto repair +" in text or "Mon3tr turn-start auto repair +" in text:
		base.append(eff("set_mon3tr_auto_repair_bonus", nums[-1] if nums else 1, "self"))
	if "Mon3tr damage +" in text:
		base.append(eff("set_mon3tr_attack_bonus", nums[-1] if nums else 3, "self"))
	if "Next Command" in text and "deals +" in text:
		base.append(eff("set_next_tag_damage_bonus", nums[-1] if nums else 4, "self", tag="Command"))
	if "Next Mon3tr attack triggers twice" in text:
		base.append(eff("set_mon3tr_next_attack_multiplier", nums[-1] if nums else 150, "self"))
	if "Next two Command" in text:
		base.append(eff("set_next_tag_damage_bonus", nums[-1] if nums else 2, "self", tag="Command"))
	if "Critical Integrity no longer reduces Mon3tr damage" in text:
		base.append(eff("set_mon3tr_low_integrity_no_penalty", 1, "self"))
	if "Integrity loss this turn is reduced" in text:
		base.append(eff("set_integrity_loss_reduction", nums[-1] if nums else 2, "self"))
	if "First Integrity loss each turn repairs" in text:
		base.append(eff("set_mon3tr_reactive_repair", nums[-1] if nums else 1, "self"))
	if "Meltdown exits at Integrity < 3" in text:
		base.append(eff("set_meta_value", 3, "self", status_id="mon3tr_meltdown_exit_threshold"))

	heal_match = re.search(r"Heal\s+(\d+)", text)
	if heal_match:
		heal_amount = int(heal_match.group(1))
		if "otherwise gain" in text or "otherwise heal" in text:
			base.append(eff("heal_if_low_else_block", heal_amount, "self", amount_2=50 if "50%" in text else 40))
		else:
			base.append(eff("heal_or_block_if_full" if "full HP" in text else "heal", heal_amount, "self", amount_2=heal_amount))

	if "gain Block equal to half" in text and heal_match:
		base.append(eff("block", max(1, int(heal_match.group(1)) // 2), "self"))
	else:
		block_match = re.search(r"gain\s+(\d+)\s+Block", text, re.IGNORECASE)
		if block_match:
			base.append(eff("block", int(block_match.group(1)), "self"))
		elif re.search(r"Gain\s+(\d+)\s+Block", text):
			base.append(eff("block", int(re.search(r"Gain\s+(\d+)\s+Block", text).group(1)), "self"))

	repair_match = re.search(r"[Rr]epair(?: Mon3tr)?\s+(\d+)", text)
	if repair_match:
		base.append(eff("repair_mon3tr", int(repair_match.group(1)), "self"))
	elif "repairs Mon3tr 1" in text:
		base.append(eff("repair_mon3tr", 1, "self"))

	if "Mon3tr loses" in text:
		loss = int(re.search(r"Mon3tr loses\s+(\d+)", text).group(1))
		base.append(eff("damage_mon3tr", loss, "self"))

	draw_match = re.search(r"Draw\s+(\d+)", text)
	if draw_match:
		if "Medical or Command" in text or "drawn card is Medical or Command" in text:
			base.append(eff("draw_discount_medical_command", int(draw_match.group(1)), "self", amount_2=1))
		else:
			base.append(eff("draw", int(draw_match.group(1)), "self"))
	elif "draw 1" in text:
		target_list().append(eff("draw", 1, "self"))

	if "gain 1 Energy" in text:
		target_list().append(eff("gain_energy", 1, "self"))

	if "Mon3tr deals" in text:
		damage_all = "all enemies" in text
		hits = 1
		if "twice" in text:
			hits = 2
		elif "three times" in text:
			hits = 3
		damage_number = 0
		damage_match = re.search(r"Mon3tr deals\s+(\d+)", text)
		if damage_match:
			damage_number = int(damage_match.group(1))
		elif "equal to current Integrity" in text:
			base.append(eff("mon3tr_damage_by_integrity", 0, "enemy"))
		if damage_number > 0:
			mon3tr_effect = eff("mon3tr_damage_all" if damage_all else "mon3tr_damage", damage_number, "all_enemies" if damage_all else "enemy", amount_2=hits)
			if "Only usable in Meltdown" in text:
				mon3tr_effect["condition"] = "mon3tr_meltdown"
			target_list().append(mon3tr_effect)

	if "Kal’tsit deals" in text or "Kal'tsit deals" in text:
		damage_match = re.search(r"Kal[’']tsit deals\s+(\d+)", text)
		if damage_match:
			base.append(eff("damage", int(damage_match.group(1)), "enemy"))
	if text.startswith("Deal "):
		damage_match = re.search(r"Deal\s+(\d+)", text)
		if damage_match:
			base.append(eff("damage", int(damage_match.group(1)), "enemy"))

	if "Lose" in text and "HP" in text:
		loss_match = re.search(r"Lose\s+(\d+)\s+HP", text)
		if loss_match:
			base.append(eff("lose_hp", int(loss_match.group(1)), "self"))

	if not base and conditional:
		base = conditional
		conditional = []
	if not base and not conditional:
		base.append(eff("set_meta_flag", 1, "self", status_id="kaltsit_" + slugify(text)[:32]))
	return base, conditional


def upgraded_effect_text(base_text: str, upgrade_text: str) -> str:
	if not upgrade_text:
		return base_text
	if "cost 0" in upgrade_text:
		return base_text
	replacements = numbers(upgrade_text)
	if not replacements:
		return base_text
	protected_mon3tr = "__MONTHREE__"
	base_text = base_text.replace("Mon3tr", protected_mon3tr)
	index = 0
	def repl(match: re.Match[str]) -> str:
		nonlocal index
		if index >= len(replacements):
			return match.group(0)
		value = str(replacements[index])
		index += 1
		return value
	return re.sub(r"\d+", repl, base_text).replace(protected_mon3tr, "Mon3tr")


def zh_effect_description(text: str) -> str:
	text = text.strip().rstrip(".")
	text = re.sub(r"\.?\s*Exhaust$", "", text).strip().rstrip(".")
	nums = numbers(text)

	if text == "Drawn: take 2 damage":
		return "抽到时：受到 2 点伤害。消耗。"
	if text == "First Command this turn costs +1":
		return "本回合第一张指令牌费用 +1。消耗。"
	if text == "First Medical this turn has effect -3":
		return "本回合第一张医疗牌效果 -3。消耗。"
	if text == "Next Mon3tr attack this turn deals -4 damage":
		return "本回合下一次 Mon3tr 攻击伤害 -4。消耗。"
	if text == "Draw 1 fewer card this turn":
		return "本回合少抽 1 张牌。消耗。"
	if text == "If HP was healed this turn, lose 1 HP at end of turn":
		return "若本回合治疗过生命，回合结束时失去 1 点生命。消耗。"

	match = re.match(r"Heal (\d+) HP, repair Mon3tr (\d+)", text)
	if match:
		return "治疗 %s 点生命，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"Heal (\d+), repair (\d+)", text)
	if match:
		return "治疗 %s 点生命，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"Heal (\d+) and draw (\d+)", text)
	if match:
		return "治疗 %s 点生命并抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"Lose (\d+) HP, repair Mon3tr (\d+)", text)
	if match:
		return "失去 %s 点生命，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"Lose (\d+) HP, draw (\d+), repair (\d+)", text)
	if match:
		return "失去 %s 点生命，抽 %s 张牌，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Heal (\d+), repair (\d+)", text)
	if match:
		return "治疗 %s 点生命，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"Heal (\d+), gain (\d+) Block, repair (\d+)", text)
	if match:
		return "治疗 %s 点生命，获得 %s 护盾，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Heal (\d+) and gain Block equal to half that value", text)
	if match:
		return "治疗 %s 点生命，并获得等同于治疗量一半的护盾。" % match.group(1)
	match = re.match(r"Heal (\d+)\. If HP is full, Mon3tr deals (\d+) to random enemy", text)
	if match:
		return "治疗 %s 点生命。若生命已满，Mon3tr 对随机敌人造成 %s 点伤害。" % (match.group(1), match.group(2))
	match = re.match(r"Heal (\d+), repair (\d+)", text)
	if match:
		return "治疗 %s 点生命，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"If HP <= (\d+)%, heal (\d+); otherwise gain (\d+) Block", text)
	if match:
		return "若生命不高于 %s%%，治疗 %s 点生命；否则获得 %s 护盾。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"If HP <= (\d+)%, heal (\d+) and draw (\d+); otherwise heal (\d+)", text)
	if match:
		return "若生命不高于 %s%%，治疗 %s 点生命并抽 %s 张牌；否则治疗 %s 点生命。" % (match.group(1), match.group(2), match.group(3), match.group(4))
	match = re.match(r"Heal (\d+)", text)
	if match:
		return "治疗 %s 点生命。" % match.group(1)

	match = re.match(r"Repair(?: Mon3tr)? (\d+)$", text)
	if match:
		return "修复 Mon3tr %s 点完整性。" % match.group(1)
	match = re.match(r"Repair (\d+)\. If Integrity <= (\d+), repair \+(\d+)", text)
	if match:
		return "修复 Mon3tr %s 点完整性；若完整性不高于 %s，额外修复 %s 点。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Repair (\d+)\. If HP was healed this turn, draw (\d+)", text)
	if match:
		return "修复 Mon3tr %s 点完整性。若本回合治疗过生命，抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"If Integrity <= (\d+), repair (\d+); otherwise repair (\d+)", text)
	if match:
		return "若完整性不高于 %s，修复 Mon3tr %s 点完整性；否则修复 %s 点。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"If Integrity <= (\d+), draw (\d+) and repair (\d+); otherwise draw (\d+)", text)
	if match:
		return "若完整性不高于 %s，抽 %s 张牌并修复 Mon3tr %s 点完整性；否则抽 %s 张牌。" % (match.group(1), match.group(2), match.group(3), match.group(4))
	match = re.match(r"If Integrity >= (\d+), draw (\d+); otherwise repair (\d+)", text)
	if match:
		return "若完整性不低于 %s，抽 %s 张牌；否则修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"If Integrity >= (\d+), enter Meltdown; otherwise repair (\d+)", text)
	if match:
		return "若完整性不低于 %s，进入融毁；否则修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"If Integrity >= (\d+), Mon3tr deals (\d+)\. Otherwise repair to (\d+) and deal (\d+)", text)
	if match:
		return "若完整性不低于 %s，Mon3tr 造成 %s 点伤害；否则修复至 %s 完整性并造成 %s 点伤害。" % (match.group(1), match.group(2), match.group(3), match.group(4))

	match = re.match(r"Draw (\d+)$", text)
	if match:
		return "抽 %s 张牌。" % match.group(1)
	match = re.match(r"Draw (\d+)\. If a Medical card was played this turn, draw \+(\d+)", text)
	if match:
		return "抽 %s 张牌。若本回合打出过医疗牌，额外抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"Draw (\d+)\. If a Command card is drawn, reduce first drawn Command cost by (\d+) this turn", text)
	if match:
		return "抽 %s 张牌。若抽到指令牌，本回合第一张抽到的指令牌费用 -%s。" % (match.group(1), match.group(2))
	match = re.match(r"Draw (\d+)\. Choose (\d+) Command or Medical in hand; it costs (\d+) this turn", text)
	if match:
		return "抽 %s 张牌。选择手牌中 %s 张指令或医疗牌，本回合费用变为 %s。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Discover (\d+) Medical cards; choose (\d+), it costs (\d+) less this turn", text)
	if match:
		return "发现 %s 张医疗牌；选择 %s 张，本回合费用 -%s。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Discover (\d+) Command cards; choose (\d+), it costs (\d+) less this turn", text)
	if match:
		return "发现 %s 张指令牌；选择 %s 张，本回合费用 -%s。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Discover (\d+) Medical / Command / Protocol cards; choose (\d+), set cost to (\d+)", text)
	if match:
		return "发现 %s 张医疗、指令或协议牌；选择 %s 张，费用变为 %s。" % (match.group(1), match.group(2), match.group(3))

	match = re.match(r"Mon3tr deals (\d+) damage three times", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害三次。" % match.group(1))
	match = re.match(r"Mon3tr deals (\d+) damage twice", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害两次。" % match.group(1))
	match = re.match(r"Mon3tr deals (\d+) twice\. If in Meltdown, third hit", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害两次；若处于融毁，追加第三段。" % match.group(1))
	match = re.match(r"Mon3tr deals (\d+) to all enemies\. If in Meltdown, (\d+)", text)
	if match:
		return mon3tr_damage_note("Mon3tr 对所有敌人造成 %s 点伤害；若处于融毁，改为 %s 点。" % (match.group(1), match.group(2)))
	match = re.match(r"Mon3tr deals (\d+) damage to all enemies", text)
	if match:
		return mon3tr_damage_note("Mon3tr 对所有敌人造成 %s 点伤害。" % match.group(1))
	match = re.match(r"Only usable in Meltdown\. Mon3tr deals (\d+) to all enemies", text)
	if match:
		return "仅可在融毁中使用。Mon3tr 对所有敌人造成 %s 点伤害。" % match.group(1)
	match = re.match(r"Mon3tr deals (\d+), then loses (\d+) Integrity", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害，然后失去 %s 点完整性。" % (match.group(1), match.group(2)))
	match = re.match(r"Mon3tr deals (\d+)\. If in Meltdown, apply (\d+) Weak", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害。若处于融毁，施加 %s 层虚弱。" % (match.group(1), match.group(2)))
	match = re.match(r"Mon3tr deals (\d+) damage", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害。" % match.group(1))
	match = re.match(r"Mon3tr deals (\d+)$", text)
	if match:
		return mon3tr_damage_note("Mon3tr 造成 %s 点伤害。" % match.group(1))
	match = re.match(r"Mon3tr loses (\d+) Integrity", text)
	if match:
		return "Mon3tr 失去 %s 点完整性。消耗。" % match.group(1)
	match = re.match(r"Kal.?tsit deals (\d+), then Mon3tr deals (\d+)", text)
	if match:
		return "凯尔希造成 %s 点伤害，然后 Mon3tr 造成 %s 点伤害。" % (match.group(1), match.group(2))
	match = re.match(r"Deal (\d+) damage\. If in Meltdown, draw (\d+)", text)
	if match:
		return "造成 %s 点伤害。若处于融毁，抽 %s 张牌。" % (match.group(1), match.group(2))

	match = re.match(r"Gain (\d+) Block\. If Mon3tr Integrity <= (\d+), repair (\d+)", text)
	if match:
		return "获得 %s 护盾。若 Mon3tr 完整性不高于 %s，修复 %s 点完整性。" % (match.group(1), match.group(2), match.group(3))
	match = re.match(r"Gain (\d+) Block, cleanse (\d+) debuff\. If in Meltdown, draw (\d+)", text)
	if match:
		return "获得 %s 护盾，清除 %s 个负面状态。若处于融毁，抽 %s 张牌。" % (match.group(1), match.group(2), match.group(3))

	match = re.match(r"Next Command this turn deals \+(\d+) damage", text)
	if match:
		return "本回合下一张指令牌伤害 +%s。" % match.group(1)
	match = re.match(r"Next Mon3tr attack triggers twice; second hit deals (\d+)% damage", text)
	if match:
		return "下一次 Mon3tr 攻击触发两次；第二段造成 %s%% 伤害。" % match.group(1)
	match = re.match(r"If Medical was played this turn, next Command costs (\d+) less and deals \+(\d+)", text)
	if match:
		return "若本回合打出过医疗牌，下一张指令牌费用 -%s，伤害 +%s。" % (match.group(1), match.group(2))
	match = re.match(r"Next two Command cards this turn deal \+(\d+)", text)
	if match:
		return "本回合接下来两张指令牌伤害 +%s。" % match.group(1)
	if text == "Next Command triggers twice":
		return "下一张指令牌触发两次。"
	if text == "Return 1 Command from discard to hand; it costs 1 less this turn":
		return "从弃牌堆将 1 张指令牌返回手牌；其本回合费用 -1。"
	if text == "Repair Mon3tr to max Integrity":
		return "修复 Mon3tr 至完整性上限。"

	power_texts = {
		"Mon3tr base max Integrity +%d": "Mon3tr 基础完整性上限 +%d。",
		"Turn-start Mon3tr auto repair +%d": "回合开始时 Mon3tr 自动修复 +%d。",
		"Medical cards give +%d Block": "医疗牌额外给予 +%d 护盾。",
		"First Command each turn repairs Mon3tr %d": "每回合第一张指令牌修复 Mon3tr %d 点完整性。",
		"Critical Integrity no longer reduces Mon3tr damage": "临界完整性不再降低 Mon3tr 伤害。",
		"Each Integrity lost gives next Mon3tr attack +%d damage": "每失去 1 点完整性，下一次 Mon3tr 攻击伤害 +%d。",
		"First Integrity loss each turn repairs %d after damage": "每回合第一次失去完整性后，修复 Mon3tr %d 点完整性。",
		"Mon3tr damage +%d": "Mon3tr 伤害 +%d。",
		"Meltdown max Integrity becomes %d": "融毁时完整性上限变为 %d。",
	}
	for pattern, template in power_texts.items():
		regex = "^" + re.escape(pattern).replace("%d", r"(\d+)") + "$"
		match = re.match(regex, text)
		if match:
			return template % tuple(int(group) for group in match.groups())

	exact = {
		"Repair 2, then Mon3tr deals damage equal to current Integrity": "修复 Mon3tr 2 点完整性，然后 Mon3tr 造成等同于当前完整性的伤害。",
		"This turn, healing overflow repairs Mon3tr": "本回合治疗溢出会修复 Mon3tr。",
		"Next Mon3tr Integrity loss this turn is reduced by 2": "本回合下一次 Mon3tr 完整性损失减少 2 点。",
		"First Medical each turn gives 3 Block": "每回合第一张医疗牌给予 3 护盾。",
		"At turn start, if HP <= 50%, heal 2": "回合开始时，若生命不高于 50%，治疗 2 点生命。",
		"First Mon3tr repair each turn repairs +1": "每回合第一次修复 Mon3tr 时，额外修复 1 点完整性。",
		"Healing overflow becomes Block": "治疗溢出转化为护盾。",
		"Healing overflow repairs Mon3tr": "治疗溢出会修复 Mon3tr。",
		"First Medical each turn discounts next Command by 1; first Command discounts next Medical by 1": "每回合第一张医疗牌使下一张指令牌费用 -1；第一张指令牌使下一张医疗牌费用 -1。",
		"First time each combat Mon3tr would fall to 1, set to 4 instead": "每场战斗第一次 Mon3tr 将降至 1 完整性时，改为设为 4。",
		"Look at top 5 cards; choose 1 Medical or Command": "查看牌堆顶 5 张牌；选择 1 张医疗或指令牌。",
		"First HP heal each turn draws 1": "每回合第一次治疗生命时抽 1 张牌。",
		"If in Meltdown, repair 3 and draw 1; otherwise repair 2": "若处于融毁，修复 Mon3tr 3 点完整性并抽 1 张牌；否则修复 2 点完整性。",
		"This turn, each Medical draws 1, max 2 triggers": "本回合每张医疗牌抽 1 张牌，最多触发 2 次。",
		"Meltdown exits at Integrity < 3 instead of < 5": "融毁改为在完整性低于 3 时退出。",
		"Healing +2; each HP heal repairs Mon3tr 1": "治疗量 +2；每次治疗生命时修复 Mon3tr 1 点完整性。",
		"First time each turn Mon3tr is repaired to max Integrity, draw 2 and gain 1 Energy": "每回合第一次将 Mon3tr 修复至完整性上限时，抽 2 张牌并获得 1 能量。",
		"Every second Command each turn makes Mon3tr deal 8 to random enemy": "每回合第二张指令牌使 Mon3tr 对随机敌人造成 8 点伤害。",
		"First Protocol each turn draws 1 and discounts next Medical or Command by 1": "每回合第一张协议牌抽 1 张牌，并使下一张医疗或指令牌费用 -1。",
		"Medical makes next Mon3tr attack +2; Command makes next healing +2": "医疗牌使下一次 Mon3tr 攻击伤害 +2；指令牌使下一次治疗量 +2。",
		"Enter Meltdown directly. Mon3tr max Integrity becomes 20 for this combat": "直接进入融毁。本场战斗 Mon3tr 完整性上限变为 20。",
		"Healing, Block gain, and Mon3tr repair each trigger 25% of the other two": "治疗、获得护盾与修复 Mon3tr 会各自触发另外两项 25% 的效果。",
		"When an enemy HP <= 25%, Mon3tr automatically deals 16 to it once per combat per enemy": "每名敌人每场战斗限一次：当其生命不高于 25% 时，Mon3tr 自动对其造成 16 点伤害。",
		"Mon3tr turn-start auto repair +2. If in Meltdown, +3": "回合开始时 Mon3tr 自动修复 +2；若处于融毁，改为 +3。",
		"This turn, each HP heal makes Mon3tr deal equal damage to a random enemy; each Mon3tr damage heals Kal’tsit 2": "本回合每次治疗生命时，Mon3tr 对随机敌人造成等量伤害；每次 Mon3tr 造成伤害时，凯尔希治疗 2 点生命。",
		"If in Meltdown, Mon3tr loses 2 Integrity; otherwise repair Mon3tr 1": "若处于融毁，Mon3tr 失去 2 点完整性；否则修复 Mon3tr 1 点完整性。消耗。",
	}
	if text in exact:
		return exact[text]

	fallback = text
	fallback = fallback.replace("HP", "生命")
	fallback = fallback.replace("Block", "护盾")
	fallback = fallback.replace("Integrity", "完整性")
	fallback = fallback.replace("Meltdown", "融毁")
	fallback = fallback.replace("damage", "伤害")
	return fallback + "。"


def zh_upgrade_description(base_text: str, upgrade_text: str) -> str:
	upgrade = upgrade_text.strip().rstrip(".")
	if not upgrade:
		return zh_effect_description(base_text)
	match = re.match(r"heal (\d+), repair (\d+)", upgrade)
	if match:
		return "升级：治疗 %s 点生命，修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"heal (\d+), gain (\d+) Block", upgrade)
	if match:
		return "升级：治疗 %s 点生命，获得 %s 护盾。" % (match.group(1), match.group(2))
	match = re.match(r"heal (\d+), damage (\d+)", upgrade)
	if match:
		return "升级：治疗 %s 点生命；满血时 Mon3tr 造成 %s 点伤害。" % (match.group(1), match.group(2))
	match = re.match(r"(\d+) Block, repair (\d+)", upgrade)
	if match:
		return "升级：获得 %s 护盾；低完整性时修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"(\d+) Block", upgrade)
	if match:
		return "升级：获得 %s 护盾。" % match.group(1)
	match = re.match(r"heal (\d+), condition draw \+(\d+)", upgrade)
	if match:
		return "升级：治疗 %s 点生命；满足条件时额外抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"repair (\d+), low Integrity \+(\d+)", upgrade)
	if match:
		return "升级：修复 Mon3tr %s 点完整性；低完整性时额外修复 %s 点。" % (match.group(1), match.group(2))
	match = re.match(r"draw (\d+), condition draw \+(\d+)", upgrade)
	if match:
		return "升级：抽 %s 张牌；满足条件时额外抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"draw (\d+) / repair (\d+)", upgrade)
	if match:
		return "升级：抽 %s 张牌 / 修复 Mon3tr %s 点完整性。" % (match.group(1), match.group(2))
	match = re.match(r"discover (\d+), choose (\d+)", upgrade)
	if match:
		return "升级：发现 %s 张，选择 %s 张。" % (match.group(1), match.group(2))
	match = re.match(r"discover (\d+)", upgrade)
	if match:
		return "升级：发现 %s 张。" % match.group(1)
	match = re.match(r"low Integrity draw (\d+)", upgrade)
	if match:
		return "升级：低完整性时抽 %s 张牌。" % match.group(1)
	match = re.match(r"(\d+) twice", upgrade)
	if match:
		desc = "升级：每段 %s 点伤害，共两段。" % match.group(1)
		return append_low_integrity_note(desc) if "Mon3tr deals" in base_text else desc
	match = re.match(r"(\d+) three times", upgrade)
	if match:
		desc = "升级：每段 %s 点伤害，共三段。" % match.group(1)
		return append_low_integrity_note(desc) if "Mon3tr deals" in base_text else desc
	match = re.match(r"(\d+) per hit", upgrade)
	if match:
		desc = "升级：每段 %s 点伤害。" % match.group(1)
		return append_low_integrity_note(desc) if "Mon3tr deals" in base_text else desc
	match = re.match(r"(\d+) / (\d+)", upgrade)
	if match:
		return "升级：数值变为 %s / %s。" % (match.group(1), match.group(2))
	match = re.match(r"(\d+) \+ (\d+)", upgrade)
	if match and ("Kal’tsit deals" in base_text or "Kal'tsit deals" in base_text) and "Mon3tr deals" in base_text:
		return mon3tr_damage_note("升级：凯尔希造成 %s 点伤害，然后 Mon3tr 造成 %s 点伤害。" % (match.group(1), match.group(2)))
	match = re.match(r"\+(\d+) / \+(\d+)", upgrade)
	if match:
		return "升级：两个加成都提高至 +%s / +%s。" % (match.group(1), match.group(2))
	match = re.match(r"\+(\d+) and draw (\d+)", upgrade)
	if match:
		return "升级：加成提高至 +%s，并抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"\+(\d+)", upgrade)
	if match:
		return "升级：加成提高至 +%s。" % match.group(1)
	match = re.match(r"healing \+(\d+)", upgrade)
	if match:
		return "升级：治疗量 +%s。" % match.group(1)
	match = re.match(r"draw (\d+)", upgrade)
	if match:
		return "升级：抽 %s 张牌。" % match.group(1)
	match = re.match(r"heal (\d+)", upgrade)
	if match:
		return "升级：治疗 %s 点生命。" % match.group(1)
	match = re.match(r"repair (\d+)", upgrade)
	if match:
		return "升级：修复 Mon3tr %s 点完整性。" % match.group(1)
	match = re.match(r"reduce by (\d+) and draw (\d+)", upgrade)
	if match:
		return "升级：减少 %s 点完整性损失，并抽 %s 张牌。" % (match.group(1), match.group(2))
	match = re.match(r"threshold (\d+)", upgrade)
	if match:
		return "升级：触发阈值改为 %s。" % match.group(1)
	match = re.match(r"Meltdown repair (\d+)", upgrade)
	if match:
		return "升级：融毁中修复 Mon3tr %s 点完整性。" % match.group(1)
	match = re.match(r"turn-start repair \+(\d+) while Critical", upgrade)
	if match:
		return "升级：临界时回合开始额外修复 %s 点完整性。" % match.group(1)
	match = re.match(r"max (\d+)", upgrade)
	if match:
		return "升级：触发上限提高至 %s 次。" % match.group(1)
	match = re.match(r"choose (\d+)", upgrade)
	if match:
		return "升级：选择 %s 张。" % match.group(1)
	match = re.match(r"cost (\d+)", upgrade)
	if match:
		return "升级：费用变为 %s。" % match.group(1)
	match = re.match(r"lose (\d+) HP", upgrade)
	if match:
		return "升级：改为失去 %s 点生命。" % match.group(1)
	match = re.match(r"repair Mon3tr to (\d+) after entering", upgrade)
	if match:
		return "升级：进入融毁后，将 Mon3tr 修复至 %s 完整性。" % match.group(1)
	match = re.match(r"(\d+)%", upgrade)
	if match:
		return "升级：比例提高至 %s%%。" % match.group(1)
	match = re.match(r"(\d+)$", upgrade)
	if match:
		if "Mon3tr deals" in base_text:
			return mon3tr_damage_note("升级：Mon3tr 伤害提高至 %s。" % match.group(1), "Only usable in Meltdown" not in base_text)
		if "Block" in base_text:
			return "升级：护盾提高至 %s。" % match.group(1)
		if "repair" in base_text.lower():
			return "升级：修复量提高至 %s。" % match.group(1)
		return "升级：数值提高至 %s。" % match.group(1)
	match = re.match(r"first auto repair each turn draws (\d+)", upgrade)
	if match:
		return "升级：每回合第一次自动修复时抽 %s 张牌。" % match.group(1)
	if upgrade == "also repair Mon3tr 1":
		return "升级：同时修复 Mon3tr 1 点完整性。"
	if upgrade == "also repairs half overflow":
		return "升级：同时将一半治疗溢出用于修复 Mon3tr。"
	if upgrade == "also gain half overflow as Block":
		return "升级：同时将一半治疗溢出转化为护盾。"
	if upgrade == "each trigger draws 1 once per turn":
		return "升级：每种触发每回合各抽 1 张牌。"
	if upgrade == "first time each turn below 3, repair 2 before exit check":
		return "升级：每回合第一次低于 3 完整性时，先修复 2 点再检查融毁退出。"
	return "升级：" + upgrade + "。"


BASIC = [
	("KS_B01", "Surgical Strike", "手术切击", 1, "Attack", ["Scalpel"], "造成 6 点伤害。", [eff("damage", 6, "enemy")], "造成 8 点伤害。", [eff("damage", 8, "enemy")]),
	("KS_B02", "Tactical Guard", "战术护持", 1, "Skill", ["Block", "Medical", "Repair"], "获得 5 护盾，修复 Mon3tr 1 点完整性。", [eff("block", 5, "self"), eff("repair_mon3tr", 1, "self")], "获得 7 护盾，修复 Mon3tr 2 点完整性。", [eff("block", 7, "self"), eff("repair_mon3tr", 2, "self")]),
	("KS_B03", "Field Treatment", "现场治疗", 1, "Skill", ["Medical", "Heal"], "治疗 5 点生命；若生命已满，改为获得 5 护盾。", [eff("heal_or_block_if_full", 5, "self", amount_2=5)], "治疗 7 点生命；若生命已满，改为获得 7 护盾。", [eff("heal_or_block_if_full", 7, "self", amount_2=7)]),
	("KS_B04", "Structure Repair", "结构修复", 1, "Skill", ["Medical", "Repair"], "修复 Mon3tr 3 点完整性。", [eff("repair_mon3tr", 3, "self")], "修复 Mon3tr 5 点完整性。", [eff("repair_mon3tr", 5, "self")]),
	("KS_B05", "Mon3tr Command", "Mon3tr 指令", 1, "Skill", ["Command", "Mon3tr"], mon3tr_damage_note("Mon3tr 对目标造成 7 点伤害。"), [eff("mon3tr_damage", 7, "enemy")], mon3tr_damage_note("Mon3tr 对目标造成 9 点伤害。"), [eff("mon3tr_damage", 9, "enemy")]),
	("KS_B06", "Defensive Intercept", "防线拦截", 1, "Skill", ["Command", "Block", "Mon3tr"], mon3tr_damage_note("获得 6 护盾。Mon3tr 失去 1 完整性并造成 6 点伤害。"), [eff("block", 6, "self"), eff("damage_mon3tr", 1, "self"), eff("mon3tr_damage", 6, "enemy")], mon3tr_damage_note("获得 8 护盾。Mon3tr 失去 1 完整性并造成 8 点伤害。"), [eff("block", 8, "self"), eff("damage_mon3tr", 1, "self"), eff("mon3tr_damage", 8, "enemy")]),
	("KS_B07", "Clinical Scheduling", "临床调度", 1, "Skill", ["Draw", "Medical"], "抽 2 张牌；首张抽到的医疗或指令牌本回合费用 -1。", [eff("draw_discount_medical_command", 2, "self", amount_2=1)], "抽 3 张牌；首张抽到的医疗或指令牌本回合费用 -1。", [eff("draw_discount_medical_command", 3, "self", amount_2=1)]),
	("KS_B08", "Vital Injection", "维生注射", 0, "Skill", ["Medical", "Repair", "Heal"], "治疗 2 点生命，修复 Mon3tr 1 点完整性。", [eff("heal", 2, "self"), eff("repair_mon3tr", 1, "self")], "治疗 3 点生命，修复 Mon3tr 2 点完整性。", [eff("heal", 3, "self"), eff("repair_mon3tr", 2, "self")]),
	("KS_B09", "Integrity Calibration", "完整性校准", 1, "Skill", ["Repair", "Meltdown"], "修复 Mon3tr 2 点完整性；若因此达到完整性上限，抽 1。", [eff("repair_mon3tr_draw_if_reaches_max", 2, "self", amount_2=1)], "修复 Mon3tr 3 点完整性；若因此达到完整性上限，抽 1。", [eff("repair_mon3tr_draw_if_reaches_max", 3, "self", amount_2=1)]),
	("KS_B10", "Protocol Start", "协议启动", 1, "Power", ["Protocol", "Medical"], "能力。每回合第一次修复 Mon3tr 后，获得 2 护盾。", [eff("set_protocol_start", 2, "self")], "能力。每回合第一次修复 Mon3tr 后，获得 3 护盾并抽 1。", [eff("set_protocol_start", 3, "self", amount_2=1)]),
]


def parse_extra_cards() -> list[dict]:
	if not SPEC.exists():
		return []
	text = SPEC.read_text(encoding="utf-8")
	card_lines: list[dict] = []
	pattern = re.compile(r"^(KS_[CURLS]\d{2})\s+([^/]+?)\s*/\s*([^—]+?)\s+—\s+(.+)$")
	for raw in text.splitlines():
		line = raw.strip()
		match = pattern.match(line)
		if not match:
			continue
		code, en_name, cn_name, rest = match.groups()
		en_name = en_name.strip()
		cn_name = cn_name.strip()
		cost_match = re.search(r"(\d+)\s+cost", rest)
		cost = int(cost_match.group(1)) if cost_match else 1
		effect_text = rest.split("—", 1)[1].strip() if "—" in rest else rest
		upgrade = ""
		if "Upgrade:" in effect_text:
			effect_text, upgrade = effect_text.split("Upgrade:", 1)
			effect_text = effect_text.strip().rstrip(".")
			upgrade = upgrade.strip().rstrip(".")
		if code in BALANCE_OVERRIDES:
			effect_text, upgrade = BALANCE_OVERRIDES[code]
		prefix = code.split("_", 1)[1][0]
		rarity = RARITY_BY_PREFIX.get(prefix, "Common")
		card_type = "Power" if "Power" in rest else "Attack" if effect_text.startswith("Deal ") or "Kal’tsit deals" in effect_text else "Skill"
		if rarity == "Status":
			card_type = "Curse" if "Burden" in en_name or "Interference" in en_name or "Fatigue" in en_name or "Echo" in en_name else "Status"
		card_id = resource_id(code, en_name)
		card_lines.append({
			"code": code,
			"id": card_id,
			"en": en_name,
			"cn": cn_name,
			"cost": cost,
			"type": card_type,
			"rarity": rarity if card_type != "Curse" else "Curse",
			"effect": effect_text,
			"upgrade": upgrade,
			"tags": tags_from_text(en_name, effect_text, card_type, rarity if card_type != "Curse" else "Curse"),
		})
	return card_lines


def effect_block(effect: dict, index: int) -> str:
	lines = [
		f'[sub_resource type="Resource" id="{index}"]',
		'script = ExtResource("2")',
		f'effect_type = "{esc(effect["effect_type"])}"',
		f'amount = {int(effect.get("amount", 0))}',
		f'amount_2 = {int(effect.get("amount_2", 0))}',
		f'target = "{esc(effect.get("target", "enemy"))}"',
	]
	if effect.get("status_id"):
		lines.append(f'status_id = "{esc(effect["status_id"])}"')
	if effect.get("tag"):
		lines.append(f'tag = "{esc(effect["tag"])}"')
	if effect.get("condition"):
		lines.append(f'condition = "{esc(effect["condition"])}"')
	return "\n".join(lines)


def write_card(card_id: str, name: str, cost: int, card_type: str, tags: list[str], desc: str, rarity: str, effects: list[dict], conditional: list[dict], upgraded_id: str = "", exhausts: bool = False) -> None:
	all_effects = effects + conditional
	load_steps = 3 + len(all_effects)
	blocks: list[str] = [
		f'[gd_resource type="Resource" script_class="CardData" load_steps={load_steps} format=3]',
		"",
		'[ext_resource type="Script" path="res://scripts/data/CardData.gd" id="1"]',
		'[ext_resource type="Script" path="res://scripts/data/EffectData.gd" id="2"]',
		"",
	]
	for index, effect in enumerate(all_effects, 1):
		blocks.append(effect_block(effect, index))
		blocks.append("")
	effect_refs = ", ".join(f'SubResource("{i}")' for i in range(1, len(effects) + 1))
	cond_refs = ", ".join(f'SubResource("{i}")' for i in range(len(effects) + 1, len(all_effects) + 1))
	blocks.extend([
		"[resource]",
		'script = ExtResource("1")',
		f'id = "{esc(card_id)}"',
		f'display_name = "{esc(name)}"',
		f'cost = {cost}',
		f'card_type = "{esc(card_type)}"',
		'tags = PackedStringArray(' + ",".join(f'"{esc(tag)}"' for tag in tags) + ')',
		f'description = "{esc(desc)}"',
		f'rarity = "{esc(rarity)}"',
		f'exhausts = {"true" if exhausts else "false"}',
		f'upgraded_id = "{esc(upgraded_id)}"',
		f'effects = [{effect_refs}]',
		f'conditional_effects = [{cond_refs}]',
	])
	(OUT / f"{card_id}.tres").write_text("\n".join(blocks) + "\n", encoding="utf-8")


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for code, en, cn, cost, card_type, tags, desc, effects, upgraded_desc, upgraded_effects in BASIC:
		card_id = resource_id(code, en)
		plus_id = f"{card_id}_plus"
		write_card(card_id, cn, cost, card_type, tags, desc, "Starter", effects, [], plus_id)
		write_card(plus_id, cn + "+", cost, card_type, tags, upgraded_desc, "Starter", upgraded_effects, [], "", False)
	for card in parse_extra_cards():
		base_effects, conditional_effects = effects_from_text(card["effect"])
		base_desc = zh_effect_description(card["effect"])
		plus_id = f'{card["id"]}_plus'
		exhausts = "Exhaust" in card["effect"] or card["rarity"] in ["Status", "Curse"]
		write_card(card["id"], card["cn"], card["cost"], card["type"], card["tags"], base_desc, card["rarity"], base_effects, conditional_effects, plus_id if card["upgrade"] else "", exhausts)
		if card["upgrade"]:
			upgraded_text = upgraded_effect_text(card["effect"], card["upgrade"])
			plus_effects, plus_conditional = effects_from_text(upgraded_text)
			plus_cost = 0 if "cost 0" in card["upgrade"] else card["cost"]
			plus_desc = zh_upgrade_description(card["effect"], card["upgrade"])
			write_card(plus_id, card["cn"] + "+", plus_cost, card["type"], card["tags"], plus_desc, card["rarity"], plus_effects, plus_conditional, "", exhausts)


if __name__ == "__main__":
	main()
