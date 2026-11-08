extends TestCase
## Generated sprites are a presentation backend: real bodies, clocks and saves remain 3D.
const Fixture := preload("res://tests/native_combat_fixture.gd")


func _pivot_world(entry: Dictionary) -> Vector3:
	var card: MeshInstance3D = entry["card"]
	var pivot: Vector2 = entry["pivot"]
	return card.global_transform * Vector3(pivot.x - 0.5, 0.5 - pivot.y, 0.0)


func run() -> void:
	var old_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	var sprites: NativeEnemySprites3D = preview._enemy_sprites
	check("new 2D monster atlas is lazy before a marked monster exists", not bool(sprites.snapshot()["texture_loaded"]) and not bool(sprites.snapshot()["corpse_texture_loaded"]))
	var floor_body := Fixture.box(game.spatial_world, Vector3(123, 2.5, 123), Vector3(30, 1, 30), SpatialWorld3D.FLOOR)
	await Fixture.settle(get_tree())
	var wave: Array[Enemy] = []
	for index in 20:
		var enemy := Enemy.new()
		enemy.setup(game, "goblin", 1)
		enemy.set_meta("visual_variant", NativeEnemySprites3D.VARIANT)
		enemy.position = SpatialWorld3D.projected(Vector3(120.0 + (index % 5) * 1.2, 3.0, 120.0 + floori(index / 5.0) * 1.2))
		game.world.add_child(enemy)
		enemy.set_process(false)
		game.enemies.append(enemy)
		wave.append(enemy)
	await Fixture.settle(get_tree())
	for raised_enemy: Enemy in wave:
		game.spatial_world.teleport_source_actor(raised_enemy, raised_enemy.position, raised_enemy.radius, true)
	preview._enemy_models.sync()
	sprites.sync()
	check("all twenty marked monsters render once without twenty duplicate 3D models", sprites.entries.size() == 20 and preview._enemy_models.entries.is_empty())
	check("living waves do not load a corpse atlas in advance", bool(sprites.snapshot()["texture_loaded"]) and not bool(sprites.snapshot()["corpse_texture_loaded"]))
	var shared_mesh: Mesh
	var shared_texture: Texture2D
	var shared_shader: Shader
	var preserved := true
	for enemy: Enemy in wave:
		var entry: Dictionary = sprites.entries[enemy.get_instance_id()]
		var card: MeshInstance3D = entry["card"]
		var material: ShaderMaterial = entry["material"]
		if shared_mesh == null:
			shared_mesh = card.mesh
			shared_texture = material.get_shader_parameter("atlas_texture")
			shared_shader = material.shader
		preserved = preserved and card.mesh == shared_mesh and material.shader == shared_shader and material.get_shader_parameter("atlas_texture") == shared_texture
		preserved = preserved and card.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preserved = preserved and game.spatial_world.actor_bodies.has(enemy.get_instance_id())
		preserved = preserved and _pivot_world(entry).distance_to(preview.actor_foot(enemy)) < 0.00001 and preview.actor_foot(enemy).y > 2.99
	check("twenty actors share one image/quad/shader while retaining actual raised 3D bodies", preserved)
	check("sprite shader keeps wall depth testing and source-colour hit support", shared_mesh is QuadMesh and "depth_test_disabled" not in shared_shader.code and "flash_strength" in shared_shader.code)
	var enemy: Enemy = wave[0]
	var id := enemy.get_instance_id()
	var entry: Dictionary = sprites.entries[id]
	enemy.sprite.clear_contact_hold()
	enemy._hitstop.clear()
	enemy._state = "chase"
	enemy._walk_cycle = 0.12
	enemy.facing = PI * 0.25
	sprites.sync()
	var first: Vector2i = entry["cell"]
	enemy._walk_cycle = 0.65
	sprites.sync()
	check("actual source walking distance selects a different generated stride frame", entry["cell"] != first)
	var directions := {}
	for facing: float in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		enemy.facing = facing
		sprites.sync()
		var cell: Vector2i = entry["cell"]
		directions[cell.y] = true
	check("all four screen-diagonal directions select different authored sheet rows", directions.size() == 4)
	var cell: Vector2i = entry["cell"]
	var rect: Vector4 = (entry["material"] as ShaderMaterial).get_shader_parameter("atlas_rect")
	check("actual non-divisible atlas size uses exact fractional normalized quarters", is_equal_approx(rect.x, cell.x / 4.0) and is_equal_approx(rect.y, cell.y / 4.0) and rect.z == 0.25 and rect.w == 0.25)
	var hp := enemy.hp
	enemy.take_damage(4.0, game.player)
	sprites.sync()
	check("actual damage flashes the generated sprite without a replacement simulation", enemy.hp < hp and is_equal_approx(float((entry["material"] as ShaderMaterial).get_shader_parameter("flash_strength")), enemy.sprite.flash))
	var held_cell: Vector2i = entry["cell"]
	enemy.sprite.contact_hold = 0.04
	enemy._walk_cycle += 0.4
	enemy.facing += PI
	sprites.sync()
	check("contact hold preserves the currently displayed generated pose", entry["cell"] == held_cell)
	var source_hp := enemy.hp
	var cycle := enemy._walk_cycle
	get_tree().paused = true
	var transform: Transform3D = (entry["card"] as MeshInstance3D).global_transform
	await _frames(3)
	sprites.sync()
	check("pause keeps source clocks and 2D geometry frozen", enemy._walk_cycle == cycle and enemy.hp == source_hp and (entry["card"] as MeshInstance3D).global_transform.is_equal_approx(transform))
	get_tree().paused = false
	enemy.sprite.clear_contact_hold()
	enemy._hitstop.clear()
	enemy.sprite.modulate.a = 0.4
	sprites.sync()
	check("source death-fade alpha reaches the sprite material exactly", is_equal_approx(((entry["material"] as ShaderMaterial).get_shader_parameter("tint") as Color).a, 0.4))
	enemy.sprite.modulate.a = 1.0
	var normal := Enemy.new()
	normal.setup(game, "goblin", 1)
	normal.position = SpatialWorld3D.projected(Vector3(126, 3, 123))
	game.world.add_child(normal)
	normal.set_process(false)
	game.enemies.append(normal)
	preview._enemy_models.sync()
	sprites.sync()
	check("ordinary monsters retain their 3D backend and do not join the generated sprite wave", preview._enemy_models.entries.has(normal.get_instance_id()) and not sprites.entries.has(normal.get_instance_id()))
	enemy.take_damage(enemy.max_hp * 2.0, game.player)
	sprites.sync()
	check("real killed source retains its brief fade after leaving the live enemy list", enemy.dead and not game.enemies.has(enemy) and sprites.entries.has(id))
	var marked: Array = game.corpses.filter(func(corpse: Dictionary): return NativeEnemySprites3D.supports_corpse(corpse))
	if check("actual death carries the generated appearance into a real corpse", marked.size() == 1):
		var corpse: Dictionary = marked[0]
		var visual: Node = corpse["visual"]
		var corpse_id := visual.get_instance_id()
		corpse["time"] = 15.0
		sprites.sync()
		preview._world_environment._sync_corpses()
		var fallen: Dictionary = sprites.corpses[corpse_id]
		var fallen_card: MeshInstance3D = fallen["card"]
		check("true generated corpse atlas loads only on actual death and no 3D goblin corpse is created", bool(sprites.snapshot()["corpse_texture_loaded"]) and (fallen["material"] as ShaderMaterial).get_shader_parameter("atlas_texture") != shared_texture and not preview._world_environment._corpses.has(corpse_id))
		check("corpse artwork stays camera-facing because it already depicts an isometric collapsed body", fallen_card.global_transform.basis.y.normalized().is_equal_approx(preview.camera.global_transform.basis.y.normalized()) and _pivot_world(fallen).y > 3.0)
		Prefs.reduce_motion = true
		sprites.sync()
		check("reduced motion retains the actual corpse and generated body", fallen_card.visible and sprites.entries.has(wave[1].get_instance_id()))
		var saved_world: Node = game.world
		game.player.position = game.dungeon.entry_point()
		check("appearance scope fixture enters the real cave", game.dungeon.enter())
		sprites.sync()
		check("entering cave clears every forest wave and corpse picture", game.world != saved_world and sprites.entries.is_empty() and sprites.corpses.is_empty())
		game.dungeon.leave("")
		await Fixture.settle(get_tree())
		sprites.sync()
		check("returning observes the original live wave and source-owned corpse", game.world == saved_world and sprites.entries.size() >= 19 and sprites.corpses.has(corpse_id))
		corpse["used"] = true
		sprites.sync()
		check("consumed corpse disappears without changing its source lifetime", not (sprites.corpses[corpse_id]["card"] as MeshInstance3D).visible and float(corpse["time"]) > 0.0)
		game.remove_corpse(corpse)
		sprites.sync()
		check("source corpse removal frees its generated picture", not sprites.corpses.has(corpse_id))
	floor_body.queue_free()
	Prefs.reduce_motion = old_motion
	game.queue_free()
	await _frames(2)
