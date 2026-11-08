extends TestCase
## Real hidden adapters must keep metadata while their native replacements own visuals.


func run() -> void:
	var before: Dictionary = IsoSprite.texture_snapshot()
	var game: Node = await make_game("mage")
	await _frames(3)
	var after: Dictionary = IsoSprite.texture_snapshot()
	check("building the native town does not acquire archived sprite sheets",
		int(after["loaded_textures"]) == int(before["loaded_textures"]))
	var sources: Array = game.village.buildings.values() + game.village.town_trees + game.village.portal_sprites.values()
	sources.append(game.village.fountain)
	for chest: Chest in game.chests:
		sources.append(chest.body_sprite)
	var lazy := true
	for source: IsoSprite in sources:
		lazy = lazy and not source.is_texture_loaded() and source._warp_mesh == null
	check("native-owned buildings trees portals fountain and chests keep metadata-only adapters", lazy)
	game.player.position = game.dungeon.entry_point()
	var entered: bool = game.dungeon.enter()
	check("lazy scenery preserves actual cave entry", entered)
	if entered:
		await _frames(3)
		var cave: Dictionary = IsoSprite.texture_snapshot()
		check("native cave replacements do not acquire archived sprite sheets",
			int(cave["loaded_textures"]) == int(after["loaded_textures"]))
		var cave_lazy := true
		for source: Node2D in game.dungeon.art.visuals:
			if source is IsoSprite:
				cave_lazy = cave_lazy and not (source as IsoSprite).is_texture_loaded()
		check("native cave props keep their original coordinate metadata without source textures", cave_lazy)
	game.queue_free()
	await _frames(2)

	var village := Village.new()
	var parent := Node2D.new()
	parent.hide()
	add_child(parent)
	var world := Node2D.new()
	var ground := Node2D.new()
	parent.add_child(world)
	parent.add_child(ground)
	var warped := IsoSprite.new().setup(village.data["sprites"]["chapel"], 320.0)
	warped.position = Vector2(140, 220)
	var foot: Array = warped.def["foot"]
	var sort_at := Vector2(foot[0] - 24, foot[1])
	var strip := warped.make_strip(730.0, 830.0, sort_at)
	var anchor_before := warped.native_point(Vector2(420, 280))
	world.add_child(warped)
	world.add_child(strip)
	var tree := IsoSprite.new().setup(village.data["sprites"]["tree-11"], 190.0)
	world.add_child(tree)
	var shade: CanopyShade = CanopyShade.attach(tree, ground)
	var pool := IsoSprite.new().setup(village.data["sprites"]["pool"], 240.0)
	var fluid: PlazaWater = PlazaWater.attach(pool, false)
	world.add_child(pool)
	var previous_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var phase := fluid.phase
	var resident: Dictionary = IsoSprite.texture_snapshot()
	await _frames(3)
	var still_resident: Dictionary = IsoSprite.texture_snapshot()
	check("hidden ready strip shadow and fluid setup never invoke texture acquisition",
		not warped.is_texture_loaded() and not strip.is_texture_loaded()
		and not tree.is_texture_loaded() and not pool.is_texture_loaded()
		and warped._warp_mesh == null and strip._warp_mesh == null
		and int(resident["loaded_textures"]) == int(still_resident["loaded_textures"]))
	check("native fluid animation clock runs without its archived image",
		fluid.phase > phase and fluid.water_material.get_shader_parameter("atlas_region") == Vector4.ZERO)
	check("hidden canopy retains ownership without allocating its alpha texture",
		shade != null and shade._texture == null and not shade.visible)
	check("strip clipping and foot alignment remain metadata-only",
		strip.clip == Vector2(730, 830) and strip.k == warped.k
		and (strip.position + strip.draw_shift).is_equal_approx(warped.position)
		and warped.native_point(Vector2(420, 280)).is_equal_approx(anchor_before))

	var consumer := Ortho3DAffordances.new()
	var geometry: Dictionary = consumer._sprite_geometry(warped)
	var source_texture: Texture2D = warped.texture
	var calibration: Dictionary = ArtWarp.data(warped.def["warp"])
	check("a real native fallback lazily builds the calibrated warped geometry",
		source_texture != null and warped._warp_mesh != null
		and geometry["vertices"].size() == calibration["points"].size())
	var arrays: Array = warped._warp_mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var row: Array = calibration["points"][0]
	var src: Array = warped.def["source"]
	var origin: Array = warped.def["origin"]
	var packing: float = warped.def["packing"]
	var expected_uv := (Vector2(src[0], src[1]) + (Vector2(row[0], row[1]) - Vector2(origin[0], origin[1])) * packing) / source_texture.get_size()
	check("fallback UVs use the original atlas and reviewed warp", uv[0].is_equal_approx(expected_uv))
	check("an unresolved strip shares the explicitly requested sheet without a second texture", strip.texture == source_texture)
	warped.texture = null
	warped.ensure_warp_mesh()
	var cleared_strip := warped.make_strip(730, 830, sort_at)
	check("explicit null and its strip never silently reacquire the source sheet",
		warped.texture == null and warped._warp_mesh == null and cleared_strip.texture == null)
	cleared_strip.free()
	warped.texture = source_texture
	warped.ensure_warp_mesh()
	check("restoring an explicit texture restores fallback geometry without moving the contact",
		warped._warp_mesh != null and warped.native_point(Vector2(420, 280)).is_equal_approx(anchor_before))

	var pool_texture: Texture2D = pool.texture
	var pool_src: Array = pool.def["source"]
	var size := pool_texture.get_size()
	var region := Vector4(pool_src[0] / size.x, pool_src[1] / size.y, pool_src[2] / size.x, pool_src[3] / size.y)
	check("first real fluid texture consumption configures its atlas before drawing",
		fluid.water_material.get_shader_parameter("atlas_region") == region)
	pool.texture = null
	check("clearing fluid texture also clears its shader region",
		pool.texture == null and fluid.water_material.get_shader_parameter("atlas_region") == Vector4.ZERO)
	pool.texture = pool_texture
	parent.show()
	await _frames(3)
	check("a visible canopy fallback still binds the real caster alpha",
		tree.is_texture_loaded() and shade._texture == tree.texture_if_loaded()
		and (shade.material as ShaderMaterial).get_shader_parameter("canopy_alpha") == tree.texture_if_loaded())
	Prefs.reduce_motion = previous_motion
	parent.queue_free()
	await _frames(2)
