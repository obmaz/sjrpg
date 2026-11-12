class_name HitTier
extends RefCounted
## JUICE #1: one place decides how hard a confirmed hit felt. Damage numbers, knockback and
## contact sounds read this tier instead of re-deriving their own thresholds (docs/juice.md).
## The tier is presentation only: it never changes damage, cooldowns or collision.

enum { LIGHT, MEDIUM, HEAVY, KILL }

## Damage as a fraction of the target's max health. HEAVY matches the original "heavy" rule
## (30% or a killing blow) so existing contact art, camera and hit-stop behaviour is unchanged.
const MEDIUM_RATIO := 0.10
const HEAVY_RATIO := 0.30


static func of(amount: float, max_health: float, killed: bool) -> int:
	if killed:
		return KILL
	var ratio := amount / maxf(1.0, max_health)
	if ratio >= HEAVY_RATIO:
		return HEAVY
	if ratio >= MEDIUM_RATIO:
		return MEDIUM
	return LIGHT


## Existing heavy-contact art, shake and hit-stop treat HEAVY and KILL alike.
static func is_heavy(tier: int) -> bool:
	return tier >= HEAVY


## JUICE #2: damage number size (pt) and colour per tier. LIGHT keeps the original 22pt pale yellow.
static func number_size(tier: int) -> int:
	return [22, 26, 32, 36][clampi(tier, LIGHT, KILL)]


static func number_color(tier: int) -> Color:
	return [Color(1, 0.95, 0.6), Color(1, 0.82, 0.4), Color(1, 0.6, 0.25), Color(1, 0.42, 0.22)][clampi(tier, LIGHT, KILL)]


## JUICE #3: knockback speed (px/s, decays at 900/s) per tier. The original fixed 160 is kept for
## bosses so their slam pacing does not change. This is the one tier effect that moves the target.
const BOSS_KNOCKBACK := 160.0

## JUICE #5: the attacker's pause on a killing blow, and the slightly larger death recoil / longer fade.
const KILL_STOP := 0.075
const KILL_STOP_LIMIT := 0.08
const KILL_RECOIL := 14.0
const KILL_FADE := 0.25
const DEFAULT_FADE := 0.18


static func knockback(tier: int, boss: bool) -> float:
	if boss:
		return BOSS_KNOCKBACK
	return [140.0, 180.0, 240.0, 260.0][clampi(tier, LIGHT, KILL)]


## JUICE #4: how far the struck body squashes (wider, shorter) at contact, as a fraction of its size.
static func squash(tier: int) -> float:
	return [0.05, 0.07, 0.10, 0.12][clampi(tier, LIGHT, KILL)]


## JUICE #14: camera zoom-in on heavy contact, as a fraction of the selected zoom (capped by game.gd ZOOM_PUNCH_LIMIT).
static func zoom_punch(tier: int) -> float:
	return 0.001 if tier == HEAVY else (0.0015 if tier == KILL else 0.0)
