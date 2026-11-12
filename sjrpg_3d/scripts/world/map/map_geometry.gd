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
	for point in ChapelPlan3D.polygon(ForestRegion.FIELD):
		field.append(Iso.project(point))
	shapes.append(shape("field", "ground", field, Color("637153")))
	shapes.append(shape("town", "ground", village.safe_zone, Color("667654")))
	var water := PackedVector2Array()
	for point in village.river.polygon:
		water.append(Iso.project(point))
	shapes.append(shape("river", "water", water, Color("40809e")))
	for index in village.map_roads.size():
		shapes.append(shape("road:%d" % index, "road", village.map_roads[index], Color("958b70")))
	var trail := CaveTrailPlan3D.points(village)
	for index in Geometry2D.offset_polyline(
		trail, CaveTrailPlan3D.HALF_WIDTH, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
	):
		var projected := PackedVector2Array()
		for point in index:
			projected.append(
				WorldSpace3D.world_to_projected(
					CaveTrailPlan3D.frame(village) * Vector3(point.x, 0, point.y)
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
	if id.begins_with("treasure:gold:"):
		return "장비 보물"
	if id.begins_with("treasure:iron:"):
		return "보급 보물"
	if id.begins_with("treasure:"):
		return "보물 상자"
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
		var portal: Node2D = game.dungeon.return_portal()
		if portal != null:
			var cleared: bool = game.dungeon.defeated == game.dungeon.total
			markers.append(
				_marker(
					"cave:return",
					portal.position,
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
		_append_treasure(markers, game)
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
		if not ExpeditionState.quest_allowed(id): continue
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
			at = game.village.warp_point(id)
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
			var required: bool = ExpeditionState.phase() == "seals" and ExpeditionState.chapter()["seals"].has(id)
			var cleared: bool = GameState.expedition.get("seals", []).has(id)
			markers.append(
				_marker(
					"stone:" + id,
					stone.position,
					("되찾은 봉인" if cleared else "숲의 봉인") if required else "재소환 비석",
					Color("ffe197") if required else Color("d6b38a") if ready else Color("9b8b7b"),
					("봉인 회복 완료" if cleared else "비석을 공격해 소환한 적을 모두 처치하세요") if required else "소환 가능" if ready else "현재 소환할 수 없습니다"
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
	if (ExpeditionState.phase() == "boss" if ExpeditionState.mode() else Quests.all_done()) and not GameState.boss_defeated:
		var boss: Enemy = game.quest_runtime._boss if game.quest_runtime != null else null
		var at: Vector2 = (
			boss.position if is_instance_valid(boss) and not boss.dead else game.village.boss_point
		)
		markers.append(_marker("boss", at, "파수꾼", Color("ff9e65"), "숲의 파수꾼 도전"))
	if ExpeditionState.mode() and ExpeditionState.phase() in ["lobby", "debrief", "return"]:
		var name := "촌장" if ExpeditionState.phase() == "return" else "보급원 미라"
		var actor := _npc(game, name)
		if actor != null: markers.append(_marker("quest:contract", actor.position, "원정 보고" if name == "촌장" else "원정 계약", Color("ffe197"), ExpeditionState.objective()))
	if ExpeditionState.phase() == "optional" and GameState.expedition.get("branch") == "elite" and game.expedition != null and game.encounters != null and game.encounters.stones.has("deep_east"):
		var actor: Enemy = game.expedition._elite
		var at: Vector2 = actor.position if is_instance_valid(actor) and not actor.dead else game.encounters.stones["deep_east"].position
		markers.append(_marker("quest:elite", at, "정예 파수꾼", Color("ff9e65"), "선택 도전 · 쓰러뜨리면 성장 선택 1회"))
	return markers


## 활성 동굴의 실물만 읽는다. 별도 위치 목록·개봉 기록·상자 참조를 지도에 보관하지 않는다.
static func _append_treasure(markers: Array[Dictionary], game: Node) -> void:
	for candidate in game.chests:
		if not is_instance_valid(candidate):
			continue
		var chest := candidate as Chest
		if (
			chest == null
			or chest.is_queued_for_deletion()
			or chest.dead
			or chest.persistent
			or chest.get_parent() != game.world
		):
			continue
		var gold := chest.variant == "gold"
		var iron := chest.variant == "iron"
		var detail := "좋은 장비 위주 · 적이 나오지 않음" if gold else "내용물은 열어서 확인"
		if iron:
			detail = "내구도 %d/%d · 포션·골드 위주" % [int(chest.hp), int(chest.max_hp)]
		markers.append(
			_marker(
				"treasure:%s:%d" % [chest.variant, chest.index],
				chest.position,
				"황금 상자" if gold else ("쇠 상자" if iron else "나무 상자"),
				Color("edcb77") if gold else Color("afc3d6"),
				detail
			)
		)
