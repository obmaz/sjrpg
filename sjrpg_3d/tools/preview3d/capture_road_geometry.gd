extends Node
## 실제 마을 생성기가 사용하는 길의 미터 좌표를 데이터 마스크 제작에 전달한다.
func _ready() -> void:
	GameState.new_game("mage")
	var ground := Node2D.new()
	var world := Node2D.new()
	add_child(ground)
	add_child(world)
	var village := Village.new()
	village.build(ground, world)
	var roads: Array = []
	var contours: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in village.map_roads:
		var points: Array = []
		for point: Vector2 in polygon:
			var native := Iso.unproject(point) / Ortho3DPreview.GROUND_PER_METER
			points.append([native.x, native.y])
		roads.append(points)
		var contour := PackedVector2Array()
		for point: Array in points:
			contour.append(Vector2(point[0], point[1]))
		var searching := true
		while searching:
			searching = false
			for index: int in contours.size():
				var merged := Geometry2D.merge_polygons(contours[index], contour)
				if merged.size() == 1:
					contour = merged[0]
					contours.remove_at(index)
					searching = true
					break
		contours.append(contour)
	var union: Array = []
	for contour: PackedVector2Array in contours:
		var points: Array = []
		for point: Vector2 in contour:
			points.append([point.x, point.y])
		union.append(points)
	var path := "res://assets/source/preview3d/generated-ground/roads.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"roads": roads, "union": union, "source": "Village.map_roads", "metres": true}, "\t") + "\n")
	file.close()
	print("ROAD_GEOMETRY ", roads.size())
	ground.queue_free()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
