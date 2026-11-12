class_name FortificationRenderer3D
extends RefCounted
## 성곽 GLB의 정적 메시·여덟 문짝을 배치하고 기존 성문 상태만 적용한다.
const OPEN_ANGLE := 1.50
var renderer: Node
var root: Node3D
var dynamic_root: Node3D
var gates: Array[Dictionary] = []
var report := {}


static func build(presenter: Node) -> FortificationRenderer3D:
	var controller := FortificationRenderer3D.new()
	controller.renderer = presenter
	var shared := {"iron": presenter._materials["iron"]}
	var visual := ArchitectureSceneLibrary.create("fortress", shared)
	controller.root = visual
	visual.name = "NativeFortification"
	NativePlayerOcclusion.mark_object(visual)
	presenter.stage.add_child(visual)
	controller.dynamic_root = visual.get_node("Geometry/MovingGateLeaves")
	controller.report = visual.report
	controller.gates.assign(visual.report["gates"])
	visual.set_meta("fortification_detail", controller.report)
	controller.sync()
	return controller


## No independent tween or timer: pause, accessibility and real threat scan remain authoritative.
func sync() -> void:
	if not is_instance_valid(root) or not is_instance_valid(renderer):
		return
	var state: TownGateRuntime = renderer.game.town_gates
	for index in gates.size():
		var value := (
			(1.0 if state.closed[index] else 0.0) if Prefs.reduce_motion else state.progress[index]
		)
		value = clampf(value, 0.0, 1.0)
		var gate: Dictionary = gates[index]
		gate["progress"] = value
		var opening_sign: float = gate["opening_sign"]
		var leaves: Array = gate["leaves"]
		for leaf_index in leaves.size():
			var leaf: Node3D = leaves[leaf_index]
			var side := -1.0 if leaf_index == 0 else 1.0
			# A closed leaf extends along -side*x. Y rotation moves that span toward
			# side*sin(angle)*z, so this sign sends both leaves outside the safe zone.
			leaf.rotation.y = side * opening_sign * OPEN_ANGLE * (1.0 - value)


## Derive exterior from the actual nearest safe-zone edge, independently of camera
## and polygon winding. Town-centre guesses can flip on offset/asymmetric passages.
static func _outward_normal(safe_zone: PackedVector2Array, point: Vector3) -> Vector3:
	var polygon := _flat_polygon(safe_zone)
	var at := Vector2(point.x, point.z)
	var nearest := INF
	var outward := Vector2.ZERO
	for index in polygon.size():
		var first := polygon[index]
		var last := polygon[(index + 1) % polygon.size()]
		var edge := last - first
		if edge.length_squared() < 0.000001:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(at, first, last)
		var distance := closest.distance_squared_to(at)
		if distance >= nearest:
			continue
		nearest = distance
		outward = edge.orthogonal().normalized()
		if Geometry2D.is_point_in_polygon((first + last) * 0.5 + outward * 0.05, polygon):
			outward = -outward
	return Vector3(outward.x, 0.0, outward.y)


static func _flat_polygon(source: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in source:
		var flat := Iso.unproject(point) / WorldRenderer3D.GROUND_PER_METER
		result.append(flat)
	return result
