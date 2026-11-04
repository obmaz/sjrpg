extends TestCase
## 지형 랜드마크: 계단으로만 오를 수 있고 절벽은 막힘


func run() -> void:
	GameState.new_game("warrior")
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	for e in game.enemies:
		e.queue_free()
	game.enemies.clear()
	var player: Player = game.player
	for lm in game.village.landmarks:
		var d: Dictionary = Landmark.data()[lm.index]
		var outline: Array = d["outline"]
		var center := Vector2.ZERO
		for p in lm.top:
			center += p
		center /= lm.top.size()
		var e: int = int(d["entrance"])
		var a: Vector2 = lm._pt(outline[e])
		var b: Vector2 = lm._pt(outline[(e + 1) % outline.size()])
		var mid := (a + b) / 2.0
		var start := mid + (mid - center).normalized() * 70.0
		player.position = start
		await _walk(player, mid, 120)
		await _walk(player, center, 360)
		var up := lm.contains_top(player.position)
		# From the opposite side, straight at a cliff edge: must stay off the top.
		var worst_ok := true
		for k in outline.size():
			if k == e:
				continue
			var p0: Vector2 = lm._pt(outline[k])
			var p1: Vector2 = lm._pt(outline[(k + 1) % outline.size()])
			var m := (p0 + p1) / 2.0
			if m.distance_to(mid) < 120.0 or (p1 - p0).length() < 60.0:
				continue
			var out_dir := (m - center).normalized()
			if not lm.contains_top(m - out_dir * 30.0):
				continue
			# Start on open ground in front of the edge (never inside a cliff face).
			var probe := Vector2.ZERO
			var found := false
			for dist in [60.0, 120.0, 200.0, 300.0]:
				var cand: Vector2 = m + out_dir * dist
				var clear := not lm.contains_top(cand)
				for q in game.village.solids:
					if Geometry2D.is_point_in_polygon(cand, q):
						clear = false
						break
				if clear:
					probe = cand
					found = true
					break
			if not found:
				continue
			player.position = probe
			await _walk(player, m - out_dir * 40.0, 300)
			if lm.contains_top(player.position):
				worst_ok = false
				print("   leak via edge %d (len %.0f) started %s ended %s" % [k, (p1 - p0).length(), player.position, "inside"])
		print("terrace %s: stairs %s, cliffs %s" % [Landmark.NAMES[lm.index], "ok" if up else "FAIL", "ok" if worst_ok else "LEAK"])
		if not up:
			failures += 1
	game.queue_free()
	await _frames(2)
