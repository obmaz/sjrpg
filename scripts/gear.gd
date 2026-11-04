class_name Gear
extends RefCounted
## 장비 (원본 rpg_model.dart의 Gear/GearDef): 부위 3 · 등급 4 · 옵션(맹공/생명/집중) · 무기 레벨 · 잠금.
## Rare/unique gifts and weapon profiles are shared by combat and the bag.

const SLOT_NAMES := {"weapon": "무기", "armor": "방어구", "charm": "부적"}
const RARITY_NAMES := ["일반", "마법", "희귀", "고유"]
const RARITY_COLORS := [Color("e3dfce"), Color("82c9ff"), Color("ffd877"), Color("efa971")]
const WEAPON_ATTACK_PER_LEVEL := 2.0
const CAPACITY := 24
## 희귀 1개 · 고유 2개의 무기 능력 (원본 WeaponGift). 연격 능력은 3연계 이상 무기에서만.
const GIFTS := {
	"frost": ["서리의 낙인", "적중한 대상 둔화 0.67초"],
	"guardian": ["수호의 맹세", "받는 피해 8% 감소"],
	"renewal": ["생명의 수확", "처치 시 생명 400 회복"],
	"comboFury": ["연격의 격정", "분신 연격 3연계마다 분노 60 회복"],
	"comboGuard": ["연격의 수호", "분신 연격 3연계마다 0.75초간 받는 피해 25% 감소"],
}
const LEGACY_GIFTS := ["frost", "guardian", "renewal"]
const ALL_GIFTS := ["frost", "guardian", "renewal", "comboFury", "comboGuard"]
const COMBO_WEAPONS := ["shortsword", "longsword", "axe", "mace", "greatsword", "twinaxes", "spear", "runeblade", "dualblades", "rapier", "katana", "halberd", "warhammer", "flail", "glaive", "falchion"]

static var _catalog: Array = []
static var _by_id := {}

var serial := 0
var base: Dictionary
var rarity := 0
var power := 0
var vitality := 0
var focus := 0
var locked := false
var acquired_level := 1
var weapon_level := -1  # -1 for non-weapons
var gifts: Array[String] = []


static func catalog() -> Array:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.open("res://assets/data/gear.json", FileAccess.READ).get_as_text())
		for i in _catalog.size():
			_catalog[i]["index"] = i
			_by_id[_catalog[i]["id"]] = _catalog[i]
	return _catalog


static func def(id: String) -> Dictionary:
	catalog()
	return _by_id.get(id, {})


static func usable(base_def: Dictionary, cls: String) -> bool:
	return base_def["cls"] == null or base_def["cls"] == cls


## gearAffixForLevel: affixes grow by 1 every ten acquisition levels.
static func affix_for_level(value: int, lvl: int) -> int:
	return value if value <= 0 else value + (mini(lvl, 81) - 1) / 10


static func make(serial_no: int, def_id: String, r := 0, p := 0, v := 0, f := 0, lvl := 1, w_level := -1) -> Gear:
	var g := Gear.new()
	g.serial = serial_no
	g.base = def(def_id)
	g.rarity = r
	g.power = affix_for_level(p, lvl)
	g.vitality = affix_for_level(v, lvl)
	g.focus = affix_for_level(f, lvl)
	g.acquired_level = lvl
	g.weapon_level = (w_level if w_level > 0 else lvl) if g.base["slot"] == "weapon" else -1
	g.gifts = default_gifts(serial_no, g.base, r)
	return g


static func gift_count(r: int) -> int:
	return 2 if r == 3 else (1 if r == 2 else 0)


static func default_gifts(serial_no: int, b: Dictionary, r: int) -> Array[String]:
	var pool: Array = ALL_GIFTS if COMBO_WEAPONS.has(b["id"]) and b["slot"] == "weapon" else LEGACY_GIFTS
	var out: Array[String] = []
	for i in gift_count(r):
		out.append(pool[(serial_no + i) % pool.size()])
	return out


func has_gift(id: String) -> bool:
	return gifts.has(id)


func slot() -> String:
	return base["slot"]


func attack() -> float:
	return base["attack"] + power + (maxi(weapon_level, 1) - 1) * WEAPON_ATTACK_PER_LEVEL


func armor() -> float:
	return base["armor"] + (rarity * 2 if slot() == "armor" else 0)


func health() -> float:
	return base["health"] + vitality


func mana() -> float:
	return base["mana"] + focus


func sale_value() -> int:
	return maxi(5, roundi(base["value"] * (1.0 + rarity * 0.6) / 3.0))


func display_name() -> String:
	if rarity == 3:
		return "%s의 유산 · %s" % ["파수꾼" if base["id"] == "sentinel" else "균열", base["name"]]
	if rarity == 0:
		return base["name"]
	return "%s의 %s" % ["맹공" if power > 0 else ("생명" if vitality > 0 else "집중"), base["name"]]


func color() -> Color:
	return RARITY_COLORS[rarity]


## 표시 단위: 공격·방어·생명 ×100, 자원 ×10 (CombatNumbers).
func stats_text(resource_name: String) -> String:
	var parts: Array[String] = []
	if weapon_level > 0:
		parts.append("무기 Lv.%d" % weapon_level)
	if base["style"] == "throwing":
		parts.append("투척 · 단일 대상")
	if attack() > 0:
		parts.append("공격 +%s" % HudArt.stat(attack()))
	if armor() > 0:
		parts.append("방어 +%s" % HudArt.stat(armor()))
	if health() > 0:
		parts.append("생명 +%s" % HudArt.stat(health()))
	if mana() > 0:
		parts.append("%s +%s" % [resource_name, HudArt.res(mana())])
	if base["haste"] > 0:
		parts.append("공격속도 +%d%%" % roundi(base["haste"] * 100.0))
	for gid in gifts:
		parts.append("%s · %s" % [GIFTS[gid][0], GIFTS[gid][1]])
	return " · ".join(parts)


func to_save() -> Dictionary:
	return {"serial": serial, "base": base["id"], "rarity": rarity, "power": power, "vitality": vitality,
		"focus": focus, "locked": locked, "level": acquired_level, "weapon_level": weapon_level, "gifts": gifts}


static func from_save(d: Dictionary) -> Gear:
	var b := def(str(d.get("base", "")))
	if b.is_empty():
		return null
	var g := Gear.new()
	g.serial = int(d.get("serial", 0))
	g.base = b
	g.rarity = clampi(int(d.get("rarity", 0)), 0, 3)
	g.power = maxi(0, int(d.get("power", 0)))
	g.vitality = maxi(0, int(d.get("vitality", 0)))
	g.focus = maxi(0, int(d.get("focus", 0)))
	g.locked = bool(d.get("locked", false))
	g.acquired_level = clampi(int(d.get("level", 1)), 1, 10000)
	g.weapon_level = int(d.get("weapon_level", -1)) if b["slot"] == "weapon" else -1
	g.gifts = default_gifts(g.serial, b, g.rarity)
	if d.has("gifts"):
		var saved: Array[String] = []
		for gid in d["gifts"]:
			if GIFTS.has(str(gid)):
				saved.append(str(gid))
		if saved.size() == gift_count(g.rarity):
			g.gifts = saved
	return g if g.serial > 0 else null


## Progress.rollLoot: pool excludes the starter armor and unique drops.
static func roll_loot(cls: String, player_level: int, serial_no: int, rng: RandomNumberGenerator, chest := false) -> Gear:
	var pool: Array = []
	for b in catalog():
		if usable(b, cls) and b["id"] != "sentinel" and b["id"] != "linen":
			pool.append(b)
	var b: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var r := 1 if rng.randf() < (0.45 if chest else 0.2) else 0
	var p := 0
	var v := 0
	var f := 0
	if r > 0:
		p = (2 + rng.randi_range(0, 3) * r) if b["slot"] == "weapon" else rng.randi_range(0, 2)
		v = 4 + rng.randi_range(0, 5) * r
		f = (3 + rng.randi_range(0, 4) * r) if cls == "mage" else 0
	var wl := maxi(1, player_level + rng.randi_range(0, 4) - 2) if b["slot"] == "weapon" else -1
	return make(serial_no, b["id"], r, p, v, f, player_level, wl)


## World-pixel range, half angle (radians), actual attack interval (seconds).
func melee_profile(frenzy := 0) -> Dictionary:
	var angles := {"rapier": 0.32, "spear": 0.42, "halberd": 0.72, "glaive": 0.95, "greatsword": 1.05, "dualblades": 1.05,
		"mace": 1.05, "warhammer": 1.05, "runeblade": 1.10, "katana": 1.15, "longsword": 1.20, "flail": 1.35, "falchion": 1.40}
	var arc: float = angles.get(base["id"], 0.5 if base["style"] == "spear" else (1.5 if base["style"] == "axe" else 1.25))
	return {"range": float(base["range"]) * 0.91, "arc": arc,
		"tempo": maxf(0.12, float(base["tempo"]) / (1.0 + float(base["haste"]) + frenzy * 0.08))}
