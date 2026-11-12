class_name TreeGeometry3D
extends RefCounted
## Fixed three-dimensional leaf sprays and branches; source simulation keeps tree collision.
## Alpha-cutout leaves receive actual light and cast depth-tested shadows, never billboard.

const PATHS := ["res://assets/models/vegetation/town_oak_0/visual.tscn", "res://assets/models/vegetation/town_oak_1/visual.tscn", "res://assets/models/vegetation/dark_fir/visual.tscn", "res://assets/models/vegetation/black_pine/visual.tscn", "res://assets/models/vegetation/spire_cypress/visual.tscn"]
const LEAVES := "res://assets/materials/shared/tree_leaves.webp"
const BARK := "res://assets/materials/shared/bark.webp"
const CAMERA_UP := Vector3(-0.408248290463863, 0.816496580927726, -0.408248290463863)
const CAMERA_RIGHT := Vector3(0.707106781186548, 0, -0.707106781186548)
static var _default_library: Array[Dictionary] = []
static var _bark_material: StandardMaterial3D
static var _needle_material: StandardMaterial3D

static func crown_ratio(variant: int) -> float:
	return [1.0, 1.0, 0.68, 0.86, 0.52][variant]


static func _material(texture: Texture2D, leaves: bool) -> StandardMaterial3D:
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = texture
	ink.roughness = 0.96
	ink.vertex_color_use_as_albedo = true
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if leaves:
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		ink.alpha_scissor_threshold = 0.42
		ink.cull_mode = BaseMaterial3D.CULL_DISABLED
		ink.backlight_enabled = true
		ink.backlight = Color(0.10, 0.13, 0.06)
	return ink


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


static func _triangle_count(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return count


static func triangle_counts(library: Array[Dictionary]) -> Array[int]:
	var counts: Array[int] = []
	for entry in library:
		counts.append(int(entry.get("triangles", 0)))
	return counts


static func _points(mesh: Mesh) -> PackedVector3Array:
	var points := PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		points.append_array(vertices)
	return points


## 마을과 외곽 숲은 5종 메시와 공유 재질을 재사용하고 청크마다 복제하지 않는다.
## Only the default family is cached; temporary comparison textures cannot grow a registry.
static func mesh_library(leaf_texture_path: String = LEAVES) -> Array[Dictionary]:
	if leaf_texture_path == LEAVES and not _default_library.is_empty():
		return _default_library
	var library: Array[Dictionary] = []
	var leaf_texture: Texture2D = load(leaf_texture_path)
	var bark_texture: Texture2D = load(BARK)
	var leaf_material := _material(leaf_texture, true)
	var bark_material := _material(bark_texture, false)
	var needle_material := _material(load(WildVegetationRenderer3D.NEEDLES) if leaf_texture_path == LEAVES else leaf_texture, true)
	needle_material.alpha_scissor_threshold = 0.28
	if leaf_texture_path == LEAVES:
		_bark_material = bark_material
		_needle_material = needle_material
	for path: String in PATHS:
		var entry := {"path": path, "mesh": null, "points": PackedVector3Array(), "triangles": 0}
		library.append(entry)
		if not ResourceLoader.exists(path):
			continue
		var resource: Resource = load(path)
		var mesh: Mesh
		var imported: Node
		if resource is Mesh:
			mesh = resource.duplicate() as Mesh
		elif resource is PackedScene:
			imported = (resource as PackedScene).instantiate()
			var source := _find_mesh(imported)
			if source != null and source.mesh != null:
				mesh = source.mesh.duplicate() as Mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var original := mesh.surface_get_material(surface)
				var is_leaf := original != null and original.resource_name.begins_with("LeafSprays")
				mesh.surface_set_material(surface, (needle_material if original.resource_name == "LeafSpraysNeedles" else leaf_material) if is_leaf else bark_material)
			entry["mesh"] = mesh
			entry["points"] = _points(mesh)
			entry["triangles"] = _triangle_count(mesh)
		if imported != null:
			imported.free()
	if leaf_texture_path == LEAVES:
		_default_library = library
	return library


## Fit the actual projected mesh, preserving ground origin and positive native scale.
## x/z share one factor, so an oak stays volumetric rather than flattening toward camera.
static func fit_basis(points: PackedVector3Array, width: float, top: float, yaw: float) -> Basis:
	var rotation := Basis(Vector3.UP, yaw)
	var low := INF
	var high := -INF
	for vertex in points:
		var horizontal := CAMERA_RIGHT.dot(rotation * vertex)
		low = minf(low, horizontal)
		high = maxf(high, horizontal)
	var radial := width / maxf(high - low, 0.001)
	var vertical := INF
	for vertex in points:
		var turned := rotation * vertex
		if turned.y <= 0.0001:
			continue
		# Every vertex stays below the measured source top; at least one touches it.
		var allowance := (top - radial * (CAMERA_UP.x * turned.x + CAMERA_UP.z * turned.z)) / (CAMERA_UP.y * turned.y)
		vertical = minf(vertical, allowance)
	if not is_finite(vertical) or vertical <= 0.0:
		vertical = 1.0
	return rotation * Basis.from_scale(Vector3(radial, vertical, radial))


static func projected_bounds(points: PackedVector3Array, basis: Basis) -> Rect2:
	var bounds := Rect2()
	var first := true
	for vertex in points:
		var at := basis * vertex
		var flat := Vector2(CAMERA_RIGHT.dot(at), -CAMERA_UP.dot(at))
		if first:
			bounds = Rect2(flat, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(flat)
	return bounds


static func build(renderer: Node, leaf_texture_path: String = LEAVES) -> Node3D:
	var root := Node3D.new()
	root.name = "NativeTownTrees"
	renderer.stage.add_child(root)
	var library := mesh_library(leaf_texture_path)
	# 배치된 메시 합계이며 카메라 컬링 후 실제 GPU draw 수와는 구별한다.
	var report := {"trees": [], "groups": 0, "triangles_by_variant": triangle_counts(library), "triangles": 0, "billboards": false, "source_count": renderer.game.village.town_trees.size(), "leaf_texture": leaf_texture_path, "max_fit_error": 0.0}
	var source_trees: Array = renderer.game.village.town_trees
	var factor: float = WorldSpace3D.GROUND_UNITS_PER_METER * WorldSpace3D.GROUND_PROJECTION_FACTOR
	for variant in PATHS.size():
		var selected: Array[IsoSprite] = []
		for index in source_trees.size():
			if int(source_trees[index].get_meta("native_tree_variant", index % PATHS.size())) == variant:
				selected.append(source_trees[index])
		if selected.is_empty():
			continue
		var mesh := library[variant]["mesh"] as Mesh
		if mesh == null:
			continue
		report["triangles"] += int(library[variant]["triangles"]) * selected.size()
		var points: PackedVector3Array = library[variant]["points"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = selected.size()
		var batch := MultiMeshInstance3D.new()
		batch.name = "OakVariant%d" % variant
		batch.set_meta("occlusion_static_instances", true)
		batch.multimesh = multi
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(batch)
		for index in selected.size():
			var tree: IsoSprite = selected[index]
			var frame: Array = tree.def["source"]
			var foot: Array = tree.def["foot"]
			var width: float = float(frame[2]) * tree.k / factor * crown_ratio(variant)
			var top: float = (float(foot[1]) - float(frame[1])) * tree.k / factor
			var yaw := fmod(float(index) * 2.39996322973 + float(variant) * 0.71, TAU)
			var basis := fit_basis(points, width, top, yaw)
			var position := WorldSpace3D.projected_to_world(tree.position)
			var transform := Transform3D(basis, position)
			multi.set_instance_transform(index, transform)
			multi.set_instance_color(index, tree.modulate_color)
			var bounds := projected_bounds(points, basis)
			var error := maxf(absf(bounds.size.x - width), absf(bounds.position.y + top))
			report["max_fit_error"] = maxf(float(report["max_fit_error"]), error)
			report["trees"].append({"source": weakref(tree), "batch": batch, "index": index, "position": position, "transform": transform, "target_width": width, "target_top": top, "projected_bounds": bounds, "fit_error": error})
		report["groups"] = int(report["groups"]) + 1
	WildVegetationRenderer3D.build_shrubs(renderer, root, source_trees)
	root.set_meta("native_tree_report", report)
	return root
