class_name Village
extends RefCounted
## 제1장 숲 마을 (원본 AuthoredSettlement + forest_isometric_frames.dart).
## A 2400×2400 ground diamond with walls, four gates, paved cross roads, the
## plaza fountain and portal, four service buildings, the raised chapel yard,
## the river and the bridge.

const DATA_PATH := "res://assets/data/village.json"
const WALL_HEIGHT := 140.0
const WALL_THICK := 38.0
const ROAD_HALF := 0.047  # paved road half width in uv
## Town trees measured from the original game's opening view.
const TREE_UV := [[0.355, 0.724, 11], [0.684, 0.703, 2], [0.246, 0.368, 11]]
## Deep, cool foliage grade used for town and field trees (ForestScenePalette).
const FOLIAGE := Color(0.52, 0.68, 0.66)
## Cobble texture density: one 418px tile covers 190 ground units.
const COBBLE_PX := 418.0 / 190.0
const NPCS := [
	["nw", "상인", 0], ["ne", "대장장이", 1], ["sw", "탈것 상인", 2], ["se", "촌장", 3],
]

var data: Dictionary
var extent := 2400.0
var spawn_uv := Vector2(0.5, 0.525)

## Collision for the game: polygons in world pixels.
var solids: Array[PackedVector2Array] = []
var circles: Array = []  # [Vector2 center, float radius]
## Walkable raised chapel yard incl. its stairs (world px): actors inside draw above the chapel art.
var terrace: PackedVector2Array
## Chapel stair path from the ground below up to the yard (world px).
var chapel_steps: PackedVector2Array
var landmarks: Array[Landmark] = []
## 의뢰 장소 (world px): roots 석조 정원 제단, moon 고목의 쉼터, sun 동굴.
var quest_sites := {}
var cave_ground := Vector2(500, 3100)
## Screen-plane rects (world px) the field scatter must keep clear.
var clear_rects: Array[Rect2] = []
## Town interior (safe zone, no monster spawns).
var safe_zone: PackedVector2Array
var spawn_point := Vector2.ZERO
var chest_points: Array[Vector2] = []
## 숲의 기억 상자: 서쪽 · 북쪽 · 동쪽 길 (ground units).
const MEMORY_SPOTS := [Vector2(-1900.0, 130.0), Vector2(180.0, -1900.0), Vector2(1450.0, 260.0)]
var gate_points: Array[Vector2] = []
## Measured pillar feet of each gate in ground units: gate -> [Vector2, Vector2].
var gate_pillars: Array = []
var bridge: Bridge
var river: River
## Minimap data (world pixels).
var map_water := PackedVector2Array()
var portal_point := Vector2.ZERO
var merchant_point := Vector2.ZERO
## 이름 → 위치: 상인 · 대장장이 · 탈것 상인 · 촌장 · 보급원 미라.
var npc_points := {}
var npc_nodes := {}
## Forecourt (road end before the bridge) in ground units, and the water band.
var forecourt_g := Vector2.ZERO
var river_band := Rect2()  # ground units: x = u, y = v


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
	_build_gates(world)
	_build_paving(ground_layer)
	_build_river(ground_layer, world)
	_build_walls(world)
	_build_landmarks(world)
	_build_quest_sites(world)
	_build_buildings(world)
	_build_plaza(world)
	_build_trees(world)
	_build_npcs(world)
	for c in data["chest_uv"]:
		chest_points.append(point(Vector2(c[0], c[1])))
	for g in MEMORY_SPOTS:
		chest_points.append(Iso.project(g))
		clear_rects.append(Rect2(Iso.project(g) - Vector2(80, 80), Vector2(160, 160)))
	var corners := [Vector2(0.04, 0.10), Vector2(0.94, 0.10), Vector2(0.94, 0.90), Vector2(0.04, 0.90)]
	safe_zone = PackedVector2Array()
	for c in corners:
		safe_zone.append(point(c))


# ───────── ground ─────────

func _box(a_uv: Vector2, b_uv: Vector2) -> PackedVector2Array:
	var a := ground(a_uv)
	var b := ground(b_uv)
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


## Real cobblestone (원본 forest-isometric-paving) laid on the ground plane, with
## a dark curb and a patch of sunlight on the plaza like the reference.
func _build_paving(layer: Node2D) -> void:
	var group := Node2D.new()
	group.z_index = 1
	layer.add_child(group)
	var merged := _box(Vector2(0.375, 0.375), Vector2(0.625, 0.625))
	for other in [_box(Vector2(0.02, 0.453), Vector2(0.96, 0.547)), _box(Vector2(0.453, 0.06), Vector2(0.547, 0.94))]:
		merged = Geometry2D.merge_polygons(merged, other)[0]
	var curb: Array = Geometry2D.offset_polygon(merged, 9.0, Geometry2D.JOIN_MITER)
	var curb_poly := Polygon2D.new()
	curb_poly.polygon = curb[0]
	curb_poly.color = Color(0.09, 0.07, 0.05, 0.7)
	group.add_child(curb_poly)
	var stone := Polygon2D.new()
	stone.polygon = merged
	stone.texture = load("res://assets/art/village/paving.webp")
	stone.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var uv := PackedVector2Array()
	for p in merged:
		uv.append(p * COBBLE_PX)
	stone.uv = uv
	stone.modulate = Color(0.86, 0.84, 0.8)
	group.add_child(stone)
	# Sunlit plaza: a soft additive glow centred on the fountain.
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.95, 0.8, 0.5), Color(1.0, 0.95, 0.8, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var glow := Sprite2D.new()
	glow.texture = tex
	glow.position = ground(Vector2(0.5, 0.5))
	glow.scale = Vector2.ONE * 760.0 / 256.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	group.add_child(glow)
	# Dirt roads continue outward from the gates; the east road ends at the
	# bridge forecourt and a narrower road crosses the bridge northwards.
	var dirt := load("res://assets/art/village/dirt.webp") as Texture2D
	var east_end := Vector2(0.94 + 390.0 / extent, 0.5)
	var roads := [
		[Vector2(0.5, 0.10), Vector2(0.5, -0.9), extent * 0.055],
		[Vector2(0.5, 0.90), Vector2(0.5, 1.9), extent * 0.055],
		[Vector2(0.04, 0.5), Vector2(-0.9, 0.5), extent * 0.055],
		[Vector2(0.94, 0.5), east_end, extent * 0.055],
		[east_end, east_end + Vector2(0, -2400.0 / extent), 95.0],
	]
	for r in roads:
		var a := ground(r[0])
		var b := ground(r[1])
		var dir := (b - a).normalized()
		var nrm := dir.orthogonal() * float(r[2])
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm])
		poly.texture = dirt
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
		poly.texture_scale = Vector2(418.0 / 180.0, 418.0 / 180.0)
		poly.z_index = 0
		layer.add_child(poly)


# ───────── river & bridge ─────────

func _build_river(layer: Node2D, world: Node2D) -> void:
	forecourt_g = Iso.unproject(gate_points[3]) + Vector2(390, 0)
	bridge = Bridge.new().setup(Iso.project(forecourt_g))
	world.add_child(bridge)
	# The water spans the bridge axis, tucked 70 units under each bank end.
	var near_v := Iso.unproject(bridge.axis_point(0.0)).y
	var far_v := Iso.unproject(bridge.axis_point(1.0)).y
	var v0 := far_v + 70.0
	var v1 := near_v - 70.0
	var u0 := forecourt_g.x - 190.0
	var u1 := 3500.0
	river_band = Rect2(u0 - 110.0, v0, u1 - u0 + 110.0, v1 - v0)
	river = River.new().setup(u0, u1, v0, v1, 110.0)
	layer.add_child(river)
	# Water blocks movement everywhere except the bridge deck.
	var water := PackedVector2Array()
	for g in river.polygon:
		water.append(Iso.project(g))
	map_water = water
	for piece in Geometry2D.clip_polygons(water, bridge.deck_polygon()):
		solids.append(piece)
	for poly in bridge.solids():
		solids.append(poly)


## True when a ground point lies on water, bank or the bridge road.
## 숲 랜드마크 (원본 stage-1 필드): 높이가 있는 윗면과 계단. Positions are ground units.
const LANDMARK_SPOTS := [[2, Vector2(-2350, -900)], [1, Vector2(-1500, -2750)], [0, Vector2(1800, 1900)]]


func _build_landmarks(world: Node2D) -> void:
	for spot in LANDMARK_SPOTS:
		var lm := Landmark.new().setup(spot[0], Iso.project(spot[1]))
		world.add_child(lm)
		landmarks.append(lm)
		for b in lm.blockers:
			solids.append(b)
		for l in lm.ledges:
			solids.append(l)
		clear_rects.append(lm.footprint_rect())


func _build_quest_sites(world: Node2D) -> void:
	# 석조 정원(제단)과 고목의 쉼터는 높은 윗면 위, 동굴은 남쪽 길 끝에 있음.
	var garden: Landmark = landmarks[1]
	var tree: Landmark = landmarks[0]
	quest_sites["roots"] = _top_center(garden)
	quest_sites["moon"] = _top_center(tree)
	var cdef: Dictionary = data["sprites"]["cave"]
	var cave := IsoSprite.new().setup(cdef, float(cdef["world_height"]) * 1.6)
	cave.position = Iso.project(cave_ground)
	world.add_child(cave)
	circles.append([cave.position + Vector2(0, -60), 120.0])
	clear_rects.append(Rect2(cave.position - Vector2(300, 280), Vector2(600, 420)))
	quest_sites["sun"] = cave.position + Vector2(150, 90)
	_npc("수녀 엘린", 1, quest_sites["roots"] + Vector2(-30, 10), world, true)
	_npc("약초사 노아", 1, quest_sites["moon"] + Vector2(-30, 10), world, true)
	_npc("조사관 로웬", 0, quest_sites["sun"], world, false)


func _top_center(lm: Landmark) -> Vector2:
	var c := Vector2.ZERO
	for p in lm.top:
		c += p
	return c / lm.top.size()


func _npc(name: String, kind: int, at: Vector2, world: Node2D, elevated: bool) -> void:
	var npc := Villager.new()
	npc.setup(kind, name)
	npc.position = at
	if elevated:
		npc.z_index = 1
	npc.marker = func(): return Quests.marker_for(name)
	if name == "조사관 로웬":
		npc.hp_ratio = func():
			var q := Quests.state("sun")
			return (float(q["defender_hp"]) / Quests.DEFENDER_HP) if (q["started"] and q["phase"] == "accepted") else -1.0
	world.add_child(npc)
	npc_points[name] = at
	npc_nodes[name] = npc
	circles.append([at, 16.0])


func near_water(g: Vector2, margin: float) -> bool:
	var sp := Iso.project(g)
	for r in clear_rects:
		if r.grow(margin).has_point(sp):
			return true
	if river_band.grow(margin + 90.0).has_point(g):
		return true
	return absf(g.x - forecourt_g.x) < 190.0 + margin and g.y < forecourt_g.y + 100.0 and g.y > forecourt_g.y - 2400.0


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
	for key in ["nw", "ne", "sw", "se"]:
		var s := _placed(key)
		world.add_child(s)
		buildings[key] = s
		solids.append(s.atlas_polygon(data["frames"][key]["ground"]))
	_build_chapel(world)


## 예배당 (새 120° 원화 assets/source/chapel-new.png): 자갈 마당(기단) 위의 고딕 예배당.
## 마당 윗면(`outline`)은 계단(`entrance` 0)으로만 오를 수 있고, 정면 절벽(`faces`)과 건물 자리(`building`)는 막힌다.
## `frames.chapel.ground`는 기단이 땅에 닿는 접점(축 검사용)이라 충돌에는 쓰지 않는다: 마당 위를 걸어야 하므로.
## 좌표는 원화 원본 픽셀이라 `native_polygon`으로 월드에 옮긴다.
func _build_chapel(world: Node2D) -> void:
	var s := _placed("chapel")
	world.add_child(s)
	buildings["chapel"] = s
	var yard: Dictionary = data["chapel"]
	terrace = s.native_polygon(yard["outline"])
	chapel_steps = s.native_polygon(yard["steps"])
	for face in yard["faces"]:
		solids.append(s.native_polygon(face))
	solids.append(s.native_polygon(yard["building"]))
	# Every outline edge except the stair entrance is a ledge.
	for i in terrace.size():
		if i == int(yard["entrance"]):
			continue
		var a := terrace[i]
		var b := terrace[(i + 1) % terrace.size()]
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
	portal_point = portal.position
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
		var nm: String = n[1]
		npc.marker = func(): return Quests.marker_for(nm)
		npc_points[n[1]] = npc.position
		if n[0] == "nw":
			merchant_point = npc.position
		world.add_child(npc)
		circles.append([npc.position, 16.0])
	var mira := Villager.new()
	mira.setup(0, "보급원 미라")
	mira.position = point(Vector2(0.44, 0.57))
	mira.marker = func(): return Quests.marker_for("보급원 미라")
	npc_points["보급원 미라"] = mira.position
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
		if town.grow(120).has_point(g) or near_water(g, 60.0):
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
		if town.has_point(g2) or near_water(g2, 0.0):
			continue
		var pd: Dictionary = data["sprites"]["plant-%d" % rng.randi_range(0, 5)]
		var plant := IsoSprite.new().setup(pd, float(pd["world_height"]))
		plant.position = Iso.project(g2)
		world.add_child(plant)
	for i in 30:
		var g3 := Vector2(rng.randf_range(field.position.x, field.end.x), rng.randf_range(field.position.y, field.end.y))
		if town.grow(200).has_point(g3) or near_water(g3, 40.0):
			continue
		var uv3 := g3 / extent + spawn_uv
		if absf(uv3.x - 0.5) < 0.09 or absf(uv3.y - 0.5) < 0.09:
			continue
		var rd: Dictionary = data["sprites"]["rock"]
		var rock := IsoSprite.new().setup(rd, float(rd["world_height"]) * rng.randf_range(0.7, 1.3))
		rock.position = Iso.project(g3)
		world.add_child(rock)
		circles.append([rock.position, 34.0])
