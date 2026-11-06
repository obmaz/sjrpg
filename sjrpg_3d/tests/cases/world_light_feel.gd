extends TestCase
## Shared daylight must create real material contrast without swallowing contact/UI feedback.


func run() -> void:
	var old_quality := Prefs.low_resolution
	Prefs.set_low_resolution(false)
	var game := await make_game()
	# Keep the source material/CPU contract as an isolated fixture. The actual3D
	# renderer intentionally disables Canvas daylight every live frame.
	game.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	preview.set_process(false)
	WorldLighting.configure(game.forest_lighting.openings, game.field_root)
	WorldLighting.set_enabled(true)
	var opening: Vector2 = game.forest_lighting.openings[0]
	var sunny := WorldLighting.color_at(opening)
	var shaded := WorldLighting.color_at(Vector2(100000, 100000))
	check("stone in daylight is warm while forest shade is cool", sunny.r > sunny.g and sunny.g > sunny.b and shaded.b > shaded.g and shaded.g > shaded.r)
	check("daylight retains warm clearing contrast without crushing forest midtones", _luminance(sunny) > _luminance(shaded) * 1.35)
	check("overlapping openings cannot double the daylight peak", is_equal_approx(sunny.r, 1.16) and sunny.g <= 1.101 and sunny.b <= 0.991)
	check("body tint keeps source alpha untouched", sunny.a == 1.0 and shaded.a == 1.0)
	_check_balanced_forest_fill(game)
	var chapel: IsoSprite = game.village.buildings["chapel"]
	var base := chapel.get_meta("base_material") as ShaderMaterial
	check("authored building form uses the shared daylight material", base == WorldLighting.material())
	check("forest material membership follows actual scene ancestry", WorldLighting.belongs_to_forest(chapel))
	var old_transform := chapel.transform
	WorldOcclusion.update(chapel.global_position - Vector2(0, 30), false)
	check("hero uncovering composes with daylight instead of replacing it", WorldOcclusion._active.has(chapel) and chapel.material == WorldOcclusion._material)
	check("occlusion keeps the same registered daylight openings", (chapel.material as ShaderMaterial).get_shader_parameter("opening_a") == opening)
	WorldOcclusion.update(Vector2(100000, 100000), false)
	check("uncover exit restores lit source material and exact geometry", chapel.material == base and chapel.transform == old_transform)
	var impact := Effect.spawn_impact(game, game.player.position, game.player)
	var glow := impact.material as CanvasItemMaterial
	check("contact light remains emissive instead of inheriting dark woodland tint", glow != null and glow.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	game.player.sprite.trigger_flash(Color.WHITE)
	check("enemy and player contact flash keep their separate silhouette shader", game.player.sprite._flash_overlay != null and (game.player.sprite._flash_overlay.material as ShaderMaterial).shader == ActorSprite.FLASH_SHADER)
	await _check_contact_lighting(game)
	var before := WorldLighting.color_at(game.player.global_position)
	game.hud.open_settings()
	WorldLighting.set_enabled(false)
	check("lighting comparison removes actor and scenery tint together during pause", WorldLighting.color_at(opening) == Color.WHITE and is_zero_approx(float(base.get_shader_parameter("daylight_amount"))))
	WorldLighting.set_enabled(true)
	Prefs.set_low_resolution(true)
	await _frames(2)
	check("economy viewport does not move the world lighting", WorldLighting.color_at(game.player.global_position).is_equal_approx(before) and game.field_root.get_viewport() == game.player.get_viewport())
	check("HUD stays outside the forest material pass", game.hud.get_viewport() == get_viewport() and game.hud.controls.material == null)
	game.hud.close_panel()
	game.player.position = game.dungeon.entry_point()
	check("cave can start under the world daylight setup", game.dungeon.enter())
	preview._process(0.0)
	await _frames(2)
	check("hidden forest cannot tint cave actors or surfaces", not WorldLighting.is_enabled() and WorldLighting.color_at(opening) == Color.WHITE and is_zero_approx(float(base.get_shader_parameter("daylight_amount"))))
	# White output from an unshaded forest shader is not equivalent to the original
	# material: the latter must still receive CaveLight's real PointLight2D pass.
	WorldOcclusion.update(Vector2(100000, 100000), false)
	var cave_receivers := 0
	var cave_lanterns := 0
	var cave_light_pass := true
	for visual in game.dungeon.art.visuals:
		if visual is IsoSprite:
			cave_receivers += 1
			cave_light_pass = cave_light_pass and not WorldLighting.belongs_to_forest(visual) and visual.material == null and not visual.has_meta("base_material")
		for child in visual.get_children():
			if child is PointLight2D:
				cave_lanterns += 1
	check("cave walls rocks arches and lantern art retain their builtin light pass", cave_receivers > 20 and cave_light_pass)
	check("live cave lantern lights remain present", cave_lanterns == 10)
	game.dungeon.leave("")
	preview._process(0.0)
	await _frames(2)
	check("returning restores native daylight without reactivating the source Canvas pass", not WorldLighting.is_enabled() and game.field_root.visibility_layer == 0 and preview.sunlight.visible and preview._world_environment.forest.visible and not preview._world_environment.cave.visible)
	WorldLighting._prune()
	var count := WorldLighting._materials.size()
	var temporary := ShaderMaterial.new()
	temporary.shader = WorldLighting.SHADER
	WorldLighting.register_material(temporary)
	check("temporary material can join the shared daylight without a light node", WorldLighting._materials.size() == count + 1)
	temporary = null
	WorldLighting._prune()
	check("material registry does not keep discarded scenes or materials alive", WorldLighting._materials.size() == count)
	game.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(old_quality)


func _luminance(value: Color) -> float:
	return value.r * 0.2126 + value.g * 0.7152 + value.b * 0.0722


func _check_balanced_forest_fill(game: Node) -> void:
	var old_fill := Color(0.58, 0.66, 0.72)
	var previous_peak := Color(1.16, 1.10, 0.99)
	for uv in [Vector2(0.5, -0.25), Vector2(1.25, 0.5), Vector2(0.5, 1.25), Vector2(-0.25, 0.5)]:
		var outside: Vector2 = game.village.point(uv)
		var fill := WorldLighting.color_at(outside)
		var ratio := _luminance(fill) / _luminance(old_fill)
		check("outside field midtones improve by a bounded fifteen to twenty percent", ratio >= 1.15 and ratio <= 1.20, "%s: %.3fx" % [uv, ratio])
	for opening in game.forest_lighting.openings:
		check("existing fully sunlit town and chapel keep their previous exposure", WorldLighting.color_at(opening).is_equal_approx(previous_peak))
	var source := FileAccess.get_file_as_string("res://scripts/world_daylight.gdshaderinc")
	var ambient_values := _shader_values(source, "FOREST_AMBIENT\\s*=\\s*vec3\\(([^)]+)\\)", 3)
	var direct_values := _shader_values(source, "CLEARING_DIRECT\\s*=\\s*vec3\\(([^)]+)\\)", 3)
	var radius_a := _shader_values(source, "world_daylight_opening\\(p,\\s*opening_a,\\s*vec2\\(([^)]+)\\)", 2)
	var radius_b := _shader_values(source, "world_daylight_opening\\(p,\\s*opening_b,\\s*vec2\\(([^)]+)\\)", 2)
	if ambient_values.size() == 3 and direct_values.size() == 3 and radius_a.size() == 2 and radius_b.size() == 2:
		var gpu_ambient := Vector3(ambient_values[0], ambient_values[1], ambient_values[2])
		var gpu_direct := Vector3(direct_values[0], direct_values[1], direct_values[2])
		check("CPU bodies and actual shader share the compensated light coefficients", gpu_ambient.is_equal_approx(WorldLighting.AMBIENT) and gpu_direct.is_equal_approx(WorldLighting.DIRECT))
		var material: ShaderMaterial = game.forest_lighting.ground_material
		var first: Vector2 = material.get_shader_parameter("opening_a")
		var second: Vector2 = material.get_shader_parameter("opening_b")
		for position in [first, second, second + Vector2(radius_b[0] * 0.5, 0), second + Vector2(radius_b[0] * 2.0, 0)]:
			var a := WorldLighting._opening(position, first, Vector2(radius_a[0], radius_a[1]))
			var b := WorldLighting._opening(position, second, Vector2(radius_b[0], radius_b[1]))
			var expected := gpu_ambient + gpu_direct * (1.0 - (1.0 - a) * (1.0 - b))
			check("shader-bound openings and CPU tint agree at lit edge and forest samples", WorldLighting.color_at(position).is_equal_approx(Color(expected.x, expected.y, expected.z)))
	var grass := 0
	var others := 0
	for surface: CanvasItem in game.forest_lighting.surfaces:
		var texture: Texture2D = surface.texture
		if texture == ForestArt.texture("grass"):
			grass += 1
			check("only the authored grass plane receives the warmer lighter albedo", surface.self_modulate == ForestArt.GRASS_TINT)
		else:
			others += 1
			check("paving and earth albedo are not recoloured by the grass request", surface.self_modulate == Color.WHITE)
	check("grass colour change remains scoped to its material surface", grass > 0 and others > 0 and ForestArt.GRASS_TINT.a == 1.0)
	var sample := Color(0.296, 0.293, 0.119)
	var old_grass := sample * old_fill
	var new_grass := sample * ForestArt.GRASS_TINT * Color(WorldLighting.AMBIENT.x, WorldLighting.AMBIENT.y, WorldLighting.AMBIENT.z)
	var grass_ratio := _luminance(new_grass) / _luminance(old_grass)
	check("brighter meadow grass remains bounded without changing foliage", grass_ratio > 1.45 and grass_ratio < 1.60)


func _shader_values(source: String, pattern: String, count: int) -> PackedFloat64Array:
	var expression := RegEx.new()
	expression.compile(pattern)
	var found := expression.search(source)
	var result := PackedFloat64Array()
	if found != null:
		for value in found.get_string(1).split(","):
			result.append(float(value.strip_edges()))
	check("shared shader light coefficients and radii remain readable for parity checks", result.size() == count)
	return result


func _check_contact_lighting(game: Node) -> void:
	var old_process := game.is_processing()
	var old_motion := Prefs.reduce_motion
	var old_settings_path := Prefs.settings_path
	Prefs.settings_path = "user://tests/world-light-settings.cfg"
	game.set_process(false)
	Prefs.reduce_motion = false
	WorldLighting.advance(1.0)
	WorldLighting.advance(1.0)
	await _frames(2)
	var scene_material := WorldLighting.material()
	var floor_material: ShaderMaterial = game.forest_lighting.materials[0]
	var water: ShaderMaterial = game.village.fountain.material
	var water_clock: PlazaWater
	for child in game.village.fountain.get_children():
		if child is PlazaWater:
			water_clock = child
	var water_processing := water_clock.is_processing()
	water_clock.set_process(false)
	var old_phase: float = water.get_shader_parameter("phase")
	water.set_shader_parameter("phase", 0.375)
	var gates_processing: bool = game.town_gates.is_processing()
	game.town_gates.set_process(false)
	var door: Node2D = game.town_gates.doors[0]
	var door_material := door.material as ShaderMaterial
	var old_reveal: float = door_material.get_shader_parameter("reveal")
	door.set_progress(0.37)
	var receivers: Array[ShaderMaterial] = [scene_material, water, door_material]
	receivers.append_array(game.forest_lighting.materials)
	var bases: Array[Shader] = []
	var identities: Array[int] = []
	var ground_values: Array[Dictionary] = []
	var bound_masks := 0
	for receiver in receivers:
		bases.append(receiver.shader)
		identities.append(receiver.get_instance_id())
	for receiver: ShaderMaterial in game.forest_lighting.materials:
		var values := {}
		for uniform in [&"edge_soil", &"edge_enabled", &"edge_paving", &"edge_distance", &"edge_origin", &"edge_extent", &"edge_span", &"root_enabled", &"root_mask", &"root_origin", &"root_extent", &"root_inverse_basis", &"root_inverse_origin", &"amount", &"opening_a", &"opening_b"]:
			values[uniform] = receiver.get_shader_parameter(uniform)
		if values[&"edge_distance"] != null or values[&"root_mask"] != null:
			bound_masks += 1
		ground_values.append(values)
	var prepared_variants := WorldLighting._contact_shaders.size()
	check("contact variants are prepared at initialization with a bounded shader cache", prepared_variants > 0 and prepared_variants <= WorldLighting.CONTACT_SHADER_LIMIT)
	var at: Vector2 = game.player.global_position
	var baseline := WorldLighting.color_at(at)
	var hp: float = game.player.hp
	WorldLighting.pulse(at, SkillDefs.COLD)
	await _frames(2)
	var cold := WorldLighting.color_at(at)
	check("confirmed contact changes local reflected light without another damage source", cold.b > baseline.b and cold.b - baseline.b > cold.r - baseline.r and game.player.hp == hp)
	var far := at + Vector2(500, 0)
	var far_before := WorldLighting.color_at(far)
	WorldLighting.pulse(at, SkillDefs.COLD)
	check("contact light has no whole-scene tint or source alpha change", WorldLighting.color_at(far).is_equal_approx(far_before) and cold.a == baseline.a)
	var activated := true
	for index in receivers.size():
		activated = activated and receivers[index].get_instance_id() == identities[index] and receivers[index].shader != bases[index] and receivers[index].shader.code.contains("#define WORLD_CONTACT_LIGHTS")
	check("contact enables compiled variants without replacing any material or creating shaders on hit", activated and WorldLighting._contact_shaders.size() == prepared_variants)
	check("water float and gate progress survive the first shader transition", is_equal_approx(float(water.get_shader_parameter("phase")), 0.375) and is_equal_approx(float(door_material.get_shader_parameter("reveal")), 0.37))
	check("real soil masks textures booleans and vectors survive the first transition", bound_masks > 1 and _ground_uniforms_match(game.forest_lighting.materials, ground_values))
	# Animation/controller updates must keep working on the exact same resources
	# while contact arithmetic is enabled, and remain after returning to idle.
	water.set_shader_parameter("phase", 1.125)
	door.set_progress(0.63)
	var light: Vector4 = scene_material.get_shader_parameter("contact_light_a")
	var tint: Vector3 = scene_material.get_shader_parameter("contact_color_a")
	check("ground and scenery share the same bounded contact uniforms", light.w > 0.0 and light == floor_material.get_shader_parameter("contact_light_a") and tint == floor_material.get_shader_parameter("contact_color_a"))
	var reflected := Vector3(cold.r - baseline.r, cold.g - baseline.g, cold.b - baseline.b)
	check("CPU body tint matches shader contact strength at its actual origin", reflected.is_equal_approx(tint * light.w) and Vector2(light.x, light.y).is_equal_approx(at))
	WorldLighting.advance(1.0)
	check("first slow frame retains one contact-light presentation", WorldLighting._contacts.size() == 1 and WorldLighting.color_at(at).b > baseline.b)
	var age := WorldLighting._contacts[0].age
	for hit in 40:
		WorldLighting.pulse(at, SkillDefs.COLD)
	check("rapid repeated contacts neither allocate extra lights nor reset their expiry", WorldLighting._contacts.size() == 1 and WorldLighting._contacts[0].age == age)
	get_tree().paused = true
	WorldLighting.advance(0.5)
	WorldLighting.pulse(at + Vector2(300, 0), SkillDefs.FIRE, true)
	check("pause freezes existing light and rejects new contact pulses", WorldLighting._contacts.size() == 1 and WorldLighting._contacts[0].age == age)
	Prefs.set_reduce_motion(true)
	await _frames(2)
	var paused_light: Vector4 = scene_material.get_shader_parameter("contact_light_a")
	check("motion setting lowers paused GPU light without advancing its lifetime", paused_light.w > 0.0 and paused_light.w < light.w * 0.5 and WorldLighting._contacts[0].age == age)
	Prefs.set_reduce_motion(false)
	get_tree().paused = false
	WorldLighting.advance(1.0)
	await _frames(2)
	check("unrendered contact still expires and clears terrain uniforms", WorldLighting._contacts.is_empty() and WorldLighting.color_at(at).is_equal_approx(baseline) and floor_material.get_shader_parameter("contact_light_a") == Vector4.ZERO)
	var restored := true
	for index in receivers.size():
		restored = restored and receivers[index].get_instance_id() == identities[index] and receivers[index].shader == bases[index]
	check("expiry restores the original compiled idle shaders on the same materials", restored)
	check("animated water and gate controller values survive the return to idle", is_equal_approx(float(water.get_shader_parameter("phase")), 1.125) and is_equal_approx(float(door_material.get_shader_parameter("reveal")), 0.63))
	check("all real terrain mask texture and boundary uniforms survive the return to idle", _ground_uniforms_match(game.forest_lighting.materials, ground_values))
	WorldLighting.pulse(at - Vector2(25, 0), Color.WHITE, true)
	WorldLighting.pulse(at + Vector2(25, 0), Color.WHITE, true)
	var overlap := WorldLighting.color_at(at)
	check("two overlapping lights keep a strict per-channel ceiling", WorldLighting._contacts.size() == WorldLighting.CONTACT_LIMIT and overlap.r - baseline.r <= 0.5501 and overlap.g - baseline.g <= 0.5501 and overlap.b - baseline.b <= 0.5501)
	for index in 30:
		WorldLighting.pulse(at + Vector2(index * 100, 0), SkillDefs.FIRE)
	check("many simultaneous victims reuse only two local contact lights", WorldLighting._contacts.size() == 2)
	WorldLighting.advance(1.0)
	WorldLighting.advance(1.0)
	WorldLighting.pulse(at, SkillDefs.FIRE, true)
	var full := WorldLighting.color_at(at)
	Prefs.reduce_motion = true
	var reduced := WorldLighting.color_at(at)
	check("reduced motion immediately lowers local flash energy", reduced.r > baseline.r and reduced.r - baseline.r < (full.r - baseline.r) * 0.5)
	Prefs.reduce_motion = false
	_check_contact_registry_cap()
	game.field_root.hide()
	check("cave transition clears pulses instead of carrying light into the cave", WorldLighting._contacts.is_empty() and WorldLighting.color_at(at) == Color.WHITE)
	check("cave transition restores the noncontact shader instead of retaining expensive active arithmetic", scene_material.shader == bases[0] and water.shader == bases[1] and door_material.shader == bases[2])
	WorldLighting.pulse(at, SkillDefs.FIRE, true)
	check("hidden forest rejects new pulses", WorldLighting._contacts.is_empty())
	game.field_root.show()
	await _frames(2)
	check("returning forest has no stale contact glow", WorldLighting.color_at(at).is_equal_approx(baseline))
	Prefs.set_reduce_motion(old_motion)
	Prefs.settings_path = old_settings_path
	water.set_shader_parameter("phase", old_phase)
	water_clock.set_process(water_processing)
	door.set_progress(old_reveal)
	game.town_gates.set_process(gates_processing)
	game.set_process(old_process)


func _ground_uniforms_match(materials: Array[ShaderMaterial], expected: Array[Dictionary]) -> bool:
	for index in materials.size():
		for uniform in expected[index]:
			if materials[index].get_shader_parameter(uniform) != expected[index][uniform]:
				return false
	return true


func _check_contact_registry_cap() -> void:
	WorldLighting._prune()
	var original := WorldLighting._contact_materials.size()
	var receivers: Array[ShaderMaterial] = []
	for index in WorldLighting.CONTACT_MATERIAL_LIMIT - original:
		var ink := ShaderMaterial.new()
		ink.shader = WorldLighting.SHADER
		receivers.append(ink)
		WorldLighting.register_contact_material(ink)
		ink = null
	var overflow := ShaderMaterial.new()
	overflow.shader = WorldLighting.SHADER
	WorldLighting.register_contact_material(overflow)
	check("contact receiver registry is bounded without retaining a permanent overflow glow", WorldLighting._contact_materials.size() == WorldLighting.CONTACT_MATERIAL_LIMIT and overflow.get_shader_parameter("contact_light_a") == Vector4.ZERO and overflow.get_shader_parameter("contact_light_b") == Vector4.ZERO)
	overflow = null
	receivers.clear()
	WorldLighting._prune()
	check("discarded contact receivers are not retained by the registry", WorldLighting._contact_materials.size() == original)
