class_name TorchModelBuilder
extends RefCounted
const SCALE := CaveLanternRenderer3D.SCALE
const HANDLE_BOTTOM := CaveLanternRenderer3D.HANDLE_BOTTOM
const TORCH_DEPTH := CaveLanternRenderer3D.TORCH_DEPTH


static func meshes() -> Dictionary:
	var timber := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var handle := CylinderMesh.new()
	handle.bottom_radius = 0.022 * SCALE
	handle.top_radius = 0.042 * SCALE
	handle.height = 0.44 * SCALE
	handle.radial_segments = 8
	handle.rings = 1
	timber.append_from(
		handle,
		0,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.22 * SCALE + HANDLE_BOTTOM, TORCH_DEPTH))
	)
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One closed iron mesh includes the flush backplate, arm and diagonal brace.
	_box(iron, Vector3(0.24, 0.54, 0.08), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.04)))
	_box(
		iron,
		Vector3(0.10, 0.07, TORCH_DEPTH),
		Transform3D(Basis.IDENTITY, Vector3(0, -0.13, TORCH_DEPTH * 0.5))
	)
	var brace_from := Vector3(0, -0.23, 0.08)
	var brace_to := Vector3(0, -0.11, TORCH_DEPTH)
	var brace_direction := brace_to - brace_from
	_box(
		iron,
		Vector3(0.065, brace_direction.length(), 0.065),
		Transform3D(
			Basis(Quaternion(Vector3.UP, brace_direction.normalized())),
			(brace_from + brace_to) * 0.5
		)
	)
	_ring(
		iron,
		0.29 * SCALE + HANDLE_BOTTOM,
		0.035 * SCALE,
		0.048 * SCALE,
		0.048 * SCALE,
		0.011 * SCALE,
		TORCH_DEPTH
	)
	_ring(
		iron,
		0.36 * SCALE + HANDLE_BOTTOM,
		0.12 * SCALE,
		0.047 * SCALE,
		0.086 * SCALE,
		0.013 * SCALE,
		TORCH_DEPTH
	)
	return {"wood": timber.commit(), "iron": iron.commit()}


static func _box(tool: SurfaceTool, size: Vector3, transform: Transform3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	# Keep iron parts unindexed together: appending an indexed primitive to
	# custom unindexed rings can leave those ring vertices out of the final draw.
	var faces := box.get_faces()
	for index in range(0, faces.size(), 3):
		var a := transform * faces[index]
		var b := transform * faces[index + 1]
		var c := transform * faces[index + 2]
		CaveLanternRenderer3D._triangle(
			tool, a, b, c, ((a + b + c) / 3.0 - transform.origin).normalized()
		)


static func _ring(
	tool: SurfaceTool,
	bottom: float,
	height: float,
	lower: float,
	upper: float,
	thickness: float,
	depth := 0.0
) -> void:
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in [
		Vector3(lower, bottom, 0),
		Vector3(upper, bottom + height, 0),
		Vector3(lower - thickness, bottom, 0),
		Vector3(upper - thickness, bottom + height, 0)
	]:
		var ring := PackedVector3Array()
		for index in 8:
			var angle := TAU * index / 8.0
			ring.append(Vector3(cos(angle) * section.x, section.y, sin(angle) * section.x + depth))
		rings.append(ring)
	for index in 8:
		var next := (index + 1) % 8
		var direction := Vector3(cos(TAU * (index + 0.5) / 8.0), 0, sin(TAU * (index + 0.5) / 8.0))
		CaveLanternRenderer3D._quad(
			tool, rings[0][index], rings[1][index], rings[1][next], rings[0][next], direction
		)
		CaveLanternRenderer3D._quad(
			tool, rings[2][index], rings[2][next], rings[3][next], rings[3][index], -direction
		)
		CaveLanternRenderer3D._quad(
			tool, rings[1][index], rings[3][index], rings[3][next], rings[1][next], Vector3.UP
		)
		CaveLanternRenderer3D._quad(
			tool, rings[0][index], rings[0][next], rings[2][next], rings[2][index], Vector3.DOWN
		)
