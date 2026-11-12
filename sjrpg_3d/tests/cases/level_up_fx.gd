extends TestCase
## Real XP grants must celebrate around the native hero as well as on the screen.


func _sources(game: Node) -> Array:
	return game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "reward" and effect.params.get("large", false))


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	check("ordinary3D adventure creates its celebration presenter without a renderer toggle", renderer != null and renderer.display.visible)
	renderer.set_process(false)
	var celebration: ProgressionEffects3D = renderer._level_up_fx
	game.grant_xp(0)
	renderer._process(0.0)
	check("zero XP cannot create a native level-up celebration", celebration._entries.is_empty() and _sources(game).is_empty())
	game.grant_xp(GameState.xp_to_next())
	var source: RewardFx = _sources(game).back()
	source.set_process(false)
	renderer._process(0.0)
	var entry: Dictionary = celebration._entries[source.get_instance_id()]
	var root: Node3D = entry["root"]
	var ring: MeshInstance3D = entry["ring"]
	var sparks: Array = entry["sparks"]
	var generated_cards := sparks.size() == ProgressionEffects3D.SPARK_COUNT
	for spark: MeshInstance3D in sparks:
		var ink := spark.material_override as ShaderMaterial
		generated_cards = generated_cards and spark.mesh is QuadMesh and spark.get_parent() == root and ink.get_shader_parameter("atlas_texture") == ProgressionEffects3D.ATLAS and spark.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check("real level-up creates a foot ring and existing-art gold particles", GameState.level == 2 and celebration._entries.size() == 1 and ring.mesh is TorusMesh and ring.position.y > 0.0 and generated_cards)
	var banner: LevelUpBanner = game.hud._level_up
	check("around-body celebration preserves the existing nonblocking LEVEL UP banner", banner.active and banner.level == GameState.level and LevelUpBanner.TITLE == "LEVEL UP" and banner.mouse_filter == Control.MOUSE_FILTER_IGNORE and not game.hud._toast.text.contains("레벨 업"))
	game.player.position += Vector2(60, 25)
	source._process(0.05)
	renderer._process(0.0)
	check("celebration follows the actual moving hero's foot anchor", root.position.is_equal_approx(WorldSpace3D.projected_to_world(game.player.position)))
	var spark: MeshInstance3D = sparks[0]
	var low := spark.position.y
	source._process(0.20)
	renderer._process(0.0)
	check("gold particles ascend using only the source effect age", spark.position.y > low and ring.scale.x > 0.86)
	var source_pose := spark.position
	var source_age := source.age
	renderer._process(5.0)
	check("native frame time cannot advance a frozen source celebration", source.age == source_age and spark.position == source_pose and celebration._entries.size() == 1)
	var paused_age := source.age
	var paused_position := spark.position
	var paused_scale := ring.scale
	source.set_process(true)
	renderer.set_process(true)
	get_tree().paused = true
	await _frames(2)
	check("pause freezes the source and all native celebration motion", source.age == paused_age and spark.position == paused_position and ring.scale == paused_scale)
	get_tree().paused = false
	source.set_process(false)
	renderer.set_process(false)
	Prefs.reduce_motion = true
	renderer._process(0.0)
	var still_position := spark.position
	var still_ring := ring.scale
	source._process(0.20)
	renderer._process(0.0)
	var ring_ink := ring.material_override as StandardMaterial3D
	check("reduced motion keeps a restrained stationary ring and glints", spark.position == still_position and ring.scale == still_ring and ring_ink.albedo_color.a <= 0.35 * 0.65)
	source._process(2.0)
	renderer._process(0.0)
	check("native celebration expires with its source without an extra clock", source.is_queued_for_deletion() and celebration._entries.is_empty() and root.is_queued_for_deletion())
	Prefs.reduce_motion = false
	game.grant_xp(GameState.xp_to_next())
	source = _sources(game).back()
	source.set_process(false)
	source._process(5.0)
	renderer._process(0.0)
	check("slow first source update still presents the real native level-up", not source.is_queued_for_deletion() and source.age <= source.life * 0.101 and celebration._entries.size() == 1)
	source._process(5.0)
	renderer._process(0.0)
	check("slow-frame level-up eventually expires", celebration._entries.is_empty())
	for index in 4:
		game.grant_xp(GameState.xp_to_next())
	for effect: Effect in _sources(game):
		effect.set_process(false)
	renderer._process(0.0)
	check("consecutive real level-ups retain a fixed native mesh budget", celebration._entries.size() == ProgressionEffects3D.MAX_ACTIVE and game.cosmetic_effects.size() <= 64)
	for effect: Effect in _sources(game):
		effect._process(2.0)
		effect._process(2.0)
	renderer._process(0.0)
	check("all bounded celebrations clear when their source effects end", celebration._entries.is_empty())
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)
