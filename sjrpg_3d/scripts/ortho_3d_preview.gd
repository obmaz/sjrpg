class_name Ortho3DPreview
extends Node
## Stage-one native3D presentation. Source gameplay/HUD are adapters; the spatial
## world owns resolved actor feet and terrain height throughout forest and cave.

const GROUND_PER_METER := 65.0
const MAX_RENDER_EDGE := 1920.0
const MAX_RENDER_PIXELS := 1536000.0
const PROJECTION_FACTOR := 1.224744871391589 * Iso.S
const CAMERA_DIRECTION := Vector3(1, 1, 1)
const MAGE_PATH := "res://assets/art/preview3d/mage.glb"
const MATERIAL_ROOT := "res://assets/art/preview3d/"
const CARD_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 next_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float frame_blend = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_strength = 0.0;
void fragment() {
	vec4 first = texture(atlas_texture, atlas_rect.xy + UV * atlas_rect.zw);
	vec4 second = texture(atlas_texture, next_rect.xy + UV * next_rect.zw);
	float alpha = mix(first.a, second.a, frame_blend);
	vec3 rgb = mix(first.rgb * first.a, second.rgb * second.a, frame_blend) / max(alpha, 0.00001);
	vec4 ink = vec4(rgb, alpha);
	ALBEDO = mix(ink.rgb * tint.rgb, flash_color.rgb, clamp(flash_strength, 0.0, 0.65));
	ALPHA = ink.a * tint.a;
}
"""
const ACTOR_FLASH_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_strength = 0.0;
void fragment() { ALBEDO = flash_color.rgb; ALPHA = flash_strength; }
"""
static var _card_shader: Shader
static var _add_shader: Shader
static var _actor_flash_shader: Shader

var game: Node2D
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var sunlight: DirectionalLight3D
var contact_light: OmniLight3D
var actor: Node3D
var animation: AnimationPlayer
var display: TextureRect
var _layer: CanvasLayer
var _materials := {}
var _encounter_props: NativeEncounterProps3D
var _cards := {}
var _native_residents: NativeResidents3D
var _enemy_models: NativeEnemyModels
var _seen_impacts := {}
var _contact_time := 0.0
var _contact_energy := 0.0
var _probe_clock := 0.0
var _ready_published := false
var _labels := {}
var _native_mage := false
var _contact_fresh := false
var _actor_meshes: Array[MeshInstance3D] = []
var _actor_flash: ShaderMaterial
var _native_visible := true
var _town_props: NativeTownProps3D
var _affordances: Ortho3DAffordances
var _was_paused := false
var _static_batch := {}
var _batch_gpu_error := -1.0
var enabled := true
var _hero_motion: Ortho3DHeroMotion
var _level_up_fx: Ortho3DLevelUp
var _combat_fx: NativeCombatFx3D
var _trees: Node3D
var _fortification: Ortho3DFortification
var _houses := {}
var _forest_stage: Node3D
var _world_environment: Ortho3DEnvironment
var _scope_is_cave := false
var _presentation_dirty := true
var _full_syncs := 0
var _paused_skips := 0
var _paused_nodes: Array[Dictionary] = []
var _paused_corpses: Array = []
var _paused_children := -1
var _paused_enemies := -1
var _paused_focus := Vector2(INF, INF)
var _paused_scope := false
var _paused_reduced := false


func setup(world_game: Node2D) -> Ortho3DPreview:
	game = world_game
	return self


## This conversion is the inverse of the real game's ground projection, not an eyeballed camera.
static func ground_position(point: Vector2, height := 0.0) -> Vector3:
	var flat := Iso.unproject(point) / GROUND_PER_METER
	return Vector3(flat.x, height, flat.y)


static func pixels_per_meter(camera_zoom: float) -> float:
	return GROUND_PER_METER * PROJECTION_FACTOR * camera_zoom


## A source point may already include a projected chest height. Undo it before placing a real3D light.
static func spatial_position(point: Vector2, height: float) -> Vector3:
	return ground_position(point + Vector2(0, height * GROUND_PER_METER * Iso.S), height)


func _ready() -> void:
	# Presentation must catch the final source frame when a menu/review pauses
	# the simulation. Its own animation/light clocks remain frozen below.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpg3dReady = false; window.__sjrpg3dProbe = null")
	game.set_forest_rendered(false)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(1024, true)
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	_layer = CanvasLayer.new()
	# Above the original economy viewport's canvas0, below the unchanged HUD layer10.
	_layer.layer = 1
	add_child(_layer)
	display = TextureRect.new()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_layer.add_child(display)
	_setup_light()
	_setup_materials()
	_town_props = NativeTownProps3D.new().setup(self, _materials)
	_town_props.sync()
	_encounter_props = NativeEncounterProps3D.new().setup(self, _materials)
	_encounter_props.sync()
	var permanent := stage.get_children()
	_build_ground()
	_build_village()
	_trees = Ortho3DTrees.build(self)
	_static_batch = Ortho3DStaticBatch.apply(stage)
	_forest_stage = Node3D.new()
	_forest_stage.name = "NativeForest"
	stage.add_child(_forest_stage)
	for child in stage.get_children():
		if child != _forest_stage and not permanent.has(child):
			child.reparent(_forest_stage, true)
	_load_actor()
	_build_residents()
	_affordances = Ortho3DAffordances.new().setup(self)
	_level_up_fx = Ortho3DLevelUp.new().setup(self)
	_combat_fx = NativeCombatFx3D.new().setup(self)
	_enemy_models = NativeEnemyModels.new().setup(self)
	game.get_viewport().size_changed.connect(_resize)
	Prefs.graphics_changed.connect(_resize)
	_resize()
	_sync_camera()
	_world_environment = Ortho3DEnvironment.new().setup(self, _forest_stage)
	_affordances.sync()


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpg3dReady = false; window.__sjrpg3dProbe = null")


func _resize() -> void:
	if not is_instance_valid(viewport):
		return
	var native: Vector2 = game.get_viewport().get_visible_rect().size
	display.size = native
	viewport.size = render_size(native, Prefs.low_resolution)
	request_redraw()
	viewport.msaa_3d = Viewport.MSAA_DISABLED if Prefs.low_resolution else Viewport.MSAA_2X
	if camera != null:
		_sync_camera()
		# Container layout can settle after the signal; deferred calls also run while settings pause simulation.
		_sync_camera.call_deferred()
		request_redraw.call_deferred()


func _setup_light() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("17231d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.57, 0.68, 0.77)
	settings.ambient_light_energy = 0.43
	environment.environment = settings
	stage.add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.light_color = Color(1.0, 0.89, 0.73)
	sunlight.light_energy = 1.6
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# Perspective fallback range; orthographic shadows use the camera clipping range.
	sunlight.directional_shadow_max_distance = 90.0
	sunlight.shadow_bias = 0.04
	sunlight.shadow_normal_bias = 0.6
	stage.add_child(sunlight)
	var projected := Iso.unproject(Vector2(0.72, 0.48)).normalized()
	var ray := Vector3(projected.x, -tan(deg_to_rad(47.0)), projected.y)
	sunlight.look_at(ray, Vector3.UP)
	# Soft reflected daylight keeps the door and carved front stone readable.
	# Only the main sun casts a shadow, so contact direction remains unambiguous.
	var bounce := DirectionalLight3D.new()
	bounce.name = "WarmDaylightBounce"
	bounce.light_color = Color(1.0, 0.94, 0.82)
	bounce.light_energy = 0.38
	bounce.shadow_enabled = false
	stage.add_child(bounce)
	bounce.look_at(-CAMERA_DIRECTION, Vector3.UP)
	contact_light = OmniLight3D.new()
	contact_light.omni_range = 3.0
	contact_light.omni_attenuation = 1.4
	contact_light.shadow_enabled = false
	contact_light.visible = false
	stage.add_child(contact_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	# Keep the single shadow map concentrated on the local village instead of a
	# 200m-deep frustum. The focus is sqrt(3) * 30m from this orthographic eye.
	camera.far = 90.0
	stage.add_child(camera)
	camera.make_current()


func _material(path: String, tint := Color.WHITE, repeats := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	if not path.is_empty():
		material.albedo_texture = load(path)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3.ONE * repeats
	return material


func _setup_materials() -> void:
	_materials["stone"] = _material(MATERIAL_ROOT + "limestone.webp")
	_materials["stone"].uv1_triplanar = true
	_materials["stone"].uv1_world_triplanar = true
	# Eight 32cm courses per generated tile; the same world scale crosses every
	# gate, wall, corner and building instead of stretching a cropped stone sample.
	_materials["stone"].uv1_scale = Vector3.ONE / 2.56
	_materials["slate"] = _material(MATERIAL_ROOT + "slate.webp")
	_materials["slate"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["wood"] = _material(MATERIAL_ROOT + "timber.webp")
	_materials["wood"].uv1_triplanar = true
	_materials["wood"].uv1_scale = Vector3.ONE * 0.65
	_materials["door"] = _material(MATERIAL_ROOT + "timber.webp")
	_materials["grass"] = _material("res://assets/art/forest/grass.webp", ForestArt.GRASS_TINT, 38.0)
	_materials["paving"] = _material("res://assets/art/forest/paving.webp")
	_materials["iron"] = _material("", Color("292b29"))
	_materials["glass"] = _material("", Color("182b36"))
	# Residential panes catch the shared light; they are not a blue emissive sign.
	# Chapel stained glass uses its separate existing material in Ortho3DChapel.
	_materials["glass"].roughness = 0.46


func _mesh(mesh: Mesh, material: Material, position: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	(parent if parent != null else stage).add_child(instance)
	instance.position = position
	return instance


func _box(position: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(shape, material, position, parent)


## Plane X follows the roof slope; material rows must cross it along the ridge.
static func roof_mesh(size: Vector2) -> ArrayMesh:
	var plane := PlaneMesh.new()
	plane.size = size
	var arrays := plane.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in uv.size():
		uv[index] = Vector2(uv[index].y, uv[index].x)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_ground() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(150, 150)
	_mesh(floor_mesh, _materials["grass"], Vector3.ZERO)
	for polygon: PackedVector2Array in game.village.map_roads:
		var points := PackedVector2Array()
		for point in polygon:
			points.append(Iso.unproject(point) / GROUND_PER_METER)
		var indices := Geometry2D.triangulate_polygon(points)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for point in points:
			vertices.append(Vector3(point.x, 0.012, point.y))
			normals.append(Vector3.UP)
			uvs.append(point / (180.0 / GROUND_PER_METER))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var road := ArrayMesh.new()
		road.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := (_materials["paving"] as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(road, material, Vector3.ZERO)


func _building_bounds(key: String) -> Rect2:
	var sprite: IsoSprite = game.village.buildings[key]
	var frame: Dictionary = game.village.data["frames"][key]
	var points := sprite.atlas_polygon(frame["ground"])
	var flat := PackedVector2Array()
	for point in points:
		flat.append(Iso.unproject(point) / GROUND_PER_METER)
	return Iso.poly_bounds(flat)


func _build_village() -> void:
	for key: String in game.village.buildings:
		_build_house(key)
	_fortification = Ortho3DFortification.build(self)


func _build_house(key: String) -> void:
	var bounds := _building_bounds(key)
	var center := bounds.get_center()
	var width := maxf(3.5, bounds.size.x)
	var depth := maxf(3.0, bounds.size.y)
	var chapel := key == "chapel"
	var height := 3.5 if chapel else 2.9
	var root := Node3D.new()
	stage.add_child(root)
	root.position = Vector3(center.x, 0, center.y)
	if chapel:
		Ortho3DChapel.build(self, root, width, depth, height)
		return
	_houses[key] = NativeHouse3D.build(self, root, key, width, depth, height)

func _build_residents() -> void:
	_native_residents = NativeResidents3D.new().setup(self)

func _load_actor() -> void:
	_native_mage = GameState.hero_class == "mage"
	if not _native_mage:
		actor = NativeWarrior3D.new().build()
		stage.add_child(actor)
		return
	if not ResourceLoader.exists(MAGE_PATH):
		push_warning("3D comparison awaits its verified skeletal mage asset")
		return
	var scene := load(MAGE_PATH) as PackedScene
	actor = scene.instantiate() as Node3D
	stage.add_child(actor)
	# Preserve the verified imported skeletal transform. Runtime down-scaling
	# currently loses the model in Compatibility; final proportion needs an
	# offline rig/mesh bake instead of changing this root's scale.
	for child in actor.find_children("*", "MeshInstance3D", true, false):
		_actor_meshes.append(child as MeshInstance3D)
	if _actor_flash_shader == null:
		_actor_flash_shader = Shader.new()
		_actor_flash_shader.code = ACTOR_FLASH_CODE
	_actor_flash = ShaderMaterial.new()
	_actor_flash.shader = _actor_flash_shader
	animation = _find_animation(actor)
	if animation != null:
		_hero_motion = Ortho3DHeroMotion.new().setup(animation, actor)


func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation(child)
		if found != null:
			return found
	return null


func _sync_camera() -> void:
	var focus_point: Vector2 = game.camera.get_screen_center_position()
	var focus := ground_position(focus_point, surface_height(game.player.position))
	camera.position = focus + CAMERA_DIRECTION * 30.0
	camera.look_at(focus, Vector3.UP)
	# Read the actual2D rendering viewport/zoom; low-quality's half-size cancels its half zoom.
	var source_view: Vector2 = game.scene_view.get_visible_rect().size
	camera.size = source_view.y / pixels_per_meter(game.camera.zoom.y)
	# Orthographic directional shadows ignore max_distance and cover the entire
	# camera depth slab. Fit visible flat ground plus up to11.5m architecture so
	# the1024 map resolves feet without clipping tall roofs at minimum zoom.
	var focus_depth := CAMERA_DIRECTION.length() * 30.0
	var ground_depth := camera.size * 0.5 * sqrt(2.0)
	camera.near = maxf(0.05, focus_depth - ground_depth - 20.0)
	camera.far = focus_depth + ground_depth + 4.0


func _process(delta: float) -> void:
	if not _sync_scope():
		return
	var frozen := get_tree().paused
	if frozen and _was_paused and not _presentation_dirty and _frozen_sources_match():
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_paused_skips += 1
		_tick_probe(delta)
		return
	_full_syncs += 1
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if frozen else SubViewport.UPDATE_ALWAYS
	_sync_camera()
	_sync_actor(0.0 if frozen else delta)
	_enemy_models.sync()
	_sync_cards()
	_native_residents.sync()
	_fortification.sync()
	_level_up_fx.sync()
	_combat_fx.sync()
	_town_props.sync()
	_encounter_props.sync()
	_affordances.sync()
	_world_environment.sync(0.0 if frozen else delta, frozen)
	if not frozen:
		if _contact_fresh:
			_contact_fresh = false
		else:
			_contact_time = maxf(0.0, _contact_time - delta)
	_was_paused = frozen
	_presentation_dirty = false
	if frozen:
		_remember_frozen_sources()
	elif not _paused_nodes.is_empty():
		_paused_nodes.clear()
		_paused_corpses.clear()
	contact_light.visible = _contact_time > 0.0
	contact_light.light_energy = _contact_energy * pow(_contact_time / 0.22, 2.0) * (0.35 if Prefs.reduce_motion else 1.0)
	_tick_probe(delta)


func _tick_probe(delta: float) -> void:
	_probe_clock += delta
	if _probe_clock >= 0.5:
		_probe_clock = 0.0
		_publish_probe()


## This independent project has one spatial renderer in every stage-one scope.
func _sync_scope() -> bool:
	if _scope_is_cave != game.dungeon.active:
		_scope_is_cave = game.dungeon.active
		_contact_time = 0.0
		_contact_fresh = false
		contact_light.visible = false
	_native_visible = true
	display.visible = true
	game.set_forest_rendered(false)
	return true


func set_enabled(_value: bool) -> void:
	# Kept as a compatibility adapter for old startup calls; never activates a2D renderer.
	enabled = true
	_sync_scope()
	_sync_camera()
	_was_paused = false


func surface_height(point: Vector2) -> float:
	var spatial: Node = game.get("spatial_world")
	if is_instance_valid(spatial) and spatial.has_method("height_at"):
		return float(spatial.height_at(point))
	if game.dungeon.active:
		return 0.0
	# Only used while the backend is being attached after the presenter becomes ready.
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(game.village):
		if SpatialWorld3D._contains(surface["top"], point):
			return SpatialWorld3D._surface_height(surface, point)
	return 0.0


func _publish_probe() -> void:
	if not OS.has_feature("web"):
		return
	if _batch_gpu_error < 0.0:
		_batch_gpu_error = Ortho3DStaticBatch.corner_error(_static_batch)
	var calls := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var physics: SpatialWorld3D = game.get("spatial_world")
	var ready := actor != null and (animation != null or not _native_mage) and (calls > 0 or _ready_published) and physics != null and physics.physics_ticks > 0
	var eye := camera.global_transform.basis.z.normalized()
	var report := {"paused": get_tree().paused, "panel_open": game.hud.panel_open(), "panel_script": game.hud._panel.get_script().resource_path if game.hud.panel_open() else "", "logical_size": [game.get_viewport_rect().size.x, game.get_viewport_rect().size.y], "window_size": [get_window().size.x, get_window().size.y], "last_background_notification": game.get_meta("last_background_notification", -1), "ready": ready, "native_active": _native_visible, "native_width": viewport.size.x, "native_height": viewport.size.y,
		"quality": "low" if Prefs.low_resolution else "high", "spatial_draw_calls": calls,
		"spatial_primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"shadow_draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"static_boxes": int(_static_batch.get("boxes", 0)), "static_groups": int(_static_batch.get("groups", 0)),
		"batch_corner_error_m": _batch_gpu_error,
		"physics_bodies": physics.actor_bodies.size() if physics != null else 0,
		"physics_ticks": physics.physics_ticks if physics != null else 0,
		"level_up_fx": _level_up_fx._entries.size() if _level_up_fx != null else 0,
		"generic_projectiles": _combat_fx.snapshot() if _combat_fx != null else {},
		"native_residents": _native_residents.snapshot() if _native_residents != null else {},
		"native_enemies": _enemy_models.snapshot() if _enemy_models != null else {},
		"native_trees": _trees.get_meta("native_tree_report")["source_count"] if _trees != null else 0,
		"native_houses": _houses.values().map(func(house: Dictionary): return {"key": house["key"], "triangles": house["triangles"], "surfaces": house["surfaces"]}),
		"gate_progress": _fortification.gates.map(func(gate: Dictionary): return gate["progress"]) if _fortification != null else [],
		"actor_scale": [actor.scale.x, actor.scale.y, actor.scale.z],
		"actor_position": [actor.position.x, actor.position.y, actor.position.z],
		"azimuth": rad_to_deg(atan2(eye.x, eye.z)), "elevation": rad_to_deg(asin(eye.y)),
		"projection": "orthographic", "simulation": "3d", "scope": "cave" if game.dungeon.active else "forest", "skeletal_actor": _native_mage and actor != null and animation != null,
		"actor_mode": "skeletal_mage" if _native_mage else "native_warrior",
		"animation": _hero_motion.snapshot() if _hero_motion != null else (actor as NativeWarrior3D).review_snapshot() if actor is NativeWarrior3D else {}}
	JavaScriptBridge.eval("window.__sjrpg3dProbe = " + JSON.stringify(report))
	if ready and not _ready_published:
		_ready_published = true
		JavaScriptBridge.eval("window.__sjrpg3dReady = true")


func _sync_actor(delta: float) -> void:
	var player: Player = game.player
	if actor == null:
		return
	if not _native_mage:
		actor.position = actor_foot(player) + ground_position(player.sprite.position)
		var heading := ground_position(Vector2.from_angle(player.facing))
		actor.rotation.y = atan2(heading.x, heading.z)
		(actor as NativeWarrior3D).sync(player)
		return
	actor.position = actor_foot(player) + ground_position(player.sprite.position)
	if _actor_flash != null:
		var overlay: Material = _actor_flash if player.sprite.flash > 0.0 else null
		if overlay != null:
			_actor_flash.set_shader_parameter("flash_color", player.sprite.flash_tint.lerp(Color.WHITE, 0.35))
			_actor_flash.set_shader_parameter("flash_strength", 0.65 * player.sprite.flash)
		for mesh in _actor_meshes:
			if mesh.material_overlay != overlay:
				mesh.material_overlay = overlay
	var direction := ground_position(Vector2.from_angle(player.facing))
	actor.rotation.y = atan2(direction.x, direction.z)
	if _hero_motion != null:
		_hero_motion.sync(player, delta, get_tree().paused)


func actor_foot(source: Node2D) -> Vector3:
	var spatial: Node = game.get("spatial_world")
	if is_instance_valid(spatial) and spatial.has_method("actor_foot"):
		return spatial.actor_foot(source)
	return ground_position(source.position, surface_height(source.position))


func _new_card(texture: Texture2D, frame: Rect2, additive: bool) -> MeshInstance3D:
	if _card_shader == null:
		_card_shader = Shader.new()
		_card_shader.code = CARD_CODE
		_add_shader = Shader.new()
		# Only authored VFX retain overlay ordering below/above their foot pivot.
		_add_shader.code = CARD_CODE.replace("blend_mix, depth_draw_never", "blend_add, depth_draw_never, depth_test_disabled")
	var ink := ShaderMaterial.new()
	ink.shader = _add_shader if additive else _card_shader
	var plane := QuadMesh.new()
	var card := _mesh(plane, ink, Vector3.ZERO)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_card_frame(card, texture, frame)
	return card


func _set_card_frame(card: MeshInstance3D, texture: Texture2D, frame: Rect2) -> void:
	var ink := card.material_override as ShaderMaterial
	var size := texture.get_size()
	ink.set_shader_parameter("atlas_texture", texture)
	ink.set_shader_parameter("atlas_rect", Vector4(frame.position.x / size.x, frame.position.y / size.y, frame.size.x / size.x, frame.size.y / size.y))
	ink.set_shader_parameter("frame_blend", 0.0)




func _place_card(card: MeshInstance3D, at: Vector2, rect: Rect2, angle := 0.0, native_foot := Vector3(INF, INF, INF)) -> void:
	var factor := GROUND_PER_METER * PROJECTION_FACTOR
	var mesh_size: Vector2 = (card.mesh as QuadMesh).size
	var desired_size := rect.size / factor
	var offset := rect.get_center() / factor
	var basis := camera.global_transform.basis * Basis(Vector3(0, 0, 1), -angle)
	# Animate the instance, not PrimitiveMesh.size: changing mesh size rebuilds
	# its GPU surface on every impact/flicker frame. Offsets still use the
	# unscaled camera basis, preserving every original billboard corner.
	card.global_transform.basis = Basis(basis.x * (desired_size.x / mesh_size.x),
		basis.y * (desired_size.y / mesh_size.y), basis.z)
	var foot := native_foot if native_foot.is_finite() else ground_position(at, surface_height(at))
	card.position = foot + basis.x * offset.x - basis.y * offset.y


func _sync_cards() -> void:
	for id in _cards.keys():
		var entry: Dictionary = _cards[id]
		var owner: Node2D = entry["owner"].get_ref()
		if owner == null or owner.is_queued_for_deletion():
			entry["node"].queue_free()
			_cards.erase(id)
			continue
		if owner is Effect:
			(entry["node"] as MeshInstance3D).visible = owner.get_parent() == game.world
	for node in game.world.get_children():
		var effect := node as Effect
		if effect == null or effect.is_queued_for_deletion():
			continue
		var id := effect.get_instance_id()
		if effect.kind == "text":
			if not _labels.has(id):
				var fresh_label := Label3D.new()
				fresh_label.font = UiKit.BOLD_FONT
				fresh_label.font_size = 22
				fresh_label.outline_size = 5
				fresh_label.pixel_size = 1.0 / (GROUND_PER_METER * PROJECTION_FACTOR)
				fresh_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				fresh_label.no_depth_test = true
				# Combat text sits above foreground foliage, like the source2D z20.
				fresh_label.render_priority = 20
				stage.add_child(fresh_label)
				_labels[id] = {"node": fresh_label, "owner": weakref(effect)}
			var label: Label3D = _labels[id]["node"]
			label.text = effect.text
			label.modulate = Color(effect.color, clampf(2.0 - effect.age / effect.life * 2.0, 0.0, 1.0))
			label.position = ground_position(effect.position, surface_height(effect.position))
			continue
		if effect.kind == "impact" and not _seen_impacts.has(id):
			_seen_impacts[id] = weakref(effect)
			_contact_time = 0.22
			_contact_fresh = true
			_contact_energy = 5.5
			contact_light.position = spatial_position(effect.position, 0.9) + Vector3.UP * surface_height(effect.position)
			if effect.has_method("native_position"):
				contact_light.position = effect.native_position() + Vector3.UP * (0.15 if is_finite(effect.spatial_height) else 0.9)
			var colors := [Color(1, 0.75, 0.45), Color(1, 0.36, 0.08), Color(0.65, 0.5, 1), Color(0.25, 0.65, 1)]
			contact_light.light_color = colors[int(effect.params.get("cell", 0))]
		var key: String = str(effect.params.get("visual", ""))
		if effect.kind == "slash":
			key = "slash"
		var impact := effect.kind in ["impact", "cast", "release"]
		if not impact and key not in ["slash", "spin", "slam", "bolt", "frost", "meteor"]:
			continue
		if effect.kind == "zone":
			continue
		var phase := effect.visual_phase()
		var time := clampf(effect.age / effect.life, 0.0, 1.0)
		var alpha := (0.35 if Prefs.reduce_motion else (0.58 if key == "frost" else 0.78)) * (1.0 - smoothstep(0.6, 1.0, time))
		var width := effect.radius * (1.4 if key == "frost" else 2.0)
		var angle := 0.0
		if effect.kind == "slash":
			width = effect.radius * 1.7
			angle = effect.angle
			alpha = (0.48 if Prefs.reduce_motion else 0.85) * (1.0 - 0.4 * time)
		elif effect.kind == "proj":
			width = 110.0
			angle = effect.velocity.angle()
			phase = 1.0 / 3.0 if Prefs.reduce_motion else 0.32 + 0.06 * sin(effect.age * 20.0)
			alpha = 0.65 if Prefs.reduce_motion else 0.9
		if effect.kind == "impact":
			width = effect.radius * (0.86 if Prefs.reduce_motion else lerpf(0.64, 1.16, ease(time, 0.3)))
			angle = 0.0 if Prefs.reduce_motion else effect.angle
			alpha = pow(1.0 - clampf((time - 0.10) / 0.90, 0.0, 1.0), 1.6) * (0.58 if Prefs.reduce_motion else 0.95)
		elif effect.kind == "cast":
			width = 38.0
			phase = 1.0 / 3.0 if Prefs.reduce_motion else lerpf(0.08, 0.28, time)
			alpha = pow(1.0 - time, 0.7) * (0.45 if Prefs.reduce_motion else 0.72)
		elif effect.kind == "release":
			width = 38.0 if Prefs.reduce_motion else 42.0 + 8.0 * time
			alpha = (0.32 if Prefs.reduce_motion else 0.7) * (1.0 - time)
		var columns := PresentationArt.impact_columns(phase)
		var frame := PresentationArt.impact_frame(int(effect.params.get("cell", 0)), int(columns.x)) if impact else ReferenceFxArt.frame(key, int(columns.x))
		var next := PresentationArt.impact_frame(int(effect.params.get("cell", 0)), int(columns.y)) if impact else ReferenceFxArt.frame(key, int(columns.y))
		var texture: Texture2D = load("res://" + str(PresentationArt.data()["impact"]["path"])) if impact else ReferenceFxArt.texture(key)
		if not _cards.has(id):
			if _cards.size() > 96:
				continue
			_cards[id] = {"node": _new_card(texture, frame, true), "owner": weakref(effect), "static": false}
		var card: MeshInstance3D = _cards[id]["node"]
		var material := card.material_override as ShaderMaterial
		_set_card_frame(card, texture, frame)
		var size := texture.get_size()
		material.set_shader_parameter("next_rect", Vector4(next.position.x / size.x, next.position.y / size.y, next.size.x / size.x, next.size.y / size.y))
		material.set_shader_parameter("frame_blend", columns.z)
		material.set_shader_parameter("tint", Color(1, 1, 1, alpha))
		var rect := Rect2(Vector2.ONE * -width * 0.5, Vector2.ONE * width) if impact else ReferenceFxArt.rect(key, width)
		if effect.kind == "slash":
			var sweep := clampf(float(effect.params.get("arc", 1.2)) / 1.2, 0.45, 1.2)
			rect.position.y *= sweep
			rect.size.y *= sweep
		var native_effect := Vector3(INF, INF, INF)
		if effect.has_method("native_position"):
			native_effect = effect.native_position()
		_place_card(card, effect.position, rect, angle, native_effect)
	for id in _seen_impacts.keys():
		if _seen_impacts[id].get_ref() == null:
			_seen_impacts.erase(id)
	for id in _labels.keys():
		var owner: Node = _labels[id]["owner"].get_ref()
		if owner == null or owner.is_queued_for_deletion():
			_labels[id]["node"].queue_free()
			_labels.erase(id)
		else:
			(_labels[id]["node"] as Label3D).visible = owner.get_parent() == game.world




## Cap only the native 3D render target. Display/HUD coordinates and orthographic
## world coverage remain unchanged; economy retains exactly half each dimension.
static func render_size(native: Vector2, economy: bool) -> Vector2i:
	var safe := Vector2(maxf(native.x, 1.0), maxf(native.y, 1.0))
	var factor := minf(1.0, minf(MAX_RENDER_EDGE / maxf(safe.x, safe.y),
		sqrt(MAX_RENDER_PIXELS / (safe.x * safe.y))))
	if economy:
		factor *= 0.5
	return Vector2i(maxi(1, floori(safe.x * factor)), maxi(1, floori(safe.y * factor)))


func request_redraw() -> void:
	_presentation_dirty = true


func _watch_frozen(node: Node, fields: Array) -> void:
	var values := []
	for field: String in fields:
		var value: Variant = node.get(field)
		values.append(value.duplicate(true) if value is Dictionary or value is Array else value)
	_paused_nodes.append({"owner": weakref(node), "parent": node.get_parent().get_instance_id(),
		"fields": fields, "values": values})


func _watch_sprite(sprite: ActorSprite) -> void:
	_watch_frozen(sprite, ["position", "visible", "modulate", "self_modulate", "frame",
		"body_height", "flash", "flash_tint", "tint", "squash_amount", "_squash_age"])


func _remember_frozen_sources() -> void:
	_paused_nodes.clear()
	_paused_children = game.world.get_child_count()
	_paused_enemies = game.enemies.size()
	_paused_scope = game.dungeon.active
	_paused_reduced = Prefs.reduce_motion
	_paused_focus = game.camera.get_screen_center_position()
	_paused_corpses = game.corpses.duplicate(true)
	_watch_frozen(game.camera, ["global_position", "zoom", "offset"])
	_watch_frozen(game.player, ["position", "facing", "dead", "_attack_time", "_run_distance", "_roll_time"])
	_watch_sprite(game.player.sprite)
	for candidate in game.enemies:
		var enemy := candidate as Enemy
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		_watch_frozen(enemy, ["position", "facing", "dead", "_state", "_timer", "_walk_cycle"])
		_watch_sprite(enemy.sprite)
	for candidate in game.village.npc_nodes.values():
		var resident := candidate as Villager
		if is_instance_valid(resident) and not resident.is_queued_for_deletion():
			_watch_frozen(resident, ["position", "visible", "facing", "_hurt_flash", "_time"])
	for candidate in game.world.get_children():
		var effect := candidate as Effect
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			_watch_frozen(effect, ["position", "kind", "age", "life", "radius", "angle", "velocity",
				"text", "color", "spatial_height", "spatial_floor_height", "params"])


func _frozen_sources_match() -> bool:
	if _paused_reduced != Prefs.reduce_motion or _paused_children != game.world.get_child_count() or _paused_enemies != game.enemies.size() or _paused_scope != game.dungeon.active:
		return false
	if _paused_focus != game.camera.get_screen_center_position() or _paused_corpses != game.corpses:
		return false
	for record: Dictionary in _paused_nodes:
		var node: Node = record["owner"].get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_parent() == null or node.get_parent().get_instance_id() != int(record["parent"]):
			return false
		var fields: Array = record["fields"]
		var values: Array = record["values"]
		for index in fields.size():
			if node.get(fields[index]) != values[index]:
				return false
	return true


func render_activity() -> Dictionary:
	return {"full_syncs": _full_syncs, "paused_skips": _paused_skips,
		"render_width": viewport.size.x, "render_height": viewport.size.y,
		"pixels": viewport.size.x * viewport.size.y, "update_mode": viewport.render_target_update_mode,
		"dirty": _presentation_dirty}
