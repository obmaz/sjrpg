class_name Village
extends RefCounted
## 제1장 숲 마을 (원본 AuthoredSettlement + forest_isometric_frames.dart).
## A data-sized ground diamond with walls, four gates, paved cross roads, the
## plaza fountain and portal, four service buildings, the raised chapel yard,
## the river and the bridge.

const DATA_PATH := "res://assets/data/village.json"
const ROAD_HALF := 0.047  # paved road half width in uv
## Preserve the reviewed generated material colors; scene light is a separate layer.
const FOLIAGE := Color.WHITE
## Six to seven irregular stones per tile, around a quarter to a third of hero height.
const COBBLE_PX := 512.0 / 180.0  # Match the reference's roughly 50–60px stones at the normal portrait camera.
const WALL_JOIN_OVERLAP := 4.0  # Ground units: cover filtered cut-edge pixels without changing collision.
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
var cave_ground := ForestRegion.CAVE_GROUND
var boss_point := Iso.project(Vector2(-2600, 300))
## Screen-plane rects (world px) the field scatter must keep clear.
var clear_rects: Array[Rect2] = []
## Town interior (safe zone, no monster spawns).
var safe_zone: PackedVector2Array
var spawn_point := Vector2.ZERO
var chest_points: Array[Vector2] = []
## 숲의 기억 상자: 서쪽 · 북쪽 · 동쪽 길 (ground units).
## East chest stays outside the gate-snapped wall: its old u1450 was inside the
## 64-unit wall footprint. +30u is the smallest whole-unit shift preserving SKIN
## around the enlarged native chest cylinder; reward/save index7 is unchanged.
const MEMORY_SPOTS := [Vector2(-1900.0, 130.0), Vector2(180.0, -1900.0), Vector2(1480.0, 260.0)]
var gate_points: Array[Vector2] = []
## Wall-end centre of each gate's two wings in ground units: gate -> [Vector2, Vector2].
var gate_ends: Array = []
## Ground-level gate passages (world px); actors use local occlusion without being raised over other buildings.
var gate_passages: Array[PackedVector2Array] = []
var bridge: Bridge
var river: River
## Minimap data (world pixels).
var map_water := PackedVector2Array()
var map_roads: Array[PackedVector2Array] = []
var sanctuary_points := {}
var portal_point := Vector2.ZERO
var portal_points := {}
var portal_sprites: Dictionary = {}
var portal_footprints: Dictionary = {}
var fountain: IsoSprite
var town_trees: Array[IsoSprite] = []
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
	var beacon := create_portal(boss_point + Vector2(0, -280))
	beacon.name = "GuardianPortal"
	world.add_child(beacon)
	solids.append(portal_base(beacon))
	_build_buildings(world)
	_build_chapel_path(ground_layer)
	_build_plaza(world)
	_build_sanctuaries(world)
	_build_trees(world, ground_layer)
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


## Reference limestone laid on the actual projected walkable ground.
## The material has no baked shadow patches; actual tree casters shade it separately.
func _build_paving(layer: Node2D) -> void:
	var group := Node2D.new()
	group.z_index = 1
	layer.add_child(group)
	var merged := _box(Vector2(0.375, 0.375), Vector2(0.625, 0.625))
	for other in [_box(Vector2(0.02, 0.453), Vector2(0.96, 0.547)), _box(Vector2(0.453, 0.06), Vector2(0.547, 0.94))]:
		merged = Geometry2D.merge_polygons(merged, other)[0]
	var stone := Polygon2D.new()
	stone.polygon = merged
	map_roads.append(_project_polygon(merged))
	stone.texture = ForestArt.texture("paving")
	stone.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var uv := PackedVector2Array()
	for p in merged:
		uv.append(p * COBBLE_PX)
	stone.uv = uv
	stone.modulate = Color.WHITE
	group.add_child(stone)
	# Dirt roads continue outward from the gates; the east road ends at the
	# bridge forecourt and a narrower road crosses the bridge northwards.
	var dirt := ForestArt.texture("earth")
	var east_end := Vector2(ForestRegion.BRIDGE_U/extent+spawn_uv.x,0.5)
	var roads := [
		[Vector2(0.5, 0.10), Vector2(0.5,(-3400.0/extent)+spawn_uv.y), extent * 0.055],
		[Vector2(0.5, 0.90), Vector2(0.5,(10200.0/extent)+spawn_uv.y), extent * 0.055],
		[Vector2(0.04, 0.5), Vector2((-3400.0/extent)+spawn_uv.x,0.5), extent * 0.055],
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
		poly.texture_scale = Vector2.ONE * 512.0 / 360.0
		poly.z_index = 0
		layer.add_child(poly)


# ───────── river & bridge ─────────

func _build_river(layer: Node2D, world: Node2D) -> void:
	forecourt_g = Vector2(ForestRegion.BRIDGE_U,Iso.unproject(gate_points[3]).y)
	bridge = Bridge.new().setup(Iso.project(forecourt_g))
	world.add_child(bridge)
	# The water spans the bridge axis, tucked 70 units under each bank end.
	var near_v := Iso.unproject(bridge.axis_point(0.0)).y
	var far_v := Iso.unproject(bridge.axis_point(1.0)).y
	var v0 := far_v + 70.0
	var v1 := near_v - 70.0
	var u0 := Iso.unproject(gate_points[3]).x+200.0
	var u1 := ForestRegion.RIVER_END_U
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
	# 정원·고목은 기존 높은 지형 위, 동굴은 확장한 남동쪽 암반 골짜기에 둔다.
	var garden: Landmark = landmarks[1]
	var tree: Landmark = landmarks[0]
	quest_sites["roots"] = _top_center(garden)
	quest_sites["moon"] = _top_center(tree)
	var cdef: Dictionary = data["sprites"]["cave"]
	var cave := IsoSprite.new().setup(cdef, float(cdef["world_height"]) * 1.6)
	cave.position = Iso.project(cave_ground)
	world.add_child(cave)
	circles.append([cave.position + NativeCavePlan.CENTER_OFFSET, NativeCavePlan.SOURCE_RADIUS])
	clear_rects.append(Rect2(cave.position-Vector2(2300,1850),Vector2(4600,3700)))
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
	if sanctuary_points.has("cave") and NativeCaveTrail.distance_to(self,g)<3.1+margin/65.0:
		return true
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
			var draw_a := a - dir * WALL_JOIN_OVERLAP if i == 1 else a
			var draw_b := b + dir * WALL_JOIN_OVERLAP if i == pts.size() - 1 else b
			var x_clip := Vector2(-INF, INF)
			for corner in [i - 1, i]:
				if corner <= 0 or corner >= pts.size() - 1:
					continue
				var center_x := Iso.project(pts[corner]).x
				var before_x := Iso.project(pts[corner - 1]).x - center_x
				var after_x := Iso.project(pts[corner + 1]).x - center_x
				if before_x * after_x < 0.0:
					# A quarter pixel of shared coverage prevents a filtered hairline at the miter.
					if Iso.project((a + b) * 0.5).x < center_x:
						x_clip.y = center_x + 0.25
					else:
						x_clip.x = center_x - 0.25
			var seg_ground := float(def["source"][2]) * float(def["k"]) / (Iso.COS * Iso.S)  # ground length of one span of art
			var length := draw_a.distance_to(draw_b)
			var offset := 0.0
			while offset < length - 0.01:
				var end := minf(length, offset + seg_ground)
				var pa := Iso.project(draw_a.lerp(draw_b, offset / length) + front)
				var pb := Iso.project(draw_a.lerp(draw_b, end / length) + front)
				if pa.x > pb.x:
					var t := pa
					pa = pb
					pb = t
				WallPiece.add_span(world, tex, def, strip_px, pa, pb, x_clip)
				offset = end


## Twin-tower gatehouse (cohesive generated family, calibrated 120° art). Art is cut into vertical strips that each depth-sort
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


## 예배당: 새 지면 접근형 본체와 문 앞 얕은 계단을 원화에서 실측한다.
## 마당 윗면(`outline`)은 계단(`entrance` 0)으로만 오를 수 있고, 정면 절벽(`faces`)과 건물 자리(`building`)는 막힌다.
## `frames.chapel.ground`는 기단이 땅에 닿는 접점(축 검사용)이라 충돌에는 쓰지 않는다: 마당 위를 걸어야 하므로.
## 좌표는 원화 원본 픽셀이라 `native_polygon`으로 월드에 옮긴다.
func _build_chapel(world: Node2D) -> void:
	var s := _placed("chapel")
	var old_center := Iso.poly_bounds(s.atlas_polygon(data["frames"]["chapel"]["ground"])).get_center()
	s.k *= NativeChapelPlan.SIZE_FACTOR
	s.position += old_center - Iso.poly_bounds(s.atlas_polygon(data["frames"]["chapel"]["ground"])).get_center()
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
	fountain = _placed("pool")
	# 중심을 유지하며 우물의 모든 치수를 두 배로 넓힌다.
	fountain.k *= 2.4
	var old_center := Iso.poly_bounds(fountain.atlas_polygon(data["frames"]["pool"]["ground"])).get_center()
	fountain.k *= 2.0
	fountain.position += old_center - Iso.poly_bounds(fountain.atlas_polygon(data["frames"]["pool"]["ground"])).get_center()
	PlazaWater.attach(fountain, false)
	world.add_child(fountain)
	# Authored frame points follow the same measured source projection as its stone base.
	solids.append(fountain.atlas_polygon(data["frames"]["pool"]["ground"]))
	# Leave room for the larger fountain and for Mira's independent interaction approach.
	var portal := _add_warp_portal("town", point(Vector2(0.395, 0.493)), world)
	portal_point = portal.position


## Join the measured doorway to the existing street on the real ground plane.
## The generated stone material shares UVs with the street; the slight outline
## irregularity is road geometry, not a painted background or a collision wall.
func _build_chapel_path(layer: Node2D) -> void:
	var start := Iso.unproject(chapel_steps[0])
	var closest := start
	var distance := INF
	var street := map_roads[0]
	var outward := (chapel_steps[0] - chapel_steps[chapel_steps.size() - 1]).normalized()
	for index in street.size():
		var a := Iso.unproject(street[index])
		var b := Iso.unproject(street[(index + 1) % street.size()])
		var at := Geometry2D.get_closest_point_to_segment(start, a, b)
		# Approach from in front of the steps, rather than the nearer street behind the doorway.
		if (Iso.project(at) - Iso.project(start)).normalized().dot(outward) < 0.35:
			continue
		if start.distance_squared_to(at) < distance:
			distance = start.distance_squared_to(at)
			closest = at
	var direction := (closest - start).normalized()
	if direction.is_zero_approx():
		return
	start -= direction * 55.0
	var finish := closest + direction * 40.0
	var normal := direction.orthogonal()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index in 5:
		var t := float(index) / 4.0
		var width := lerpf(120.0, 140.0, t)
		var offset: float = [0.0, 7.0, -5.0, 8.0, 0.0][index]
		var center := start.lerp(finish, t)
		left.append(center + normal * (width + offset))
		right.append(center - normal * (width - offset))
	right.reverse()
	left.append_array(right)
	var path := Polygon2D.new()
	path.polygon = left
	path.texture = ForestArt.texture("paving")
	path.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var uv := PackedVector2Array()
	for point in left:
		uv.append(point * COBBLE_PX)
	path.uv = uv
	path.z_index = 1
	layer.add_child(path)
	map_roads.append(_project_polygon(left))


func _build_trees(world: Node2D, ground_layer: Node2D) -> void:
	# Build a wooded middle/background around the real chapel and service houses.
	# Trunk positions stay off the actual structures, roads and stair approach.
	for key in ["chapel", "nw", "ne", "sw", "se"]:
		var building: IsoSprite = buildings[key]
		var bounds := Iso.poly_bounds(building.atlas_polygon(data["frames"][key]["ground"]))
		var points: Array[Vector2] = [
			Vector2(bounds.position.x - 60.0, bounds.position.y - 65.0),
			Vector2(bounds.end.x + 65.0, bounds.position.y + 25.0),
		]
		if key == "chapel":
			points[0] = Vector2(bounds.position.x + 10.0, bounds.position.y - 65.0)
			points.append(Vector2(bounds.get_center().x + 30.0, bounds.position.y - 145.0))
			points.append(Vector2(bounds.end.x - 20.0, bounds.end.y + 150.0))
			points.append(bounds.position + Vector2(-340.0, -170.0))
		for index in points.size():
			var at := points[index]
			if not _grove_clear(at):
				continue
			var definition: Dictionary = data["sprites"]["tree-2" if index % 2 == 0 else "tree-1"]
			var extra := IsoSprite.new().setup(definition, float(definition["world_height"]) * (1.0 if key == "chapel" else 0.82))
			extra.position = at
			if _canopy_blocks_service(extra):
				extra.free()
				continue
			extra.modulate_color = FOLIAGE
			if key == "chapel" and at.y < building.position.y - 50.0:
				# A cool, shaded background layer; foreground crowns keep their source light.
				extra.modulate_color = Color(0.76, 0.80, 0.79)
			world.add_child(extra)
			town_trees.append(extra)
			circles.append([at, 18.0])
	# Prioritize the new chapel grove. These flat-ground casters use their own alpha,
	# never a repeating dark patch painted into the grass material.
	var casters := town_trees.duplicate()
	var chapel: IsoSprite = buildings["chapel"]
	casters.sort_custom(func(a: IsoSprite, b: IsoSprite): return a.position.distance_squared_to(chapel.position) < b.position.distance_squared_to(chapel.position))
	for caster in casters:
		CanopyShade.attach(caster, ground_layer)


## A trunk can clear the door while its much wider crown still hides the NPC.
## Compare the actual painted bounds and draw order, including adjacent houses.
func _canopy_blocks_service(tree: IsoSprite) -> bool:
	var src: Array = tree.def["source"]
	var bounds := Iso.poly_bounds(tree.atlas_polygon([[src[0], src[1]], [src[0] + src[2], src[1]], [src[0] + src[2], src[1] + src[3]], [src[0], src[1] + src[3]]]))
	for service in NPCS:
		var key: String = service[0]
		var approach: Array = data["approaches"][key]
		var npc: Vector2 = buildings[key].native_point(Vector2(approach[0], approach[1]))
		var readable := NpcArt.readability_rect(str(service[1]), Villager.BODY_HEIGHT)
		readable.position += npc
		if tree.position.y > npc.y + 4.0 and bounds.intersects(readable):
			return true
	return false


func _grove_clear(at: Vector2) -> bool:
	if near_water(Iso.unproject(at), 30.0):
		return false
	for solid in solids:
		if Geometry2D.is_point_in_polygon(at, solid):
			return false
	for road in map_roads:
		if Geometry2D.is_point_in_polygon(at, road):
			return false
	for step in chapel_steps:
		if at.distance_to(step) < 95.0:
			return false
	for point in portal_points.values():
		if at.distance_to(point) < 145.0:
			return false
	for gate in gate_points:
		if at.distance_to(gate) < 160.0:
			return false
	for uv in data["chest_uv"]:
		if at.distance_to(point(Vector2(uv[0], uv[1]))) < 85.0:
			return false
	for key in ["nw", "ne", "sw", "se"]:
		var building: IsoSprite = buildings[key]
		var approach: Array = data["approaches"][key]
		if at.distance_to(building.native_point(Vector2(approach[0], approach[1]))) < 85.0:
			return false
	return true


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
		npc_nodes[n[1]] = npc
		if n[0] == "nw":
			merchant_point = npc.position
		world.add_child(npc)
		circles.append([npc.position, 16.0])
	var mira := Villager.new()
	mira.setup(0, "보급원 미라")
	mira.position = point(Vector2(0.44, 0.57))
	mira.marker = func(): return Quests.marker_for("보급원 미라")
	npc_points["보급원 미라"] = mira.position
	npc_nodes["보급원 미라"] = mira
	world.add_child(mira)
	circles.append([mira.position, 16.0])


## Trees, plants and rocks of the surrounding stage-1 forest field.
func build_field(world: Node2D, field: Rect2, rng: RandomNumberGenerator) -> void:
	var town := Rect2(ground(Vector2(-0.05, 0.0)), Vector2(extent * 1.1, extent))
	var placed: Array[Vector2] = []
	var tree_cells := {}
	var attempts := 0
	while placed.size() < 1040 and attempts < 24000:
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
		var placement_cell := Vector2i((g/150.0).floor())
		# 150단위 이내의 나무는 인접한 아홉 셀에만 있다. 배치/RNG는 유지한다.
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				var peers: Array = tree_cells.get(placement_cell+Vector2i(dx,dy),[])
				for q: Vector2 in peers:
					if q.distance_to(g)<150.0:
						ok = false
		if not ok:
			continue
		placed.append(g)
		var bucket: Array = tree_cells.get(placement_cell,[])
		bucket.append(g)
		tree_cells[placement_cell] = bucket
		var variant := rng.randi_range(0, 17)
		var def: Dictionary = data["sprites"]["tree-%d" % variant]
		var tree := IsoSprite.new().setup(def, float(def["world_height"]))
		tree.position = Iso.project(g)
		tree.flip = rng.randf() < 0.5
		tree.modulate_color = FOLIAGE
		world.add_child(tree)
		circles.append([tree.position, 16.0 + float(def["world_height"]) * 0.03])
	for i in 880:
		var g2 := Vector2(rng.randf_range(field.position.x, field.end.x), rng.randf_range(field.position.y, field.end.y))
		if town.has_point(g2) or near_water(g2, 0.0):
			continue
		# Keep the same random draw count so decoration cannot change tree/loot placement.
		var pd := ForestArt.frame(["flowers_white", "flowers_warm", "fern", "grass"][rng.randi_range(0, 5) % 4])
		var plant := IsoSprite.new().setup(pd, float(pd["world_height"]))
		plant.position = Iso.project(g2)
		world.add_child(plant)
	for i in 120:
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


## Every use of this portal art shares one physical scale, including guardian and cave gates.
func create_portal(at: Vector2) -> IsoSprite:
	var definition: Dictionary = data["sprites"]["portal"]
	var body: Array = definition["body"]
	var height := float(definition["height"]) * 180.0 / float(body[2]) * 1.4
	var portal := IsoSprite.new().setup(definition, height)
	portal.position = at
	PlazaWater.attach(portal, true)
	return portal


static func portal_base(portal: IsoSprite) -> PackedVector2Array:
	if portal.def.has("base_ground"):
		return portal.native_polygon(portal.def["base_ground"])
	var body: Array = portal.def["body"]
	return portal.atlas_polygon([[body[0], body[1] + body[3] * 0.35], [body[0] + body[2], body[1] + body[3] * 0.35], [body[0] + body[2], body[1] + body[3]], [body[0], body[1] + body[3]]])


## Only the three discovered travel destinations belong to this registry.
func _add_warp_portal(id: String, at: Vector2, world: Node2D) -> IsoSprite:
	var portal := create_portal(at)
	if id != "town":
		portal.set_meta("ground_waypoint",id)
	portal.name = "WarpGate_" + id
	portal_points[id] = at
	portal_sprites[id] = portal
	world.add_child(portal)
	var footprint := portal_base(portal)
	if id != "town":
		footprint = PackedVector2Array()
		for i: int in 24:
			footprint.append(at+Iso.project(Vector2.from_angle(TAU*i/24.0)*NativeWaypoint3D.RADIUS*SpatialWorld3D.UNITS))
	portal_footprints[id] = footprint
	if id == "town":
		solids.append(footprint)
	var src: Array = portal.def["source"]
	var corners := portal.atlas_polygon([[src[0], src[1]], [src[0] + src[2], src[1]], [src[0] + src[2], src[1] + src[3]], [src[0], src[1] + src[3]]])
	clear_rects.append(Iso.poly_bounds(corners).grow(40.0))
	return portal


func _build_sanctuaries(world: Node2D) -> void:
	var tree: Landmark = landmarks[0]
	var outline: Array = Landmark.data()[tree.index]["outline"]
	var entrance: int = Landmark.data()[tree.index]["entrance"]
	var mid := (tree._pt(outline[entrance]) + tree._pt(outline[(entrance + 1) % outline.size()])) / 2.0
	var tree_point := mid + (mid - _top_center(tree)).normalized() * 160.0
	sanctuary_points = {"town": spawn_point, "tree": tree_point}
	for id in ["tree", "cave"]:
		var proposed: Vector2 = NativeCaveTrail.proposal(self) if id=="cave" else sanctuary_points[id]+Vector2(-320,210)
		var chosen := _waypoint_clearing(proposed)
		sanctuary_points[id] = chosen
		clear_rects.append(Rect2(chosen-Vector2(240,240),Vector2(480,480)))
		_add_warp_portal(id,chosen,world)


func _waypoint_clearing(proposed: Vector2) -> Vector2:
	# 건물·강·모든 높은 지형과 동굴의 실제 외곽에서 여유를 확보한다.
	for ring: int in 40:
		for index: int in 16:
			var at := proposed+Iso.project(Vector2.from_angle(TAU*index/16.0)*ring*85.0)
			var ground_at := Iso.unproject(at)
			if not ForestRegion.FIELD.grow(-300.0).has_point(ground_at) or near_water(ground_at,150.0):
				continue
			var cave_at := NativeCavePlan.frame(Iso.project(cave_ground)+NativeCavePlan.ENTRY_OFFSET).origin
			if (ground_at/65.0-Vector2(cave_at.x,cave_at.z)).length()<NativeCavePlan.SITE_RADIUS+6.0:
				continue
			var clear := true
			for polygon: PackedVector2Array in solids:
				if Geometry2D.is_point_in_polygon(at,polygon):
					clear = false
				for i: int in polygon.size():
					if at.distance_to(Geometry2D.get_closest_point_to_segment(at,polygon[i],polygon[(i+1)%polygon.size()]))<230.0:
						clear = false
			for circle: Array in circles:
				if at.distance_to(circle[0])<float(circle[1])+260.0:
					clear = false
			for landmark: Landmark in landmarks:
				if Geometry2D.is_point_in_polygon(at,landmark.top):
					clear = false
				for i: int in landmark.top.size():
					if at.distance_to(Geometry2D.get_closest_point_to_segment(at,landmark.top[i],landmark.top[(i+1)%landmark.top.size()]))<230.0:
						clear = false
			if clear:
				return at
	push_error("웨이포인트를 위한 빈 지형을 찾지 못했습니다")
	return proposed
