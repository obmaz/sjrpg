class_name NativeForestFlora3D
extends RefCounted
## Closed, lit native plant meshes. Exact source IDs gate fallback removal.
const SPECIES := ["grass", "fern", "flowers_white", "flowers_warm"]
const CHUNK := 12.0
static var _library := {}

static func species_of(source: IsoSprite) -> String:
	var tagged := str(source.get_meta("forest_species", ""))
	if tagged in SPECIES:
		return tagged
	# build_field's original decoration predates border-flora metadata.
	for kind: String in SPECIES:
		if source.def == ForestArt.frame(kind):
			return kind
	return ""

static func accepts(source: IsoSprite) -> bool:
	return not species_of(source).is_empty() and source.visible and source.clip == Vector2.ZERO and source.draw_shift == Vector2.ZERO

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, ink: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0 - centre) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for p in [a, c, b]:
		tool.set_normal(normal)
		tool.set_color(ink)
		tool.add_vertex(p)

static func _leaf(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, ink: Color) -> void:
	var direction := (b - a).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var normal := side.cross(direction).normalized()
	var middle := a.lerp(b, 0.48)
	# Four-edge cross section gives a real convex volume, never a facing quad.
	var ring := [middle + side * width, middle + normal * width * 0.18, middle - side * width, middle - normal * width * 0.18]
	for i in 4:
		_triangle(tool, a, ring[i], ring[(i + 1) % 4], middle, ink)
		_triangle(tool, b, ring[(i + 1) % 4], ring[i], middle, ink)

static func _stem(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, ink: Color) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.RIGHT).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.FORWARD
	var other := along.cross(side).normalized()
	for i in 6:
		var first := (side * cos(TAU * i / 6.0) + other * sin(TAU * i / 6.0)) * radius
		var second := (side * cos(TAU * (i + 1) / 6.0) + other * sin(TAU * (i + 1) / 6.0)) * radius
		_triangle(tool, a + first, b + first * 0.6, b + second * 0.6, (a + b) * 0.5, ink)
		_triangle(tool, a + first, b + second * 0.6, a + second, (a + b) * 0.5, ink)
		_triangle(tool, a, a + second, a + first, (a + b) * 0.5, ink)
		_triangle(tool, b, b + first * 0.6, b + second * 0.6, (a + b) * 0.5, ink)

static func mesh_library() -> Dictionary:
	if not _library.is_empty():
		return _library
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	for kind: String in SPECIES:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var green := Color("455c34") if kind == "fern" else Color("566c37")
		if kind == "grass":
			for i in 7:
				var angle := TAU * i / 7.0
				var direction := Vector3(cos(angle), 0, sin(angle))
				var root := direction * 0.06
				var bend := direction * 0.19 + Vector3.UP * (0.46 + 0.04 * (i % 3))
				var tip := direction * 0.40 + Vector3.UP * (1.0 - 0.09 * (i % 3))
				_leaf(tool, root, bend, 0.045, green)
				_leaf(tool, bend, tip, 0.03, green.lightened(0.05))
		elif kind == "fern":
			_stem(tool, Vector3.ZERO, Vector3(0, 0.92, 0), 0.014, green.darkened(0.12))
			for i in 7:
				var y := 0.18 + i * 0.105
				var spread := 0.40 * (1.0 - float(i) / 9.0)
				for side in [-1.0, 1.0]:
					_leaf(tool, Vector3(0, y, 0), Vector3(side * spread, y + 0.14, 0.09 * sin(i)), 0.07, green.lightened(i * 0.008))
			_leaf(tool, Vector3(0, 0.82, 0), Vector3(0.04, 1, 0), 0.045, green)
		else:
			var petal := Color("cfbc87") if kind == "flowers_white" else Color("c68a36")
			for i in 3:
				var angle := TAU * i / 3.0 + 0.4
				var root := Vector3(cos(angle), 0, sin(angle)) * 0.09
				var top := root + Vector3(cos(angle) * 0.07, 0.82 + i * 0.07, sin(angle) * 0.07)
				_stem(tool, root, top, 0.014, green)
				for side in [-1.0, 1.0]:
					var leaf_root := root.lerp(top, 0.4)
					_leaf(tool, leaf_root, leaf_root + Vector3(side * 0.23, 0.15, 0.07), 0.06, green)
				for k in 5:
					var petal_angle := TAU * k / 5.0
					var end := top + Vector3(cos(petal_angle) * 0.10, 0.04, sin(petal_angle) * 0.10)
					_leaf(tool, top, end, 0.045, petal)
				_leaf(tool, top - Vector3.UP * 0.025, top + Vector3.UP * 0.04, 0.035, Color("9b762d"))
		var mesh := tool.commit()
		mesh.surface_set_material(0, material)
		_library[kind] = mesh
	return _library

static func build(preview: Node, parent: Node3D, world: Node2D) -> Dictionary:
	var library := mesh_library()
	var root := Node3D.new()
	root.name = "NativeBorderFlora"
	parent.add_child(root)
	var owned := {}
	var buckets := {}
	var placements: Array[Dictionary] = []
	for child in world.get_children():
		if not child is IsoSprite or not accepts(child):
			continue
		var source := child as IsoSprite
		var species := species_of(source)
		var height := float(source.def.get("height", 0)) * source.k / (Ortho3DPreview.GROUND_PER_METER * Iso.S)
		if not is_finite(height) or height <= 0.0 or height > 2.5:
			continue
		var at := Ortho3DPreview.ground_position(source.global_position, preview.surface_height(source.global_position))
		var chunk := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
		var key := "%d:%d:%s" % [chunk.x, chunk.y, species]
		var seed := Ortho3DForestTrees.placement_seed("%s:%.4f:%.4f" % [species, source.global_position.x, source.global_position.y])
		var basis := Basis(Vector3.UP, float(seed % 65536) * TAU / 65536.0).scaled(Vector3.ONE * height)
		var record := {"source_id": source.get_instance_id(), "species": species, "transform": Transform3D(basis, at), "source_foot": source.global_position, "height": height}
		if not buckets.has(key):
			buckets[key] = {"species": species, "chunk": chunk, "entries": []}
		buckets[key]["entries"].append(record)
		owned[source.get_instance_id()] = true
		placements.append(record)
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		var entries: Array = bucket["entries"]
		var chunk: Vector2i = bucket["chunk"]
		var origin := Vector3(chunk.x * CHUNK, 0, chunk.y * CHUNK)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = library[bucket["species"]]
		multi.instance_count = entries.size()
		var bounds := AABB()
		for i in entries.size():
			var local: Transform3D = entries[i]["transform"]
			local.origin -= origin
			multi.set_instance_transform(i, local)
			var box: AABB = local * multi.mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		multi.custom_aabb = bounds.grow(0.02)
		var batch := MultiMeshInstance3D.new()
		batch.name = "Flora_" + key.replace(":", "_")
		batch.position = origin
		batch.multimesh = multi
		root.add_child(batch)
	var report := {"owned_source_ids": owned, "placements": placements, "groups": root.get_child_count(), "root": root, "billboards": false}
	root.set_meta("native_flora_report", report)
	return report
