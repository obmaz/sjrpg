extends TestCase

func run() -> void:
	var game := await make_game()
	# The real village has more silhouettes than a mobile instance buffer can hold simultaneously.
	var maximum := 0
	for point in [game.village.spawn_point, game.village.gate_points[0], game.village.gate_points[1], game.village.gate_points[2], game.village.gate_points[3], game.village.buildings["nw"].position - Vector2(0, 150)]:
		WorldOcclusion.update(point, false)
		maximum = maxi(maximum, WorldOcclusion._active.size())
	check("occlusion instance budget stays below mobile buffer capacity", maximum < 128)
	WorldOcclusion.update(game.village.spawn_point, true)
	check("raised player does not punch holes in lower ground art", WorldOcclusion._active.is_empty())
	for index in 100:
		game.float_text(game.player.position, str(index), Color.WHITE)
	check("cosmetic effects have a bounded budget", game.cosmetic_effects.size() == 64)
	var projectile := Effect.new()
	projectile.kind = "proj"
	projectile.life = 10.0
	game._add_effect(projectile)
	check("gameplay projectiles are not removed by cosmetic budget", not projectile.is_queued_for_deletion() and game.cosmetic_effects.size() == 64)
	game.queue_free()
	await _frames(2)
