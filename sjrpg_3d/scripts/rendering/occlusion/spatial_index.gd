class_name NativeOcclusionIndex
extends RefCounted
## 시각 가림 후보만 찾는 미터 단위 공간 색인. 재질·배우·게임 상태는 변경하지 않는다.
const CELL_METRES := 8.0
var _cells := {}
var _tracked := {}
var _entry_serial := 0


func add(entry: Dictionary) -> void:
	_entry_serial += 1
	entry["id"] = _entry_serial
	_refresh_bounds(entry)
	_index(entry)
	var id: int = entry["node"].get_instance_id()
	if not _tracked.has(id):
		_tracked[id] = {"node": entry["node"], "entries": []}
	_tracked[id]["entries"].append(entry)


func _refresh_bounds(entry: Dictionary) -> void:
	var node: GeometryInstance3D = entry["node"]
	var frame := node.global_transform
	entry["source_frame"] = frame
	if entry["index"] >= 0:
		frame *= entry["transform"]
	entry["inverse"] = frame.affine_inverse()
	entry["world_box"] = frame * entry["box"]


func _index(entry: Dictionary) -> void:
	var cells: Array[Vector2i] = []
	entry["cells"] = cells
	var box: AABB = entry["world_box"]
	if box.size.y < 0.45:
		return
	box = box.grow(0.12)
	var a := Vector2i(floori(box.position.x / CELL_METRES), floori(box.position.z / CELL_METRES))
	var b := Vector2i(floori(box.end.x / CELL_METRES), floori(box.end.z / CELL_METRES))
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			var cell := Vector2i(x, z)
			var bucket: Array = _cells.get(cell, [])
			bucket.append(entry)
			_cells[cell] = bucket
			cells.append(cell)


func _unindex(entry: Dictionary) -> void:
	for cell: Vector2i in entry["cells"]:
		var bucket: Array = _cells[cell]
		bucket.erase(entry)
		if bucket.is_empty():
			_cells.erase(cell)
	entry["cells"] = []


func candidates(foot: Vector3, toward: Vector3) -> Array:
	# 배칭 노드별로 변환을 한 번만 확인한다. 정적 모델 재배치·삭제도 색인에 반영한다.
	for id in _tracked.keys():
		var tracked: Dictionary = _tracked[id]
		if not is_instance_valid(tracked["node"]):
			for entry: Dictionary in tracked["entries"]:
				_unindex(entry)
			_tracked.erase(id)
		elif tracked["entries"][0]["source_frame"] != tracked["node"].global_transform:
			for entry: Dictionary in tracked["entries"]:
				_unindex(entry)
				_refresh_bounds(entry)
				_index(entry)
	var end := foot + toward
	var a := Vector2i(
		floori((minf(foot.x, end.x) - 0.13) / CELL_METRES),
		floori((minf(foot.z, end.z) - 0.13) / CELL_METRES)
	)
	var b := Vector2i(
		floori((maxf(foot.x, end.x) + 0.13) / CELL_METRES),
		floori((maxf(foot.z, end.z) + 0.13) / CELL_METRES)
	)
	var found := {}
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			for entry: Dictionary in _cells.get(Vector2i(x, z), []):
				found[entry["id"]] = entry
	return found.values()
