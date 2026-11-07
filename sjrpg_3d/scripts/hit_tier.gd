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
