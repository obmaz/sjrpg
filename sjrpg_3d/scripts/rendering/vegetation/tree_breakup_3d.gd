class_name TreeBreakup3D
extends RefCounted
## 실제 줄기·가지 파편을 최대 세 그루만 잠시 표시한다. 물리/그림자/추가 광원 없음.

const LIMIT := 3
const SECONDS := 0.85
var _slots: Array[Dictionary] = []
var _serial := 0


func setup(parent: Node3D) -> TreeBreakup3D:
	var root := Node3D.new()
	root.name = "TreeBreakup"
	root.set_meta("occlusion_dynamic", true)
	parent.add_child(root)
	for index in LIMIT:
		var draws: Array[MeshInstance3D] = []
		for piece in TreeDamageGeometry3D.BREAK_PIECES:
			var draw := MeshInstance3D.new()
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw.visible = false
			root.add_child(draw)
			draws.append(draw)
		_slots.append({"age": SECONDS, "draws": draws})
	return self


func burst(entry: Dictionary, kind: String) -> void:
	if Prefs.reduce_motion or kind not in ["frozen", "charred"]:
		return
	var slot: Dictionary = _slots[_serial % LIMIT]
	_serial += 1
	slot["age"] = 0.0
	slot["frame"] = entry["transform"]
	slot["frozen"] = kind == "frozen"
	var meshes := TreeDamageGeometry3D.fragments(entry["variant"], kind)
	for index in meshes.size():
		var draw: MeshInstance3D = slot["draws"][index]
		draw.mesh = meshes[index]
		draw.visible = meshes[index] != null
	_pose(slot)


func sync(delta: float) -> void:
	for slot in _slots:
		if float(slot["age"]) >= SECONDS:
			continue
		slot["age"] = minf(SECONDS, float(slot["age"]) + delta)
		_pose(slot)


func clear() -> void:
	for slot in _slots:
		slot["age"] = SECONDS
		for draw: MeshInstance3D in slot["draws"]:
			draw.visible = false


func active_count() -> int:
	var count := 0
	for slot in _slots:
		if float(slot["age"]) < SECONDS:
			count += 1
	return count


func _pose(slot: Dictionary) -> void:
	var age: float = slot["age"]
	var frame: Transform3D = slot["frame"]
	var frozen: bool = slot["frozen"]
	var travel := maxf(0.0, age - 0.035)
	var shrink := 1.0 - smoothstep(0.52, SECONDS, age)
	for index in TreeDamageGeometry3D.BREAK_PIECES:
		var draw: MeshInstance3D = slot["draws"][index]
		draw.visible = draw.mesh != null and age < SECONDS and not Prefs.reduce_motion
		if not draw.visible:
			continue
		var pivot := draw.mesh.get_aabb().get_center()
		var angle := float(index) * 2.39996323
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var axis := Vector3(-radial.z, 0.0, radial.x)
		var rotation := Basis(axis, travel * (2.8 if frozen else 1.8))
		var basis := frame.basis * rotation * Basis.from_scale(Vector3.ONE * shrink)
		var velocity := radial * (1.5 if frozen else 0.7) + Vector3.UP * (0.9 if frozen else 0.15)
		var offset := velocity * travel + Vector3.DOWN * 3.0 * travel * travel
		draw.transform = Transform3D(basis, frame * pivot + offset - basis * pivot)
