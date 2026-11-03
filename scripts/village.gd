class_name Village
extends RefCounted
## 제1장 숲 마을 (원본 AuthoredSettlement + forest_isometric_frames.dart).
## A 2400×2400 ground diamond with walls, four gates, paved cross roads, the
## plaza fountain and portal, four service buildings and the raised chapel yard.

const DATA_PATH := "res://assets/data/village.json"
const WALL_HEIGHT := 140.0
const WALL_THICK := 38.0
const ROAD_HALF := 0.047  # paved road half width in uv
## Town trees measured from the original game's opening view.
const TREE_UV := [[0.355, 0.724, 11], [0.684, 0.703, 2], [0.246, 0.368, 11]]
## Deep, cool foliage grade used for town and field trees (ForestScenePalette).
const FOLIAGE := Color(0.52, 0.68, 0.66)
const NPCS := [
	["nw", "상인", 0], ["ne", "대장장이", 1], ["sw", "탈것 상인", 2], ["se", "촌장", 3],
]

var data: Dictionary
var extent := 2400.0
var spawn_uv := Vector2(0.5, 0.525)

## Collision for the game: polygons in world pixels.
var solids: Array[PackedVector2Array] = []
var circles: Array = []  # [Vector2 center, float radius]
## Walkable raised chapel yard (z above the chapel art).
var terrace: PackedVector2Array
## Town interior (safe zone, no monster spawns).
var safe_zone: PackedVector2Array
var spawn_point := Vector2.ZERO
var chest_points: Array[Vector2] = []
## Chapel stair path from the yard below to the terrace (world pixels).
var chapel_steps: PackedVector2Array
var gate_points: Array[Vector2] = []
## Measured pillar feet of each gate in ground units: gate -> [Vector2, Vector2].
var gate_pillars: Array = []


func _init() -> void:
	data = JSON.parse_string(FileAccess.open(DATA_PATH, FileAccess.READ).get_as_text())
	extent = data["extent"]
	spawn_uv = Vector2(data["spawn_uv"][0], data["spawn_uv"][1])


## Town uv → ground units (spawn at the origin).
func ground(uv: Vector2) -> Vector2:
	return (uv - spawn_uv) * extent


func point(uv: Vector2) -> Vector2:
	return Iso.project(ground(uv))


func build(ground_layer: Node2D, world: Node2D) -> void:
	_build_paving(ground_layer)
	_build_gates(world)
	_build_walls(world)
	_build_buildings(world)
	_build_plaza(world)
	_build_trees(world)
	_build_npcs(world)
	var cdef: Dictionary = data["sprites"]["chest"]
	for c in data["chest_uv"]:
		var at := point(Vector2(c[0], c[1]))
		chest_points.append(at)
		# Chest bodies are sized by their measured wooden body width (68).
		var chest := IsoSprite.new().setup(cdef, float(cdef["height"]) * 68.0 / float(cdef["body"][2]) * 1.3)
		chest.position = at
		world.add_child(chest)
		circles.append([at, 24.0])
	var corners := [Vector2(0.04, 0.10), Vector2(0.94, 0.10), Vector2(0.94, 0.90), Vector2(0.04, 0.90)]
	safe_zone = PackedVector2Array()
	for c in corners:
		safe_zone.append(point(c))


# ───────── ground ─────────

func _in_paving(uv: Vector2) -> int:
	# 0 none, 1 road, 2 plaza (light)
	var c := Vector2(0.5, 0.5)
	var d := (uv - c).abs()
	if maxf(d.x, d.y) < 0.1:
		return 2
	if maxf(d.x, d.y) < 0.125:
		return 1
	if d.y < ROAD_HALF and uv.x > 0.0 and uv.x < 1.0:
		return 1
	if d.x < ROAD_HALF and uv.y > 0.06 and uv.y < 0.94:
		return 1
	return 0


func _build_paving(layer: Node2D) -> void:
	var node := Node2D.new()
	node.z_index = 1
	node.draw.connect(func():
		var side := Iso.PAVING * 1.3
		var n := int(extent / side)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1201
		for gy in n:
			for gx in n:
				var uv := Vector2((gx + 0.5) * side / extent, (gy + 0.5) * side / extent)
				var kind := _in_paving(uv)
				if kind == 0:
					continue
				var shade := rng.randf_range(-0.02, 0.02)
				var col := Color(0.36, 0.37, 0.4) if rng.randf() < 0.7 else Color(0.42, 0.43, 0.46)
				if kind == 2:
					# The plaza brightens toward the fountain and dithers at its rim.
					var t := clampf((1.0 - maxf(absf(uv.x - 0.5), absf(uv.y - 0.5)) / 0.105) * 2.4, 0.0, 1.0)
					if rng.randf() < t:
						col = Color(0.75, 0.74, 0.71) if rng.randf() < 0.6 else Color(0.82, 0.81, 0.78)
				col = col.lightened(shade) if shade > 0 else col.darkened(-shade)
				var g := ground(uv) - Vector2(side, side) * 0.5
				node.draw_rect(Rect2(g, Vector2(side, side)), col)
				node.draw_rect(Rect2(g, Vector2(side, side)), Color(0.2, 0.21, 0.23, 0.6), false, 1.6))
	layer.add_child(node)
	# Dirt roads continue outward from the four gates.
	var dirt := load("res://assets/art/village/dirt.webp") as Texture2D
	var roads := [
		[Vector2(0.5, 0.10), Vector2(0.5, -0.9)], [Vector2(0.5, 0.90), Vector2(0.5, 1.9)],
		[Vector2(0.04, 0.5), Vector2(-0.9, 0.5)], [Vector2(0.94, 0.5), Vector2(1.9, 0.5)],
	]
	for r in roads:
		var a := ground(r[0])
		var b := ground(r[1])
		var dir := (b - a).normalized()
		var nrm := dir.orthogonal() * extent * 0.055
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm])
		poly.texture = dirt
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
		poly.texture_scale = Vector2(418.0 / 180.0, 418.0 / 180.0)
		poly.z_index = 0
		layer.add_child(poly)


# ───────── walls & gates ─────────

## A wall run's gate-side end snaps to the centre of the nearest measured
## pillar foot, so the pillar covers the end instead of the wall poking into
## the opening. `axis` is the coordinate that varies across the gate.
func _snap_to_pillar(end: Vector2, gate: int) -> Vector2:
	var axis := 0 if gate < 2 else 1
	var best: Vector2 = gate_pillars[gate][0]
	for f in gate_pillars[gate]:
		if absf(f[axis] - end[axis]) < absf(best[axis] - end[axis]):
			best = f
	var snapped := end
	snapped[axis] = best[axis]
	return snapped


func _build_walls(world: Node2D) -> void:
	var tex := load("res://assets/art/village/wall.webp") as Texture2D
	# [first-end gate, last-end gate] for the four runs.
	var run_gates := [[0, 2], [2, 1], [0, 3], [3, 1]]
	for r in data["wall_runs"].size():
		var run: Array = data["wall_runs"][r]
		var pts: Array[Vector2] = []
		for p in run:
			pts.append(ground(Vector2(p[0], p[1])))
		pts[0] = _snap_to_pillar(pts[0], run_gates[r][0])
		pts[pts.size() - 1] = _snap_to_pillar(pts[pts.size() - 1], run_gates[r][1])
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var length := a.distance_to(b)
			var pieces := maxi(1, ceili(length / 72.0))
			for p in pieces:
				var pa := a.lerp(b, float(p) / pieces)
				var pb := a.lerp(b, float(p + 1) / pieces)
				var w := WallPiece.new()
				w.setup(pa, pb, WALL_HEIGHT, WALL_THICK, tex)
				world.add_child(w)
				solids.append(w.footprint)


func _build_gates(world: Node2D) -> void:
	for gate in 4:
		var uv := Vector2(data["gate_centers"][gate][0], data["gate_centers"][gate][1])
		var def: Dictionary = data["sprites"]["gate-%d" % (0 if gate < 2 else 2)]
		var s := IsoSprite.new().setup(def, float(def["world_height"]) * 1.35)
		s.position = point(uv)
		# The gate always draws over the wall ends that tuck into its pillars.
		s.z_index = 1
		world.add_child(s)
		gate_points.append(s.position)
		var feet: Array[Vector2] = []
		for contact in data["gate_contacts"][0 if gate < 2 else 1]:
			var c := s.atlas_point(Vector2(contact[0], contact[1]))
			feet.append(Iso.unproject(c))
			var u := Iso.project(Vector2(22, 0))
			var v := Iso.project(Vector2(0, 22))
			solids.append(PackedVector2Array([c - u, c - v, c + u, c + v]))
		gate_pillars.append(feet)


# ───────── buildings ─────────

func _placed(key: String) -> IsoSprite:
	var def: Dictionary = data["sprites"][key]
	var place: Array = data["placements"][key]
	var h := float(def["world_height"])
	if h <= 0.0:
		h = float(place[1]) * Iso.HERO_HEIGHT
	var s := IsoSprite.new().setup(def, h)
	s.position = point(Vector2(place[0][0], place[0][1]))
	return s


var buildings := {}


func _build_buildings(world: Node2D) -> void:
	for key in ["nw", "ne", "sw", "se", "chapel"]:
		var s := _placed(key)
		world.add_child(s)
		buildings[key] = s
		solids.append(s.atlas_polygon(data["frames"][key]["ground"]))
	var chapel: IsoSprite = buildings["chapel"]
	var yard: Dictionary = data["chapel"]
	terrace = chapel.native_polygon(yard["outline"])
	chapel_steps = chapel.native_polygon(yard["steps"])
	for face in yard["faces"]:
		solids.append(chapel.native_polygon(face))
	# Every outline edge except the stair entrance is a ledge.
	var outline: PackedVector2Array = terrace
	for i in outline.size():
		if i == int(yard["entrance"]):
			continue
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var n := (b - a).orthogonal().normalized() * 5.0
		solids.append(PackedVector2Array([a + n, b + n, b - n, a - n]))


func _build_plaza(world: Node2D) -> void:
	var pool := _placed("pool")
	pool.k *= 1.44
	world.add_child(pool)
	var h := float(data["placements"]["pool"][1]) * Iso.HERO_HEIGHT * Iso.S * 1.44
	var src_w := float(data["sprites"]["pool"]["source"][2]) * pool.k
	var well := pool.position - Vector2(0, h * 0.18)
	var rx := src_w * 0.43
	var ry := h * 0.18
	var ellipse := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		ellipse.append(well + Vector2(cos(a) * rx, sin(a) * ry))
	solids.append(ellipse)
	# Warp portal beside the fountain, sized by its measured base width (180).
	var pdef: Dictionary = data["sprites"]["portal"]
	var body_w := float(pdef["body"][2])
	var portal := IsoSprite.new().setup(pdef, float(pdef["height"]) * 180.0 / body_w * 1.4)
	portal.position = point(Vector2(0.448, 0.502))
	world.add_child(portal)
	var b: Array = pdef["body"]
	solids.append(portal.atlas_polygon([[b[0], b[1] + b[3] * 0.35], [b[0] + b[2], b[1] + b[3] * 0.35], [b[0] + b[2], b[1] + b[3]], [b[0], b[1] + b[3]]]))


func _build_trees(world: Node2D) -> void:
	for t in TREE_UV:
		var def: Dictionary = data["sprites"]["tree-%d" % t[2]]
		var tree := IsoSprite.new().setup(def, float(def["world_height"]) * 1.05)
		tree.position = point(Vector2(t[0], t[1]))
		tree.modulate_color = FOLIAGE
		world.add_child(tree)
		circles.append([tree.position, 18.0])


func _build_npcs(world: Node2D) -> void:
	for n in NPCS:
		var b: IsoSprite = buildings[n[0]]
		var a: Array = data["approaches"][n[0]]
		var npc := Villager.new()
		npc.setup(n[2], n[1])
		npc.position = b.native_point(Vector2(a[0], a[1]))
		world.add_child(npc)
		circles.append([npc.position, 16.0])
	var mira := Villager.new()
	mira.setup(0, "보급원 미라")
	mira.position = point(Vector2(0.44, 0.57))
	world.add_child(mira)
	circles.append([mira.position, 16.0])


## Trees, plants and rocks of the surrounding stage-1 forest field.
func build_field(world: Node2D, field: Rect2, rng: RandomNumberGenerator) -> void:
	var town := Rect2(ground(Vector2(-0.05, 0.0)), Vector2(extent * 1.1, extent))
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < 260 and attempts < 9000:
		attempts += 1
		var g := Vector2(rng.randf_range(field.position.x, field.end.x), rng.randf_range(field.position.y, field.end.y))
		if town.grow(120).has_point(g):
			continue
		var uv := g / extent + spawn_uv
		# Keep the gate roads open.
		if absf(uv.x - 0.5) < 0.1 or absf(uv.y - 0.5) < 0.1:
			continue
		# Groves: denser in clustered noise cells.
		var cell := Vector2i(floori(g.x / 900.0), floori(g.y / 900.0))
		if (hash(cell) % 100) < 30 and rng.randf() < 0.6:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(g) < 150.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(g)
		var variant := rng.randi_range(0, 17)
		var def: Dictionary = data["sprites"]["tree-%d" % variant]
		var tree := IsoSprite.new().setup(def, float(def["world_height"]))
		tree.position = Iso.project(g)
		tree.flip = rng.randf() < 0.5
		tree.modulate_color = FOLIAGE
		world.add_child(tree)
		circles.append([tree.position, 16.0 + float(def["world_height"]) * 0.03])
	for i in 220:
		var g2 := Vector2(rng.randf_range(field.position.x, field.end.x), rng.randf_range(field.position.y, field.end.y))
		if town.has_point(g2):
			continue
		var pd: Dictionary = data["sprites"]["plant-%d" % rng.randi_range(0, 5)]
		var plant := IsoSprite.new().setup(pd, float(pd["world_height"]))
		plant.position = Iso.project(g2)
		world.add_child(plant)
	for i in 30:
		var g3 := Vector2(rng.randf_range(field.position.x, field.end.x), rng.randf_range(field.position.y, field.end.y))
		if town.grow(200).has_point(g3):
			continue
		var uv3 := g3 / extent + spawn_uv
		if absf(uv3.x - 0.5) < 0.09 or absf(uv3.y - 0.5) < 0.09:
			continue
		var rd: Dictionary = data["sprites"]["rock"]
		var rock := IsoSprite.new().setup(rd, float(rd["world_height"]) * rng.randf_range(0.7, 1.3))
		rock.position = Iso.project(g3)
		world.add_child(rock)
		circles.append([rock.position, 34.0])
