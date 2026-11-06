extends TestCase
## Shared daylight must create real material contrast without swallowing contact/UI feedback.


func run() -> void:
	var old_quality := Prefs.low_resolution
	Prefs.set_low_resolution(false)
	var game := await make_game()
	WorldLighting.configure(game.forest_lighting.openings, game.field_root)
	WorldLighting.set_enabled(true)
	var opening: Vector2 = game.forest_lighting.openings[0]
	var sunny := WorldLighting.color_at(opening)
	var shaded := WorldLighting.color_at(Vector2(100000, 100000))
	check("stone in daylight is warm while forest shade is cool", sunny.r > sunny.g and sunny.g > sunny.b and shaded.b > shaded.g and shaded.g > shaded.r)
	check("daylight has a visibly stronger luminance step than the former subtle tint", _luminance(sunny) > _luminance(shaded) * 1.6)
	check("overlapping openings cannot double the daylight peak", is_equal_approx(sunny.r, 1.16) and sunny.g <= 1.101 and sunny.b <= 0.991)
	check("body tint keeps source alpha untouched", sunny.a == 1.0 and shaded.a == 1.0)
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
	await _frames(2)
	check("returning restores the same world-anchored light model", WorldLighting.is_enabled() and WorldLighting.color_at(opening).is_equal_approx(sunny))
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
