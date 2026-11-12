extends Node
## Explicit ?loot_review=1 only. Same real sources/materials; no production rules change.
## Model rotation is a full-face asset inspection, not a camera/projection change.
var _renderer: WorldRenderer3D
var _props: EncounterPropRenderer3D
var _game: Node
var _callback: JavaScriptObject
var _role := "stone"
var _stone_id := "west"
var _rotation := 0.0
var _baseline := false
var _cards := {}


func setup(presenter: WorldRenderer3D, props: EncounterPropRenderer3D) -> Node:
	_renderer = presenter
	_props = props
	_game = presenter.game
	process_priority = 1000
	return self


func _ready() -> void:
	while not _game.native_ready:
		await get_tree().physics_frame
	_game.set_process(false)
	_game.player.set_process(false)
	_game.encounters.set_process(false)
	_game.quest_runtime.set_process(false)
	_game.exploration.set_process(false)
	DirAccess.make_dir_recursive_absolute("/userfs/sjrpg_3d/reviews")
	var source_encounters: Dictionary = _game.encounters.states
	var selected_class: String = GameState.hero_class
	GameState.save_path = "/userfs/sjrpg_3d/reviews/native-loot-%d.json" % Time.get_ticks_usec()
	# A fresh isolated browser profile starts a proper review slot. Its initial
	# source encounter owners already exist; retain that dictionary/capture.
	if not GameState.create_slot(1, selected_class):
		push_error("Cannot create the isolated native-loot review slot")
		return
	GameState.encounters = source_encounters
	GameState.encounter_capture = _game.encounters.capture
	if not GameState.save_game():
		push_error("Cannot save the isolated native-loot review slot")
		return
	Prefs.sound_enabled = false
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	for id in _game.encounters._members:
		_game.encounters._members[id] = []
	for stone in _game.encounters.stones.values():
		stone.set_process(false)
	_callback = JavaScriptBridge.create_callback(_action)
	var window := JavaScriptBridge.get_interface("window")
	window.__sjrpgLootAction = _callback
	_focus()
	JavaScriptBridge.eval("window.__sjrpgLootReviewReady = true")


func _action(args: Array) -> void:
	var command := str(args[0])
	if command == "cave":
		if not _game.dungeon.active:
			Quests.state("sun")["started"] = false
			_game.spatial_world.teleport_source_actor(_game.player, _game.dungeon.entry_point(), Player.RADIUS)
			_game.dungeon.enter()
		_game.camera.position = _game.player.position
		_game.camera.reset_smoothing()
		return
	if _game.dungeon.active:
		_game.dungeon.leave("")
	if command == "site" and _game.encounters.stones.has(str(args[1])):
		_stone_id = str(args[1])
		_role = "stone"
		_rotation = 0.0
		_baseline = false
	elif command in ["stone", "chest"]:
		_role = command
		_rotation = deg_to_rad(float(args[1])) if args.size() > 1 else 0.0
		_baseline = bool(args[2]) if args.size() > 2 else false
	elif command == "open":
		(_game.chests[0] as Chest).take_damage(1.0, _game.player)
	elif command == "empty":
		for enemy in _game.enemies:
			enemy.queue_free()
		_game.enemies.clear()
		for id in _game.encounters._members:
			_game.encounters._members[id] = []
		var state: Dictionary = _game.encounters.states[_stone_id]
		state["charges"] = 0
		state["recharge"] = 298.2
		(_game.encounters.stones[_stone_id] as EncounterStone)._process(0.0)
	elif command == "ready":
		var state: Dictionary = _game.encounters.states[_stone_id]
		state["initial_spawned"] = true
		state["charges"] = 3
		state["recharge"] = 0.0
		(_game.encounters.stones[_stone_id] as EncounterStone)._process(0.0)
	elif command == "hit":
		var stone: EncounterStone = _game.encounters.stones[_stone_id]
		stone.take_damage(1.0, _game.player)
		stone._process(0.03)  # Hold the real source response for slow GPU screenshot readback.
		for enemy in _game.enemies:
			enemy.set_process(false)
			enemy.sprite.set_process(false)
	_focus()


func _focus() -> void:
	var source: Node2D = _game.encounters.stones[_stone_id] if _role == "stone" else _game.chests[0]
	var approach := source.position + Vector2(70, 85)
	_game.spatial_world.teleport_source_actor(_game.player, approach, Player.RADIUS)
	_game._fx_review_focus = source.position + Vector2(0, -42)
	_game.camera.position = _game._fx_review_focus
	_game.camera.reset_smoothing()
	_game.hud._toast_queue.clear()
	_game.hud._toast_time = 0.0
	_game.hud._toast_plaque.hide()
	_renderer._sync_camera()


func _process(_delta: float) -> void:
	if not _game.native_ready:
		return
	var target: Node2D = _game.encounters.stones[_stone_id] if _role == "stone" else _game.chests[0]
	var target_id := target.get_instance_id()
	for id in _props._entries:
		var entry: Dictionary = _props._entries[id]
		var root: Node3D = entry["root"]
		root.rotation.y = _rotation if id == target_id else 0.0
		if _baseline:
			root.visible = false
	_sync_baseline()
	var stone: EncounterStone = _game.encounters.stones[_stone_id]
	var header: Label3D = _props._entries[stone.get_instance_id()]["header"]
	JavaScriptBridge.eval("window.__sjrpgLootReview = " + JSON.stringify({"role": _role, "stone_site": _stone_id, "rotation_degrees": rad_to_deg(_rotation), "baseline": _baseline, "realm": "cave" if _game.dungeon.active else "forest", "entries": _props._entries.size(), "visible_models": _visible_models(), "source_ids": _props.source_ids().keys(), "stone_triangles": _props._meshes["stone_triangles"], "chest_triangles": _props._meshes["chest_triangles"], "sweep_radius": _props._lid_sweep_radius, "status": header.text, "save_error": GameState.save_error}))


func _visible_models() -> int:
	var count := 0
	for entry: Dictionary in _props._entries.values():
		if (entry["root"] as Node3D).is_visible_in_tree():
			count += 1
	return count


func _sync_baseline() -> void:
	var current := {}
	for entry: Dictionary in _props._entries.values():
		var source: Node2D = (entry["owner"] as WeakRef).get_ref()
		if source == null:
			continue
		var sprite: IsoSprite = (source as EncounterStone).art if source is EncounterStone else (source as Chest).body_sprite
		var id := sprite.get_instance_id()
		current[id] = true
		if not _cards.has(id):
			var card := _renderer._new_card(sprite.texture, Rect2(Vector2.ZERO, sprite.texture.get_size()), false)
			var geometry := _renderer._sprite_fallbacks._sprite_geometry(sprite)
			card.mesh = geometry["mesh"]
			_cards[id] = {"card": card, "vertices": geometry["vertices"]}
			if source is EncounterStone:
				var header := (entry["header"] as Label3D).duplicate() as Label3D
				_renderer.stage.add_child(header)
				_cards[id]["header"] = header
		var card: MeshInstance3D = _cards[id]["card"]
		card.basis = _renderer.camera.global_basis
		var minimum := 0.0
		for vertex: Vector3 in _cards[id]["vertices"]:
			minimum = minf(minimum, (card.basis * vertex).y)
		card.position = WorldSpace3D.projected_to_world(sprite.global_position, _renderer.surface_height(sprite.global_position)) + card.basis.z * (-minimum / card.basis.z.y + 0.018)
		(card.material_override as ShaderMaterial).set_shader_parameter("tint", sprite.modulate_color * sprite.modulate * sprite.self_modulate)
		card.visible = _baseline and not _game.dungeon.active and source.visible and sprite.visible
		if _cards[id].has("header"):
			var original: Label3D = entry["header"]
			var header: Label3D = _cards[id]["header"]
			header.global_transform = original.global_transform
			header.text = original.text
			header.visible = card.visible and original.visible
	for id in _cards.keys():
		if not current.has(id):
			(_cards[id]["card"] as MeshInstance3D).queue_free()
			if _cards[id].has("header"):
				(_cards[id]["header"] as Label3D).queue_free()
			_cards.erase(id)


func _exit_tree() -> void:
	for entry: Dictionary in _cards.values():
		if is_instance_valid(entry["card"]):
			(entry["card"] as MeshInstance3D).queue_free()
		if entry.has("header") and is_instance_valid(entry["header"]):
			(entry["header"] as Label3D).queue_free()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgLootReviewReady = false; window.__sjrpgLootAction = null; window.__sjrpgLootReview = null")
