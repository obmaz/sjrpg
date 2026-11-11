class_name NativeEncounterProps3D
extends RefCounted
## Forest and cave interactables observe source identity, durability and consumed state.
## Source ancestors stay hidden adapters; no new timers, rewards or collision.

const CHEST_SHADER := preload("res://scripts/native_chest_material.gdshader")
var _preview: Node
var _game: Node
var _forest_world: Node
var _materials := {}
var _meshes := {}
var _entries := {}
var _source_ids := {}
var _chest_material: ShaderMaterial
var _chest_variants := {}
var _lid_sweep_radius := 0.0


func setup(presenter: Node, material_map: Dictionary) -> NativeEncounterProps3D:
	_preview = presenter
	_game = presenter.game
	_forest_world = _game.village.fountain.get_parent()
	_materials = material_map.duplicate()
	if not _materials.has("stone") or not _materials.has("iron"):
		return self  # A missing native family keeps individual source-art fallbacks.
	if not _materials["stone"] is StandardMaterial3D or not _materials["iron"] is StandardMaterial3D:
		return self
	if (_materials["stone"] as StandardMaterial3D).albedo_texture == null:
		return self
	_meshes = NativeEncounterMesh3D.build()
	_lid_sweep_radius = _chest_sweep_radius()
	_chest_material = ShaderMaterial.new()
	_chest_material.shader = CHEST_SHADER
	_chest_material.set_shader_parameter("surface_atlas",load("res://assets/models/materials/chests/albedo.png"))
	for kind: String in ["iron","gold"]:
		var material := _chest_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("variant",1 if kind == "iron" else 2)
		_chest_variants[kind] = material
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search", true)).contains("loot_review=1"):
		_start_review.call_deferred()
	return self


func _start_review() -> void:
	var fixture := preload("res://scripts/native_encounter_review.gd").new()
	_preview.add_child(fixture.setup(_preview, self))


func sync() -> void:
	var current := {}
	_source_ids.clear()
	if not _meshes.is_empty():
		for source in _game.encounters.stones.values():
			_sync_source(source, "stone", current)
		if _game.dungeon.active:
			for source in _game.dungeon._forest_chests:
				_sync_source(source, "chest", current)
		for source in _game.chests:
			_sync_source(source, "chest", current)
	for id in _entries.keys():
		if not current.has(id):
			(_entries[id]["root"] as Node3D).queue_free()
			_entries.erase(id)


func owns(source: Node) -> bool:
	return is_instance_valid(source) and _source_ids.has(source.get_instance_id())


func source_ids() -> Dictionary:
	return _source_ids.duplicate()


func _sync_source(source: Node2D, role: String, current: Dictionary) -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or source.get_parent() not in [_game.world, _forest_world]:
		return
	var sprite: IsoSprite = (source as EncounterStone).art if role == "stone" else (source as Chest).body_sprite
	if not is_instance_valid(sprite) or sprite.is_queued_for_deletion():
		return
	if role == "chest" and _chest_radius(source as Chest) + 0.0001 < _lid_sweep_radius:
		return  # Never replace an unsupported footprint by stretching a model.
	var id := source.get_instance_id()
	if not _entries.has(id):
		_entries[id] = _create(source, role)
	current[id] = true
	_source_ids[sprite.get_instance_id()] = true
	var entry: Dictionary = _entries[id]
	var root: Node3D = entry["root"]
	root.position = Ortho3DPreview.ground_position(source.position, _preview.surface_height(source.position))
	var in_realm: bool = source.get_parent() == _game.world
	root.visible = in_realm and source.visible and sprite.visible
	if role == "stone":
		_sync_stone(source as EncounterStone, entry)
	else:
		var chest := source as Chest
		(entry["lid"] as Node3D).rotation.x = deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE) if chest.dead else 0.0
		(entry["splinters"] as MeshInstance3D).visible = chest.dead
		entry["consumed"] = chest.dead
		if entry.has("chest_header"):
			var header: Label3D = entry["chest_header"]
			header.visible = not chest.dead
			header.text = "황금 상자" if chest.variant == "gold" else "쇠 상자 %d/%d" % [int(chest.hp),int(chest.max_hp)]


func _create(source: Node2D, role: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeEncounterStone_%s" % (source as EncounterStone).id if role == "stone" else "NativeTreasureChest_%d" % (source as Chest).index
	root.set_meta("native_interactable_source", source.get_instance_id())
	root.set_meta("native_interactable_role", role)
	_preview.stage.add_child(root)
	var entry := {"root": root, "role": role, "owner": weakref(source)}
	if role == "stone":
		var stone: StandardMaterial3D = (_materials["stone"] as StandardMaterial3D).duplicate()
		var rune := StandardMaterial3D.new()
		rune.albedo_color = Color("398779")
		rune.roughness = 0.68
		rune.emission_enabled = true
		rune.emission = Color("236d60")
		rune.emission_energy_multiplier = 0.12
		_instance(_meshes["stone"], root, {"stone": stone})
		_instance(_meshes["glyph"], root, {"iron": _materials["iron"], "rune": rune})
		var header := Label3D.new()
		header.font = UiKit.BOLD_FONT
		header.font_size = 17
		header.outline_size = 4
		header.pixel_size = 1.0 / (Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR)
		header.no_depth_test = true  # Existing status UI convention, never a prop depth override.
		header.modulate = Color("d4e3cd")
		header.position = Vector3(0, NativeEncounterMesh3D.STONE_SIZE.y + 0.26, 0)
		root.add_child(header)
		entry.merge({"stone": stone, "rune": rune, "header": header})
	else:
		var chest := source as Chest
		var ink: ShaderMaterial = _chest_variants.get(chest.variant,_chest_material)
		_instance(_meshes["base"], root, {"chest": ink})
		var lid := Node3D.new()
		lid.name = "ObservedConsumedLid"
		lid.position = NativeEncounterMesh3D.LID_PIVOT
		root.add_child(lid)
		_instance(_meshes["lid"], lid, {"chest": ink})
		var splinters := _instance(_meshes["splinters"], root, {"chest": ink})
		entry.merge({"lid": lid, "splinters": splinters, "consumed": false})
		if chest.variant != "wood":
			var header := Label3D.new()
			header.font = UiKit.BOLD_FONT
			header.font_size = 18
			header.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			header.pixel_size = 0.012
			header.position.y = NativeEncounterMesh3D.CHEST_COLLISION_HEIGHT+0.20
			header.modulate = Color("e4c16b") if chest.variant == "gold" else Color("c4ced5")
			root.add_child(header)
			entry["chest_header"] = header
	return entry


func _instance(mesh: ArrayMesh, parent: Node3D, material_map: Dictionary) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	for surface in mesh.get_surface_count():
		node.set_surface_override_material(surface, material_map[mesh.surface_get_name(surface)])
	parent.add_child(node)
	return node


func _sync_stone(stone: EncounterStone, entry: Dictionary) -> void:
	var tint := stone.art.modulate_color * stone.art.modulate * stone.art.self_modulate
	var base: StandardMaterial3D = _materials["stone"]
	(entry["stone"] as StandardMaterial3D).albedo_color = base.albedo_color * tint
	var ready: bool = stone.runtime.can_summon(stone.id)
	var rune: StandardMaterial3D = entry["rune"]
	rune.albedo_color = Color("398779") * tint
	rune.emission_energy_multiplier = 0.12 if ready else 0.015
	var state: Dictionary = stone.runtime.states[stone.id]
	var living: int = stone.runtime.living(stone.id)
	var header: Label3D = entry["header"]
	header.global_basis = _preview.camera.global_basis
	header.visible = stone.position.distance_squared_to(_game.player.position) < 240.0 * 240.0
	header.text = status_text(state, living, stone.id)
	entry["observed_charges"] = int(state["charges"])
	entry["observed_flash"] = stone._flash


static func status_text(state: Dictionary, living: int, site_id := "") -> String:
	if site_id == EncounterRuntime.CAVE_SITE:
		return "동굴 잠복자 · %d" % living if living > 0 else "공격해 소환 · 20마리"
	if living > 0:
		return "주변의 적 · %d" % living
	if int(state["charges"]) == 0:
		return "충전까지 %d초" % ceili(EncounterRuntime.RECHARGE_SECONDS - float(state["recharge"]))
	return "공격해 재소환 · %d/3" % int(state["charges"])


func _chest_radius(source: Chest) -> float:
	if _game.dungeon.active and source.get_parent() == _game.world:
		return SpatialWorld3D.radius_metres(Chest.COLLISION_RADIUS)
	for circle: Array in _game.village.circles:
		var point: Vector2 = circle[0]
		if point.distance_squared_to(source.position) < 1.0:
			return SpatialWorld3D.radius_metres(float(circle[1]))
	return 0.0


func _chest_sweep_radius() -> float:
	# Bound actual geometry continuously: z(theta)=y*sin(theta)+z*cos(theta).
	# Its extrema are endpoints and atan2(y,z)+k*PI, never just a few frames.
	var radius := 0.0
	for key in ["base", "splinters"]:
		var fixed: ArrayMesh = _meshes[key]
		for surface in fixed.get_surface_count():
			var vertices: PackedVector3Array = fixed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				radius = maxf(radius, Vector2(vertex.x, vertex.z).length())
	var lid: ArrayMesh = _meshes["lid"]
	var opening := deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE)
	for surface in lid.get_surface_count():
		var vertices: PackedVector3Array = lid.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var stationary := atan2(vertex.y, vertex.z)
			for angle: float in [0.0, opening, stationary, stationary - PI, stationary + PI]:
				if angle < opening or angle > 0.0:
					continue
				var pose := Transform3D(Basis(Vector3.RIGHT, angle), NativeEncounterMesh3D.LID_PIVOT)
				var point := pose * vertex
				radius = maxf(radius, Vector2(point.x, point.z).length())
	return radius
