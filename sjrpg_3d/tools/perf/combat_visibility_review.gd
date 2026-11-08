extends Node
## CI-ONLY EXPLICIT VISUAL FIXTURES, not ordinary gameplay or performance evidence.
## The same source is injected into disposable baseline and candidate exports.
var _screen: Node
var _callback: Variant
var _busy := false
var _scenario := ""
var _proof := {}
var _serial := 0
const SCENARIOS := ["cave_torches", "combat_health", "boss_warning", "meteor_warning", "firewall", "cave_swarm", "sprite_directions", "sprite_corpses"]


func setup(screen: Node) -> Node:
	_screen = screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	return self


func _ready() -> void:
	_callback = JavaScriptBridge.create_callback(_command)
	var window: Variant = JavaScriptBridge.get_interface("window")
	window.__sjrpgCombatVisibilityCommand = _callback
	_publish(false)


func _game() -> Node:
	if is_instance_valid(_screen.current) and _screen.current is NativeAdventure:
		return _screen.current.simulation
	return null


func _command(args: Array) -> void:
	if args.is_empty():
		return
	var requested := str(args[0])
	if requested == "snapshot":
		_publish(not _busy and not _scenario.is_empty())
		return
	if _busy or requested not in SCENARIOS:
		return
	_serial += 1
	_scenario = requested
	_busy = true
	_proof = {"fixture": true, "performance_evidence": false, "scenario": requested,
		"mutation_policy": "explicit source enemies/HP/ages and camera framing; cave swarm must use a real basic attack"}
	_publish(false)
	_prepare.call_deferred(requested)


func _draws(count: int) -> bool:
	var started: int = Engine.get_frames_drawn()
	var deadline: int = Time.get_ticks_msec() + 25000
	while Engine.get_frames_drawn() < started + count:
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true


func _halt(game: Node) -> void:
	game.set_process(false)
	game.player.set_process(false)
	game.player.sprite.set_process(false)
	game.encounters.set_process(false)
	game.exploration.set_process(false)
	game.quest_runtime.set_process(false)
	game.hud.controls.release_all()
	game.player.move_input = Vector2.ZERO
	game.player.held_slots.clear()
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
		enemy.sprite.set_process(false)
	for node in game.world.get_children():
		if node is Effect:
			node.set_process(false)


func _clear(game: Node) -> void:
	for enemy: Enemy in game.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	game.enemies.clear()
	for node in game.world.get_children():
		if node is Effect:
			node.queue_free()


func _field_center(game: Node) -> Vector2:
	var desired: Vector2 = game.dungeon.entry_point() + Vector2(0, 470)
	for index in 65:
		var at: Vector2 = desired if index == 0 else desired + Vector2.from_angle((index - 1) * 2.399963) * (80.0 + index * 4.0)
		if game._inside_field(at, 180.0) and not game.in_town(at) and not game._blocked(at, 80.0):
			return at
	return desired


func _teleport(game: Node, at: Vector2) -> void:
	game.spatial_world.teleport_source_actor(game.player, at, Player.RADIUS)
	game.player._cancel_actions()
	game.player.sprite.clear_contact_hold()
	game.player._hitstop.clear()


func _enemy(game: Node, kind: String, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, kind, 1)
	enemy.position = at
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	enemy.sprite.set_process(false)
	enemy.facing = 0.6
	return enemy


func _prepare(requested: String) -> void:
	var game: Node = _game()
	if game == null or not bool(game.get("native_ready")):
		_fail("a normally started native adventure is required")
		return
	get_tree().paused = false
	if game.hud.panel_open():
		game.hud.close_panel()
	if game.dungeon.active:
		game.dungeon.leave("")
	_halt(game)
	_clear(game)
	await get_tree().physics_frame
	await get_tree().process_frame
	var center := _field_center(game)
	_teleport(game, center + Vector2(-140, 90))
	var focus: Vector2 = center + Vector2(0, -45)
	match requested:
		"cave_torches":
			_teleport(game, game.dungeon.entry_point())
			if not game.dungeon.enter():
				_fail("the real cave entrance rejected the visual fixture")
				return
			_halt(game)
			_clear(game)
			var at := Iso.project(Vector2(650, 0))
			_teleport(game, at)
			focus = Iso.project(Vector2(480, 0)) + Vector2(0, -30)
			_proof["actual_cave_enter"] = true
			_proof["authored_room"] = 0
		"combat_health":
			var targets := []
			for index in 3:
				var enemy := _enemy(game, ["goblin", "wolf", "skeleton"][index], center + Vector2((index - 1) * 96, (index % 2) * -26))
				enemy.hp = enemy.max_hp * 0.58
				enemy.ghost_hp = enemy.max_hp * 0.84
				enemy._ghost_hold = 1.0
				targets.append({"kind": enemy.kind, "hp": enemy.hp, "max_hp": enemy.max_hp, "ghost_hp": enemy.ghost_hp})
			_proof["configured_targets"] = targets
		"boss_warning":
			var boss := _enemy(game, "golem", center)
			boss.make_boss()
			boss._state = "windup"
			boss._timer = boss._windup_duration * 0.45
			boss.hp = boss.max_hp * 0.82
			boss.ghost_hp = boss.max_hp * 0.94
			boss._ghost_hold = 1.0
			_proof["boss"] = {"state": boss._state, "timer": boss._timer, "windup": boss._windup_duration, "range": boss.attack_range}
		"meteor_warning":
			game.spawn_zone({"pos": center, "radius": 110.0, "duration": 3.0, "tick": 0.3, "damage": 1.0, "color": SkillDefs.FIRE, "delay": 1.0, "visual": "meteor"})
			for node in game.world.get_children():
				if node is Effect and node.kind == "zone":
					node.set_process(false)
					node.age = 0.55
			_proof["zone"] = {"kind": "meteor", "delay": 1.0, "age": 0.55, "radius": 110.0}
		"firewall":
			game.spawn_zone({"pos": center, "radius": 115.0, "duration": 4.0, "tick": 0.25, "damage": 1.0, "color": SkillDefs.FIRE, "wall": -PI / 6.0})
			for node in game.world.get_children():
				if node is Effect and node.kind == "zone":
					node.set_process(false)
					node.age = 0.75
			_proof["zone"] = {"kind": "firewall", "age": 0.75, "radius": 115.0, "wall": -PI / 6.0}
		"sprite_directions", "sprite_corpses":
			var records := []
			for index in 4:
				var offset := Vector2(-90.0 if index % 2 == 0 else 90.0, -55.0 if index < 2 else 105.0)
				var target := _enemy(game, "goblin", center + offset + Vector2(-140, 0))
				target.set_meta("visual_variant", "cave_crawler")
				target.display_name = "동굴 잠복자"
				target.facing = PI * 0.25 + index * PI * 0.5
				target._state = "chase"
				target._walk_cycle = 0.25
				target.xp_reward = 0
				records.append({"direction": index, "facing": target.facing, "position": [target.position.x, target.position.y]})
				if requested == "sprite_corpses":
					target.take_damage(target.max_hp * 3.0, game.player)
			for node in game.world.get_children():
				if node is Effect:
					node.queue_free()
			if requested == "sprite_corpses":
				# Inspect after the genuine source crossfade, not its alpha-zero start.
				for corpse: Dictionary in game.corpses:
					corpse["time"] = maxf(0.0, float(corpse["lifetime"]) - 0.5)
				_proof["corpse_age_seconds"] = 0.5
			_proof["configured_sprite_directions"] = records
			_proof["actual_source_deaths"] = 4 if requested == "sprite_corpses" else 0
		"cave_swarm":
			var site := "cave_swarm"
			if not game.encounters.stones.has(site):
				_proof["available"] = false
				focus = game.dungeon.entry_point() + Vector2(210, -265)
			else:
				var stone: EncounterStone = game.encounters.stones[site]
				var approach := Vector2.INF
				for distance: float in [60.0, 90.0, 120.0]:
					for index in 32:
						var at: Vector2 = stone.position + Vector2.from_angle(index * TAU / 32.0) * distance
						if not game.in_town(at) and not game._blocked(at, Player.RADIUS) and game.encounters.clear_line(at, stone.position):
							approach = at
							break
					if approach.is_finite():
						break
				if not approach.is_finite():
					_fail("no real supported attack approach to cave marker")
					return
				_teleport(game, approach)
				game.player.facing = (game.player.position - stone.position).angle()
				game.player.cooldowns.clear()
				game.player.resource = game.player.resource_max
				var accepted: bool = game.player.cast_slot(0)
				if accepted:
					game.player._process(game.player._attack_duration * 0.46)
				_halt(game)
				var living: int = game.encounters.living(site)
				_proof["available"] = true
				_proof["actual_basic_attack"] = accepted
				_proof["living"] = living
				_proof["stone"] = [stone.position.x, stone.position.y]
				if not accepted or living != 20:
					_fail("real cave-stone attack did not create the full twenty-pack")
					return
				focus = stone.position + Vector2(0, -65)
	_halt(game)
	game._impact_offset = Vector2.ZERO
	game.camera.offset = Vector2.ZERO
	game._fx_review_focus = focus
	game.camera.position_smoothing_enabled = false
	game.camera.position = focus
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.hud._toast_plaque.hide()
	game.hud._update_layout()
	game.hud.controls._layout()
	var presenter: Node = game.ortho_preview
	presenter._world_environment._clock = 0.67
	presenter.request_redraw()
	presenter._process(0.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	get_tree().paused = true
	presenter.request_redraw()
	presenter._process(0.0)
	if not await _draws(2):
		_fail("two actual post-fixture draw frames did not complete")
		return
	presenter._publish_probe()
	_busy = false
	_publish(true)


func _fail(message: String) -> void:
	_busy = false
	_proof["error"] = message
	_publish(false)
	push_error("COMBAT_VISIBILITY_FIXTURE " + message)


func _publish(ready: bool) -> void:
	var result := {"ready": ready, "busy": _busy, "serial": _serial, "scenario": _scenario,
		"fixture": true, "performance_evidence": false, "proof": _proof,
		"frames_drawn": Engine.get_frames_drawn()}
	var game: Node = _game()
	if game != null and bool(game.get("native_ready")):
		var presenter: Node = game.ortho_preview
		result["hero"] = GameState.hero_class
		result["paused"] = get_tree().paused
		result["scope"] = "cave" if game.dungeon.active else "forest"
		result["player"] = [game.player.position.x, game.player.position.y]
		result["camera_focus"] = [game.camera.position.x, game.camera.position.y]
		result["native_size"] = [presenter.viewport.size.x, presenter.viewport.size.y]
		result["camera_size"] = presenter.camera.size
		result["enemy_count"] = game.enemies.filter(func(enemy): return is_instance_valid(enemy) and not enemy.dead).size()
		var feedback: Variant = presenter.get("_enemy_feedback")
		if is_instance_valid(feedback):
			result["enemy_feedback"] = feedback.snapshot()
		var zones: Variant = presenter.get("_zone_fx")
		if is_instance_valid(zones):
			result["native_zones"] = zones.snapshot()
		var sprites: Variant = presenter.get("_enemy_sprites")
		if is_instance_valid(sprites):
			result["enemy_sprites"] = sprites.snapshot()
			var visible_corpses := 0
			for entry: Dictionary in sprites.corpses.values():
				var card: MeshInstance3D = entry["card"]
				var tint: Color = entry["uniforms"].get("tint", Color.TRANSPARENT)
				if card.is_visible_in_tree() and tint.a > 0.1:
					visible_corpses += 1
			result["visible_sprite_corpses"] = visible_corpses
		var environment: Variant = presenter.get("_world_environment")
		if is_instance_valid(environment):
			result["cave_lights"] = environment._cave_lights.size()
	JavaScriptBridge.eval("window.__sjrpgCombatVisibility = " + JSON.stringify(result), true)
