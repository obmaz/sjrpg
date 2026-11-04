extends TestCase
## 120° 기준: 지면 접촉 원화의 바닥 변이 ±30°에서 2.5° 이내인지 검사


func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.open("res://assets/data/village.json", FileAccess.READ).get_as_text())
	for key in data["frames"]:
		var s: Dictionary = data["sprites"][key]
		var poly: Array = data["frames"][key]["ground"]
		var bad := []
		for i in poly.size():
			var a: Array = poly[i]
			var b: Array = poly[(i + 1) % poly.size()]
			var pa := Vector2(a[0], a[1] * s["gvs"] + a[0] * s["gvk"])
			var pb := Vector2(b[0], b[1] * s["gvs"] + b[0] * s["gvk"])
			if pa.distance_to(pb) < 150.0:
				continue  # short porch steps are not ground-axis edges
			var t := rad_to_deg((pb - pa).angle())
			if t > 90.0:
				t -= 180.0
			if t < -90.0:
				t += 180.0
			if absf(absf(t) - 30.0) > 2.5:
				bad.append(snappedf(t, 0.1))
		print("axis audit %-6s %s" % [key, "ok" if bad.is_empty() else "FAIL %s" % str(bad)])
		if not bad.is_empty():
			failures += 1
	# Bridge deck edges are exactly +-30 by construction of the original measurement.
	var deck: Array = Bridge.DECK
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
