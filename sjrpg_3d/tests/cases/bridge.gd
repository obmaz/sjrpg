extends TestCase
## 동문 밖 다리: 건널 수 있고 강은 막힘


func run() -> void:
	GameState.delete_save()
	GameState.new_game("warrior")
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	for e in game.enemies:
		e.queue_free()
	game.enemies.clear()
	var player: Player = game.player
	var v: Village = game.village
	# Walk from the forecourt over the deck to the far bank.
	player.position = Iso.project(v.forecourt_g)
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		await _walk(player, v.bridge.axis_point(t), 240)
	var far := player.position.distance_to(v.bridge.axis_point(1.0)) < 40.0
	print("bridge crossing: %s" % ("ok" if far else "FAIL at %s" % player.position))
	if not far:
		failures += 1
	# From the near bank, walking straight into the river must be stopped.
	var start := v.forecourt_g + Vector2(350, -60)
	player.position = Iso.project(start)
	await _walk(player, Iso.project(start + Vector2(0, -460)), 300)
	var g := Iso.unproject(player.position)
	var moved := g.y < start.y - 40.0
	var wet := v.river_band.grow(-20.0).has_point(g)
	print("river blocks: %s (moved %.0f, v=%.0f, band top %.0f)" % ["FAIL in water" if wet or not moved else "ok", start.y - g.y, g.y, v.river_band.end.y])
	if not moved:
		failures += 1
	if wet:
		failures += 1
	game.queue_free()
	await _frames(2)
