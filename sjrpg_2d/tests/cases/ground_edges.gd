extends TestCase
## Terrain masks derive from actual geometry; material transitions add no obstacles.


func run() -> void:
	var concave := PackedVector2Array([Vector2.ZERO, Vector2(200, 0), Vector2(200, 70), Vector2(70, 70), Vector2(70, 200), Vector2(0, 200)])
	check("concave ground keeps the inside arm", is_equal_approx(GroundEdges.signed_distance(Vector2(35, 150), concave), 35.0))
	check("concave notch remains outside the material", is_equal_approx(GroundEdges.signed_distance(Vector2(120, 120), concave), -50.0))
	check("actual boundary has zero signed coverage distance", is_zero_approx(GroundEdges.signed_distance(Vector2(200, 35), concave)))
	var mask := GroundEdges.distance_record(concave)
	var repeated := GroundEdges.distance_record(concave.duplicate())
	check("identical road geometry reuses its immutable mask", mask["texture"] == repeated["texture"])
	var image: Image = mask["texture"].get_image()
	check("edge textures have a bounded pixel cost", image.get_width() <= 128 and image.get_height() <= 128)
	check("mask pixels preserve both the concave arm and missing corner", _sample(mask, image, Vector2(35, 150)) > 0.6 and _sample(mask, image, Vector2(120, 120)) < 0.3)
	var other := PackedVector2Array([Vector2(500, 0), Vector2(700, 0), Vector2(700, 200), Vector2(500, 200)])
	var second := GroundEdges.distance_record(other)
	check("separate terrain polygons retain independent boundaries", second["texture"] != mask["texture"] and second["origin"] != mask["origin"])
	var game := await make_game()
	var lighting: ForestLighting = game.forest_lighting
	var roads_before: Array = game.village.map_roads.duplicate(true)
	var solid_count: int = game.village.solids.size()
	var circle_count: int = game.village.circles.size()
	var world_count: int = game.world.get_child_count()
	var edge_count := 0
	for surface in lighting.surfaces:
		var ink := surface.material as ShaderMaterial
		var road := surface as Polygon2D
		if road != null:
			var polygon: PackedVector2Array = road.polygon.duplicate()
			var uv: PackedVector2Array = road.uv.duplicate()
			var before := road.transform
			var repeated_ink := GroundEdges.material_for(road, lighting.ground_material)
			check("material blending cannot change road vertices or UVs", road.polygon == polygon and road.uv == uv and road.transform == before)
			check("authored paving and earth retain the shared light shader", repeated_ink.shader == lighting.ground_material.shader and ink.get_shader_parameter("edge_enabled") == true)
			check("road mask never applies the tree-floor tint", ink.get_shader_parameter("root_enabled") == false)
			edge_count += 1
		else:
			check("meadow alone receives the tree-root albedo", ink.get_shader_parameter("root_enabled") == true and ink.get_shader_parameter("edge_enabled") == false)
	check("all current street and dirt outlines gain transitions", edge_count >= 7)
	check("ground transitions leave routes and collision unchanged", game.village.map_roads == roads_before and game.village.solids.size() == solid_count and game.village.circles.size() == circle_count and game.world.get_child_count() == world_count)
	var roots := lighting.root_floor
	var root_image: Image = roots["texture"].get_image()
	check("all tree clearings share one bounded texture", root_image.get_width() <= 512 and root_image.get_height() <= 512)
	var tree_count := 0
	var aligned := true
	for child in game.world.get_children():
		var tree := child as IsoSprite
		if tree == null or str(tree.def.get("sheet", "")) != "forest-isometric-trees":
			continue
		tree_count += 1
		aligned = aligned and roots["centers"].has(tree.global_position) and _sample(roots, root_image, tree.global_position) > 0.65
	check("root soil follows actual town and field tree contacts", aligned and tree_count > 250 and tree_count == int(roots["count"]))
	var previous := Prefs.low_resolution
	Prefs.set_low_resolution(not previous)
	await _frames(2)
	check("quality change keeps road masks and root contacts anchored", lighting.root_floor["texture"] == roots["texture"] and lighting.get_viewport() == lighting.surfaces[0].get_viewport())
	Prefs.set_low_resolution(previous)
	game.queue_free()
	await _frames(2)


func _sample(record: Dictionary, image: Image, point: Vector2) -> float:
	var uv: Vector2 = (point - Vector2(record["origin"])) / Vector2(record["extent"])
	var pixel := Vector2i(uv * Vector2(image.get_size())).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(pixel).r
