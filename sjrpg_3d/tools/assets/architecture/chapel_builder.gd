class_name NativeChapelBuilder
extends RefCounted
## 실제 사용자 화면의 돌출 입구·두 박공·종탑과 생성형 전체 면 그림을 결합한다.
## 창·문 세공은 원화, 몸체·지붕·열린 종탑·부벽·계단은 실제 입체다.

const ARCH_SEGMENTS := 12
const SLATE_TILE := 2.6
const SLATE_COURSES := 8
const SLATE_PITCH := SLATE_TILE / SLATE_COURSES
const MedievalDetails := preload("res://tools/assets/architecture/medieval_details.gd")
var _root: Node3D
var _materials := {}
var _surfaces := {}
var _box_arrays: Array
var _triangles := 0
var _pieces := 0
var _roof_rows := 0
var _offset := Vector3.ZERO
var _facade_reliefs := 0


static func build(
	presenter: Node, root: Node3D, width: float, depth: float, height: float
) -> Dictionary:
	var builder := NativeChapelBuilder.new()
	builder._root = root
	builder._materials = presenter._materials.duplicate()
	builder._materials["slate"] = BuildingSurfaceMaterials.roof_material("chapel")
	return builder._build(width, depth, height)


func _build(width: float, depth: float, _height: float) -> Dictionary:
	width *= ChapelPlan3D.FOOTPRINT_SCALE
	depth *= ChapelPlan3D.FOOTPRINT_SCALE
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_box_arrays = unit.surface_get_arrays(0)
	_materials["stone"] = BuildingSurfaceMaterials.material("chapel", Vector3.ONE, 3)
	_materials["stone"].set_shader_parameter("tile", true)
	_materials["facade"] = NativeChapelFacade.material()
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("82704a")
	bronze.metallic = 0.5
	bronze.roughness = 0.65
	_materials["bronze"] = bronze
	_materials["lead"] = _materials["iron"]
	var porch_width := width * 0.40
	var nave_width := width * 0.60
	var porch_x := ChapelPlan3D.entrance_x(width)
	var nave_x := width * 0.20
	var nave_front := depth * ChapelPlan3D.NAVE_FRONT_FRACTION
	var nave_depth := depth * ChapelPlan3D.NAVE_DEPTH_FRACTION
	# 돌출된 왼쪽 입구와 오른쪽 본당이 각각 독립한 박공을 갖는다.
	_hall(
		Vector3(porch_x, 0, 0),
		porch_width,
		depth,
		ChapelPlan3D.PORCH_EAVES,
		ChapelPlan3D.PORCH_RISE,
		0
	)
	_hall(
		Vector3(nave_x, 0, (nave_front - depth * 0.5) * 0.5),
		nave_width,
		nave_depth,
		ChapelPlan3D.NAVE_EAVES,
		ChapelPlan3D.NAVE_RISE,
		1
	)
	_offset = Vector3.ZERO
	var tower_height := _tower(Vector3(porch_x, 0, -depth * 0.16), 5.0)
	_box(Vector3(0, 0.12, 0), Vector3(width + 0.30, 0.24, depth + 0.30), "stone")
	_box(Vector3(0, 0.26, 0), Vector3(width + 0.18, 0.04, depth + 0.18), "stone")
	for tier: Dictionary in ChapelPlan3D.tiers(Vector2.ZERO, width, depth):
		var rect: Rect2 = tier["rect"]
		var tall: float = tier["height"]
		_box(
			Vector3(rect.get_center().x, tall * 0.5, rect.get_center().y),
			Vector3(rect.size.x, tall, rect.size.y),
			"stone"
		)
	for side: float in [-1.0, 1.0]:
		var fixture := Transform3D(Basis.IDENTITY, Vector3(porch_x + side * porch_width * .41, 2.18, depth * .5 + .02))
		MedievalDetails.lantern(self, fixture, "lead", "bronze")
	var meshes := _flush()
	var bounds := meshes[0].mesh.get_aabb()
	for mesh in meshes:
		bounds = bounds.merge(mesh.mesh.get_aabb())
	var report := {
		"triangles": _triangles,
		"pieces": _pieces,
		"surfaces": meshes.size(),
		"meshes": meshes,
		"footprint": Vector2(width, depth),
		"floor_height": ChapelPlan3D.FLOOR,
		"door_width": porch_width * 0.65,
		"door_height": 3.0,
		"door_recess": 0.0,
		"door_bottom": Vector3(porch_x, ChapelPlan3D.FLOOR, depth * 0.5),
		"windows": [],
		"oculi": [],
		"roof_rows": _roof_rows,
		"tower_height": tower_height,
		"hybrid_facade": true,
		"gable_count": 2,
		"gable_heights":
		Vector2(
			ChapelPlan3D.PORCH_EAVES + ChapelPlan3D.PORCH_RISE,
			ChapelPlan3D.NAVE_EAVES + ChapelPlan3D.NAVE_RISE
		),
		"facade_reliefs": _facade_reliefs,
		"entrance_offset": porch_x,
		"nave_front": nave_front,
		"reference": "assets/source/style/approved-game-reference.jpg",
		"craft_family": MedievalDetails.FAMILY,
		"lanterns": 2,
		"bounds": bounds
	}
	_root.set_meta("chapel_detail", report)
	return report


func _hall(
	at: Vector3, width: float, depth: float, eaves: float, rise: float, front_cell: int
) -> void:
	_offset = at
	var bottom := ChapelPlan3D.FLOOR
	_box(Vector3(0, (bottom + eaves) * 0.5, 0), Vector3(width, eaves - bottom, depth), "stone")
	# 개구부 세공은 한 면 원화로, 지붕과 벽 두께·부벽은 실제 부피로 표현한다.
	for side: float in [-1.0, 1.0]:
		var frame := Transform3D(
			Basis(Vector3.UP, side * PI * 0.5), Vector3(side * (width * 0.5 + 0.003), 0, 0)
		)
		_facade(depth, bottom, eaves, 0.0, frame, 2 if front_cell == 1 else 3)
		for z: float in [-depth * 0.46, depth * 0.46]:
			_box(Vector3(side * width * 0.5, 1.68, z), Vector3(0.18, 2.8, 0.24), "stone")
			_taper_cap(Vector3(side * width * 0.5, 3.18, z), Vector2(0.24, 0.30), 0.24)
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 0, depth * 0.5 + 0.005))
	_facade(width, bottom, eaves, rise, front, front_cell)
	var rear := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -depth * 0.5 - 0.005))
	_facade(width, bottom, eaves, rise, rear, 3)
	_roof(width, depth, eaves, rise)


func _facade(
	width: float, bottom: float, eaves: float, rise: float, frame: Transform3D, cell: int
) -> void:
	var local: Array[Vector3] = [
		Vector3(-width * 0.5, bottom, 0),
		Vector3(width * 0.5, bottom, 0),
		Vector3(width * 0.5, eaves, 0),
		Vector3(-width * 0.5, eaves, 0)
	]
	if rise > 0.0:
		local.insert(3, Vector3(0, eaves + rise, 0))
	var corner := Vector2(cell % 2, cell / 2)
	for index in range(1, local.size() - 1):
		var points: Array[Vector3] = []
		var uv: Array[Vector2] = []
		for vertex: int in [0, index, index + 1]:
			var p := local[vertex]
			points.append(frame * p)
			var unit_uv := Vector2(
				p.x / width + 0.5, 1.0 - (p.y - bottom) / (eaves + rise - bottom)
			)
			uv.append((corner + Vector2(0.018, 0.018) + unit_uv * 0.964) * 0.5)
		_triangle(points, uv, frame.basis.z, "facade")
	_facade_relief(width, bottom, eaves + rise, frame, cell)


## 그림의 정규 좌표를 실제 벽과 같은 UV 역변환으로 옮긴다. 몰딩과 그림의 경계가 같다.
func _painted_point(uv: Vector2, width: float, bottom: float, top: float, cell: int) -> Vector2:
	var unit := (uv - Vector2.ONE * .018) / .964
	return Vector2((unit.x - .5) * width, NativeChapelFacade.height(cell, uv.y, bottom, top))


func _facade_relief(width: float, bottom: float, top: float, frame: Transform3D, cell: int) -> void:
	var arches: Array[Array] = []
	if cell == 0:
		arches.append([.19, .81, .985, .60, .33, .075])
	elif cell == 1:
		arches.append([.08, .46, .95, .64, .44, .065])
		arches.append([.54, .92, .95, .64, .44, .065])
		arches.append([.40, .60, .39, .16, .03, .045])
	elif cell == 2:
		arches.append([.07, .43, .88, .31, .11, .065])
		arches.append([.57, .93, .88, .31, .11, .065])
	for plan: Array in arches:
		var low := _painted_point(Vector2(plan[0], plan[2]), width, bottom, top, cell)
		var high := _painted_point(Vector2(plan[1], plan[4]), width, bottom, top, cell)
		var shoulder := _painted_point(Vector2(.5, plan[3]), width, bottom, top, cell).y
		var thickness: float = plan[5]
		_painted_arch(low.x, high.x, low.y, shoulder, high.y, thickness, frame)
		_facade_reliefs += 1


static func _painted_path(
	left: float, right: float, bottom: float, shoulder: float, top: float
) -> PackedVector2Array:
	var path := PackedVector2Array([Vector2(left, bottom), Vector2(left, shoulder)])
	var centre := (left + right) * .5
	for index in range(1, 13):
		var t := float(index) / 12.0
		path.append(
			Vector2(lerpf(left, centre, t * t), lerpf(shoulder, top, 1.0 - pow(1.0 - t, 2)))
		)
	for index in range(1, 13):
		var t := float(index) / 12.0
		path.append(
			Vector2(lerpf(centre, right, 1.0 - pow(1.0 - t, 2)), lerpf(top, shoulder, t * t))
		)
	path.append(Vector2(right, bottom))
	return path


func _painted_arch(
	left: float,
	right: float,
	bottom: float,
	shoulder: float,
	top: float,
	thickness: float,
	frame: Transform3D
) -> void:
	var outer := _painted_path(left, right, bottom, shoulder, top)
	var inner := _painted_path(
		left + thickness, right - thickness, bottom, shoulder - thickness * .2, top - thickness
	)
	var outer_frame := frame.translated_local(Vector3(0, 0, .055))
	for index in outer.size() - 1:
		var a := outer[index].lerp(outer[index + 1], .01)
		var b := outer[index + 1].lerp(outer[index], .01)
		var c := inner[index + 1].lerp(inner[index], .01)
		var d := inner[index].lerp(inner[index + 1], .01)
		_prism(PackedVector2Array([a, b, c, d]), .13, outer_frame, "stone")
	var sill := BoxMesh.new()
	sill.size = Vector3(right - left + .10, .10, .22)
	_append_mesh(
		sill,
		frame * Transform3D(Basis.IDENTITY, Vector3((left + right) * .5, bottom - .025, .065)),
		"stone"
	)


static func _arch_path(width: float, bottom: float, shoulder: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	var half := width * 0.5
	for step in 7:
		path.append(Vector2(-half, lerpf(bottom, shoulder, step / 6.0)))
	for step in range(1, ARCH_SEGMENTS + 1):
		var angle := lerpf(PI, PI * 2.0 / 3.0, float(step) / ARCH_SEGMENTS)
		path.append(Vector2(half + width * cos(angle), shoulder + width * sin(angle)))
	for step in range(1, ARCH_SEGMENTS + 1):
		var angle := lerpf(PI / 3.0, 0.0, float(step) / ARCH_SEGMENTS)
		path.append(Vector2(-half + width * cos(angle), shoulder + width * sin(angle)))
	for step in range(1, 7):
		path.append(Vector2(half, lerpf(shoulder, bottom, step / 6.0)))
	return path


func _arch_ring(
	width: float,
	bottom: float,
	shoulder: float,
	thickness: float,
	depth: float,
	transform: Transform3D,
	material := "stone"
) -> void:
	var inner := _arch_path(width, bottom, shoulder)
	var outer := _arch_path(width + thickness * 2.0, bottom, shoulder)
	for index in inner.size() - 1:
		# Small physical mortar joints keep the pointed curve's voussoirs legible.
		var a := outer[index].lerp(outer[index + 1], 0.015)
		var b := outer[index + 1].lerp(outer[index], 0.015)
		var c := inner[index + 1].lerp(inner[index], 0.015)
		var d := inner[index].lerp(inner[index + 1], 0.015)
		_prism(PackedVector2Array([a, b, c, d]), depth, transform, material)


func _roof(width: float, depth: float, top: float, rise: float) -> void:
	var half := width * 0.5 + 0.19
	var reach := depth * 0.5 + 0.20
	var length := sqrt(half * half + rise * rise)
	var rows := maxi(1, ceili(length / SLATE_PITCH))
	_roof_rows += rows
	for side in [-1.0, 1.0]:
		var normal := Vector3(side * rise / half, 1, 0).normalized()
		# A covered underlay and real raised course lips share the village slate grid.
		var base: Array[Vector3] = [
			Vector3(side * half, top, -reach),
			Vector3(side * half, top, reach),
			Vector3(0, top + rise, reach),
			Vector3(0, top + rise, -reach)
		]
		var base_uv: Array[Vector2] = [
			Vector2(-reach, 0) / SLATE_TILE,
			Vector2(reach, 0) / SLATE_TILE,
			Vector2(reach, length) / SLATE_TILE,
			Vector2(-reach, length) / SLATE_TILE
		]
		_triangle(
			[base[0], base[1], base[2]], [base_uv[0], base_uv[1], base_uv[2]], normal, "slate"
		)
		_triangle(
			[base[0], base[2], base[3]], [base_uv[0], base_uv[2], base_uv[3]], normal, "slate"
		)
		for row in rows:
			var low := row * SLATE_PITCH / length
			var high := minf(1.0, (row + 1) * SLATE_PITCH / length)
			var a := Vector3(side * half * (1.0 - low), top + rise * low, -reach) + normal * 0.028
			var b := Vector3(a.x, a.y, reach)
			var c := Vector3(side * half * (1.0 - high), top + rise * high, reach) + normal * 0.006
			var d := Vector3(c.x, c.y, -reach)
			var uv: Array[Vector2] = [
				Vector2(-reach, low * length) / SLATE_TILE,
				Vector2(reach, low * length) / SLATE_TILE,
				Vector2(reach, high * length) / SLATE_TILE,
				Vector2(-reach, high * length) / SLATE_TILE
			]
			var tile_normal := (b - a).cross(d - a).normalized()
			if tile_normal.y < 0.0:
				tile_normal = -tile_normal
			_triangle([a, b, c], [uv[0], uv[1], uv[2]], tile_normal, "slate")
			_triangle([a, c, d], [uv[0], uv[2], uv[3]], tile_normal, "slate")
			var low_a := a - normal * 0.022
			var low_b := b - normal * 0.022
			var edge_normal := Vector3(side * normal.y, -absf(normal.x), 0).normalized()
			var drop := Vector2(0, 0.022 / SLATE_TILE)
			_triangle([a, low_a, low_b], [uv[0], uv[0] + drop, uv[1] + drop], edge_normal, "slate")
			_triangle([a, low_b, b], [uv[0], uv[1] + drop, uv[1]], edge_normal, "slate")
		for end in [-1.0, 1.0]:
			_beam(
				Vector3(side * half, top + 0.04, end * (reach - 0.025)),
				Vector3(0, top + rise + 0.06, end * (reach - 0.025)),
				0.11,
				"stone"
			)
		_box(
			Vector3(side * (half - 0.025), top - 0.035, 0),
			Vector3(0.10, 0.13, depth + 0.40),
			"stone"
		)
		for corbel in 9:
			_box(
				Vector3(
					side * (width * 0.5 - 0.01),
					top - 0.17,
					lerpf(-depth * 0.43, depth * 0.43, corbel / 8.0)
				),
				Vector3(0.21, 0.16, 0.10),
				"stone"
			)
	var caps := ceili(depth / 0.38)
	for cap in caps:
		_box(
			Vector3(0, top + rise + 0.07, -depth * 0.5 + (cap + 0.5) * depth / caps),
			Vector3(0.22, 0.12, depth / caps - 0.012),
			"stone"
		)


func _tower(center: Vector3, top: float) -> float:
	var half := 0.76
	_box(center + Vector3.UP * top * 0.5, Vector3(1.52, top, 1.52), "stone")
	var bay_bottom := top + 0.10
	var bay_top := bay_bottom + 1.35
	for y: float in [top, bay_top + 0.06]:
		_box(center + Vector3.UP * y, Vector3(1.70, 0.15, 1.70), "stone")
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_box(
				center + Vector3(x * 0.64, (bay_bottom + bay_top) * 0.5, z * 0.64),
				Vector3(0.24, 1.35, 0.24),
				"stone"
			)
	for face in 4:
		var basis := Basis(Vector3.UP, face * PI * 0.5)
		var shoulder := bay_top - 0.82 * sqrt(3.0) * 0.5
		_arch_ring(
			0.82,
			bay_bottom,
			shoulder,
			0.12,
			0.20,
			Transform3D(basis, center + basis * Vector3(0, 0, half))
		)
	_bell(center + Vector3.UP * (bay_bottom + 0.65))
	for tier in 3:
		var roof := CylinderMesh.new()
		roof.radial_segments = 4
		roof.rings = 0
		roof.bottom_radius = 1.24 - tier * 0.30
		roof.top_radius = 0.90 - tier * 0.30
		roof.height = 0.44
		_append_mesh(
			roof,
			Transform3D(
				Basis(Vector3.UP, PI * 0.25), center + Vector3.UP * (bay_top + 0.30 + tier * 0.40)
			),
			"slate"
		)
	_box(center + Vector3.UP * (bay_top + 1.29), Vector3(0.36, 0.12, 0.36), "stone")
	return bay_top + 1.35


func _bell(at: Vector3) -> void:
	var profile := [
		Vector2(0.08, 0.45),
		Vector2(0.13, 0.36),
		Vector2(0.18, 0.26),
		Vector2(0.20, 0.02),
		Vector2(0.31, -0.12),
		Vector2(0.34, -0.15)
	]
	for row in profile.size() - 1:
		for segment in 16:
			var a := segment * TAU / 16.0
			var b := (segment + 1) * TAU / 16.0
			var low: Vector2 = profile[row]
			var high: Vector2 = profile[row + 1]
			var points := [
				at + Vector3(cos(a) * low.x, low.y, sin(a) * low.x),
				at + Vector3(cos(b) * low.x, low.y, sin(b) * low.x),
				at + Vector3(cos(b) * high.x, high.y, sin(b) * high.x),
				at + Vector3(cos(a) * high.x, high.y, sin(a) * high.x)
			]
			var normal := Vector3(cos((a + b) * 0.5), 0.2, sin((a + b) * 0.5)).normalized()
			_quad(points, normal, "bronze")
	_beam(at + Vector3(0, -0.12, 0), at + Vector3(0, 0.40, 0), 0.045, "lead")
	_sphere(at + Vector3(0, -0.16, 0), 0.063, "lead")


func _taper_cap(at: Vector3, size: Vector2, tall: float) -> void:
	var cap := CylinderMesh.new()
	cap.top_radius = 0.42
	cap.bottom_radius = 0.71
	cap.height = 1.0
	cap.radial_segments = 4
	cap.rings = 1
	_append_mesh(
		cap,
		Transform3D(Basis(Vector3.UP, PI * 0.25).scaled(Vector3(size.x, tall, size.y)), at),
		"stone"
	)


func _sphere(
	at: Vector3, radius: float, material: String, transform := Transform3D.IDENTITY
) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_append_mesh(sphere, transform * Transform3D(Basis.IDENTITY, at), material)


func _beam(
	a: Vector3, b: Vector3, thickness: float, material: String, transform := Transform3D.IDENTITY
) -> void:
	var direction := b - a
	var basis := Basis(Quaternion(Vector3(0, 0, 1), direction.normalized()))
	_append_arrays(
		_box_arrays,
		(
			transform
			* Transform3D(
				basis.scaled_local(Vector3(thickness, thickness, direction.length())), (a + b) * 0.5
			)
		),
		material
	)


func _box(at: Vector3, size: Vector3, material: String, transform := Transform3D.IDENTITY) -> void:
	_append_arrays(_box_arrays, transform * Transform3D(Basis.from_scale(size), at), material)


func _append_mesh(mesh: Mesh, transform: Transform3D, material: String) -> void:
	_append_arrays(mesh.surface_get_arrays(0), transform, material)


func _append_arrays(arrays: Array, transform: Transform3D, material: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var normal_basis := transform.basis.inverse().transposed()
	var tool := _surface(material)
	for index in count:
		var source := indices[index] if not indices.is_empty() else index
		tool.set_normal((normal_basis * normals[source]).normalized())
		tool.set_uv(uvs[source])
		tool.add_vertex(transform * vertices[source] + _offset)
	_triangles += count / 3
	_pieces += 1


func _surface(material: String) -> SurfaceTool:
	if not _surfaces.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[material] = tool
	return _surfaces[material] as SurfaceTool


func _prism(
	polygon: PackedVector2Array, depth: float, transform: Transform3D, material: String
) -> void:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var bounds := Iso.poly_bounds(polygon)
	var normal_basis := transform.basis.inverse().transposed()
	for side in [-1.0, 1.0]:
		var normal := (normal_basis * Vector3(0, 0, side)).normalized()
		for index in range(0, triangles.size(), 3):
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner in 3:
				var point := polygon[triangles[index + corner]]
				points.append(transform * Vector3(point.x, point.y, side * depth * 0.5))
				uvs.append(
					Vector2(
						(point.x - bounds.position.x) / maxf(bounds.size.x, 0.001),
						1.0 - (point.y - bounds.position.y) / maxf(bounds.size.y, 0.001)
					)
				)
			_triangle(points, uvs, normal, material)
	var area := 0.0
	for index in polygon.size():
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var normal := (normal_basis * Vector3(edge.y, -edge.x, 0) * signf(area)).normalized()
		var points := [
			transform * Vector3(a.x, a.y, -depth * 0.5),
			transform * Vector3(b.x, b.y, -depth * 0.5),
			transform * Vector3(b.x, b.y, depth * 0.5),
			transform * Vector3(a.x, a.y, depth * 0.5)
		]
		_quad(points, normal, material)
	_pieces += 1


func _quad(points: Array, normal: Vector3, material: String) -> void:
	_triangle(
		[points[0], points[1], points[2]],
		[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE],
		normal,
		material
	)
	_triangle(
		[points[0], points[2], points[3]],
		[Vector2.ZERO, Vector2.ONE, Vector2.DOWN],
		normal,
		material
	)


func _triangle(points: Array, uvs: Array, normal: Vector3, material: String) -> void:
	var tool := _surface(material)
	# Godot's front winding is clockwise; explicit outward normals drive real light.
	var order := (
		[0, 2, 1]
		if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0
		else [0, 1, 2]
	)
	for index in order:
		tool.set_normal(normal)
		tool.set_uv(uvs[index])
		tool.add_vertex(points[index] + _offset)
	_triangles += 1


func _flush() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for key: String in _surfaces:
		var tool: SurfaceTool = _surfaces[key]
		tool.index()
		var mesh := MeshInstance3D.new()
		mesh.name = "ChapelDetail_" + key
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[key]
		_root.add_child(mesh)
		meshes.append(mesh)
	return meshes
