class_name NativeActorShapes
extends RefCounted
## Authored cross-section lofts. Rings are (height, half-width, half-depth, Z offset).
## Closed caps or a closed fabric shell give every authored face actual thickness.
static func loft(rings: Array[Vector4], segments: int = 16, folds: float = 0.0, start: float = 0.0, span: float = TAU, thickness: float = 0.0) -> ArrayMesh:
	var partial: bool = span < TAU - 0.001
	var count: int = segments + 1
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var shells: int = 2 if thickness > 0.0 else 1
	for shell: int in shells:
		for row: int in rings.size():
			var ring: Vector4 = rings[row]
			var before: Vector4 = rings[maxi(0, row - 1)]
			var after: Vector4 = rings[mini(rings.size() - 1, row + 1)]
			var slope: float = ((after.y + after.z) - (before.y + before.z)) * 0.5 / maxf(after.x - before.x, 0.001)
			for column: int in count:
				var fraction: float = float(column) / float(segments)
				var angle: float = start + fraction * span
				var pleat: float = folds * sin(angle * 8.0 + ring.x * 0.8)
				var width: float = maxf(0.005, ring.y + pleat - float(shell) * thickness)
				var depth: float = maxf(0.005, ring.z + pleat - float(shell) * thickness)
				vertices.append(Vector3(cos(angle) * width, ring.x, sin(angle) * depth + ring.w))
				var normal: Vector3 = Vector3(cos(angle) * depth, -slope * (width + depth) * 0.5, sin(angle) * width).normalized()
				normals.append(normal * (-1.0 if shell == 1 else 1.0))
				uv.append(Vector2(fraction, float(row) / float(rings.size() - 1)))
	var shell_size: int = count * rings.size()
	for shell: int in shells:
		for row: int in rings.size() - 1:
			for column: int in segments:
				var a: int = shell * shell_size + row * count + column
				var b: int = a + count
				if shell == 0:
					indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
				else:
					indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	if thickness > 0.0:
		for row: int in rings.size() - 1:
			for edge: int in [0, segments]:
				var a: int = row * count + edge
				var b: int = a + count
				indices.append_array(PackedInt32Array([a, b, a + shell_size, b, b + shell_size, a + shell_size]) if edge == 0 else PackedInt32Array([a, a + shell_size, b, b, a + shell_size, b + shell_size]))
		for row: int in [0, rings.size() - 1]:
			for column: int in segments:
				var a: int = row * count + column
				indices.append_array(PackedInt32Array([a, a + shell_size, a + 1, a + 1, a + shell_size, a + shell_size + 1]) if row == 0 else PackedInt32Array([a, a + 1, a + shell_size, a + 1, a + shell_size + 1, a + shell_size]))
	else:
		for row: int in [0, rings.size() - 1]:
			var center: int = vertices.size()
			var ring: Vector4 = rings[row]
			vertices.append(Vector3(0, ring.x, ring.w))
			normals.append(Vector3.DOWN if row == 0 else Vector3.UP)
			uv.append(Vector2(0.5, 0.5))
			for column: int in segments:
				var a: int = row * count + column
				indices.append_array(PackedInt32Array([center, a + 1, a]) if row == 0 else PackedInt32Array([center, a, a + 1]))
		if partial:
			for row: int in rings.size() - 1:
				var a: int = row * count
				var b: int = a + count
				var c: int = a + segments
				var d: int = b + segments
				indices.append_array(PackedInt32Array([a, b, c, c, b, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func boot() -> ArrayMesh:
	return loft([Vector4(0, 0.075, 0.12, 0.065), Vector4(0.045, 0.088, 0.16, 0.075), Vector4(0.10, 0.083, 0.155, 0.065), Vector4(0.15, 0.068, 0.10, 0.025), Vector4(0.27, 0.066, 0.073, 0), Vector4(0.31, 0.072, 0.077, 0)], 12)


static func head() -> ArrayMesh:
	return loft([Vector4(0, 0.053, 0.060, 0.025), Vector4(0.035, 0.080, 0.078, 0.012), Vector4(0.085, 0.103, 0.092, 0.008), Vector4(0.145, 0.110, 0.102, 0), Vector4(0.205, 0.101, 0.096, -0.005), Vector4(0.245, 0.070, 0.066, -0.009), Vector4(0.26, 0.018, 0.018, -0.009)], 20)


static func sleeve(length: float = 0.54, width: float = 0.085) -> ArrayMesh:
	return loft([Vector4(-length, width * 0.66, width * 0.70, 0.045), Vector4(-length * 0.79, width * 0.87, width * 0.86, 0.036), Vector4(-length * 0.48, width * 0.78, width * 0.80, 0.020), Vector4(-length * 0.22, width, width * 1.03, 0), Vector4(0, width * 0.97, width * 1.08, 0)], 12, 0.004)


static func chest() -> ArrayMesh:
	return loft([Vector4(0.82, 0.19, 0.14, 0), Vector4(0.99, 0.18, 0.135, 0), Vector4(1.13, 0.23, 0.17, 0), Vector4(1.30, 0.265, 0.16, -0.005), Vector4(1.39, 0.19, 0.11, 0), Vector4(1.45, 0.075, 0.075, 0)], 16)


static func blade() -> ArrayMesh:
	# Flattened diamond section with a tapering point, +Y length before socket rotation.
	return loft([Vector4(0, 0.038, 0.013, 0), Vector4(0.10, 0.044, 0.015, 0), Vector4(0.63, 0.031, 0.013, 0), Vector4(0.81, 0.002, 0.002, 0)], 4, 0.0, PI * 0.25)
