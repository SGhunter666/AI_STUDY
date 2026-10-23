#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC_PATH = ROOT / "tmp" / "exusiai_spec.txt"
CARDS_DIR = ROOT / "data" / "cards"
MODULES_DIR = ROOT / "data" / "modules"
CHARMS_DIR = ROOT / "data" / "charms"
CHARACTER_PATH = ROOT / "data" / "characters" / "exusiai.tres"

CARD_SCRIPT = "res://scripts/data/CardData.gd"
EFFECT_SCRIPT = "res://scripts/data/EffectData.gd"
MODULE_SCRIPT = "res://scripts/data/ModuleData.gd"
CHARM_SCRIPT = "res://scripts/data/CharmData.gd"
CHARACTER_SCRIPT = "res://scripts/data/CharacterData.gd"


TAG_MAP = {
    "shot": "Shot",
    "multi_hit": "MultiHit",
    "ammo_use": "AmmoUse",
    "ammo_gain": "AmmoGain",
    "reload": "Reload",
    "mark": "Mark",
    "burst": "Burst",
    "support": "Support",
    "tempo": "Tempo",
    "retain": "Retain",
    "exhaust": "Exhaust",
    "aoe": "AOE",
    "finisher": "Finisher",
    "status": "Status",
    "curse": "Curse",
}

DESCRIPTION_OVERRIDES = {
    "EX_B06": (
        "准备 Burst：下回合能量 +2、抽牌 +2。本回合下一张 Shot 费用 -1。",
        "准备 Burst：下回合能量 +2、抽牌 +2。本回合下一张 Shot 费用 -1，并抽 1。",
    ),
    "EX_C17": (
        "准备 Burst：下回合进入爆发。本回合前两张 Shot +2 伤害。",
        "准备 Burst：下回合进入爆发。本回合前两张 Shot +3 伤害，并抽 1。",
    ),
    "EX_U13": (
        "准备 Burst：下回合进入爆发。本回合所有多段 Shot +1 次命中。",
        "准备 Burst：下回合进入爆发。本回合所有多段 Shot +1 次命中，并抽 1。",
    ),
    "EX_R15": (
        "失去 2 HP，恢复 3 Ammo，准备 Burst：下回合进入爆发。",
        "恢复 3 Ammo，准备 Burst：下回合进入爆发。",
    ),
    "EX_R20": (
        "准备 Burst：下回合进入爆发。从 Support 池中生成 1 张临时 Support 到手牌。",
        "准备 Burst：下回合进入爆发。从 Support 池中生成 1 张 0 费临时 Support 到手牌。",
    ),
}

RARITY_MAP = {
    "6.1": "Starter",
    "6.2": "Common",
    "6.3": "Uncommon",
    "6.4": "Rare",
    "6.5": "Legendary",
    "6.6": "Status",
}

MODULE_ID_MAP = {
    "EX_M01": "ex_m01_racing_magazine",
    "EX_M02": "ex_m02_light_stock",
    "EX_M03": "ex_m03_fast_feeder",
    "EX_M04": "ex_m04_target_scope",
    "EX_M05": "ex_m05_penguin_invoice",
    "EX_M06": "ex_m06_muzzle_suppressor",
    "EX_M07": "ex_m07_spare_pouch",
    "EX_M08": "ex_m08_highspeed_loader",
    "EX_M09": "ex_m09_cluster_calibrator",
    "EX_M10": "ex_m10_tempo_pedal",
    "EX_M11": "ex_m11_storm_permit",
    "EX_M12": "ex_m12_chainfire_recorder",
    "EX_M13": "ex_m13_airdrop_beacon",
    "EX_M14": "ex_m14_hunter_clearance",
    "EX_M15": "ex_m15_gunfire_halo",
    "EX_M16": "ex_m16_heaven_circuit",
}

MODULE_RARITY_MAP = {
    "EX_M01": "Common",
    "EX_M02": "Common",
    "EX_M03": "Common",
    "EX_M04": "Common",
    "EX_M05": "Common",
    "EX_M06": "Common",
    "EX_M07": "Uncommon",
    "EX_M08": "Uncommon",
    "EX_M09": "Uncommon",
    "EX_M10": "Uncommon",
    "EX_M11": "Rare",
    "EX_M12": "Rare",
    "EX_M13": "Rare",
    "EX_M14": "Rare",
    "EX_M15": "Legendary",
    "EX_M16": "Legendary",
}

CHARM_ID_MAP = {
    "EX_H01": "ex_h01_applepie_badge",
    "EX_H02": "ex_h02_fast_sling",
    "EX_H03": "ex_h03_red_dot_pendant",
    "EX_H04": "ex_h04_delivery_badge",
    "EX_H05": "ex_h05_spare_mag",
    "EX_H06": "ex_h06_gunfire_cross",
    "EX_H07": "ex_h07_express_terminal",
    "EX_H08": "ex_h08_angel_shard",
}

MULTI_HIT_MAP = {
    "一次": 1,
    "两次": 2,
    "三次": 3,
    "四次": 4,
    "五次": 5,
    "六次": 6,
    "八次": 8,
    "十次": 10,
    "十二次": 12,
}


def q(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def slugify_english(name: str) -> str:
    lowered = name.lower().replace("’", "").replace("'", "")
    lowered = re.sub(r"[^a-z0-9]+", "_", lowered)
    return lowered.strip("_")


def card_id(code: str, en_name: str) -> str:
    return f"{code.lower()}_{slugify_english(en_name)}"


def parse_tags(raw: str) -> list[str]:
    raw = raw.strip().strip("[]")
    if not raw:
        return []
    tags = []
    for item in raw.split(","):
        key = item.strip().lower()
        tags.append(TAG_MAP.get(key, key.title()))
    return tags


def fx(effect_type: str, amount: int = 0, target: str = "enemy", **extra) -> dict:
    data = {
        "effect_type": effect_type,
        "amount": amount,
        "target": target,
    }
    data.update(extra)
    return data


def clone_effects(effects: list[dict]) -> list[dict]:
    return [dict(effect) for effect in effects]


def desc_condition(clause: str) -> tuple[str, str]:
    clause = clause.strip(" 。")
    if clause.startswith("若你有 Burst") or clause.startswith("若有 Burst"):
        return "player_has_burst", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("否则"):
        return "not_player_has_burst", clause.replace("否则", "", 1).strip(" ，")
    if clause.startswith("若目标有 Mark"):
        return "target_has_mark", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若目标有 3+ Mark"):
        return "target_mark_gte:3", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若目标有 4+ Mark"):
        return "target_mark_gte:4", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若目标有 5+ Mark"):
        return "target_mark_gte:5", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若当前 Ammo ≤ 2"):
        return "player_ammo_lte:2", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若 Ammo = 0"):
        return "player_ammo_eq:0", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合打出过 Shot"):
        return "played_shot_this_turn_gte:1", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合打出过 Shot 牌"):
        return "played_shot_this_turn_gte:1", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合打出过 Support"):
        return "played_support_this_turn_gte:1", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合这不是第一张 Shot") or clause.startswith("若你本回合这不是第一张 Shot"):
        return "played_shot_this_turn_gte:1", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合已打出 2 张牌"):
        return "cards_played_this_turn_gte:2", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合已进入 Burst"):
        return "player_has_burst", clause.split("，", 1)[1] if "，" in clause else clause
    if clause.startswith("若本回合已恢复过 Ammo"):
        return "ammo_restored_this_turn", clause.split("，", 1)[1] if "，" in clause else clause
    return "", clause


def parse_multi_hits(text: str) -> int:
    for key, value in MULTI_HIT_MAP.items():
        if key in text:
            return value
    return 1


def first_int(text: str, default: int = 0) -> int:
    match = re.search(r"(\d+)", text)
    return int(match.group(1)) if match else default


def extract_pattern_amount(text: str, patterns: list[str], default: int = 0) -> int:
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return int(match.group(1))
    return default


def extract_damage_amount(text: str, default: int = 0) -> int:
    return extract_pattern_amount(text, [
        r"伤害[:：]\s*(\d+)",
        r"造成\s*(\d+)\s*伤害",
        r"造成\s*(\d+)\s*(?:一次|两次|三次|四次|五次|六次|八次|十次|十二次)",
        r"再造成\s*(\d+)\s*伤害",
        r"再造成\s*(\d+)",
        r"否则\s*(\d+)\s*伤害",
        r"改为\s*(\d+)\s*伤害",
        r"(\d+)\s*伤害",
    ], default)


def extract_draw_amount(text: str, default: int = 0) -> int:
    return extract_pattern_amount(text, [r"抽\s*(\d+)"], default)


def extract_block_amount(text: str, default: int = 0) -> int:
    return extract_pattern_amount(text, [r"获得\s*(\d+)\s*护盾"], default)


def extract_mark_amount(text: str, default: int = 0) -> int:
    return extract_pattern_amount(text, [r"施加\s*(\d+)\s*Mark"], default)


def extract_ammo_amount(text: str, default: int = 0) -> int:
    return extract_pattern_amount(text, [
        r"恢复\s*(\d+)\s*Ammo",
        r"获得\s*(\d+)\s*Ammo",
    ], default)


def extract_energy_amount(text: str, default: int = 0) -> int:
    return extract_pattern_amount(text, [
        r"获得\s*(\d+)\s*能量",
        r"费用返还\s*(\d+)",
        r"返还\s*(\d+)",
    ], default)


def merge_conditions(primary: str, extra: str) -> str:
    if primary and extra:
        return f"{primary}&{extra}"
    return primary or extra


def damage_effect_indices(effects: list[dict]) -> list[int]:
    result: list[int] = []
    for index, effect in enumerate(effects):
        if effect.get("effect_type") in {
            "damage",
            "damage_all",
            "damage_random_hits",
            "damage_ignore_block_percent",
            "damage_plus_mark",
            "damage_consume_all_mark",
            "damage_all_marked",
        }:
            result.append(index)
    return result


def set_effect_amount(effects: list[dict], effect_type: str, amount: int, occurrence: int = 0, condition_contains: str = "", key: str = "amount") -> bool:
    matched_index = 0
    for effect in effects:
        if effect.get("effect_type") != effect_type:
            continue
        if condition_contains and condition_contains not in str(effect.get("condition", "")):
            continue
        if matched_index == occurrence:
            effect[key] = amount
            return True
        matched_index += 1
    return False


def set_damage_amount(effects: list[dict], amount: int, occurrence: int = 0, condition_contains: str = "", key: str = "amount") -> bool:
    matched_index = 0
    for index in damage_effect_indices(effects):
        effect = effects[index]
        if condition_contains and condition_contains not in str(effect.get("condition", "")):
            continue
        if matched_index == occurrence:
            effect[key] = amount
            return True
        matched_index += 1
    return False


def add_effect(effects: list[dict], effect_type: str, amount: int = 0, target: str = "self", **extra) -> None:
    effects.append(fx(effect_type, amount, target, **extra))


def translate_upgrade_effects(code: str, base_effects: list[dict], upgrade_text: str, tags: list[str]) -> list[dict]:
    text = upgrade_text.strip().strip("。")
    if not text:
        return clone_effects(base_effects)

    if not base_effects:
        return fallback_effects(text, tags)

    translated = clone_effects(base_effects)

    if text.startswith("并抽 "):
        add_effect(translated, "draw", extract_draw_amount(text), "self")
        return translated
    if text.startswith("并恢复 ") and "Ammo" in text:
        add_effect(translated, "gain_ammo", extract_ammo_amount(text), "self")
        return translated
    if text.startswith("并 +"):
        bonus = first_int(text)
        damage_indices = damage_effect_indices(translated)
        if damage_indices:
            first_damage: dict = translated[damage_indices[0]]
            first_damage["amount"] = int(first_damage.get("amount", 0)) + bonus
        return translated
    if text.startswith("+"):
        delta = first_int(text)
        if set_damage_amount(translated, int(translated[damage_effect_indices(translated)[0]].get("amount", 0)) + delta):
            return translated
        for effect in translated:
            if effect.get("effect_type") == "set_meta_value":
                effect["amount"] = int(effect.get("amount", 0)) + delta
                return translated
        return translated
    if text.startswith("每次 "):
        amount = first_int(text)
        set_damage_amount(translated, amount)
        return translated
    if text.startswith("每层 "):
        amount = first_int(text)
        if not set_effect_amount(translated, "damage_plus_mark", amount, key="amount_2"):
            set_effect_amount(translated, "damage_consume_all_mark", amount, key="amount_2")
        return translated
    if text.startswith("Ammo 上限 +"):
        amount = first_int(text)
        set_effect_amount(translated, "set_max_ammo_bonus", amount)
        return translated
    if text in {"不弃牌", "改为不弃牌", "不掉血"}:
        return translated

    slash_match = re.match(r"^(\d+)\s*/\s*(\d+)$", text)
    if slash_match:
        first_value = int(slash_match.group(1))
        second_value = int(slash_match.group(2))
        if not set_damage_amount(translated, first_value, condition_contains="player_has_burst"):
            if not set_effect_amount(translated, "gain_ammo", first_value, condition_contains="player_has_burst"):
                set_damage_amount(translated, first_value)
        if not set_damage_amount(translated, second_value, condition_contains="not_player_has_burst"):
            if not set_effect_amount(translated, "gain_ammo", second_value, condition_contains="not_player_has_burst"):
                set_damage_amount(translated, second_value, 1)
        return translated

    plus_match = re.match(r"^(\d+)\s*\+\s*(\d+)$", text)
    if plus_match:
        set_damage_amount(translated, int(plus_match.group(1)))
        set_damage_amount(translated, int(plus_match.group(2)), 1)
        return translated

    if "伤害" in text:
        amount = extract_damage_amount(text)
        if amount > 0:
            if not set_damage_amount(translated, amount):
                set_effect_amount(translated, "damage_plus_mark", amount)
        if "无视 50% 护盾" in text:
            set_effect_amount(translated, "damage_ignore_block_percent", amount)
        return translated
    if "护盾" in text:
        set_effect_amount(translated, "block", extract_block_amount(text))
        return translated
    if "抽" in text:
        amount = extract_draw_amount(text)
        if not set_effect_amount(translated, "draw", amount):
            add_effect(translated, "draw", amount, "self")
        return translated
    if "施加" in text and "Mark" in text:
        set_effect_amount(translated, "apply_mark", extract_mark_amount(text))
        return translated
    if "恢复" in text and "Ammo" in text:
        amount = extract_ammo_amount(text)
        if not set_effect_amount(translated, "gain_ammo", amount):
            set_effect_amount(translated, "queue_reload", amount)
        return translated

    parsed = fallback_effects(text, tags)
    return parsed if parsed else translated


def fallback_effects(desc: str, tags: list[str]) -> list[dict]:
    effects: list[dict] = []
    primary_damage = 0
    primary_hits = 1
    for raw_clause in re.split(r"[；。]", desc):
        clause = raw_clause.strip()
        if not clause:
            continue
        condition, clause = desc_condition(clause)
        clause = clause.strip(" ，")
        clause_ammo_cost = extract_pattern_amount(clause, [r"消耗\s*(\d+)\s*Ammo"], 0)

        if "进入 Burst" in clause:
            effect = fx("enter_burst", 0, "self")
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        if "恢复到满 Ammo" in clause:
            effect = fx("fill_ammo", 0, "self")
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        elif ("恢复" in clause or "获得" in clause) and ("Ammo" in clause or "AmmoGain" in tags or "Reload" in tags):
            ammo_gain = extract_ammo_amount(clause, 0)
            if ammo_gain <= 0 and ("AmmoGain" in tags or "Reload" in tags):
                ammo_gain = first_int(clause)
            if ammo_gain > 0 and "回合结束时" not in clause:
                effect = fx("gain_ammo", ammo_gain, "self")
                if condition:
                    effect["condition"] = condition
                effects.append(effect)
        if "回合结束时恢复" in clause and ("Ammo" in clause or "AmmoGain" in tags or "Reload" in tags):
            reload_amount = extract_ammo_amount(clause, 0)
            if reload_amount <= 0:
                reload_amount = first_int(clause)
            effect = fx("queue_reload", reload_amount, "self", timing="turn_end")
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        if "施加" in clause and "Mark" in clause:
            effect = fx("apply_mark", extract_mark_amount(clause), "enemy")
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        if "抽" in clause:
            amount = extract_draw_amount(clause)
            if amount > 0:
                effect = fx("draw", amount, "self")
                if condition:
                    effect["condition"] = condition
                effects.append(effect)
        if "获得" in clause and "护盾" in clause:
            effect = fx("block", extract_block_amount(clause), "self")
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        if "获得 1 能量" in clause or "获得 2 能量" in clause:
            effect = fx("gain_energy", extract_energy_amount(clause), "self")
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        if "对所有有 Mark 的敌人造成" in clause:
            primary_damage = extract_damage_amount(clause)
            primary_hits = parse_multi_hits(clause)
            effect = fx("damage_all_marked", primary_damage)
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        elif "对所有敌人造成" in clause:
            primary_damage = extract_damage_amount(clause)
            primary_hits = parse_multi_hits(clause)
            effect = fx("damage_all", primary_damage)
            if condition:
                effect["condition"] = condition
            if clause_ammo_cost > 0:
                effect["condition"] = merge_conditions(f"player_ammo_gte:{clause_ammo_cost}", effect.get("condition", ""))
            effects.append(effect)
        elif "每层 Mark 再造成" in clause and "并消耗全部 Mark" in desc:
            effect = fx("damage_consume_all_mark", extract_damage_amount(desc), "enemy", amount_2=extract_damage_amount(clause, 1))
            if condition:
                effect["condition"] = condition
            if clause_ammo_cost > 0:
                effect["condition"] = merge_conditions(f"player_ammo_gte:{clause_ammo_cost}", effect.get("condition", ""))
            effects.append(effect)
        elif "每层 Mark 再造成" in clause or ("若目标有 Mark，再造成等同 Mark 层数的伤害" in clause):
            per_mark = extract_damage_amount(clause, 1)
            base_damage = extract_damage_amount(desc)
            effect = fx("damage_plus_mark", base_damage, "enemy", amount_2=per_mark)
            if condition:
                effect["condition"] = condition
            if clause_ammo_cost > 0:
                effect["condition"] = merge_conditions(f"player_ammo_gte:{clause_ammo_cost}", effect.get("condition", ""))
            effects.append(effect)
        elif "第二段 +" in clause:
            bonus_damage = first_int(clause)
            if bonus_damage > 0:
                effect = fx("damage", bonus_damage, "enemy")
                if condition:
                    effect["condition"] = condition
                effects.append(effect)
        elif "再打" in clause and primary_damage > 0:
            extra_hits = first_int(clause, 1)
            effect = fx("damage_random_hits", primary_damage, "enemy", amount_2=extra_hits)
            if condition:
                effect["condition"] = condition
            effects.append(effect)
        elif parse_multi_hits(clause) > 1 and "造成" not in clause and primary_damage > 0:
            desired_hits = parse_multi_hits(clause)
            extra_hits = max(0, desired_hits - primary_hits)
            if extra_hits > 0:
                effect = fx("damage_random_hits", primary_damage, "enemy", amount_2=extra_hits)
                if condition:
                    effect["condition"] = condition
                effects.append(effect)
        elif "造成" in clause or "伤害" in clause:
            damage_amount = extract_damage_amount(clause)
            if damage_amount > 0:
                hits = parse_multi_hits(clause)
                primary_damage = damage_amount
                primary_hits = hits
                effect_type = "damage_random_hits" if hits > 1 else "damage"
                effect = fx(effect_type, damage_amount, "enemy", amount_2=hits if hits > 1 else 0)
                if "无视 50% 护盾" in clause:
                    effect = fx("damage_ignore_block_percent", damage_amount, "enemy", amount_2=50)
                if condition:
                    effect["condition"] = condition
                if clause_ammo_cost > 0:
                    effect["condition"] = merge_conditions(f"player_ammo_gte:{clause_ammo_cost}", effect.get("condition", ""))
                effects.append(effect)
                if clause_ammo_cost > 0:
                    effects.append(fx("consume_ammo", clause_ammo_cost, "self", condition=f"player_ammo_gte:{clause_ammo_cost}"))
    return effects


def manual_effects(code: str, tags: list[str], desc: str) -> tuple[list[dict], list[dict] | None]:
    base: list[dict] | None = None
    upgrade: list[dict] | None = None
    if code == "EX_B06":
        base = [fx("enter_burst", 0, "self"), fx("set_meta_value", 1, "self", status_id="next_shot_cost_reduction"), fx("set_meta_value", 1, "self", status_id="next_shot_cost_reduction_charges")]
        upgrade = clone_effects(base) + [fx("draw", 1, "self")]
    elif code == "EX_B07":
        base = [fx("gain_ammo", 2, "self")]
        upgrade = [fx("gain_ammo", 2, "self"), fx("draw", 1, "self")]
    elif code == "EX_B09":
        base = [fx("set_meta_value", 1, "self", status_id="next_shot_damage_bonus"), fx("set_meta_value", 1, "self", status_id="next_shot_damage_bonus_charges"), fx("draw", 1, "self")]
        upgrade = [fx("set_meta_value", 2, "self", status_id="next_shot_damage_bonus"), fx("set_meta_value", 1, "self", status_id="next_shot_damage_bonus_charges"), fx("draw", 1, "self")]
    elif code == "EX_C04":
        base = [fx("draw", 1, "self"), fx("set_meta_value", 2, "self", status_id="next_shot_damage_bonus"), fx("set_meta_value", 1, "self", status_id="next_shot_damage_bonus_charges")]
        upgrade = [fx("draw", 2, "self"), fx("set_meta_value", 2, "self", status_id="next_shot_damage_bonus"), fx("set_meta_value", 1, "self", status_id="next_shot_damage_bonus_charges")]
    elif code == "EX_C05":
        base = [fx("set_meta_flag", 0, "self", status_id="fast_tempo_active")]
        upgrade = clone_effects(base) + [fx("set_meta_flag", 0, "self", status_id="fast_tempo_guard")]
    elif code == "EX_C08":
        base = [fx("gain_ammo", 1, "self", condition="player_has_burst"), fx("draw", 1, "self", condition="player_has_burst")]
        upgrade = clone_effects(base) + [fx("set_meta_value", 2, "self", status_id="next_shot_damage_bonus", condition="player_has_burst"), fx("set_meta_value", 1, "self", status_id="next_shot_damage_bonus_charges", condition="player_has_burst")]
    elif code == "EX_C15":
        base = [fx("damage", 7, "enemy", condition="player_ammo_gte:1"), fx("consume_ammo", 1, "self", condition="player_ammo_gte:1"), fx("gain_energy", 1, "self", condition="player_ammo_gte:1&target_has_mark")]
        upgrade = [fx("damage", 9, "enemy", condition="player_ammo_gte:1"), fx("consume_ammo", 1, "self", condition="player_ammo_gte:1"), fx("gain_energy", 1, "self", condition="player_ammo_gte:1&target_has_mark")]
    elif code == "EX_C16":
        base = [fx("set_meta_flag", 0, "self", status_id="mark_decay_locked_once")]
        upgrade = [fx("set_meta_flag", 0, "self", status_id="mark_decay_locked")]
    elif code == "EX_C17":
        base = [fx("enter_burst", 0, "self"), fx("set_meta_value", 2, "self", status_id="next_shot_damage_bonus"), fx("set_meta_value", 2, "self", status_id="next_shot_damage_bonus_charges")]
        upgrade = clone_effects(base) + [fx("draw", 1, "self")]
    elif code == "EX_C19":
        base = [fx("draw", 2, "self"), fx("set_next_card_cost_delta", -1, "self", condition="player_has_burst")]
        upgrade = [fx("draw", 3, "self"), fx("set_next_card_cost_delta", -1, "self", condition="player_has_burst")]
    elif code == "EX_C20":
        base = [fx("gain_energy", 2, "self", condition="player_ammo_eq:0")]
        upgrade = clone_effects(base) + [fx("draw", 1, "self", condition="player_ammo_eq:0")]
    elif code == "EX_C23":
        base = [fx("set_meta_flag", 0, "self", status_id="burst_kill_draw_active")]
        upgrade = clone_effects(base) + [fx("gain_ammo", 1, "self")]
    elif code == "EX_C24":
        base = [fx("set_meta_value", 4, "self", status_id="heated_barrel_damage"), fx("set_meta_value", 2, "self", status_id="heated_barrel_hits"), fx("set_meta_flag", 0, "self", status_id="heated_barrel_active")]
        upgrade = [fx("set_meta_value", 5, "self", status_id="heated_barrel_damage"), fx("set_meta_value", 2, "self", status_id="heated_barrel_hits"), fx("set_meta_flag", 0, "self", status_id="heated_barrel_active")]
    elif code == "EX_C27":
        base = [fx("set_meta_value", 2, "self", status_id="team_callout_block"), fx("set_meta_flag", 0, "self", status_id="team_callout_active")]
        upgrade = [fx("set_meta_value", 3, "self", status_id="team_callout_block"), fx("set_meta_flag", 0, "self", status_id="team_callout_active")]
    elif code == "EX_C30":
        base = [fx("set_meta_flag", 0, "self", status_id="urban_mobility_active")]
        upgrade = clone_effects(base) + [fx("set_meta_value", 2, "self", status_id="urban_mobility_bonus")]
    elif code == "EX_U01":
        base = [fx("set_max_ammo_bonus", 1, "self")]
        upgrade = [fx("set_max_ammo_bonus", 2, "self")]
    elif code == "EX_U03":
        base = [fx("queue_reload", 4, "self", timing="turn_end"), fx("draw", 1, "self")]
        upgrade = [fx("queue_reload", 4, "self", timing="turn_end"), fx("draw", 2, "self")]
    elif code == "EX_U04":
        base = [fx("set_meta_value", 2, "self", status_id="stabilized_track_bonus"), fx("set_meta_flag", 0, "self", status_id="stabilized_track_active")]
        upgrade = [fx("set_meta_value", 3, "self", status_id="stabilized_track_bonus"), fx("set_meta_flag", 0, "self", status_id="stabilized_track_active")]
    elif code == "EX_U11":
        base = [fx("set_meta_flag", 0, "self", status_id="headline_rhythm_active"), fx("set_meta_value", 1, "self", status_id="headline_rhythm_limit")]
        upgrade = [fx("set_meta_flag", 0, "self", status_id="headline_rhythm_active"), fx("set_meta_value", 2, "self", status_id="headline_rhythm_limit")]
    elif code == "EX_U13":
        base = [fx("enter_burst", 0, "self"), fx("set_meta_value", 1, "self", status_id="multi_shot_extra_hits_turn")]
        upgrade = clone_effects(base) + [fx("draw", 1, "self")]
    elif code == "EX_U14":
        base = [fx("set_meta_flag", 0, "self", status_id="chain_trigger_active")]
        upgrade = clone_effects(base) + [fx("set_meta_flag", 0, "self", status_id="burst_kill_draw_active")]
    elif code == "EX_U17":
        base = [fx("set_meta_flag", 0, "self", status_id="combo_rhythm_active")]
        upgrade = clone_effects(base) + [fx("set_meta_value", 1, "self", status_id="combo_rhythm_bonus")]
    elif code == "EX_U22":
        base = [fx("set_meta_value", 4, "self", status_id="air_cover_damage"), fx("set_meta_value", 2, "self", status_id="air_cover_hits"), fx("set_meta_flag", 0, "self", status_id="air_cover_active")]
        upgrade = [fx("set_meta_value", 5, "self", status_id="air_cover_damage"), fx("set_meta_value", 2, "self", status_id="air_cover_hits"), fx("set_meta_flag", 0, "self", status_id="air_cover_active")]
    elif code == "EX_R01":
        base = [fx("set_max_ammo_bonus", 2, "self"), fx("set_meta_value", 1, "self", status_id="battle_start_bonus_ammo")]
        upgrade = [fx("set_max_ammo_bonus", 3, "self"), fx("set_meta_value", 1, "self", status_id="battle_start_bonus_ammo")]
    elif code == "EX_R03":
        base = [fx("set_meta_value", 2, "self", status_id="seamless_reload_amount"), fx("set_meta_flag", 0, "self", status_id="seamless_reload_active")]
        upgrade = [fx("set_meta_value", 3, "self", status_id="seamless_reload_amount"), fx("set_meta_flag", 0, "self", status_id="seamless_reload_active")]
    elif code == "EX_R05":
        base = [fx("set_meta_value", 3, "self", status_id="fireline_control_bonus"), fx("set_meta_flag", 0, "self", status_id="fireline_control_active")]
        upgrade = [fx("set_meta_value", 4, "self", status_id="fireline_control_bonus"), fx("set_meta_flag", 0, "self", status_id="fireline_control_active")]
    elif code == "EX_R06":
        base = [fx("set_meta_value", 1, "self", status_id="angel_mark_bonus"), fx("set_meta_flag", 0, "self", status_id="angel_mark_active")]
        upgrade = [fx("set_meta_value", 2, "self", status_id="angel_mark_bonus"), fx("set_meta_flag", 0, "self", status_id="angel_mark_active")]
    elif code == "EX_R09":
        base = [fx("set_meta_value", 4, "self", status_id="first_shot_vs_mark_bonus_static"), fx("set_meta_flag", 0, "self", status_id="terminal_lock_active")]
        upgrade = [fx("set_meta_value", 6, "self", status_id="first_shot_vs_mark_bonus_static"), fx("set_meta_flag", 0, "self", status_id="terminal_lock_active")]
    elif code == "EX_R11":
        base = [fx("set_meta_value", 2, "self", status_id="burst_entry_draw"), fx("set_meta_value", 1, "self", status_id="burst_entry_ammo_once"), fx("set_meta_flag", 0, "self", status_id="angelic_storm_active")]
        upgrade = [fx("set_meta_value", 3, "self", status_id="burst_entry_draw"), fx("set_meta_value", 1, "self", status_id="burst_entry_ammo_once"), fx("set_meta_flag", 0, "self", status_id="angelic_storm_active")]
    elif code == "EX_R12":
        base = [fx("set_meta_value", 2, "self", status_id="fire_frenzy_bonus"), fx("set_meta_flag", 0, "self", status_id="fire_frenzy_active")]
        upgrade = [fx("set_meta_value", 3, "self", status_id="fire_frenzy_bonus"), fx("set_meta_flag", 0, "self", status_id="fire_frenzy_active")]
    elif code == "EX_R14":
        base = [fx("set_meta_flag", 0, "self", status_id="endless_chain_active")]
        upgrade = clone_effects(base) + [fx("set_meta_flag", 0, "self", status_id="burst_kill_draw_active")]
    elif code == "EX_R16":
        base = [fx("set_meta_value", 3, "self", status_id="pl_standard_kit_block"), fx("set_meta_flag", 0, "self", status_id="pl_standard_kit_active")]
        upgrade = [fx("set_meta_value", 5, "self", status_id="pl_standard_kit_block"), fx("set_meta_flag", 0, "self", status_id="pl_standard_kit_active")]
    elif code == "EX_R17":
        base = [fx("set_meta_value", 2, "self", status_id="support_shot_bonus"), fx("set_meta_flag", 0, "self", status_id="cover_network_active")]
        upgrade = [fx("set_meta_value", 3, "self", status_id="support_shot_bonus"), fx("set_meta_flag", 0, "self", status_id="cover_network_active")]
    elif code == "EX_R18":
        base = [fx("add_random_cards_to_hand_free", 1, "self", meta={"tags_any": ["Reload", "AmmoGain"], "pool_size": 3})]
        upgrade = [fx("add_random_cards_to_hand_free", 1, "self", meta={"tags_any": ["Reload", "AmmoGain"], "pool_size": 4})]
    elif code == "EX_L03":
        base = [fx("set_meta_flag", 0, "self", status_id="mark_decay_locked"), fx("set_meta_value", 10, "self", status_id="first_shot_vs_mark_bonus_static")]
        upgrade = [fx("set_meta_flag", 0, "self", status_id="mark_decay_locked"), fx("set_meta_value", 12, "self", status_id="first_shot_vs_mark_bonus_static")]
    elif code == "EX_L04":
        base = [fx("set_meta_flag", 0, "self", status_id="angel_combo_active")]
        upgrade = clone_effects(base) + [fx("set_meta_value", 1, "self", status_id="angel_combo_damage_bonus")]
    elif code == "EX_L07":
        base = [fx("add_random_cards_to_hand_free", 2, "self", meta={"tags_any": ["Support", "Reload", "Burst"], "pool_size": 4})]
        upgrade = [fx("add_random_cards_to_hand_free", 2, "self", meta={"tags_any": ["Support", "Reload", "Burst"], "pool_size": 5})]
    elif code == "EX_U21":
        base = [fx("fetch_low_cost_from_discard", 1, "self", meta={"max_cost": 1})]
        upgrade = clone_effects(base) + [fx("draw", 1, "self")]
    elif code == "EX_S01":
        base = [fx("set_next_tag_cost_delta", 1, "self", tag="Shot")]
        upgrade = clone_effects(base)
    elif code == "EX_S04":
        base = [fx("set_next_tag_damage_bonus", -3, "self", tag="Shot")]
        upgrade = clone_effects(base)
    elif code == "EX_S06":
        base = [fx("set_meta_flag", 0, "self", status_id="overheated_bolt_active")]
        upgrade = clone_effects(base)
    elif code == "EX_S07":
        base = [fx("set_meta_flag", 0, "self", status_id="command_delay_active")]
        upgrade = clone_effects(base)
    elif code == "EX_M01":
        base = [fx("set_meta_value", 1, "self", status_id="battle_start_bonus_ammo")]
    elif code == "EX_M02":
        base = [fx("set_meta_value", 2, "self", status_id="first_shot_bonus_damage")]
    elif code == "EX_M03":
        base = [fx("set_meta_flag", 0, "self", status_id="ammo_refill_draw_first")]
    elif code == "EX_M04":
        base = [fx("set_meta_flag", 0, "self", status_id="target_scope_active")]
    elif code == "EX_M05":
        base = [fx("set_meta_flag", 0, "self", status_id="pl_standard_kit_active"), fx("set_meta_value", 1, "self", status_id="pl_standard_kit_block")]
    elif code == "EX_M06":
        base = [fx("set_meta_value", 1, "self", status_id="multihit_segment_bonus")]
    elif code == "EX_M07":
        base = [fx("set_max_ammo_bonus", 1, "self")]
    elif code == "EX_M08":
        base = [fx("set_meta_flag", 0, "self", status_id="low_ammo_reload_active")]
    elif code == "EX_M09":
        base = [fx("set_meta_value", 1, "self", status_id="marked_target_bonus_damage_static")]
    elif code == "EX_M10":
        base = [fx("set_meta_flag", 0, "self", status_id="tempo_pedal_active")]
    elif code == "EX_M11":
        base = [fx("set_meta_value", 2, "self", status_id="burst_entry_ammo_once")]
    elif code == "EX_M12":
        base = [fx("set_meta_value", 3, "self", status_id="second_shot_bonus_damage")]
    elif code == "EX_M13":
        base = []
    elif code == "EX_M14":
        base = [fx("set_meta_value", 6, "self", status_id="first_shot_vs_mark_bonus_static")]
    elif code == "EX_M15":
        base = [fx("set_meta_value", 2, "self", status_id="burst_shot_damage_bonus_persistent")]
    elif code == "EX_M16":
        base = [fx("set_meta_flag", 0, "self", status_id="ammo_three_energy_active")]
    return base or [], upgrade


def format_effect_subresources(effects: list[dict]) -> tuple[list[str], list[str]]:
    lines: list[str] = []
    refs: list[str] = []
    for index, effect in enumerate(effects, start=1):
        sub_id = str(index)
        lines.append(f'[sub_resource type="Resource" id="{sub_id}"]')
        lines.append(f'script = ExtResource("2")')
        lines.append(f'effect_type = {q(effect["effect_type"])}')
        for key in ["amount", "amount_2", "status_id", "card_id", "tag", "timing", "damage_type", "target", "condition", "meta"]:
            if key not in effect:
                continue
            value = effect[key]
            if isinstance(value, str):
                lines.append(f"{key} = {q(value)}")
            elif isinstance(value, dict):
                lines.append(f"{key} = {json.dumps(value, ensure_ascii=False)}")
            else:
                lines.append(f"{key} = {json.dumps(value)}")
        lines.append("")
        refs.append(f'SubResource("{sub_id}")')
    return lines, refs


def write_card_resource(card: dict, output_path: Path) -> None:
    effects = card.get("effects", [])
    conditional_effects = card.get("conditional_effects", [])
    total_subresources = len(effects) + len(conditional_effects)
    load_steps = 2 + total_subresources
    lines: list[str] = [
        f'[gd_resource type="Resource" script_class="CardData" load_steps={load_steps} format=3]',
        "",
        f'[ext_resource type="Script" path="{CARD_SCRIPT}" id="1"]',
        f'[ext_resource type="Script" path="{EFFECT_SCRIPT}" id="2"]',
        "",
    ]
    effect_lines, effect_refs = format_effect_subresources(effects)
    conditional_shifted = []
    if conditional_effects:
        shifted = []
        for idx, effect in enumerate(conditional_effects, start=len(effects) + 1):
            shifted.append((str(idx), effect))
        effect_lines_cond: list[str] = []
        for sub_id, effect in shifted:
            effect_lines_cond.append(f'[sub_resource type="Resource" id="{sub_id}"]')
            effect_lines_cond.append('script = ExtResource("2")')
            effect_lines_cond.append(f'effect_type = {q(effect["effect_type"])}')
            for key in ["amount", "amount_2", "status_id", "card_id", "tag", "timing", "damage_type", "target", "condition", "meta"]:
                if key not in effect:
                    continue
                value = effect[key]
                if isinstance(value, str):
                    effect_lines_cond.append(f"{key} = {q(value)}")
                elif isinstance(value, dict):
                    effect_lines_cond.append(f"{key} = {json.dumps(value, ensure_ascii=False)}")
                else:
                    effect_lines_cond.append(f"{key} = {json.dumps(value)}")
            effect_lines_cond.append("")
            conditional_shifted.append(f'SubResource("{sub_id}")')
        effect_lines.extend(effect_lines_cond)
    lines.extend(effect_lines)
    lines.extend([
        "[resource]",
        'script = ExtResource("1")',
        f'id = {q(card["id"])}',
        f'display_name = {q(card["name_cn"])}',
        f'cost = {card["cost"]}',
        f'card_type = {q(card["card_type"])}',
        f'tags = PackedStringArray({", ".join(q(tag) for tag in card["tags"])})' if card["tags"] else "tags = PackedStringArray()",
        f'description = {q(card["description"])}',
        f'rarity = {q(card["rarity"])}',
    ])
    if card.get("exhausts"):
        lines.append("exhausts = true")
    if card.get("innate"):
        lines.append("innate = true")
    if card.get("ethereal"):
        lines.append("ethereal = true")
    if card.get("upgraded_id"):
        lines.append(f'upgraded_id = {q(card["upgraded_id"])}')
    lines.append(f'effects = [{", ".join(effect_refs)}]' if effect_refs else "effects = []")
    lines.append(f'conditional_effects = [{", ".join(conditional_shifted)}]' if conditional_shifted else "conditional_effects = []")
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_module_resource(module_id: str, name_cn: str, desc: str, rarity: str) -> None:
    path = MODULES_DIR / f"{module_id}.tres"
    text = "\n".join([
        '[gd_resource type="Resource" script_class="ModuleData" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Script" path="{MODULE_SCRIPT}" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        f'id = {q(module_id)}',
        f'display_name = {q(name_cn)}',
        f'rarity = {q(rarity)}',
        f'description = {q(desc)}',
    ]) + "\n"
    path.write_text(text, encoding="utf-8")


def write_charm_resource(charm_id: str, name_cn: str, desc: str) -> None:
    path = CHARMS_DIR / f"{charm_id}.tres"
    text = "\n".join([
        '[gd_resource type="Resource" script_class="CharmData" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Script" path="{CHARM_SCRIPT}" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        f'id = {q(charm_id)}',
        f'display_name = {q(name_cn)}',
        f'description = {q(desc)}',
        'slot_type = "charm"',
    ]) + "\n"
    path.write_text(text, encoding="utf-8")


def write_character_resource() -> None:
    text = "\n".join([
        '[gd_resource type="Resource" script_class="CharacterData" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Script" path="{CHARACTER_SCRIPT}" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        'id = "exusiai"',
        'display_name = "能天使"',
        'max_hp = 70',
        'starting_energy = 3',
        'combat_resource_name = "Ammo"',
        'resource_max = 6',
        'passive_id = "angel_of_bullets"',
        'starter_deck = PackedStringArray("ex_b01_burst_shot", "ex_b01_burst_shot", "ex_b02_cover_step", "ex_b02_cover_step", "ex_b03_quick_reload", "ex_b04_target_ping", "ex_b05_crossfire_ping", "ex_b06_burst_entry", "ex_b07_mag_swap", "ex_b08_angled_volley")',
        'starter_charms = PackedStringArray("ex_h01_applepie_badge", "ex_h02_fast_sling")',
    ]) + "\n"
    CHARACTER_PATH.write_text(text, encoding="utf-8")


def parse_spec_cards(text: str) -> list[dict]:
    lines = [line.rstrip() for line in text.splitlines()]
    cards: list[dict] = []
    current_rarity = ""
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        section_match = re.match(r"^(6\.\d)", line)
        if section_match and section_match.group(1) in RARITY_MAP:
            current_rarity = RARITY_MAP[section_match.group(1)]
            i += 1
            continue
        if re.match(r"^[7-9]\.", line):
            current_rarity = ""
            break
        if not re.match(r"^EX_[BCURLS]\d{2}\b", line) or not current_rarity:
            i += 1
            continue
        parts = [part.strip() for part in line.split(" / ")]
        if len(parts) >= 6:
            code, name_cn, name_en, cost_text, card_type_raw, tags_raw = parts[:6]
            cost = int(cost_text)
            card_type = card_type_raw.capitalize()
            tags = parse_tags(tags_raw)
            i += 1
        else:
            if len(parts) < 2:
                i += 1
                continue
            code, name_cn = parts[:2]
            name_en = parts[2] if len(parts) >= 3 else name_cn
            i += 1
            stat_line = lines[i].strip().lstrip("•").strip()
            stat_parts = [part.strip() for part in stat_line.split(" / ")]
            cost = int(re.search(r"(\d+)", stat_parts[0]).group(1))
            type_key = stat_parts[1].strip().lower()
            card_type = "Curse" if type_key == "curse" else "Skill"
            tags = parse_tags(stat_parts[2])
            i += 1
        effect_text = ""
        upgrade_text = ""
        while i < len(lines):
            bullet = lines[i].strip()
            if bullet.startswith("EX_") or re.match(r"^(6\.\d|7\.|8\.)", bullet):
                break
            if bullet.startswith("•") and "效果：" in bullet:
                effect_text = bullet.split("效果：", 1)[1].strip()
            elif bullet.startswith("•") and "伤害：" in bullet:
                extra_damage = bullet.split("伤害：", 1)[1].strip()
                effect_text = f"{effect_text}；伤害：{extra_damage}" if effect_text else f"伤害：{extra_damage}"
            elif bullet.startswith("•") and "升级：" in bullet:
                upgrade_text = bullet.split("升级：", 1)[1].strip()
            i += 1
        cid = card_id(code, name_en)
        base_effects, upgrade_override = manual_effects(code, tags, effect_text)
        base_effects = base_effects or fallback_effects(effect_text, tags)
        upgrade_effects = upgrade_override or translate_upgrade_effects(code, base_effects, upgrade_text or effect_text, tags)
        if code in DESCRIPTION_OVERRIDES:
            effect_text, upgrade_text = DESCRIPTION_OVERRIDES[code]
        rarity = current_rarity
        card_type_final = "Curse" if "Curse" in tags else card_type
        if current_rarity == "Status" and "Curse" not in tags:
            card_type_final = "Skill"
        cost_final = 99 if card_type_final == "Curse" else cost
        cards.append({
            "id": cid,
            "name_cn": name_cn,
            "cost": cost_final,
            "card_type": card_type_final,
            "tags": tags,
            "description": effect_text,
            "rarity": "Curse" if "Curse" in tags else rarity,
            "effects": base_effects,
            "conditional_effects": [],
            "upgraded_id": f"{cid}_plus",
            "ethereal": card_type_final == "Curse",
            "upgrade": {
                "id": f"{cid}_plus",
                "name_cn": f"{name_cn}+",
                "cost": cost_final,
                "card_type": card_type_final,
                "tags": tags,
                "description": upgrade_text or effect_text,
                "rarity": "Curse" if "Curse" in tags else rarity,
                "effects": upgrade_effects,
                "conditional_effects": [],
                "ethereal": card_type_final == "Curse",
            },
        })
    return cards


def parse_named_entries(text: str, prefix: str, section_number: str, explicit_ids: dict[str, str]) -> list[tuple[str, str, str, str]]:
    lines = [line.rstrip() for line in text.splitlines()]
    results: list[tuple[str, str, str, str]] = []
    in_section = False
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith(section_number):
            in_section = True
            i += 1
            continue
        if in_section and re.match(r"^\d+\.", line):
            break
        if in_section and line.startswith(prefix):
            code, name_cn = [part.strip() for part in line.split(" / ", 1)]
            i += 1
            desc = ""
            while i < len(lines):
                bullet = lines[i].strip()
                if bullet.startswith(prefix) or re.match(r"^\d+\.", bullet):
                    break
                if bullet.startswith("•"):
                    desc = bullet.lstrip("•").strip()
                    break
                i += 1
            resource_id = explicit_ids.get(code, code.lower())
            results.append((code, resource_id, name_cn, desc))
        i += 1
    return results


def main() -> None:
    text = SPEC_PATH.read_text(encoding="utf-8")
    cards = parse_spec_cards(text)
    for card in cards:
        write_card_resource(card, CARDS_DIR / f'{card["id"]}.tres')
        upgrade = dict(card["upgrade"])
        upgrade["upgraded_id"] = ""
        write_card_resource(upgrade, CARDS_DIR / f'{upgrade["id"]}.tres')

    for code, module_id, name_cn, desc in parse_named_entries(text, "EX_M", "7.", MODULE_ID_MAP):
        write_module_resource(module_id, name_cn, desc, MODULE_RARITY_MAP.get(code, "Rare"))
    for _code, charm_id, name_cn, desc in parse_named_entries(text, "EX_H", "8.", CHARM_ID_MAP):
        if charm_id == "ex_h02_fast_sling":
            desc = "战斗开始时获得 8 护盾。"
        write_charm_resource(charm_id, name_cn, desc)
    write_character_resource()
    print(f"Generated {len(cards) * 2} Exusiai card resources.")


if __name__ == "__main__":
    main()
