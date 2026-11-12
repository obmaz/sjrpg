class_name BridgePlan3D
extends RefCounted
## 낮은 강바닥에 닿는 교각 기초·물살 가름돌을 표시와 물리에 함께 제공한다.


static func frame(bridge: Bridge) -> Transform3D:
	var deck := bridge.deck_polygon()
	var a := WorldSpace3D.projected_to_world(deck[0])
	var along := (WorldSpace3D.projected_to_world(deck[1]) - a).normalized()
	var across := (WorldSpace3D.projected_to_world(deck[3]) - a).normalized()
	return Transform3D(Basis(along, Vector3.UP, across), a)


static func foundations(bridge: Bridge) -> Array[Dictionary]:
	var deck := bridge.deck_polygon()
	var length := WorldSpace3D.projected_to_world(deck[0]).distance_to(
		WorldSpace3D.projected_to_world(deck[1])
	)
	var width := WorldSpace3D.projected_to_world(deck[0]).distance_to(
		WorldSpace3D.projected_to_world(deck[3])
	)
	var parts: Array[Dictionary] = []
	for pier in 3:
		var x := pier * length * 0.5
		parts.append(
			{
				"polygon":
				PackedVector2Array(
					[
						Vector2(x - 0.34, -0.16),
						Vector2(x + 0.34, -0.16),
						Vector2(x + 0.34, width + 0.16),
						Vector2(x - 0.34, width + 0.16)
					]
				),
				"bottom": -1.88,
				"top": -1.52
			}
		)
		for side: float in [-1.0, 1.0]:
			var edge := 0.0 if side < 0.0 else width
			parts.append(
				{
					"polygon":
					PackedVector2Array(
						[
							Vector2(x - 0.23, edge),
							Vector2(x + 0.23, edge),
							Vector2(x, edge + side * 0.48)
						]
					),
					"bottom": -1.55,
					"top": -0.35
				}
			)
	return parts


static func faces(part: Dictionary, transform := Transform3D.IDENTITY) -> PackedVector3Array:
	var polygon: PackedVector2Array = part["polygon"]
	var indices := Geometry2D.triangulate_polygon(polygon)
	var result := PackedVector3Array()
	var centre := Vector3(0, (float(part["bottom"]) + float(part["top"])) * 0.5, 0)
	for p: Vector2 in polygon:
		centre += Vector3(p.x, 0, p.y) / polygon.size()
	for index in range(0, indices.size(), 3):
		for y: float in [part["bottom"], part["top"]]:
			for corner in 3:
				var p := polygon[indices[index + corner]]
				result.append(Vector3(p.x, y, p.y))
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var low_a := Vector3(a.x, part["bottom"], a.y)
		var low_b := Vector3(b.x, part["bottom"], b.y)
		var high_a := Vector3(a.x, part["top"], a.y)
		var high_b := Vector3(b.x, part["top"], b.y)
		result.append_array(PackedVector3Array([low_a, high_a, high_b, low_a, high_b, low_b]))
	# Godot 전면(시계 방향)과 일치시켜 렌더와 삼각형 충돌의 면을 공유한다.
	for index in range(0, result.size(), 3):
		var a := result[index]
		var b := result[index + 1]
		var c := result[index + 2]
		if (b - a).cross(c - a).dot((a + b + c) / 3.0 - centre) > 0.0:
			result[index + 1] = c
			result[index + 2] = b
	for index in result.size():
		result[index] = transform * result[index]
	return result
