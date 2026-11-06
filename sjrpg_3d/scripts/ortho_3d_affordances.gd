class_name Ortho3DAffordances
extends RefCounted
## Existing-art fallbacks for live village interactions in the optional native comparison.
## Preserve measured sprite meshes; these cards are not native portal/chest models.

var _preview: Node
var _game: Node
var _art := {}
var _headers := {}


func setup(presenter: Node) -> Ortho3DAffordances:
	_preview = presenter
	_game = presenter.game
	return self


func sync() -> void:
	var current := {}
	var portals: Array = [] if _game.dungeon.active else _game.village.portal_sprites.values()
	for candidate in portals:
		var portal := candidate as IsoSprite
		if is_instance_valid(portal):
			_sync_art(portal, current)
	for candidate in _game.chests:
		var chest := candidate as Chest
		if is_instance_valid(chest) and is_instance_valid(chest.body_sprite):
			# Breaking a chest replaces its actual sprite, including its measured warp.
			_sync_art(chest.body_sprite, current)
	for id in _art.keys():
		if not current.has(id):
			var entry: Dictionary = _art[id]
			(entry["node"] as MeshInstance3D).queue_free()
			_art.erase(id)
	for candidate in _game.village.npc_nodes.values():
		var resident := candidate as Villager
		if is_instance_valid(resident):
			_sync_header(resident)
	for id in _headers.keys():
		var entry: Dictionary = _headers[id]
		var resident: Villager = (entry["owner"] as WeakRef).get_ref()
		if not is_instance_valid(resident) or resident.is_queued_for_deletion():
			(entry["root"] as Node3D).queue_free()
			_headers.erase(id)


func _sync_art(sprite: IsoSprite, current: Dictionary) -> void:
	if sprite.is_queued_for_deletion():
		return
	var id := sprite.get_instance_id()
	current[id] = true
	if not _art.has(id):
		var size := sprite.texture.get_size()
		var card: MeshInstance3D = _preview._new_card(sprite.texture, Rect2(Vector2.ZERO, size), false)
		var geometry := _sprite_geometry(sprite)
		card.mesh = geometry["mesh"]
		_art[id] = {"node": card, "vertices": geometry["vertices"]}
	var entry: Dictionary = _art[id]
	var card: MeshInstance3D = entry["node"]
	var ink := card.material_override as ShaderMaterial
	ink.set_shader_parameter("tint", sprite.modulate_color * sprite.modulate * sprite.self_modulate)
	# The hidden field's ancestors are intentionally ignored; a source's own visibility is authoritative.
	card.visible = sprite.visible
	var basis: Basis = _preview.camera.global_transform.basis
	card.basis = basis
	var minimum_y := 0.0
	for vertex: Vector3 in entry["vertices"]:
		minimum_y = minf(minimum_y, (basis * vertex).y)
	# Slide toward the orthographic camera without moving the projected art. This keeps
	# the small painted base below its foot pivot from being cut in half by the native floor.
	var lift := -minimum_y / maxf(basis.z.y, 0.001) + 0.015
	card.position = Ortho3DPreview.ground_position(sprite.global_position, _preview.surface_height(sprite.global_position)) + basis.z * lift


func _sprite_geometry(sprite: IsoSprite) -> Dictionary:
	var pixels := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	if sprite._warp_mesh != null:
		var original: Array = sprite._warp_mesh.surface_get_arrays(0)
		pixels = original[Mesh.ARRAY_VERTEX]
		uvs = original[Mesh.ARRAY_TEX_UV]
		indices = original[Mesh.ARRAY_INDEX]
	else:
		var source: Array = sprite.def["source"]
		var foot: Array = sprite.def["foot"]
		var frame := Rect2(source[0], source[1], source[2], source[3])
		if sprite.clip != Vector2.ZERO:
			frame.position.x = sprite.clip.x
			frame.size.x = sprite.clip.y - sprite.clip.x
		var anchor := Vector2(foot[0], foot[1])
		for corner in [frame.position, frame.position + Vector2(frame.size.x, 0), frame.end, frame.position + Vector2(0, frame.size.y)]:
			var delta: Vector2 = corner - anchor
			pixels.append(Vector3((-1.0 if sprite.flip else 1.0) * delta.x * sprite.k + sprite.draw_shift.x,
				(delta.y * float(sprite.def["gvs"]) + delta.x * float(sprite.def["gvk"])) * sprite.k + sprite.draw_shift.y, 0))
			uvs.append(corner / sprite.texture.get_size())
		indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var vertices := PackedVector3Array()
	var factor := Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR
	for pixel in pixels:
		# Preserve the source node's scale/rotation as well as its authored affine/warp mesh.
		var offset: Vector2 = sprite.global_transform.basis_xform(Vector2(pixel.x, pixel.y))
		vertices.append(Vector3(offset.x, -offset.y, 0) / factor)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "vertices": vertices}


func _label(parent: Node3D, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font = UiKit.BOLD_FONT
	label.font_size = size
	label.modulate = color
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.pixel_size = 1.0 / (Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	parent.add_child(label)
	return label


func _bar(parent: Node3D, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = 10
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _sync_header(resident: Villager) -> void:
	var id := resident.get_instance_id()
	if not _headers.has(id):
		var root := Node3D.new()
		_preview.stage.add_child(root)
		var name_label := _label(root, 14, Color(1, 0.95, 0.8))
		name_label.text = resident.display_name
		var badge := _label(root, 32, Color(1, 0.82, 0.3))
		badge.text = "●"
		badge.outline_size = 0
		var marker := _label(root, 22, Color(0.2, 0.1, 0))
		marker.text = "!"
		marker.outline_size = 0
		marker.render_priority = 12
		var health := _bar(root, Color(0.3, 0.85, 0.45))
		(health.material_override as StandardMaterial3D).render_priority = 11
		_headers[id] = {"root": root, "owner": weakref(resident), "name": name_label,
			"badge": badge, "marker": marker, "bar": _bar(root, Color(0.05, 0.05, 0.05)),
			"health": health}
	var entry: Dictionary = _headers[id]
	var layout := resident.header_layout()
	var root: Node3D = entry["root"]
	root.visible = resident.visible and not _game.dungeon.active
	var name_label: Label3D = entry["name"]
	# The source name uses a baseline; Label3D is centered on its line box.
	var name_y: float = layout["name_y"]
	var center_y := name_y - UiKit.BOLD_FONT.get_ascent(14) + UiKit.BOLD_FONT.get_height(14) * 0.5
	var elevation: float = _preview.surface_height(resident.global_position)
	name_label.position = Ortho3DPreview.ground_position(resident.global_position + Vector2(0, center_y), elevation)
	var show_marker := resident.marker.is_valid() and bool(resident.marker.call())
	var bob := 0.0 if Prefs.reduce_motion else sin(resident._time * 4.0) * 3.0
	var marker_y: float = layout["marker_y"]
	var marker_at := Ortho3DPreview.ground_position(resident.global_position + Vector2(0, marker_y + bob), elevation)
	var badge: Label3D = entry["badge"]
	var marker: Label3D = entry["marker"]
	badge.visible = show_marker
	marker.visible = show_marker
	badge.position = marker_at
	marker.position = marker_at
	var ratio: float = layout["ratio"]
	var bar: MeshInstance3D = entry["bar"]
	var health: MeshInstance3D = entry["health"]
	bar.visible = ratio >= 0.0
	health.visible = ratio > 0.0
	if ratio >= 0.0:
		var bounds: Rect2 = layout["bar"]
		_preview._place_card(bar, resident.global_position, bounds)
		var fill := Rect2(bounds.position + Vector2(2, 2), Vector2(62.0 * clampf(ratio, 0, 1), 5))
		_preview._place_card(health, resident.global_position, fill)
