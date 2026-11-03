class_name SkillDefs
extends RefCounted
## Combat behaviour for every skill in assets/data/skills.json.
## Names, descriptions, levels, costs and the tree come from the Flutter catalog
## (barbarian_catalog.dart / sorceress_catalog.dart); the numbers below are the
## Godot port's simplified tuning. `mult` scales hero attack, `growth` is +x per rank.

const FIRE := Color(1.0, 0.55, 0.2)
const COLD := Color(0.6, 0.85, 1.0)
const LIGHT := Color(0.75, 0.8, 1.0)
const STEEL := Color(1.0, 0.92, 0.7)
const SHOUT := Color(1.0, 0.78, 0.45)

const DEFS := {
	# ── 전사: 기본·특수 ──
	"cleave": {"type": "melee", "mult": 1.0, "growth": 0.06, "arc": 70, "range": 105},
	"shadowAssault": {"type": "shadow", "mult": 1.3, "growth": 0.1, "targets": 5, "range": 380},
	"battleSprint": {"type": "buff", "buff": "sprint", "duration": 2.5, "value": 0.6},
	# ── 전사: 전투 기술 ──
	"bash": {"type": "melee", "mult": 1.7, "growth": 0.1, "arc": 40, "range": 100, "knock": 280},
	"leap": {"type": "leap", "distance": 230, "dist_growth": 8, "radius": 110, "knock": 260},
	"doubleSwing": {"type": "melee", "hits": 2, "mult": 0.85, "growth": 0.07, "arc": 60, "range": 105, "free_at": 9},
	"stun": {"type": "melee", "mult": 1.0, "growth": 0.06, "arc": 40, "range": 100, "stun": 1.2, "stun_growth": 0.1},
	"doubleThrow": {"type": "proj", "count": 2, "spread": 12, "mult": 0.9, "growth": 0.08, "speed": 720, "color": STEEL, "throw": true},
	"leapAttack": {"type": "leap", "to_enemy": true, "distance": 320, "radius": 70, "mult": 2.0, "growth": 0.12},
	"concentrate": {"type": "melee", "mult": 1.6, "growth": 0.09, "arc": 45, "range": 100, "self_buff": "guard", "buff_time": 2.0, "buff_value": 0.5},
	"frenzy": {"type": "melee", "hits": 2, "mult": 0.8, "growth": 0.06, "arc": 60, "range": 105, "frenzy": true},
	"whirlwind": {"type": "spin", "radius": 125, "ticks": 3, "mult": 0.8, "growth": 0.06},
	"berserk": {"type": "melee", "mult": 2.4, "growth": 0.12, "arc": 45, "range": 100, "self_buff": "berserk", "buff_time": 1.5, "buff_value": 1.0},
	# ── 전사: 함성 ──
	"howl": {"type": "nova", "radius": 210, "fear": 2.0, "fear_growth": 0.2, "color": SHOUT},
	"findPotion": {"type": "corpse", "reward": "potion", "chance": 0.265, "chance_growth": 0.015, "chance_cap": 0.65},
	"taunt": {"type": "nova", "radius": 240, "taunt": 6.0, "color": Color(1, 0.4, 0.3)},
	"shout": {"type": "buff", "buff": "shout", "duration": 12.0, "dur_growth": 1.0, "value": 0.6, "value_growth": 0.08},
	"findItem": {"type": "corpse", "reward": "item", "chance": 0.162, "chance_growth": 0.012, "chance_cap": 0.65},
	"battleCry": {"type": "nova", "radius": 220, "cry": 6.0, "cry_value": 0.2, "cry_growth": 0.02, "color": Color(1, 0.6, 0.35)},
	"battleOrders": {"type": "buff", "buff": "orders", "duration": 20.0, "dur_growth": 2.0, "value": 0.3, "value_growth": 0.03},
	"grimWard": {"type": "corpse", "reward": "ward", "duration": 10.0, "dur_growth": 1.0, "radius": 180},
	"warcry": {"type": "nova", "radius": 200, "mult": 1.4, "growth": 0.12, "stun": 1.0, "color": SHOUT},
	"battleCommand": {"type": "buff", "buff": "command", "duration": 10.0, "dur_growth": 1.0, "value": 1.0},
	# ── 전사: 전투 숙련 (passive) ──
	"swordMastery": {"type": "passive", "stat": "weapon", "value": 0.1, "value_growth": 0.06},
	"axeMastery": {"type": "passive", "stat": "weapon", "value": 0.1, "value_growth": 0.06},
	"maceMastery": {"type": "passive", "stat": "weapon", "value": 0.1, "value_growth": 0.06},
	"polearmMastery": {"type": "passive", "stat": "weapon", "value": 0.1, "value_growth": 0.06},
	"spearMastery": {"type": "passive", "stat": "weapon", "value": 0.1, "value_growth": 0.06},
	"throwingMastery": {"type": "passive", "stat": "throw", "value": 0.15, "value_growth": 0.07},
	"increasedStamina": {"type": "passive", "stat": "stamina", "value": 0.3, "value_growth": 0.1},
	"ironSkin": {"type": "passive", "stat": "armor", "value": 0.3, "value_growth": 0.1},
	"increasedSpeed": {"type": "passive", "stat": "speed", "value": 0.13, "value_growth": 0.015},
	"naturalResistance": {"type": "passive", "stat": "resist", "value": 0.06, "value_growth": 0.012},
	# ── 마법사: 기본 ──
	"sorceressAttack": {"type": "melee", "mult": 0.7, "growth": 0.0, "arc": 55, "range": 95},
	"firebolt": {"type": "proj", "element": "fire", "mult": 1.0, "growth": 0.1, "speed": 620, "color": FIRE},
	"chargedBolt": {"type": "proj", "element": "lightning", "count": 3, "count_growth": 0.5, "max_count": 8, "spread": 55, "mult": 0.45, "growth": 0.08, "speed": 430, "color": LIGHT, "wiggle": true},
	"iceBolt": {"type": "proj", "element": "cold", "mult": 0.85, "growth": 0.09, "speed": 560, "slow": 2.0, "color": COLD},
	# ── 마법사: 냉기 ──
	"frozenArmor": {"type": "buff", "buff": "armor", "armor": "frozen", "duration": 60.0, "value": 0.4, "value_growth": 0.05},
	"frostNova": {"type": "nova", "element": "cold", "radius": 200, "mult": 0.7, "growth": 0.09, "slow": 3.0, "color": COLD},
	"iceBlast": {"type": "proj", "element": "cold", "mult": 1.3, "growth": 0.1, "speed": 600, "freeze": 1.5, "freeze_growth": 0.1, "color": COLD},
	"shiverArmor": {"type": "buff", "buff": "armor", "armor": "shiver", "duration": 60.0, "value": 0.5, "value_growth": 0.05},
	"glacialSpike": {"type": "proj", "element": "cold", "mult": 1.2, "growth": 0.1, "speed": 620, "explode": 65, "freeze": 1.2, "color": COLD},
	"blizzard": {"type": "zone", "element": "cold", "radius": 135, "duration": 4.0, "tick": 0.35, "mult": 0.45, "growth": 0.09, "slow": 1.0, "color": COLD, "shards": true},
	"chillingArmor": {"type": "buff", "buff": "armor", "armor": "chilling", "duration": 60.0, "value": 0.45, "value_growth": 0.05},
	"frozenOrb": {"type": "orb", "element": "cold", "mult": 0.35, "growth": 0.08, "speed": 330, "life": 1.6, "color": COLD},
	"coldMastery": {"type": "passive", "stat": "cold", "value": 0.2, "value_growth": 0.05},
	# ── 마법사: 번개 ──
	"staticField": {"type": "nova", "element": "lightning", "radius": 180, "radius_growth": 8, "pct": 0.25, "color": LIGHT},
	"telekinesis": {"type": "proj", "element": "lightning", "mult": 0.5, "growth": 0.06, "speed": 820, "knock": 320, "color": Color(0.85, 0.75, 1.0)},
	"nova": {"type": "nova", "element": "lightning", "radius": 220, "mult": 1.0, "growth": 0.09, "color": LIGHT},
	"lightning": {"type": "beam", "element": "lightning", "mult_min": 0.3, "mult_max": 2.2, "growth": 0.1, "length": 560, "color": LIGHT},
	"chainLightning": {"type": "chain", "element": "lightning", "mult": 0.9, "growth": 0.09, "jumps": 4, "jump_growth": 0.25, "radius": 230, "range": 480, "color": LIGHT},
	"blink": {"type": "blink", "distance": 220, "dist_growth": 12, "cost_drop": 1.0, "min_cost": 8},
	"thunderStorm": {"type": "buff", "buff": "storm", "duration": 20.0, "dur_growth": 2.0, "mult": 1.6, "growth": 0.1},
	"energyShield": {"type": "buff", "buff": "shield", "duration": 60.0, "dur_growth": 5.0, "value": 0.4, "value_growth": 0.02},
	"lightningMastery": {"type": "passive", "stat": "lightning", "value": 0.3, "value_growth": 0.07},
	# ── 마법사: 화염 ──
	"warmth": {"type": "passive", "stat": "regen", "value": 0.3, "value_growth": 0.12},
	"inferno": {"type": "cone", "element": "fire", "range": 175, "arc": 30, "mult": 0.35, "growth": 0.08, "cost_scale": 2.0, "color": FIRE},
	"blaze": {"type": "buff", "buff": "blaze", "duration": 6.0, "dur_growth": 1.0, "mult": 0.25, "growth": 0.07},
	"fireball": {"type": "proj", "element": "fire", "mult": 1.5, "growth": 0.11, "speed": 600, "explode": 85, "color": FIRE},
	"firewall": {"type": "zone", "element": "fire", "wall": true, "radius": 115, "duration": 4.0, "tick": 0.25, "mult": 0.3, "growth": 0.07, "color": FIRE},
	"enchant": {"type": "buff", "buff": "enchant", "duration": 60.0, "value": 0.5, "value_growth": 0.08},
	"meteor": {"type": "zone", "element": "fire", "radius": 110, "delay": 1.0, "impact": 2.6, "growth": 0.12, "duration": 3.0, "tick": 0.3, "mult": 0.25, "color": FIRE},
	"hydra": {"type": "summon", "element": "fire", "duration": 10.0, "rate": 0.8, "mult": 0.6, "growth": 0.08, "range": 400},
	"fireMastery": {"type": "passive", "stat": "fire", "value": 0.3, "value_growth": 0.07},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func scaled(base: float, growth: float, rank: int) -> float:
	return base * (1.0 + growth * maxi(0, rank - 1))


## Resource cost at the given rank.
static func cost(skill: Dictionary, rank: int) -> float:
	var d := get_def(skill["id"])
	var c := float(skill["cost"])
	if d.has("free_at"):
		c *= clampf(1.0 - float(rank - 1) / float(int(d["free_at"]) - 1), 0.0, 1.0)
	if d.has("cost_drop"):
		c = maxf(float(d["min_cost"]), c - float(d["cost_drop"]) * (rank - 1))
	if d.has("cost_scale"):
		c *= float(d["cost_scale"])
	return c


## Short human-readable effect line for the tree's detail panel.
static func describe(id: String, rank: int) -> String:
	var d := get_def(id)
	if d.is_empty() or rank <= 0:
		return ""
	var r := rank
	match d["type"]:
		"melee", "spin", "nova", "proj", "chain", "zone", "orb", "cone", "summon", "shadow":
			var parts := []
			if d.has("mult"):
				parts.append("피해 %d%%" % roundi(scaled(d["mult"], d.get("growth", 0.0), r) * 100.0))
			if d.has("impact"):
				parts.append("충격 %d%%" % roundi(scaled(d["impact"], d.get("growth", 0.0), r) * 100.0))
			if d.has("hits"):
				parts.append("%d회 타격" % d["hits"])
			if d.has("ticks"):
				parts.append("%d회 회전" % d["ticks"])
			if d.has("count"):
				parts.append("%d발" % mini(int(d["count"] + d.get("count_growth", 0.0) * (r - 1)), int(d.get("max_count", 99))))
			if d.has("pct"):
				parts.append("현재 생명 %d%% 감소" % roundi(d["pct"] * 100))
			if d.has("radius"):
				parts.append("반경 %.1f걸음" % ((d["radius"] + d.get("radius_growth", 0.0) * (r - 1)) / 40.0))
			if d.has("stun"):
				parts.append("기절 %.1f초" % (d["stun"] + d.get("stun_growth", 0.0) * (r - 1)))
			if d.has("freeze"):
				parts.append("빙결 %.1f초" % (d["freeze"] + d.get("freeze_growth", 0.0) * (r - 1)))
			if d.has("slow"):
				parts.append("둔화 %.1f초" % d["slow"])
			if d.has("fear"):
				parts.append("공포 %.1f초" % (d["fear"] + d.get("fear_growth", 0.0) * (r - 1)))
			if d.has("taunt"):
				parts.append("도발 %.0f초 · 적 공격력 -30%%" % d["taunt"])
			if d.has("cry"):
				parts.append("%.0f초간 적 공격 -25%% · 받는 피해 +%d%%" % [d["cry"], roundi((d["cry_value"] + d["cry_growth"] * (r - 1)) * 100)])
			if d.has("jumps"):
				parts.append("연쇄 %d회" % int(d["jumps"] + d["jump_growth"] * (r - 1)))
			if d.has("targets"):
				parts.append("최대 %d명" % d["targets"])
			if d.has("duration"):
				parts.append("%.0f초 지속" % d["duration"])
			if d.has("explode"):
				parts.append("폭발 반경 %.1f걸음" % (d["explode"] / 40.0))
			return " · ".join(parts)
		"beam":
			return "피해 %d–%d%% · 관통" % [roundi(scaled(d["mult_min"], d["growth"], r) * 100), roundi(scaled(d["mult_max"], d["growth"], r) * 100)]
		"leap":
			var t := "거리 %.1f걸음" % ((d["distance"] + d.get("dist_growth", 0.0) * (r - 1)) / 40.0)
			if d.has("mult"):
				t += " · 피해 %d%%" % roundi(scaled(d["mult"], d["growth"], r) * 100)
			return t
		"blink":
			return "거리 %.1f걸음" % ((d["distance"] + d["dist_growth"] * (r - 1)) / 40.0)
		"corpse":
			match d["reward"]:
				"potion":
					return "시체에서 물약 발견 확률 %d%%" % roundi(minf(d["chance"] + d["chance_growth"] * (r - 1), 0.65) * 100)
				"item":
					return "시체에서 전리품(장비 대신 경험치) 발견 확률 %d%%" % roundi(minf(d["chance"] + d["chance_growth"] * (r - 1), 0.65) * 100)
				_:
					return "수호물 %.0f초 · 반경 %.1f걸음 공포" % [d["duration"] + d["dur_growth"] * (r - 1), d["radius"] / 40.0]
		"buff":
			var dur: float = d["duration"] + d.get("dur_growth", 0.0) * (r - 1)
			var v: float = d.get("value", 0.0) + d.get("value_growth", 0.0) * (r - 1)
			match d["buff"]:
				"sprint":
					return "%.1f초간 이동 속도 +%d%%" % [dur, roundi(v * 100)]
				"shout":
					return "%.0f초간 방어력 +%d%%" % [dur, roundi(v * 100)]
				"orders":
					return "%.0f초간 최대 생명·분노 +%d%%" % [dur, roundi(v * 100)]
				"command":
					return "%.0f초간 배운 기술 +1등급" % dur
				"armor":
					var extra := {"frozen": "근접 타격자 빙결", "shiver": "근접 타격자에게 냉기 피해", "chilling": "공격자에게 냉기 탄환 반격"}
					return "%.0f초간 방어력 +%d%% · %s" % [dur, roundi(v * 100), extra[d["armor"]]]
				"storm":
					return "%.0f초간 번개 낙하 · 피해 %d%%" % [dur, roundi(scaled(d["mult"], d["growth"], r) * 100)]
				"shield":
					return "%.0f초간 받는 피해 %d%%를 마나로 흡수" % [dur, roundi(v * 100)]
				"blaze":
					return "%.0f초간 불길 · 초당 피해 %d%%" % [dur, roundi(scaled(d["mult"], d["growth"], r) * 300)]
				"enchant":
					return "%.0f초간 일반 공격에 화염 피해 +%d%%" % [dur, roundi(v * 100)]
		"passive":
			var v2: float = d["value"] + d["value_growth"] * (r - 1)
			var labels := {"weapon": "근접 피해", "throw": "투척 피해", "stamina": "질주 지속", "armor": "방어력",
				"speed": "이동 속도", "resist": "받는 피해 감소·상태 이상 단축", "regen": "마나 회복",
				"fire": "화염 피해", "lightning": "번개 피해", "cold": "냉기 피해"}
			return "%s +%d%%" % [labels[d["stat"]], roundi(v2 * 100)]
	return ""
