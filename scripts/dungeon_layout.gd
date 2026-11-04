class_name DungeonLayout
extends RefCounted
## Five combat rooms; two pairs of branches rejoin the main route.

const ROOMS := [Vector2(700, 0), Vector2(1550, 0), Vector2(2400, 0), Vector2(3250, 0), Vector2(4100, 0)]
const COUNTS := [3, 4, 4, 5, 6]
const EXIT := Vector2(4700, 0)
var polygons: Array[PackedVector2Array] = []
var bounds := Rect2()

func _init() -> void:
	var rects: Array[Rect2] = [Rect2(-220, -220, 440, 440), Rect2(0, -110, 700, 220), Rect2(4500, -220, 420, 440)]
	for center in ROOMS:
		rects.append(Rect2(center - Vector2(300, 300), Vector2(600, 600)))
	for start in [1550.0, 3250.0, 4100.0]:
		rects.append(Rect2(start, -110, 850.0 if start < 4000.0 else 600.0, 220))
	for start in [700.0, 2400.0]:
		for direction in [-1.0, 1.0]:
			var y := -600.0 if direction < 0.0 else 0.0
			rects.append(Rect2(start - 100.0, y, 200, 600))
			rects.append(Rect2(start + 750.0, y, 200, 600))
			rects.append(Rect2(start - 100.0, -600.0 if direction < 0.0 else 400.0, 1050, 200))
	for rect in rects:
		var polygon := PackedVector2Array()
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			polygon.append(Iso.project(corner))
		polygons.append(polygon)
	bounds = Rect2(Iso.project(Vector2(-220, 600)), Vector2.ZERO)
	for polygon in polygons:
		for point in polygon:
			bounds = bounds.expand(point)


func contains(point: Vector2, radius := 0.0) -> bool:
	if not _inside(point):
		return false
	for i in 16:
		if not _inside(point + Vector2.from_angle(TAU * i / 16.0) * radius):
			return false
	return true


func _inside(point: Vector2) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func resolve(from: Vector2, to: Vector2, radius: float) -> Vector2:
	var count := maxi(1, ceili(from.distance_to(to) / 8.0))
	var step := (to - from) / count
	var current := from
	for i in count:
		if contains(current + step, radius):
			current += step
		elif contains(current + Vector2(step.x, 0), radius):
			current.x += step.x
		elif contains(current + Vector2(0, step.y), radius):
			current.y += step.y
	return current
