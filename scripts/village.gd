class_name Village
extends RefCounted
## 제1장 숲 마을 (원본 AuthoredSettlement + forest_isometric_frames.dart).
## A 2400×2400 ground diamond with walls, four gates, paved cross roads, the
## plaza fountain and portal, four service buildings, the raised chapel yard,
## the river and the bridge.

const DATA_PATH := "res://assets/data/village.json"
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
## Wall height/thickness come from the gatehouse art (data["wall"]) so the wall meets the gate wings exactly.
var wall_height := 200.0
var wall_thick := 64.0
## Collision footprint (world px) of each wall run segment.
var wall_footprints: Array[PackedVector2Array] = []
var extent := 2400.0
var spawn_uv := Vector2(0.5, 0.525)

## Collision for the game: polygons in world pixels.
var solids: Array[PackedVector2Array] = []
var circles: Array = []  # [Vector2 center, float radius]
## Walkable raised chapel yard incl. its stairs (world px): actors inside draw above the chapel art.
var terrace: PackedVector2Array
## Chapel stair path from the ground below up to the yard (world px).
var chapel_steps: PackedVector2Array
## Index range [first, end) of the chapel's own blockers inside `solids` (cliff faces, church body, yard ledges).
var chapel_solids := Vector2i.ZERO
var landmarks: Array[Landmark] = []
## 의뢰 장소 (world px): roots 석조 정원 제단, moon 고목의 쉼터, sun 동굴.
var quest_sites := {}
var cave_ground := Vector2(500, 3100)
var boss_point := Iso.project(Vector2(-2600, 300))
## Screen-plane rects (world px) the field scatter must keep clear.
var clear_rects: Array[Rect2] = []
## Town interior (safe zone, no monster spawns).
var safe_zone: PackedVector2Array
var spawn_point := Vector2.ZERO
var chest_points: Array[Vector2] = []
## 숲의 기억 상자: 서쪽 · 북쪽 · 동쪽 길 (ground units).
const MEMORY_SPOTS := [Vector2(-1900.0, 130.0), Vector2(180.0, -1900.0), Vector2(1450.0, 260.0)]
var gate_points: Array[Vector2] = []
## Wall-end centre of each gate's two wings in ground units: gate -> [Vector2, Vector2].
var gate_ends: Array = []
## Gate passages (world px): actors inside draw above the gatehouse art so they stay visible in the arch.
var gate_passages: Array[PackedVector2Array] = []
var bridge: Bridge
var river: River
## Minimap data (world pixels).
var map_water := PackedVector2Array()
var map_roads: Array[PackedVector2Array] = []
var sanctuary_points := {}
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
	wall_height = data["wall"]["height"]
	wall_thick = data["wall"]["thick"]
	spawn_uv = Vector2(data["spawn_uv"][0], data["spawn_uv"][1])


## Town uv → ground units (spawn at the origin).
func ground(uv: Vector2) -> Vector2:
	return (uv - spawn_uv) * extent


## World position → town uv (inverse of `point`).
func uv_of(world: Vector2) -> Vector2:
	return Iso.unproject(world) / extent + spawn_uv


func point(uv: Vector2) -> Vector2:
	return Iso.project(ground(uv))


func build(ground_layer: Node2D, world: Node2D) -> void:
	_build_gates(world)
	_build_paving(ground_layer)
	_build_river(ground_layer, world)
	_build_walls(world)
	_build_landmarks(world)
	_build_quest_sites(world)
	clear_rects.append(Rect2(boss_point - Vector2(600, 500), Vector2(1200, 1000)))
	var beacon_def: Dictionary = data["sprites"]["portal"]
	var beacon := IsoSprite.new().setup(beacon_def, 150.0)
	beacon.position = boss_point + Vector2(0, -280)
	world.add_child(beacon)
	circles.append([beacon.position, 45.0])
	_build_buildings(world)
	_build_plaza(world)
	_build_sanctuaries(world)
	_build_trees(world)
	_build_npcs(world)
	for c in data["chest_uv"]:
		chest_points.append(point(Vector2(c[0], c[1])))
	# The waterfall chest is above the measured dry path; memory IDs 5–7 stay stable.
	for g in MEMORY_SPOTS:
		chest_points.append(Iso.project(g))
		clear_rects.append(Rect2(Iso.project(g) - Vector2(80, 80), Vector2(160, 160)))
	chest_points.append(landmarks[3]._pt(Vector2(215, 472)))
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
	map_roads.append(_project_polygon(merged))
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
		map_roads.append(_project_polygon(poly.polygon))
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
const LANDMARK_SPOTS := [[2, Vector2(-2350, -900)], [1, Vector2(-1500, -2750)], [0, Vector2(1800, 1900)], [3, Vector2(-2400, 2400)]]


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

## A wall run's gate-side end snaps to the centre of the nearest gate wing end, so the wall continues the wing
## at the same height and thickness instead of poking into the gate.
func _snap_to_gate(end: Vector2, gate: int) -> Vector2:
	var best: Vector2 = gate_ends[gate][0]
	for e in gate_ends[gate]:
		if e.distance_to(end) < best.distance_to(end):
			best = e
	return best


func _build_walls(world: Node2D) -> void:
	var tex := load("res://assets/art/village/walls.webp") as Texture2D
	var segs: Dictionary = data["wall"]["segs"]
	var strip_px: float = data["wall"]["slice_px"]
	# [first-end gate, last-end gate] for the four runs.
	var run_gates := [[0, 2], [2, 1], [0, 3], [3, 1]]
	var half := wall_thick * 0.5
	for r in data["wall_runs"].size():
		var run: Array = data["wall_runs"][r]
		var pts: Array[Vector2] = []
		for p in run:
			pts.append(ground(Vector2(p[0], p[1])))
		pts[0] = _snap_to_gate(pts[0], run_gates[r][0])
		pts[pts.size() - 1] = _snap_to_gate(pts[pts.size() - 1], run_gates[r][1])
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var dir := (b - a).normalized()
			# Corner ends (not at a gate) run on by half a wall thickness so the two runs overlap into a closed corner.
			if i > 1:
				a -= dir * half
			if i < pts.size() - 1:
				b += dir * half
			var along_u := absf(b.x - a.x) > absf(b.y - a.y)
			# Art "a" runs along +u, art "b" along v; the visible face is the +v / +u side of the wall.
			var def: Dictionary = segs["a" if along_u else "b"]
			var front := Vector2(0.0, half) if along_u else Vector2(half, 0.0)
			var n := dir.orthogonal() * half
			solids.append(PackedVector2Array([Iso.project(a - n), Iso.project(b - n), Iso.project(b + n), Iso.project(a + n)]))
			wall_footprints.append(solids[solids.size() - 1])
			var seg_ground := float(def["source"][2]) * float(def["k"]) / (Iso.COS * Iso.S)  # ground length of one span of art
			var pieces := maxi(1, roundi(a.distance_to(b) / seg_ground))
			for p in pieces:
				var pa := Iso.project(a.lerp(b, float(p) / pieces) + front)
				var pb := Iso.project(a.lerp(b, float(p + 1) / pieces) + front)
				if pa.x > pb.x:
					var t := pa
					pa = pb
					pb = t
				WallPiece.add_span(world, tex, def, strip_px, pa, pb)


## Twin-tower gatehouse (새 120° 원화 assets/source/gate-new-*.png). Art is cut into vertical strips that each depth-sort
## by their own lowest ground point, so an actor walking along a wing's face is never hidden by the far end of the gate.
## Collision: the two towers and the wings outside them; the passage between stays open.
func _build_gates(world: Node2D) -> void:
	for gate in 4:
		var uv := Vector2(data["gate_centers"][gate][0], data["gate_centers"][gate][1])
		var key := "gate-%d" % (0 if gate < 2 else 2)
		var def: Dictionary = data["sprites"][key]
		var info: Dictionary = data["gates"][key]
		var s := IsoSprite.new().setup(def, float(def["world_height"]))
		s.position = point(uv)
		for strip in def["slices"]:
			world.add_child(s.make_strip(strip[0], strip[1], Vector2(strip[2], strip[3])))
		gate_points.append(s.position)
		var ends: Array[Vector2] = []
		for e in info["ends"]:
			ends.append(Iso.unproject(s.atlas_point(Vector2(e[0], e[1]))))
		gate_ends.append(ends)
		for poly in info["solids"]:
			solids.append(s.atlas_polygon(poly))
		gate_passages.append(s.atlas_polygon(info["passage"]))
		s.free()


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
	var first := solids.size()
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
	chapel_solids = Vector2i(first, solids.size())


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


func _project_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for point in polygon:
		projected.append(Iso.project(point))
	return projected


func _build_sanctuaries(world: Node2D) -> void:
	var tree: Landmark = landmarks[0]
	var outline: Array = Landmark.data()[tree.index]["outline"]
	var entrance: int = Landmark.data()[tree.index]["entrance"]
	var mid := (tree._pt(outline[entrance]) + tree._pt(outline[(entrance + 1) % outline.size()])) / 2.0
	var tree_point := mid + (mid - _top_center(tree)).normalized() * 160.0
	sanctuary_points = {"town": spawn_point, "tree": tree_point, "cave": quest_sites["sun"] + Vector2(-220, 220)}
	for id in ["tree", "cave"]:
		var point: Vector2 = sanctuary_points[id]
		clear_rects.append(Rect2(point - Vector2(220, 220), Vector2(440, 440)))
		var portal := IsoSprite.new().setup(data["sprites"]["portal"], 130.0)
		portal.position = point + Vector2(0, -110)
		world.add_child(portal)
		circles.append([portal.position, 35.0])
