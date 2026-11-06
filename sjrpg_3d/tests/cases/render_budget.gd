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
		game.float_text(game.player.position + Vector2(index * 400, 0), str(index), Color.WHITE)
	check("cosmetic effects have a bounded budget", game.cosmetic_effects.size() == 64)
	var projectile := Effect.new()
	projectile.kind = "proj"
	projectile.life = 10.0
	game._add_effect(projectile)
	check("gameplay projectiles are not removed by cosmetic budget", not projectile.is_queued_for_deletion() and game.cosmetic_effects.size() == 64)
	var minimap: Minimap = game.hud.minimap
	var origin: Vector2 = game.player.position
	minimap._update_geometry(origin)
	var rebuilds := minimap.geometry_rebuilds
	for index in 120:
		minimap._update_geometry(origin)
	check("stationary map terrain reuses its clipped geometry", minimap.geometry_rebuilds == rebuilds)
	var quarter_pixel := Minimap.WORLD_RADIUS / minimap.radius * 0.25
	minimap._update_geometry(origin + Vector2.RIGHT * quarter_pixel * 0.5)
	check("terrain reuses only subpixel map movement", minimap.geometry_rebuilds == rebuilds)
	minimap._update_geometry(origin + Vector2.RIGHT * quarter_pixel * 1.1)
	check("visible map movement refreshes clipped terrain", minimap.geometry_rebuilds == rebuilds + 1)
	minimap.radius += 1.0
	minimap._update_geometry(origin)
	check("map resizing refreshes its circle and terrain", minimap.geometry_rebuilds == rebuilds + 2)
	var forest_shapes: Array[Dictionary] = game.map_shapes
	game.map_shapes = [] as Array[Dictionary]
	minimap._update_geometry(origin)
	check("map transition cannot retain the old forest geometry", minimap._geometry.is_empty())
	game.map_shapes = forest_shapes
	minimap._update_geometry(origin)
	check("returning to the forest restores map geometry", not minimap._geometry.is_empty())
	game.queue_free()
	await _frames(2)
