extends TestCase
## 주민 원본과 실제 네이티브 서비스 접근·시야를 검사한다. 숨겨진2D 벽 그림은 검수 기준으로 쓰지 않는다.


func _native_head_clear(game: Node, npc: Villager) -> bool:
	var spatial: SpatialWorld3D = game.spatial_world
	var head := WorldSpace3D.projected_to_world(npc.position, 1.72)
	var query := PhysicsRayQueryParameters3D.create(
		head + Vector3.ONE * 30.0, head, SpatialWorld3D.SOLID
	)
	var excluded: Array[RID] = []
	for circle: Dictionary in spatial._circles:
		if (circle["point"] as Vector2).is_equal_approx(npc.position):
			excluded.append((circle["body"] as StaticBody3D).get_rid())
	query.exclude = excluded
	var hit := spatial.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		print(
			"ART_AUDIT NPC_HEAD_OCCLUDED ",
			npc.display_name,
			" head=",
			head,
			" hit=",
			hit["position"],
			" collider=",
			hit["collider"].get_path()
		)
	return hit.is_empty()


func run() -> void:
	var art := NpcArt.data()
	for record: Dictionary in (
		[art["source"], art["generation"], art["measure"], art["atlas"]] + art["references"]
	):
		check(
			"NPC art provenance matches reviewed pixels",
			FileAccess.get_sha256("res://" + str(record["path"])) == str(record["sha256"])
		)
	var unique := {}
	for label in art["labels"]:
		var identity: String = NpcArt.identity(label)
		var definition: Dictionary = art["people"][identity]
		unique[str(definition["pixels_sha256"])] = true
		check(
			"each named resident has its own identity: " + label,
			identity != "" and definition["body_height"] == Villager.BODY_HEIGHT
		)
	check(
		"all eight residents have different drawn bodies",
		unique.size() == 8 and art["labels"].size() == 8
	)
	var image := Image.load_from_file("res://" + str(art["atlas"]["path"]))
	for definition: Dictionary in art["people"].values():
		var source: Array = definition["source"]
		var origin := Vector2i(source[0], source[1])
		check(
			"NPC padding retains real transparent alpha",
			(
				image.get_pixelv(origin + Vector2i(1, 1)).a < 0.02
				and image.get_pixelv(origin + Vector2i(source[2] - 2, source[3] - 2)).a < 0.02
			)
		)

	var game := await make_game()
	var residents: Array[Villager] = []
	for node in game.world.get_children():
		if node is Villager:
			residents.append(node)
	check("town and field use eight named service/quest residents", residents.size() == 8)
	var painted_hero_heights: Array[float] = []
	for key in ["warrior", "mage"]:
		var metadata: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/sprites/actors/" + key + ".json")
		)
		var texture := ActorAtlas.get_atlas(key).texture
		var pixels := texture.get_image()
		var region: Array = metadata["frames"][0]
		var min_y := int(region[3])
		var max_y := -1
		for y in int(region[3]):
			for x in int(region[2]):
				if pixels.get_pixel(int(region[0]) + x, int(region[1]) + y).a > 0.25:
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
		painted_hero_heights.append(
			(
				float(max_y - min_y + 1)
				* game.player.sprite.body_height
				/ float(metadata["sizes"][0][1])
			)
		)
	for npc in residents:
		var body := npc.body_rect()
		for hero_height in painted_hero_heights:
			check(
				"resident body matches the painted human scale: " + npc.display_name,
				body.size.y / hero_height >= 0.90 and body.size.y / hero_height <= 1.08,
				"npc=%.2f hero=%.2f" % [body.size.y, hero_height]
			)
		check(
			"resident keeps its feet on the actual world anchor",
			body.end.y >= -1.0 and body.end.y < 4.0,
			str(body)
		)
		if npc.display_name in ["상인", "대장장이", "탈것 상인", "촌장", "보급원 미라"]:
			check(
				"native static geometry leaves resident head visible: " + npc.display_name,
				_native_head_clear(game, npc)
			)

	for key: String in TownPlazaPlan3D.LEGACY_CENTERS:
		var bounds: Rect2 = game.world_renderer._building_bounds(key)
		var expected: Vector2 = TownPlazaPlan3D.LEGACY_CENTERS[key]
		check(
			"preserved house follows the explicit plaza layout: " + key,
			bounds.get_center().distance_to(expected) < .001
		)
		var report: Dictionary = game.world_renderer._houses[key]
		var root := NativePlayerOcclusion.static_owner(report["meshes"][0]) as Node3D
		var approach: Rect2 = report["door_approach"]
		var center := approach.get_center()
		var at := WorldSpace3D.world_to_projected(
			root.global_transform * Vector3(center.x, 0, center.y)
		)
		check(
			"actual native house doorstep remains reachable: " + key,
			not game._blocked(at, Player.RADIUS)
		)
	for id: String in TownPlazaPlan3D.SERVICES:
		var at := TownPlazaPlan3D.approach(id)
		var outward := WorldSpace3D.world_to_projected(Vector3(0, 0, 1.2))
		check(
			"dedicated service approach remains clear: " + id,
			not game._blocked(at + outward, Player.RADIUS)
		)
	game.queue_free()
	await _frames(2)
