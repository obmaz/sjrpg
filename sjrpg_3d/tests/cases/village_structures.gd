extends TestCase
## 실제 설치한 상부 통로와 수면 아래 교각을 물리 레이/캡슐로 확인한다.


func run() -> void:
	var game := await make_game("warrior")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var spatial: SpatialWorld3D = game.spatial_world
	var space := spatial.get_world_3d().direct_space_state
	var walk: Dictionary = game.world_renderer._fortification.report["wall_walk"]
	var decks := 0
	var ground_clear := true
	var overhead := true
	var capsule := CapsuleShape3D.new()
	var dimensions := SpatialWorld3D.actor_dimensions(game.player, Player.RADIUS)
	capsule.radius = dimensions.x
	capsule.height = dimensions.y
	for route: Transform3D in walk["routes"]:
		var at := route.origin
		var ray := PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * 0.10, at - Vector3.UP * 0.25, SpatialWorld3D.SOLID
		)
		var hit := space.intersect_ray(ray)
		overhead = (
			overhead and not hit.is_empty() and absf((hit["position"] as Vector3).y - at.y) < 0.005
		)
		ground_clear = ground_clear and absf(spatial.height_at(WorldSpace3D.world_to_projected(at))) < 0.01
		# 지상 머리 위 여유는 새 통로의 충돌만 따로 검사해 기존 집/벽과 구별한다.
		var body := spatial._geometry.get_node("WallWalkStructure") as StaticBody3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(
			Basis.IDENTITY, Vector3(at.x, dimensions.y * 0.5 + 0.01, at.z)
		)
		query.collision_mask = SpatialWorld3D.SOLID
		for contact: Dictionary in space.intersect_shape(query):
			ground_clear = ground_clear and contact["collider"] != body
		decks += 1
	check(
		"every long wall segment has a real solid guard-walk deck",
		decks == 8 and overhead and float(walk["width"]) >= 1.1
	)
	check("upper structure preserves ground FLOOR and hero headroom", ground_clear)
	var frame := BridgePlan3D.frame(game.village.bridge)
	var bridge_parts := 0
	var foundations := true
	for part: Dictionary in BridgePlan3D.foundations(game.village.bridge):
		var polygon: PackedVector2Array = part["polygon"]
		var centre := Vector2.ZERO
		for p: Vector2 in polygon:
			centre += p / polygon.size()
		var top: float = part["top"]
		var at := frame * Vector3(centre.x, top, centre.y)
		var ray := PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * 0.04, at - Vector3.UP * 0.08, SpatialWorld3D.SOLID
		)
		var hit := space.intersect_ray(ray)
		foundations = (
			foundations
			and not hit.is_empty()
			and absf((hit["position"] as Vector3).y - top) < 0.005
		)
		bridge_parts += 1
	check(
		"all bridge footings and cutwaters have actual underwater collision",
		bridge_parts == 9 and foundations
	)
	var material := game.world_renderer._materials["village_stone"] as ShaderMaterial
	check(
		"pillars and steps use the adopted shared stone atlas",
		material.get_shader_parameter("atlas") == load(NativeVillageSurfaces.ROOT + "masonry.png")
	)
	print(
		"ART_AUDIT village_structures ",
		JSON.stringify(
			{
				"wall_routes": decks,
				"walk_parts": walk["parts"].size(),
				"headroom_clear": ground_clear,
				"bridge_foundations": bridge_parts
			}
		)
	)
	game.queue_free()
	await _frames(2)
