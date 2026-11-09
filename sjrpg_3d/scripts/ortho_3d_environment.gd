class_name Ortho3DEnvironment
extends RefCounted
## Stage-one spatial environment. Existing authored art is individual fixed cutout
## geometry with measured pivots; no captured Canvas/SubViewport is used as scenery.

const CUTOUT_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
void fragment() {
	vec4 ink = texture(source_texture, UV) * COLOR;
	ALBEDO = ink.rgb;
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = 0.18;
}
"""
const CAVE_AMBIENT := 0.34
const CAVE_AMBIENT_COLOR := Color(0.62, 0.69, 0.76)
const CAVE_BACKGROUND := Color(0.055, 0.065, 0.070)
var preview: Node
var forest: Node3D
var cave: Node3D
var _cave_source_id := 0
var _forest_world: Node2D
var _water_material: StandardMaterial3D
var _cave_lights: Array[OmniLight3D] = []
var _cave_key: DirectionalLight3D
var _cave_entry_light: OmniLight3D
var _lighting_scope_cave := false
var _ambient_outside := {}
var _cave_rock := {}
var _stone_cards := {}
var _corpses := {}
var _clock := 0.0
var report := {"forest_sprites": 0, "forest_groups": 0, "landmarks": 0, "cave_sprites": 0, "cave_groups": 0, "cave_walls": 0, "scope": "forest"}
static var _shader: Shader


func setup(presenter: Node, forest_root: Node3D) -> Ortho3DEnvironment:
	preview = presenter
	forest = forest_root
	_forest_world = preview.game.world
	_build_forest()
	return self


func _ink(texture: Texture2D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CUTOUT_CODE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("source_texture", texture)
	return material


func _append(texture: Texture2D, geometry: Dictionary, foot: Vector2, tint: Color, buckets: Dictionary, height := 0.0) -> void:
	var key := texture.get_instance_id()
	if not buckets.has(key):
		buckets[key] = {"texture": texture, "vertices": PackedVector3Array(), "uv": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	var bucket: Dictionary = buckets[key]
	var vertices: PackedVector3Array = bucket["vertices"]
	var uvs: PackedVector2Array = bucket["uv"]
	var colors: PackedColorArray = bucket["colors"]
	var indices: PackedInt32Array = bucket["indices"]
	var incoming: PackedVector3Array = geometry["vertices"]
	var input_uv: PackedVector2Array = geometry["uv"]
	var input_indices: PackedInt32Array = geometry["indices"]
	var basis: Basis = preview.camera.global_transform.basis
	var minimum := 0.0
	for point in incoming:
		minimum = minf(minimum, (basis * point).y)
	# Move on the viewing ray, preserving the exact screen projection while keeping
	# source roots below the painted pivot from being clipped by the real floor.
	var origin := Ortho3DPreview.ground_position(foot, height) + basis.z * (-minimum / basis.z.y + 0.018)
	var start := vertices.size()
	for index in incoming.size():
		vertices.append(origin + basis * incoming[index])
		uvs.append(input_uv[index])
		colors.append(tint)
	for index in input_indices:
		indices.append(start + index)
	bucket["vertices"] = vertices
	bucket["uv"] = uvs
	bucket["colors"] = colors
	bucket["indices"] = indices
	buckets[key] = bucket


func _sprite(sprite: IsoSprite, buckets: Dictionary) -> void:
	var geometry: Dictionary = preview._affordances._sprite_geometry(sprite)
	var mesh: ArrayMesh = geometry["mesh"]
	var arrays := mesh.surface_get_arrays(0)
	geometry["uv"] = arrays[Mesh.ARRAY_TEX_UV]
	geometry["indices"] = arrays[Mesh.ARRAY_INDEX]
	_append(sprite.texture, geometry, sprite.global_position, sprite.modulate_color * sprite.modulate * sprite.self_modulate, buckets, preview.surface_height(sprite.global_position))


func _flush(buckets: Dictionary, parent: Node3D, prefix: String) -> int:
	for key in buckets:
		var bucket: Dictionary = buckets[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = bucket["vertices"]
		arrays[Mesh.ARRAY_TEX_UV] = bucket["uv"]
		arrays[Mesh.ARRAY_COLOR] = bucket["colors"]
		arrays[Mesh.ARRAY_INDEX] = bucket["indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = prefix + str(key)
		node.mesh = mesh
		node.material_override = _ink(bucket["texture"])
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	return buckets.size()


func _floor(polygon: PackedVector2Array, texture: Texture2D, parent: Node3D, height: float, tint := Color.WHITE, tile := 2.6) -> MeshInstance3D:
	var flat := PackedVector2Array()
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var normals := PackedVector3Array()
	for point in polygon:
		var at := Ortho3DPreview.ground_position(point, height)
		flat.append(Vector2(at.x, at.z))
		vertices.append(at)
		uv.append(Vector2(at.x, at.z) / tile)
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(flat)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = texture
	ink.albedo_color = tint
	ink.roughness = 0.94
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return preview._mesh(mesh, ink, Vector3.ZERO, parent)


func _build_forest() -> void:
	report["remaining_sources"] = {"forest": [], "cave": []}
	var buckets := {}
	var native: Dictionary = preview._town_props.source_ids()
	var forest_trees := Ortho3DForestTrees.build(preview, forest, _forest_world)
	var tree_report: Dictionary = forest_trees.get_meta("native_forest_tree_report")
	# Failed/unsupported replacements keep their source card. Never skip a whole sheet.
	native.merge(tree_report["owned_source_ids"])
	var landmark_report := NativeLandmarks3D.build(preview, forest)
	native.merge(landmark_report["owned_source_ids"])
	report["native_landmarks"] = landmark_report["entries"].size()
	report["native_landmark_surfaces"] = {}
	for entry: Dictionary in landmark_report["entries"]:
		report["native_landmark_surfaces"][str(entry["surface"]["id"])] = true
	var flora_report := NativeForestFlora3D.build(preview, forest, _forest_world)
	native.merge(flora_report["owned_source_ids"])
	report["native_flora"] = flora_report["placements"].size()
	report["native_flora_groups"] = flora_report["groups"]
	var scenery := NativeSceneryProps3D.build(preview, forest, _forest_world, false, native)
	native.merge(scenery["owned_source_ids"])
	report["native_forest_scenery"] = scenery["entries"].size()
	report["native_forest_trees"] = tree_report["trees"].size()
	for object in preview.game.village.buildings.values():
		native[object.get_instance_id()] = true
	for tree: IsoSprite in preview.game.village.town_trees:
		native[tree.get_instance_id()] = true
	# Affordances own the animated fallback for any non-native portal.
	for portal in preview.game.village.portal_sprites.values():
		native[portal.get_instance_id()] = true
	for child in _forest_world.get_children():
		if child is IsoSprite:
			var sprite := child as IsoSprite
			var sheet: String = sprite.def.get("sheet", "")
			if native.has(sprite.get_instance_id()) or sheet.contains("gates") or sheet.contains("wall"):
				continue
			_sprite(sprite, buckets)
			report["remaining_sources"]["forest"].append(_source_record(sprite))
			report["forest_sprites"] = int(report["forest_sprites"]) + 1
		elif child is Landmark:
			if not native.has(child.get_instance_id()):
				_landmark(child, buckets)
				report["remaining_sources"]["forest"].append(_source_record(child))
			report["landmarks"] = int(report["landmarks"]) + 1
	report["forest_groups"] = _flush(buckets, forest, "ForestArt_")
	_build_river()
	_build_bridge()
	_build_raised_floors()
	for stone in preview.game.encounters.stones.values():
		if preview._encounter_props.owns(stone.art):
			continue
		var sprite: IsoSprite = stone.art
		var texture: Texture2D = sprite.texture
		var card: MeshInstance3D = preview._new_card(texture, Rect2(Vector2.ZERO, texture.get_size()), false)
		var geometry: Dictionary = preview._affordances._sprite_geometry(sprite)
		card.mesh = geometry["mesh"]
		card.reparent(forest, true)
		var header := Label3D.new()
		header.font = UiKit.BOLD_FONT
		header.font_size = 17
		header.outline_size = 4
		header.pixel_size = 1.0 / (Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR)
		header.no_depth_test = true
		header.modulate = Color("d4e3cd")
		forest.add_child(header)
		_stone_cards[stone.get_instance_id()] = {"owner": weakref(stone), "card": card, "vertices": geometry["vertices"], "header": header}


func _source_record(source: Node2D) -> Dictionary:
	var result := {"source_id": source.get_instance_id(), "name": str(source.name), "type": "IsoSprite" if source is IsoSprite else "Landmark", "foot": [source.global_position.x, source.global_position.y], "role": str(source.get_meta("cave_role", source.get_meta("forest_species", "")))}
	if source is IsoSprite:
		result["sheet"] = str(source.def.get("sheet", ""))
		result["definition"] = source.def.duplicate(true)
	elif source is Landmark:
		result["sheet"] = "res://assets/art/village/landmarks.webp"
		result["definition"] = {"index": source.index}
	return result

func _landmark(source: Landmark, buckets: Dictionary) -> void:
	var factor := Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	if source._warp_mesh != null:
		var arrays := source._warp_mesh.surface_get_arrays(0)
		var original: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for point in original:
			vertices.append(Vector3(point.x, -point.y, 0) / factor)
		uv = arrays[Mesh.ARRAY_TEX_UV]
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		var cell := Landmark.CELL
		for point in [Vector2.ZERO, Vector2(cell, 0), Vector2(cell, cell), Vector2(0, cell)]:
			var local := source._pt([point.x, point.y]) - source.position
			vertices.append(Vector3(local.x, -local.y, 0) / factor)
			uv.append((Vector2((source.index % 2) * cell, (source.index / 2) * cell) + point) / Landmark._sheet.get_size())
		indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	_append(Landmark._sheet, {"vertices": vertices, "uv": uv, "indices": indices}, source.position, Color.WHITE, buckets)


func _build_river() -> void:
	var river: River = preview.game.village.river
	var water := PackedVector2Array()
	for point in river.polygon:
		water.append(Iso.project(point))
	var outer := Geometry2D.offset_polygon(water, 62.0)
	if not outer.is_empty():
		_floor(outer[0], load("res://assets/art/village/rock.webp"), forest, 0.014)
	var surface := _floor(water, load("res://assets/art/village/water.webp"), forest, 0.022, Color(0.78, 0.91, 0.96), River.TILE_UNITS / Ortho3DPreview.GROUND_PER_METER)
	_water_material = surface.material_override as StandardMaterial3D
	_water_material.roughness = 0.35
	_water_material.metallic = 0.12


func _build_bridge() -> void:
	var bridge: Bridge = preview.game.village.bridge
	_floor(bridge.deck_polygon(), load("res://assets/art/forest/paving.webp"), forest, 0.045)
	var deck := bridge.deck_polygon()
	for pair in [[deck[0], deck[1]], [deck[3], deck[2]]]:
		var a := Ortho3DPreview.ground_position(pair[0])
		var b := Ortho3DPreview.ground_position(pair[1])
		var rail: MeshInstance3D = preview._box((a + b) * 0.5 + Vector3.UP * 0.48, Vector3(a.distance_to(b), 0.96, 0.22), preview._materials["stone"], forest)
		rail.rotation.y = -atan2((b - a).z, (b - a).x)


func _build_raised_floors() -> void:
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(preview.game.village):
		if (report.get("native_landmark_surfaces", {}) as Dictionary).has(str(surface["id"])):
			continue
		if float(surface["rise"]) <= 0.001:
			continue
		var points: PackedVector3Array = SpatialWorld3D.surface_faces(surface)
		if points.is_empty():
			continue
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for index in range(0, points.size(), 3):
			var normal := (points[index + 1] - points[index]).cross(points[index + 2] - points[index]).normalized()
			if normal.y < 0.0:
				normal = -normal
			for offset in 3:
				var vertex: Vector3 = points[index + offset]
				vertex.y += 0.008
				points[index + offset] = vertex
				normals.append(normal)
				uvs.append(Vector2(points[index + offset].x, points[index + offset].z) / 2.6)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := (preview._materials["paving"] as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var floor_mesh: MeshInstance3D = preview._mesh(mesh, material, Vector3.ZERO, forest)
		floor_mesh.name = "RaisedSurface_" + str(surface["id"])
		floor_mesh.set_meta("terrain_surface", surface["id"])


func _build_cave() -> void:
	# Build-time ownership must be current even when a test/manual scope switch calls
	# this before the next presenter frame; otherwise a portal card is baked forever.
	preview._town_props.sync()
	if cave != null:
		cave.name = "RetiredCave"
		cave.queue_free()
	cave = Node3D.new()
	cave.name = "NativeCave"
	preview.stage.add_child(cave)
	_cave_source_id = preview.game.dungeon._root.get_instance_id()
	_cave_lights.clear()
	var layout: DungeonLayout = preview.game.dungeon.layout
	var textures: Dictionary = DungeonArt.data()["textures"]
	var floor_texture: Texture2D = load("res://" + str(textures["floor"]["path"]))
	var floor_material := Ortho3DCaveRock.floor_material(floor_texture)
	for index in layout.polygons.size():
		var surface := _floor(layout.polygons[index], floor_texture, cave, 0.004, Color.WHITE, Ortho3DCaveRock.TILE_METRES)
		surface.name = "CaveFloor_%d" % index
		surface.material_override = floor_material
	var rock: Texture2D = load("res://" + str(textures["dark"]["path"]))
	# DungeonArt recorded this union before the separate return-portal obstacle
	# was added; a prop must not become a new cave boundary cell.
	_cave_rock = Ortho3DCaveRock.build(layout, cave, rock, preview.game.dungeon.art.boundary_segments)
	var lanterns := NativeCaveLanterns3D.build(preview, cave, preview.game.dungeon.art.visuals)
	var native_lantern_ids: Dictionary = lanterns["owned_source_ids"]
	report["native_cave_lanterns"] = lanterns["count"]
	var native_scenery_excluded: Dictionary = preview._town_props.source_ids()
	native_scenery_excluded.merge(native_lantern_ids)
	var scenery := NativeSceneryProps3D.build(preview, cave, preview.game.world, true, native_scenery_excluded)
	var native_scenery_ids: Dictionary = scenery["owned_source_ids"]
	report["native_cave_scenery"] = scenery["entries"].size()
	report["native_cave_prop_sources"] = native_scenery_excluded.keys() + native_scenery_ids.keys()
	var buckets := {}
	var replaced: Array[int] = []
	var retained: Array[int] = []
	report["remaining_sources"]["cave"] = []
	for node in preview.game.dungeon.art.visuals:
		if node is IsoSprite and not preview._town_props.owns(node) and not native_lantern_ids.has(node.get_instance_id()) and not native_scenery_ids.has(node.get_instance_id()):
			# Wall strips and end caps share atlases with useful lamps. Replace
			# only the metadata-owned boundary art, never the whole texture bucket.
			if str(node.get_meta("cave_role", "")) == "wall":
				replaced.append(node.get_instance_id())
				continue
			_sprite(node, buckets)
			report["remaining_sources"]["cave"].append(_source_record(node))
			retained.append(node.get_instance_id())
			report["cave_sprites"] = int(report["cave_sprites"]) + 1
	for node in preview.game.world.get_children():
		if node is IsoSprite and not preview._town_props.owns(node) and not native_lantern_ids.has(node.get_instance_id()) and not native_scenery_ids.has(node.get_instance_id()) and not preview.game.dungeon.art.visuals.has(node):
			_sprite(node, buckets)
			report["remaining_sources"]["cave"].append(_source_record(node))
			report["cave_sprites"] = int(report["cave_sprites"]) + 1
			retained.append(node.get_instance_id())
	report["cave_groups"] = _flush(buckets, cave, "CaveArt_")
	report["cave_walls"] = int(_cave_rock["segments"])
	report["cave_rock_triangles"] = int(_cave_rock["triangles"])
	report["cave_rock_groups"] = int(_cave_rock["groups"])
	report["cave_replaced_wall_sources"] = replaced
	report["cave_retained_sources"] = retained
	for position: Vector3 in lanterns["light_positions"]:
		var light := OmniLight3D.new()
		light.position = position
		light.light_color = Color(1.0, 0.66, 0.29)
		light.light_energy = 2.6
		light.omni_range = 5.0
		light.shadow_enabled = false
		cave.add_child(light)
		_cave_lights.append(light)
	_build_cave_fill()
	var batch := Ortho3DStaticBatch.apply(cave)
	cave.set_meta("static_batch", batch)
	cave.set_meta("boundary_sources", {"replaced": replaced, "retained": retained, "native_props": report["native_cave_prop_sources"]})


func _build_cave_fill() -> void:
	# One bounded directional shadow pass replaces the disabled outdoor sun.
	# It represents cutaway cave scatter, not a painted outdoor sun patch.
	_cave_key = DirectionalLight3D.new()
	_cave_key.name = "CaveScatterKey"
	_cave_key.light_color = Color(0.76, 0.82, 0.91)
	_cave_key.light_energy = 0.62
	_cave_key.shadow_enabled = true
	_cave_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_cave_key.shadow_opacity = 0.60
	_cave_key.shadow_bias = 0.025
	_cave_key.shadow_normal_bias = 0.22
	cave.add_child(_cave_key)
	_cave_key.look_at(Vector3(-0.45, -1.0, -0.55), Vector3.UP)
	# The existing entry chamber has no authored lantern in range. A fixed
	# cool entrance bounce makes the arriving navy silhouette readable there.
	_cave_entry_light = OmniLight3D.new()
	_cave_entry_light.name = "CaveEntryBounce"
	_cave_entry_light.position = Vector3(-0.60, 2.30, -0.30)
	_cave_entry_light.light_color = Color(0.67, 0.77, 0.84)
	_cave_entry_light.light_energy = 1.20
	_cave_entry_light.omni_range = 6.20
	_cave_entry_light.shadow_enabled = false
	cave.add_child(_cave_entry_light)


func _sync_cave_lighting(inside: bool) -> void:
	if inside == _lighting_scope_cave:
		return
	for child in preview.stage.get_children():
		if not child is WorldEnvironment:
			continue
		var settings: Environment = (child as WorldEnvironment).environment
		var id: int = child.get_instance_id()
		if inside:
			_ambient_outside[id] = {"energy": settings.ambient_light_energy, "color": settings.ambient_light_color, "background": settings.background_color}
			settings.ambient_light_energy = CAVE_AMBIENT
			settings.ambient_light_color = CAVE_AMBIENT_COLOR
			settings.background_color = CAVE_BACKGROUND
		elif _ambient_outside.has(id):
			var original: Dictionary = _ambient_outside[id]
			settings.ambient_light_energy = original["energy"]
			settings.ambient_light_color = original["color"]
			settings.background_color = original["background"]
			_ambient_outside.erase(id)
	_lighting_scope_cave = inside


func sync(delta: float, frozen: bool) -> void:
	NativeLandmarks3D.sync_water(forest, preview.game.village)
	var inside: bool = preview.game.dungeon.active
	forest.visible = not inside
	if inside and (_cave_source_id != preview.game.dungeon._root.get_instance_id() or not is_instance_valid(cave)):
		report["cave_sprites"] = 0
		report["cave_walls"] = 0
		_build_cave()
	if cave != null:
		cave.visible = inside
	if inside and is_instance_valid(preview.game.dungeon._root):
		preview.game.dungeon._root.visibility_layer = 0
	preview.sunlight.visible = not inside
	_sync_cave_lighting(inside)
	var bounce: DirectionalLight3D = preview.stage.get_node_or_null("WarmDaylightBounce")
	if bounce != null:
		bounce.visible = not inside
	report["scope"] = "cave" if inside else "forest"
	if not frozen:
		_clock += delta
		if _water_material != null:
			_water_material.uv1_offset = Vector3(_clock * 0.025, _clock * 0.006, 0)
	NativeCaveLanterns3D.sync(cave, _clock)
	for light in _cave_lights:
		light.light_energy = 2.6 if Prefs.reduce_motion else 2.6 + sin(_clock * 3.8 + light.position.x) * 0.10
	for entry: Dictionary in _stone_cards.values():
		var owner: EncounterStone = entry["owner"].get_ref()
		var card: MeshInstance3D = entry["card"]
		if not is_instance_valid(owner):
			card.visible = false
			(entry["header"] as Label3D).visible = false
			continue
		card.visible = owner.visible and owner.art.visible
		card.basis = preview.camera.global_transform.basis
		var basis: Basis = card.basis
		var minimum := 0.0
		for vertex: Vector3 in entry["vertices"]:
			minimum = minf(minimum, (basis * vertex).y)
		var foot := Ortho3DPreview.ground_position(owner.position, preview.surface_height(owner.position))
		card.position = foot + basis.z * (-minimum / basis.z.y + 0.018)
		(card.material_override as ShaderMaterial).set_shader_parameter("tint", owner.art.modulate_color)
		var header: Label3D = entry["header"]
		header.basis = basis
		header.position = foot + basis.y * 1.72
		header.visible = card.visible and owner.position.distance_squared_to(preview.game.player.position) < 240.0 * 240.0
		var living: int = owner.runtime.living(owner.id)
		var state: Dictionary = owner.runtime.states[owner.id]
		header.text = NativeEncounterProps3D.status_text(state, living)
	_sync_corpses()


func _sync_corpses() -> void:
	var current := {}
	for corpse: Dictionary in preview.game.corpses:
		if NativeEnemySprites3D.supports_corpse(corpse):
			continue
		var source: Node = corpse.get("visual")
		if not is_instance_valid(source):
			continue
		var id := source.get_instance_id()
		current[id] = true
		if not _corpses.has(id):
			var model := NativeEnemyModels.build(str(corpse.get("kind", "goblin")))
			preview.stage.add_child(model["root"])
			_corpses[id] = model
		NativeEnemyModels.place_corpse(preview, _corpses[id], corpse)
	for id in _corpses.keys():
		if not current.has(id):
			(_corpses[id]["root"] as Node3D).queue_free()
			_corpses.erase(id)
