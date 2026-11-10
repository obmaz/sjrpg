class_name WorldOcclusion
extends RefCounted
## Only silhouettes actually covering the hero use instance uniforms; a whole village exceeds mobile buffers.

const SHADER := preload("res://scripts/world_occlusion.gdshader")
static var _material: ShaderMaterial
static var _active: Array[Node2D] = []

static func attach(item: Node2D, bounds: Rect2) -> void:
	item.add_to_group("world_occluders")
	item.set_meta("occlusion_bounds", bounds)
	if item.material != null:
		item.set_meta("base_material", item.material)


static func bounds_of(rect: Rect2, transform: Transform2D) -> Rect2:
	var bounds := Rect2(transform * rect.position, Vector2.ZERO)
	for corner in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		bounds = bounds.expand(transform * corner)
	return bounds


## `scan` is false while the source canvas is hidden (the native 3D game): no silhouette
## can cover the hero there, so only the shader globals are published.
static func update(position: Vector2, above: bool, scan := true) -> void:
	RenderingServer.global_shader_parameter_set("hero_world_position", position)
	RenderingServer.global_shader_parameter_set("hero_above", above)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		WorldLighting.register_material(_material)
	var selected: Array[Node2D] = []
	if scan and not above:
		var body := Rect2(position - Vector2(38, 100), Vector2(76, 116))
		var tree := Engine.get_main_loop() as SceneTree
		for item in tree.get_nodes_in_group("world_occluders"):
			if not item.is_visible_in_tree() or item.global_position.y <= position.y + 4.0:
				continue
			var bounds: Rect2 = item.get_meta("occlusion_bounds")
			if bounds.intersects(body):
				selected.append(item)
	for item in _active:
		if is_instance_valid(item) and not selected.has(item):
			item.material = item.get_meta("base_material") if item.has_meta("base_material") else null
	for item in selected:
		if not _active.has(item):
			var base: Material = item.get_meta("base_material", null)
			item.material = _material if base == null or base == WorldLighting.material() else base
			item.set_instance_shader_parameter("sort_y", item.global_position.y)
	_active = selected
