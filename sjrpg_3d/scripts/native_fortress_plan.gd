class_name NativeFortressPlan
extends RefCounted
## 망루·상부 통로의 표시와 SOLID가 같은 미터 기준을 사용한다.
const CORNER_RADIUS := 1.30
const CORNER_SHAFT_TOP := 4.15
const CORNER_GALLERY_BASE := 4.25
const CORNER_EAVES := 5.05
const CORNER_ROOF_TOP := 6.95
const CORNER_GALLERY_RADIUS := 1.48
const CORNER_ROOF_RADIUS := 1.65
const WALK_WIDTH := 1.12
const WALK_HEADROOM := 2.02


## 상부 통로의 부피를 표시와 SOLID가 공유한다. 지상 FLOOR와 구별해 아래 통행을 보존한다.
static func wall_walk(village: Village) -> Dictionary:
	var centre := Vector3.ZERO
	for point: Vector2 in village.safe_zone:
		centre += Ortho3DPreview.ground_position(point)
	centre /= village.safe_zone.size()
	var floor_y := village.wall_height / 65.0 - 0.70
	var parts: Array[Dictionary] = []
	var routes: Array[Transform3D] = []
	var lengths: Array[float] = []
	for footprint: PackedVector2Array in village.wall_footprints:
		var polygon := PackedVector2Array()
		for point: Vector2 in footprint:
			polygon.append(Iso.unproject(point) / 65.0)
		var bounds := Iso.poly_bounds(polygon)
		var along := Vector3.RIGHT if bounds.size.x > bounds.size.y else Vector3.BACK
		var inward := along.cross(Vector3.UP)
		var at := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
		if inward.dot(centre - at) < 0.0:
			along = -along
			inward = -inward
		var length := maxf(bounds.size.x, bounds.size.y) - 0.28
		if length < 1.6:
			continue
		var thickness := minf(bounds.size.x, bounds.size.y)
		var frame := Transform3D(Basis(along, Vector3.UP, inward), at)
		var cross := thickness * 0.5 + WALK_WIDTH * 0.5 - 0.04
		routes.append(frame * Transform3D(Basis.IDENTITY, Vector3(0, floor_y, cross)))
		lengths.append(length)
		_walk_box(
			parts,
			frame,
			Vector3(0, floor_y - 0.07, cross),
			Vector3(length, 0.14, WALK_WIDTH),
			"wood"
		)
		var rail_z := cross + WALK_WIDTH * 0.5 - 0.055
		for rail_y: float in [0.42, 0.84]:
			_walk_box(
				parts,
				frame,
				Vector3(0, floor_y + rail_y, rail_z),
				Vector3(length, 0.085, 0.10),
				"wood"
			)
		var bays := maxi(1, ceili(length / 2.8))
		for index in bays + 1:
			var x := lerpf(-length * 0.5 + 0.08, length * 0.5 - 0.08, float(index) / bays)
			_walk_box(
				parts,
				frame,
				Vector3(x, floor_y + 0.40, rail_z),
				Vector3(0.115, 0.95, 0.115),
				"wood"
			)
			_walk_box(
				parts,
				frame,
				Vector3(x, WALK_HEADROOM + 0.10, thickness * 0.5 + 0.10),
				Vector3(0.23, 0.20, 0.30),
				"granite"
			)
			_walk_box(
				parts,
				frame,
				Vector3(x, floor_y - 0.23, cross - 0.06),
				Vector3(0.16, 0.16, WALK_WIDTH - 0.12),
				"wood"
			)
	return {
		"parts": parts,
		"routes": routes,
		"lengths": lengths,
		"floor_y": floor_y,
		"width": WALK_WIDTH
	}


static func _walk_box(
	parts: Array[Dictionary], frame: Transform3D, at: Vector3, size: Vector3, material: String
) -> void:
	parts.append(
		{"frame": frame * Transform3D(Basis.IDENTITY, at), "size": size, "material": material}
	)


static func wall_walk_faces(plan: Dictionary) -> PackedVector3Array:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var faces := unit.get_faces()
	var result := PackedVector3Array()
	for part: Dictionary in plan["parts"]:
		var frame: Transform3D = part["frame"]
		var size: Vector3 = part["size"]
		for point: Vector3 in faces:
			result.append(frame * (point * size))
	return result


static func roof_points(at: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array([at + Vector3.UP * CORNER_ROOF_TOP])
	for segment: int in 16:
		var angle := TAU * segment / 16.0
		points.append(
			(
				at
				+ Vector3(
					cos(angle) * CORNER_ROOF_RADIUS, CORNER_EAVES, sin(angle) * CORNER_ROOF_RADIUS
				)
			)
		)
	return points


static func corners(village: Village) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for run: Array in village.data["wall_runs"]:
		var point: Array = run[1]
		var native := Iso.unproject(village.point(Vector2(point[0], point[1]))) / 65.0
		result.append(Vector3(native.x, 0, native.y))
	return result
