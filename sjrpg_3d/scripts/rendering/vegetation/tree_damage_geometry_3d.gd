class_name TreeDamageGeometry3D
extends RefCounted
## 원래 GLB의 피벗·UV·줄기 기하를 공유하고 손상 표면만 다섯 패밀리로 캐시한다.

static var _meshes: Dictionary = {}
static var _inks: Dictionary = {}
static var _fire_anchors: Dictionary = {}
static var _fragments: Dictionary = {}

const BREAK_PIECES := 6
const FLAMES_PER_TREE := 8


## 줄기와 가지의 실제 정점에서 높이·방향이 다른 부착점을 고른다.
static func fire_anchors(variant: int) -> PackedVector3Array:
	if _fire_anchors.has(variant):
		return _fire_anchors[variant]
	var wood := mesh(variant, "charred")
	var points := TreeGeometry3D._points(wood)
	var bounds := wood.get_aabb()
	var anchors := PackedVector3Array()
	for index in FLAMES_PER_TREE:
		var angle := float(index) * 2.39996323
		var level := 0.20 + float(index % 4) * 0.18
		var target := bounds.get_center()
		target.y = bounds.position.y + bounds.size.y * level
		target.x += cos(angle) * bounds.size.x * 0.38
		target.z += sin(angle) * bounds.size.z * 0.38
		var nearest := points[0]
		var distance := INF
		for point in points:
			var score := point.distance_squared_to(target)
			if score < distance:
				distance = score
				nearest = point
		anchors.append(nearest)
	_fire_anchors[variant] = anchors
	return anchors


## 실제 GLB 삼각형·UV를 보존해 아래 줄기/윗줄기/네 방향 가지로 나눈다.
## 캐시는 로딩 중 준비하며 파괴 순간에는 공유 메시만 재사용한다.
static func fragments(variant: int, state: String) -> Array[Mesh]:
	var key := "%d:%s" % [variant, state]
	if _fragments.has(key):
		return _fragments[key]
	var source := mesh(variant, state)
	var bounds := source.get_aabb()
	var parts: Array[Mesh] = []
	for piece in BREAK_PIECES:
		var result := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var colors: PackedColorArray = (
				arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			)
			var indices: PackedInt32Array = (
				arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			)
			var count := vertices.size() if indices.is_empty() else indices.size()
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(source.surface_get_material(surface))
			var used := false
			for start in range(0, count, 3):
				var triangle := PackedInt32Array()
				var center := Vector3.ZERO
				for corner in 3:
					var index := start + corner if indices.is_empty() else indices[start + corner]
					triangle.append(index)
					center += vertices[index] / 3.0
				if _piece(center, bounds) != piece:
					continue
				used = true
				for index in triangle:
					builder.set_normal(normals[index])
					builder.set_uv(uvs[index])
					if not colors.is_empty():
						builder.set_color(colors[index])
					builder.add_vertex(vertices[index])
			if used:
				builder.commit(result)
		parts.append(result if result.get_surface_count() > 0 else null)
	_fragments[key] = parts
	return parts


static func _piece(center: Vector3, bounds: AABB) -> int:
	if center.y < bounds.position.y + bounds.size.y * 0.26:
		return 0
	if Vector2(center.x, center.z).length() < maxf(bounds.size.x, bounds.size.z) * 0.10:
		return 1
	return 2 + int(center.x >= 0.0) + 2 * int(center.z >= 0.0)


static func mesh(variant: int, state: String) -> Mesh:
	var key := "%d:%s" % [variant, state]
	if _meshes.has(key):
		return _meshes[key]
	var source: Mesh = TreeGeometry3D.mesh_library()[variant]["mesh"]
	if state in ["ash", "felled"]:
		var stump := CylinderMesh.new()
		stump.top_radius = 0.16
		stump.bottom_radius = 0.28
		stump.height = 0.24 if state == "felled" else 0.10
		stump.radial_segments = 9
		stump.rings = 1
		stump.material = _ink(TreeGeometry3D._bark_material, state)
		# Geometry is based at zero, never re-fit a remnant to the former crown height.
		var surface := SurfaceTool.new()
		surface.append_from(stump, 0, Transform3D(Basis.IDENTITY, Vector3.UP * stump.height * 0.5))
		var result := surface.commit()
		result.surface_set_material(0, stump.material)
		_meshes[key] = result
		return result
	var result := ArrayMesh.new()
	for index in source.get_surface_count():
		var ink: StandardMaterial3D = source.surface_get_material(index)
		if state == "charred" and ink != TreeGeometry3D._bark_material:
			continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(index))
		result.surface_set_material(result.get_surface_count() - 1, _ink(ink, state))
	_meshes[key] = result
	return result


static func _ink(source: StandardMaterial3D, state: String) -> Material:
	var key := "%d:%s" % [source.get_instance_id(), state]
	if _inks.has(key):
		return _inks[key]
	if state == "frozen":
		var frost := ShaderMaterial.new()
		frost.shader = load("res://assets/materials/vegetation/tree_frost.gdshader")
		frost.set_shader_parameter("albedo_texture", source.albedo_texture)
		frost.set_shader_parameter("cutout", source != TreeGeometry3D._bark_material)
		frost.set_shader_parameter("cutout_threshold", source.alpha_scissor_threshold)
		_inks[key] = frost
		return frost
	var ink := source.duplicate() as StandardMaterial3D
	match state:
		"burning":
			ink.albedo_color = Color(0.55, 0.40, 0.25)
			ink.roughness = 1.0
		"charred", "ash":
			ink.albedo_color = Color(0.19, 0.18, 0.17)
			ink.roughness = 1.0
		_:
			ink.albedo_color = Color(0.75, 0.64, 0.46)
	_inks[key] = ink
	return ink
