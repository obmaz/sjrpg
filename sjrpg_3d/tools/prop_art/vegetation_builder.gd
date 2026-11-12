class_name WildVegetationBuilder
extends RefCounted


static func _triangle(
	tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	normal: Vector3
) -> void:
	var order: Array = [[a, uv_a], [b, uv_b], [c, uv_c]]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		order = [[a, uv_a], [c, uv_c], [b, uv_b]]
	for entry: Array in order:
		tool.set_normal(normal.normalized())
		tool.set_uv(entry[1])
		tool.add_vertex(entry[0])


static func _branch(tool: SurfaceTool, points: Array, radii: Array, sides := 7) -> void:
	var rings: Array[PackedVector3Array] = []
	var distance := 0.0
	var lengths: Array[float] = []
	for i: int in points.size():
		var point: Vector3 = points[i]
		var before: Vector3 = points[maxi(0, i - 1)]
		var after: Vector3 = points[mini(points.size() - 1, i + 1)]
		var tangent: Vector3 = (after - before).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		if across.length_squared() < 0.1:
			across = tangent.cross(Vector3.RIGHT).normalized()
		var other := tangent.cross(across).normalized()
		var ring := PackedVector3Array()
		for j: int in sides:
			var angle := TAU * j / sides
			var vertex: Vector3 = (
				point + (across * cos(angle) + other * sin(angle)) * float(radii[i])
			)
			vertex.y = maxf(0.0, vertex.y)
			ring.append(vertex)
		if i > 0:
			distance += point.distance_to(points[i - 1])
		lengths.append(distance)
		rings.append(ring)
	for i: int in rings.size() - 1:
		for j: int in sides:
			var k := (j + 1) % sides
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][k]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][j]
			var centre: Vector3 = (points[i] + points[i + 1]) * 0.5
			var n: Vector3 = ((a + b + c + d) * 0.25 - centre).normalized()
			var u := float(j) / sides
			var v := float(j + 1) / sides
			_triangle(
				tool,
				a,
				b,
				c,
				Vector2(u, lengths[i]),
				Vector2(v, lengths[i]),
				Vector2(v, lengths[i + 1]),
				n
			)
			_triangle(
				tool,
				a,
				c,
				d,
				Vector2(u, lengths[i]),
				Vector2(v, lengths[i + 1]),
				Vector2(u, lengths[i + 1]),
				n
			)
	for end: int in [0, rings.size() - 1]:
		var tangent: Vector3 = (
			(points[1] - points[0]).normalized()
			if end == 0
			else (points[end] - points[end - 1]).normalized()
		)
		var n := -tangent if end == 0 else tangent
		for j: int in sides:
			_triangle(
				tool,
				points[end],
				rings[end][j],
				rings[end][(j + 1) % sides],
				Vector2(0.5, 0.5),
				Vector2.ZERO,
				Vector2.ONE,
				n
			)


static func _spray(
	tool: SurfaceTool,
	at: Vector3,
	length: float,
	width: float,
	direction: Vector3,
	roll: float,
	color: Color
) -> void:
	var along := direction.normalized()
	var across := along.cross(Vector3.UP).normalized()
	if across.length_squared() < 0.1:
		across = Vector3.RIGHT
	across = across.rotated(along, roll)
	var normal := across.cross(along).normalized()
	var points: Array[PackedVector3Array] = []
	for y: int in 3:
		var row := PackedVector3Array()
		for x: int in 3:
			var point := (
				at
				+ along * (float(y) * 0.5 - 0.5) * length
				+ across * (float(x) * 0.5 - 0.5) * width
				+ normal * (0.06 * width if x == 1 else 0.0)
			)
			point.y = maxf(0.0, point.y)
			row.append(point)
		points.append(row)
	tool.set_color(color)
	for y: int in 2:
		for x: int in 2:
			var a: Vector3 = points[y][x]
			var b: Vector3 = points[y][x + 1]
			var c: Vector3 = points[y + 1][x + 1]
			var d: Vector3 = points[y + 1][x]
			_triangle(
				tool,
				a,
				b,
				c,
				Vector2(x, y) * 0.5,
				Vector2(x + 1, y) * 0.5,
				Vector2(x + 1, y + 1) * 0.5,
				(b - a).cross(c - a)
			)
			_triangle(
				tool,
				a,
				c,
				d,
				Vector2(x, y) * 0.5,
				Vector2(x + 1, y + 1) * 0.5,
				Vector2(x, y + 1) * 0.5,
				(c - a).cross(d - a)
			)


static func make_mesh(kind: int) -> ArrayMesh:
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_color(Color(0.70, 0.76, 0.71))
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shrub := kind >= 3
	var height := 0.95 if shrub else (5.6 if kind == 0 else (4.8 if kind == 1 else 6.2))
	_branch(
		wood,
		[Vector3.ZERO, Vector3(0.025, height * 0.4, -0.02), Vector3(-0.025, height, 0.02)],
		[0.045 if shrub else 0.19, 0.025 if shrub else 0.11, 0.006],
		8
	)
	var tiers := 3 if shrub else 8
	var count := 6 if kind != 2 else 5
	var sprays := 0
	var branches := 1
	for level: int in tiers:
		var progress := float(level) / tiers
		var y := (0.15 + progress * (0.72 if shrub else 0.80)) * height
		var radius := (
			(0.65 if shrub else (1.65 if kind == 0 else (1.75 if kind == 1 else 1.1)))
			* pow(1.0 - progress, 0.80)
		)
		for arm: int in count:
			var angle := arm * TAU / count + level * 1.713 + sin(arm * 7.0 + level) * 0.11
			var axis := Vector3(cos(angle), 0, sin(angle))
			var base := Vector3(0, y, 0)
			var tip := (
				base
				+ axis * radius
				+ Vector3.UP * (radius * (0.62 if kind == 2 else (-0.09 if kind == 0 else 0.17)))
			)
			var middle := base.lerp(tip, 0.6) - Vector3.UP * radius * 0.06
			_branch(
				wood,
				[base, middle, tip],
				[0.025 if shrub else 0.065 * (1.0 - progress), 0.016, 0.003],
				6
			)
			branches += 1
			for packet: int in 4:
				var t := 0.27 + packet * 0.21
				var centre := base.lerp(tip, t)
				var fan := axis.rotated(Vector3.UP, (packet % 2 * 2 - 1) * 0.6)
				var needle_ink := (
					Color(0.82, 0.94, 0.90)
					if kind == 0
					else (Color(0.69, 0.83, 0.76) if kind == 2 else Color(0.90, 0.96, 0.79))
				)
				if kind != 4 or packet % 2 == 0:
					_spray(
						leaves,
						centre,
						radius * 0.82 + 0.16,
						radius * 0.60 + 0.08,
						fan + Vector3.UP * (0.55 if kind == 2 else 0.27),
						sin(level + arm * 2.3) * 0.6,
						needle_ink
					)
					sprays += 1
				if kind == 4:
					_branch(
						wood, [centre, centre + fan * 0.14 + Vector3.UP * 0.17], [0.012, 0.001], 5
					)
					branches += 1
	# 꼭대기도 고정된 곡면 바늘잎으로 덮는다.
	_spray(
		leaves,
		Vector3(0, height * 0.94, 0),
		height * 0.22,
		0.25 if shrub else 0.48,
		Vector3.UP,
		0.4,
		Color(0.75, 0.87, 0.77)
	)
	sprays += 1
	var mesh := wood.commit()
	leaves.commit(mesh)
	var bark := StandardMaterial3D.new()
	bark.resource_name = "Bark"
	var needle := StandardMaterial3D.new()
	needle.resource_name = "LeafSpraysNeedles"
	mesh.surface_set_material(0, bark)
	mesh.surface_set_material(1, needle)
	mesh.set_meta(
		"authored_vegetation",
		{
			"kind": kind,
			"branches": branches,
			"sprays": sprays,
			"root": Vector3.ZERO,
			"billboard": false
		}
	)
	return mesh
