extends TestCase
## The complete border stays in its control and map dots never paint onto the bezel.


func run() -> void:
	var minimap := Minimap.new()
	for u in [0.75, 1.0, 2.0]:
		minimap.radius = 64.0 * u
		minimap.size = Vector2.ONE * 136.0 * u
		var painted := minimap.paint_bounds()
		check("map shadow and rim fit the reference frame at scale " + str(u), Rect2(Vector2.ZERO, minimap.size).encloses(painted))
		check("content preserves the scaled rim inset " + str(u), is_equal_approx(minimap.content_radius(), 62.0 * u))
		for dot in [maxf(2.0, minimap.radius * 0.035), maxf(1.8, minimap.radius * 0.027)]:
			var edge: float = minimap.content_radius() - dot - maxf(1.0, u)
			check("whole dot is accepted at its inside edge " + str(u), minimap.marker_fits(Vector2(edge - 0.001, 0), dot))
			check("whole dot cannot cross the rim " + str(u), not minimap.marker_fits(Vector2(edge + 0.1, 0), dot))
	minimap.free()
