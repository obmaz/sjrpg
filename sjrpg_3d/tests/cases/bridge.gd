extends TestCase
## 동문 밖 다리: 건널 수 있고 강은 막힘


func run() -> void:
	# 실제 공간 준비와 초기 적 배치가 끝난 뒤 걷기 검사를 시작한다.
	var game := await make_game("warrior")
	var player: Player = game.player
	var v: Village = game.village
	# Walk from the forecourt over the deck to the far bank.
	player.position = Iso.project(v.forecourt_g)
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		await _walk(player, v.bridge.axis_point(t), 240)
	var far := player.position.distance_to(v.bridge.axis_point(1.0)) < 40.0
	print("bridge crossing: %s" % ("ok" if far else "FAIL at %s" % player.position))
	check("native bridge crossing reaches the far bank", far, str(player.position))
	# From the near bank, walking straight into the river must be stopped.
	var start := v.forecourt_g + Vector2(350, -60)
	player.position = Iso.project(start)
	await _walk(player, Iso.project(start + Vector2(0, -460)), 300)
	var g := Iso.unproject(player.position)
	var moved := g.y < start.y - 40.0
	var wet := v.river_band.grow(-20.0).has_point(g)
	print("river blocks: %s (moved %.0f, v=%.0f, band top %.0f)" % ["FAIL in water" if wet or not moved else "ok", start.y - g.y, g.y, v.river_band.end.y])
	check("native river approach moves before meeting the bank", moved, "start=%s actual=%s" % [start, g])
	check("native river blocks entry into water", not wet, "actual=%s band=%s" % [g, v.river_band])
	game.queue_free()
	await _frames(2)
