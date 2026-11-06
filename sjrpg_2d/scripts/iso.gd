class_name Iso
extends RefCounted
## 2.5D quarter view (원본 IsometricGround): ground axes at ±30° on screen,
## so square floors become 60°/120° diamonds. Ground units follow the Flutter
## world; `S` converts them to this port's world pixels, calibrated so props,
## buildings and paving match the original's proportions to the hero.

const COS := 0.8660254037844386
const SIN := 0.5
const S := 0.97
const HERO_HEIGHT := 56.64  # SceneScale.heroHeight in original units
const PAVING := 24.0  # IsometricTileGrid.pavingStoneSide


## Ground (u, v) in original units → screen-plane world position.
static func project(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * COS, (p.x + p.y) * SIN) * S


static func unproject(p: Vector2) -> Vector2:
	var q := p / S
	return Vector2(q.x / COS + q.y / SIN, q.y / SIN - q.x / COS) / 2.0


## Transform that maps ground units directly onto the screen plane.
static func ground_transform() -> Transform2D:
	return Transform2D(Vector2(COS, SIN) * S, Vector2(-COS, SIN) * S, Vector2.ZERO)


## Pushes `p` (circle of radius r) out of a convex-or-concave polygon. Returns p
## unchanged when outside.
static func push_out(p: Vector2, poly: PackedVector2Array, r: float) -> Vector2:
	var inside := Geometry2D.is_point_in_polygon(p, poly)
	var best := INF
	var best_point := p
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var c := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(c)
		if d < best:
			best = d
			best_point = c
	if inside:
		var n := (best_point - p).normalized() if best > 0.001 else Vector2.DOWN
		return best_point + n * r
	if best < r:
		var n2 := (p - best_point).normalized() if best > 0.001 else Vector2.DOWN
		return best_point + n2 * r
	return p


static func poly_bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r
