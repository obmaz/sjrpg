class_name MapGeometry
extends RefCounted
## 지도는 실제 배치/보행 설계를 읽는다. 월드와 별개인 좌표 목록을 보관하지 않는다.


static func shape(
	id: String, kind: String, polygon: PackedVector2Array, color: Color
) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"poly": polygon,
		"bounds": Iso.poly_bounds(polygon) if polygon.size() > 0 else Rect2(),
		"color": color
	}


static func build(village: Village) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var field := PackedVector2Array()
	for point in NativeChapelPlan.polygon(ForestRegion.FIELD):
		field.append(Iso.project(point))
	shapes.append(shape("field", "ground", field, Color("637153")))
	shapes.append(shape("town", "ground", village.safe_zone, Color("667654")))
	var water := PackedVector2Array()
	for point in village.river.polygon:
		water.append(Iso.project(point))
	shapes.append(shape("river", "water", water, Color("40809e")))
	for index in village.map_roads.size():
		shapes.append(shape("road:%d" % index, "road", village.map_roads[index], Color("958b70")))
	var trail := NativeCaveTrail.points(village)
	for index in Geometry2D.offset_polyline(
		trail, NativeCaveTrail.HALF_WIDTH, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
	):
		var projected := PackedVector2Array()
		for point in index:
			projected.append(
				SpatialWorld3D.projected(
					NativeCaveTrail.frame(village) * Vector3(point.x, 0, point.y)
				)
			)
		shapes.append(shape("cave_trail:%d" % shapes.size(), "road", projected, Color("8c8064")))
	shapes.append(shape("bridge", "bridge", village.bridge.deck_polygon(), Color("b3a17c")))
	for index in village.wall_footprints.size():
		shapes.append(
			shape("wall:%d" % index, "wall", village.wall_footprints[index], Color("42423c"))
		)
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(village):
		if str(surface["id"]).begins_with("landmark_"):
			shapes.append(shape(str(surface["id"]), "terrain", surface["top"], Color("8a9566")))
	for landmark in village.landmarks:
		for index in landmark.water.size():
			shapes.append(
				shape(
					"pool:%d:%d" % [landmark.index, index],
					"water",
					landmark.water[index],
					Color("40809e")
				)
			)
	for key: String in village.buildings:
		var polygon: PackedVector2Array
		if key == "chapel":
			polygon = SpatialWorld3D._native_chapel(village)["building"]
		else:
			var building: IsoSprite = village.buildings[key]
			polygon = building.atlas_polygon(village.data["frames"][key]["ground"])
		shapes.append(shape("building:" + key, "building", polygon, Color("c0aa7d")))
	return shapes


static func _npc(game: Node, name: String) -> Node2D:
	var node: Node2D = game.village.npc_nodes.get(name)
	return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null


static func category(marker: Dictionary) -> String:
	var id: String = marker["id"]
	if id.begins_with("cave:room:"):
		return "전투 구역"
	if id.begins_with("hazard:spike"):
		return "가시 함정"
	if id.begins_with("hazard:flame"):
		return "화염 장치"
	if id.begins_with("quest:"):
		return "의뢰"
	if id.begins_with("sanctuary:"):
		return "웨이포인트"
	if id == "cave:return":
		return "귀환문"
	if id.begins_with("npc:"):
		return "마을 시설"
	if id.begins_with("stone:"):
		return "재소환 비석"
	return "보스" if id == "boss" else "동굴"


static func _marker(
	id: String, at: Vector2, label: String, color: Color, detail := ""
) -> Dictionary:
	return {"id": id, "pos": at, "label": label, "color": color, "detail": detail}


static func markers(game: Node) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if game.dungeon.active:
		markers.append(
			_marker("cave:entry", Vector2.ZERO, "동굴 입구", Color("96c9ee"), "입구에서 탐험을 마칠 수 있습니다")
		)
		var portal := game.world.get_node_or_null("CaveReturnPortal") as Node2D
		var at := portal.position if portal != null else Iso.project(DungeonLayout.EXIT)
		var cleared: bool = game.dungeon.defeated == game.dungeon.total
		markers.append(
			_marker(
				"cave:return",
				at,
				"귀환문",
				Color("c4a5ee"),
				"정리 완료 · 이곳에서 탐험 완료 보상 받기" if cleared else "모든 적을 정리한 뒤 탐험 완료 보상 받기"
			)
		)
		if game.dungeon.rooms != null:
			for room in DungeonLayout.ROOMS.size():
				var ready: bool = game.dungeon.rooms.remaining[room] == 0
				markers.append(
					_marker(
						"cave:room:%d" % room,
						Iso.project(DungeonLayout.ROOMS[room]),
						"%d번 방" % (room + 1),
						Color("85bdaf") if ready else Color("dfc18b"),
						game.dungeon.rooms.detail(room)
					)
				)
		if game.dungeon.hazards != null:
			for trap: DungeonTrap in game.dungeon.hazards.traps:
				var ink := Color("e5ba6b") if trap.kind == "spike" else Color("e7866f")
				markers.append(
					_marker(
						"hazard:" + trap.id,
						trap.position,
						trap.title(),
						ink,
						trap.detail() + " · 높이 %+.1f m" % DungeonRelief.at(trap.position)
					)
				)
		return markers
	for definition in Quests.DEFS:
		var id: String = definition["id"]
		var phase := Quests.phase(id)
		if phase == "completed":
			continue
		var name: String = definition["giver"]
		var state := Quests.state(id)
		if id == "moon" and (phase == "ready" or (phase == "accepted" and state["parcel"])):
			name = definition["recipient"]
		var actor := _npc(game, name)
		if actor == null:
			continue
		var at := actor.position
		if (
			id == "roots"
			and phase == "accepted"
			and int(state["altar_kills"]) < Quests.ALTAR_KILL_GOAL
		):
			at = game.village.quest_sites[id]
			name = "석조 정원"
		markers.append(_marker("quest:" + id, at, name, Color("ffe197"), Quests.objective(id)))
	for id: String in game.village.sanctuary_points:
		var found := GameState.discovered_sanctuaries.has(id)
		var at: Vector2 = game.village.sanctuary_points[id]
		var sprite: Node2D = game.village.portal_sprites.get(id)
		if is_instance_valid(sprite):
			at = sprite.position
		markers.append(
			_marker(
				"sanctuary:" + id,
				at,
				Exploration.NAMES[id],
				Color("c4a5ee") if found else Color("9989af"),
				"발견 · 이동 탭에서 이용" if found else "미발견 · 직접 밟으면 활성화"
			)
		)
	for name: String in ["상인", "대장장이", "탈것 상인", "촌장"]:
		var actor := _npc(game, name)
		if actor != null:
			markers.append(_marker("npc:" + name, actor.position, name, Color("7edbcc"), "마을 시설"))
	if game.encounters != null:
		for id: String in game.encounters.stones:
			var stone: EncounterStone = game.encounters.stones[id]
			if not is_instance_valid(stone) or stone.is_queued_for_deletion():
				continue
			var ready: bool = game.encounters.can_summon(id)
			markers.append(
				_marker(
					"stone:" + id,
					stone.position,
					"재소환 비석",
					Color("d6b38a") if ready else Color("9b8b7b"),
					"소환 가능" if ready else "현재 소환할 수 없습니다"
				)
			)
	markers.append(
		_marker(
			"cave:entrance",
			game.dungeon.entry_point(),
			"바람 동굴",
			Color("96c9ee"),
			"흙길을 따라 골짜기 아래 입구로"
		)
	)
	if Quests.all_done() and not GameState.boss_defeated:
		var boss: Enemy = game.quest_runtime._boss if game.quest_runtime != null else null
		var at: Vector2 = (
			boss.position if is_instance_valid(boss) and not boss.dead else game.village.boss_point
		)
		markers.append(_marker("boss", at, "파수꾼", Color("ff9e65"), "숲의 파수꾼 도전"))
	return markers
