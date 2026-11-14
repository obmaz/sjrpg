class_name VillageReviewSnapshot
extends RefCounted
## 명시적 검수 쿼리에서 실제 표시 루트·문·모델 간격을 읽는다. 게임 상태는 변경하지 않는다.


static func publish(game: Node) -> void:
	var tree := game.get_tree()
	# 로딩 중 카메라는 인물 중앙을 보므로 실제 플레이 추적이 시작된 뒤 읽는다.
	while not game.native_ready:
		await tree.process_frame
		if not is_instance_valid(game):
			return
	for frame in 4:
		await tree.process_frame
		if not is_instance_valid(game):
			return
	if is_instance_valid(game) and OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__sjrpgVillageReview = " + JSON.stringify(snapshot(game)), true
		)


static func snapshot(game: Node) -> Dictionary:
	var renderer: WorldRenderer3D = game.world_renderer
	var buildings: Array[Dictionary] = []
	for child: Node in renderer._forest_stage.get_children():
		var chapel := child.has_meta("chapel_detail")
		if not chapel and not child.has_meta("native_house"):
			continue
		var root := child as Node3D
		if root == null:
			continue
		var report: Dictionary = root.get_meta("chapel_detail" if chapel else "native_house")
		var id := "chapel" if chapel else str(report["key"])
		var actual := root.global_transform
		var bounds: AABB = actual * report["bounds"]
		var footprint := Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)
		var forward := actual.basis * Vector3.BACK
		var start := renderer.camera.unproject_position(actual.origin)
		var end := renderer.camera.unproject_position(actual.origin + forward)
		var item := {
			"id": id,
			"origin": _v3(actual.origin),
			"basis": [_v3(actual.basis.x), _v3(actual.basis.y), _v3(actual.basis.z)],
			"forward": _v3(forward),
			"frontScreenVector": [end.x - start.x, end.y - start.y],
			"modelBounds":
			[footprint.position.x, footprint.position.y, footprint.size.x, footprint.size.y],
			"triangles": report["triangles"]
		}
		if not chapel:
			item["matchesPlan"] = actual.is_equal_approx(TownPlazaPlan3D.frame(id))
		if report.has("door_approach"):
			var entry: Rect2 = report["door_approach"]
			var at := actual * Vector3(entry.get_center().x, 0, entry.position.y + 1.0)
			var projected := WorldSpace3D.world_to_projected(at)
			item["doorApproachSample"] = {
				"point": _v3(at),
				"blockedIncludingResidents": game.spatial_world.blocked(projected, Player.RADIUS),
				"floor": game.spatial_world.height_at(projected)
			}
		buildings.append(item)
	var gaps: Array[Dictionary] = []
	for a in buildings.size():
		for b in range(a + 1, buildings.size()):
			var first: Array = buildings[a]["modelBounds"]
			var second: Array = buildings[b]["modelBounds"]
			var dx := maxf(
				0,
				maxf(
					float(first[0]) - float(second[0]) - float(second[2]),
					float(second[0]) - float(first[0]) - float(first[2])
				)
			)
			var dz := maxf(
				0,
				maxf(
					float(first[1]) - float(second[1]) - float(second[3]),
					float(second[1]) - float(first[1]) - float(first[3])
				)
			)
			gaps.append(
				{
					"a": buildings[a]["id"],
					"b": buildings[b]["id"],
					"metres": Vector2(dx, dz).length()
				}
			)
	var gates: Array[Dictionary] = []
	for point: Vector2 in game.village.gate_points:
		var ground := Iso.unproject(point) / WorldSpace3D.GROUND_UNITS_PER_METER
		var nearest := INF
		for item: Dictionary in buildings:
			var raw: Array = item["modelBounds"]
			var box := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
			nearest = minf(nearest, ground.distance_to(ground.clamp(box.position, box.end)))
		gates.append({"ground": [ground.x, ground.y], "nearestBuildingMetres": nearest})
	var foot: Vector3 = game.spatial_world.actor_foot(game.player)
	return {
		"schemaVersion": 1,
		"cameraZoom": game.camera.zoom.y,
		"cameraSize": renderer.camera.size,
		"buildings": buildings,
		"modelGaps": gaps,
		"gates": gates,
		"townInterior": _rect(TownPlazaPlan3D.TOWN_INTERIOR),
		"plaza": _rect(TownPlazaPlan3D.PLAZA),
		"playerFoot": _v3(foot),
		"cameraMode": "follow" if (not is_instance_valid(game.inspection) or game.inspection.focus_point == Vector2.ZERO) else "inspection",
		"note": "모든 모델 부품을 포함한 실제 회전 XZ AABB 간격이다. 지붕 간격·시선 겹침·전체 보행을 대신 판정하지 않는다. 문앞 blocked에는 주민 충돌도 포함한다."
	}


static func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
