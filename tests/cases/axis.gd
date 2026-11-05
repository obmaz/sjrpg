extends TestCase
## Collision/placement models follow the ground axes. Actual illustration pixels are audited by art_projection.


func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.open("res://assets/data/village.json", FileAccess.READ).get_as_text())
	for key in data["frames"]:
		var s: Dictionary = data["sprites"][key]
		var poly: Array = data["frames"][key]["ground"]
		var sprite := IsoSprite.new().setup(s, 1000.0)
		var bad := []
		for i in poly.size():
			var a: Array = poly[i]
			var b: Array = poly[(i + 1) % poly.size()]
			var pa := sprite.atlas_point(Vector2(a[0], a[1]))
			var pb := sprite.atlas_point(Vector2(b[0], b[1]))
			if Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) < 150.0:
				continue  # short porch steps are not ground-axis edges
			var t := rad_to_deg((pb - pa).angle())
			if t > 90.0:
				t -= 180.0
			if t < -90.0:
				t += 180.0
			if absf(absf(t) - 30.0) > 2.5:
				bad.append(snappedf(t, 0.1))
		print("axis audit %-6s %s" % [key, "ok" if bad.is_empty() else "FAIL %s" % str(bad)])
		sprite.free()
		if not bad.is_empty():
			failures += 1
	# The deck collision plane follows the ground axes; its visible coping is audited separately.
	var deck: Array = Bridge.model_deck()
	for i in 4:
		var d: Vector2 = deck[(i + 1) % 4] - deck[i]
		var t := absf(rad_to_deg(d.angle()))
		t = t if t <= 90.0 else 180.0 - t
		if absf(t - 30.0) > 2.5:
			print("axis audit bridge FAIL %.1f" % t)
			failures += 1
	# The chapel must be in the audited set (its plinth foot is `frames.chapel.ground`).
	check("axis audit: chapel is audited", data["frames"].has("chapel") and data["sprites"].has("chapel"))

	# Natural rock edges are irregular; the waterfall's built entry and path still follow the ground axes.
	var waterfall: Dictionary = Landmark.data()[3]
	for edge in [0, 2]:
		var a: Array = waterfall["outline"][edge]
		var b: Array = waterfall["outline"][edge + 1]
		var angle := absf(rad_to_deg(Vector2(b[0] - a[0], b[1] - a[1]).angle()))
		check("waterfall path axis %d" % edge, absf(angle - 30.0) <= 2.5)
