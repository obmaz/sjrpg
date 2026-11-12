class_name AreaEffects3D
extends RefCounted
## Read-only pictures for persistent zones omitted by the hidden source Canvas.
## Two draws per picture: a ground footprint and instanced generated atlas glows.
const MAX_ZONES := 16
const SEGMENTS := 48
const MAX_GLOWS := 9
const SURFACE_LIFT := 0.018
const GLOW_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	vec4 ink = texture(atlas_texture, atlas_rect.xy + UV * atlas_rect.zw);
	ALBEDO = ink.rgb * COLOR.rgb;
	ALPHA = ink.a * COLOR.a;
}
"""
static var _glow_shader: Shader
var _renderer: Node
var _atlas: Texture2D
var _quad: QuadMesh
var _entries := {}


func setup(presenter: Node) -> AreaEffects3D:
	_renderer = presenter
	_atlas = load("res://" + str(PresentationArt.data()["impact"]["path"]))
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_CODE
	return self


func sync() -> void:
	var current := {}
	var children: Array[Effect] = Effect.in_world(_renderer.game.world)
	for index in range(children.size() - 1, -1, -1):
		var source := children[index]
		if not is_instance_valid(source) or source.is_queued_for_deletion() or source.kind != "zone" or source.age >= source.life:
			continue
		var at := source.native_position()
		if not at.is_finite() or source.radius <= 0.0:
			continue
		var id := source.get_instance_id()
		current[id] = true
		if not _entries.has(id):
			_entries[id] = _create(source)
		_update(_entries[id], source, at)
		if current.size() >= MAX_ZONES:
			break
	for id in _entries.keys():
		if not current.has(id):
			var root: Node3D = _entries[id]["root"]
			root.hide()
			root.queue_free()
			_entries.erase(id)


func _create(source: Effect) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativePersistentZone"
	_renderer.stage.add_child(root)
	var marker := MeshInstance3D.new()
	marker.name = "ActualGroundFootprint"
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y = SURFACE_LIFT
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ink.vertex_color_use_as_albedo = true
	marker.material_override = ink
	root.add_child(marker)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = _quad
	instances.instance_count = MAX_GLOWS
	instances.visible_instance_count = 0
	var glows := MultiMeshInstance3D.new()
	glows.name = "GeneratedZoneGlows"
	glows.multimesh = instances
	glows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var atlas_ink := ShaderMaterial.new()
	atlas_ink.shader = _glow_shader
	atlas_ink.set_shader_parameter("atlas_texture", _atlas)
	glows.material_override = atlas_ink
	root.add_child(glows)
	var offsets: Array = []
	offsets.resize(MAX_GLOWS)
	return {"root": root, "marker": marker, "glows": glows, "glow_offsets": offsets, "source": weakref(source),
		"shape_key": [], "points": PackedVector2Array(), "phase": "", "age": source.age,
		"cell": -1, "mesh_builds": 0}


## Gameplay areas use the legacy screen-world distance budget. Inverse-project
## that perimeter onto XZ; do not replace it with an unrelated circular metre radius.
static func footprint(source: Effect) -> PackedVector2Array:
	var result := PackedVector2Array()
	var reach := source.radius + (10.0 if source.params.has("wall") else 0.0)
	for index in SEGMENTS:
		result.append(Vector2.from_angle(TAU * float(index) / SEGMENTS) * reach)
	if source.params.has("wall"):
		var angle: float = source.params["wall"]
		var axis := Vector2.from_angle(angle)
		var side := axis.orthogonal() * 26.0
		var along := axis * (reach + 1.0)
		var strip := PackedVector2Array([-along - side, along - side, along + side, -along + side])
		var clipped := Geometry2D.intersect_polygons(result, strip)
		if not clipped.is_empty():
			result = clipped[0]
	return result


static func _local_ground(point: Vector2) -> Vector3:
	return WorldSpace3D.projected_to_world(point, 0.0)


static func _vertex(tool: SurfaceTool, point: Vector2, alpha: float) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_color(Color(1, 1, 1, alpha))
	tool.add_vertex(_local_ground(point))


static func _ground_mesh(points: PackedVector2Array, radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inset := maxf(0.0, 1.0 - 2.5 / maxf(radius, 2.5))
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		# Convex disk/strip intersection: one quiet fill and a thin readable rim.
		for p in [Vector2.ZERO, a * inset, b * inset]:
			_vertex(tool, p, 0.13)
		for p in [a * inset, a, b, a * inset, b, b * inset]:
			_vertex(tool, p, 1.0)
	return tool.commit()


func _update(entry: Dictionary, source: Effect, at: Vector3) -> void:
	var root: Node3D = entry["root"]
	root.global_position = at
	var marker: MeshInstance3D = entry["marker"]
	var shape_key := [source.radius, source.params.has("wall"), source.params.get("wall", 0.0)]
	if entry["shape_key"] != shape_key:
		var points := footprint(source)
		entry["points"] = points
		entry["shape_key"] = shape_key
		entry["mesh_builds"] = int(entry["mesh_builds"]) + 1
		marker.mesh = _ground_mesh(points, source.radius)
	var delay := maxf(0.0, float(source.params.get("delay", 0.0)))
	var warning := source.age < delay
	var meteor := str(source.params.get("visual", "")) == "meteor"
	var wall := source.params.has("wall")
	var shards := bool(source.params.get("shards", false))
	var fade := clampf((source.life - source.age) / 0.5, 0.0, 1.0)
	entry["phase"] = "warning" if warning else "active"
	entry["age"] = source.age
	var alpha := 0.75 if warning else (0.25 if meteor else 0.60) * fade
	var ink := marker.material_override as StandardMaterial3D
	var color := Color(source.color, alpha)
	if ink.albedo_color != color:
		ink.albedo_color = color
	var instances: MultiMesh = (entry["glows"] as MultiMeshInstance3D).multimesh
	var cell := Effect._element_cell(source.color)
	if int(entry["cell"]) != cell:
		entry["cell"] = cell
		var frame := PresentationArt.impact_frame(cell, 1)
		var size := _atlas.get_size()
		((entry["glows"] as MultiMeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("atlas_rect",
			Vector4(frame.position.x / size.x, frame.position.y / size.y, frame.size.x / size.x, frame.size.y / size.y))
	var count := (1 if Prefs.reduce_motion else 3) if warning else (9 if wall else 5)
	instances.visible_instance_count = count
	var offsets: Array = entry["glow_offsets"]
	var camera_basis: Basis = _renderer.camera.global_transform.basis
	var factor := WorldSpace3D.GROUND_UNITS_PER_METER * WorldSpace3D.GROUND_PROJECTION_FACTOR
	for index in count:
		var offset := Vector3.ZERO
		var width := 17.0
		var height := 17.0
		var opacity := 0.25 * fade
		if warning:
			var progress := clampf(source.age / maxf(delay, 0.0001), 0.0, 1.0)
			offset = Vector3(1.3, 4.8, -0.4) * (1.0 - progress) + Vector3(0.12, 0.35, 0.12) * index
			if Prefs.reduce_motion:
				offset = Vector3(0, 0.45, 0)
			width = 42.0 - index * 9.0
			height = width
			opacity = 0.80 - index * 0.20
		elif wall:
			var direction := Vector2.from_angle(float(source.params["wall"]))
			offset = _local_ground(direction * lerpf(-source.radius, source.radius, float(index) / 8.0))
			offset.y = 0.32 if Prefs.reduce_motion else 0.32 + 0.07 * sin(source.age * 12.0 + index)
			width = 30.0
			height = 48.0
			opacity = (0.40 if Prefs.reduce_motion else 0.65) * fade
		else:
			offset = _local_ground(Vector2.from_angle(index * 2.39996) * source.radius * 0.60)
			offset.y = 0.10
			if shards:
				offset.y = 0.15 if Prefs.reduce_motion else 2.3 * (1.0 - fposmod(source.age * 3.0 + index * 0.37, 1.0))
				width = 11.0
				height = 25.0
				opacity = (0.30 if Prefs.reduce_motion else 0.55) * fade
		var basis := Basis(camera_basis.x * width / factor, camera_basis.y * height / factor, camera_basis.z)
		offsets[index] = offset
		instances.set_instance_transform(index, Transform3D(basis, offset))
		instances.set_instance_color(index, Color(1, 1, 1, opacity))


func snapshot() -> Dictionary:
	var sources := []
	for id in _entries:
		var entry: Dictionary = _entries[id]
		var source: Effect = (entry["source"] as WeakRef).get_ref()
		if not is_instance_valid(source):
			continue
		var root: Node3D = entry["root"]
		var instances: MultiMesh = (entry["glows"] as MultiMeshInstance3D).multimesh
		sources.append({"id": id, "phase": entry["phase"], "age": source.age, "life": source.life,
			"radius": source.radius, "wall": source.params.has("wall"), "shards": bool(source.params.get("shards", false)),
			"position": [root.global_position.x, root.global_position.y, root.global_position.z],
			"glows": instances.visible_instance_count, "draw_surfaces": 2, "mesh_builds": entry["mesh_builds"]})
	return {"count": _entries.size(), "max_count": MAX_ZONES, "sources": sources}
