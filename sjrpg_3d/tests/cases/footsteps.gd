extends TestCase


func run() -> void:
	var game := await make_game("warrior")
	game.player.set_process(false)
	var player: Player = game.player
	var track := player.footsteps
	var half_cycle := PlayerFootsteps.WARRIOR_CYCLE * 0.5
	player._run_distance = half_cycle - 1.0
	track.observe(player, 0.0)
	check("standing still produces no contacts", track.contacts == 0)
	player._run_distance += 0.5
	track.observe(player, 0.5)
	check("small motion before the actual leg contact stays quiet", track.contacts == 0)
	player._run_distance += 1.0
	track.observe(player, 1.0)
	check("crossing a leg contact produces one step", track.contacts == 1)
	track.observe(player, 0.0)
	check("holding against a wall cannot produce timed footsteps", track.contacts == 1)
	player._run_distance += half_cycle * 3.0
	track.observe(player, half_cycle * 3.0)
	check("a slow frame cannot burst multiple old steps", track.contacts == 2)
	player.warp_locked = true
	player._run_distance += half_cycle
	track.observe(player, half_cycle)
	check("warp movement stays silent", track.contacts == 2)
	player.warp_locked = false
	player._roll_time = 0.1
	player._run_distance += half_cycle
	track.observe(player, half_cycle)
	check("a dodge cannot masquerade as walking", track.contacts == 2)
	player._roll_time = 0.0
	player.is_mage = true
	var before := track.contacts
	player._run_distance = PlayerFootsteps.MAGE_CONTACT_OFFSET - 0.5
	track.observe(player, 0.5)
	player._run_distance += 1.0
	track.observe(player, 1.0)
	check("mage footfall uses the measured GLB contact offset", track.contacts == before + 1)
	player.is_mage = false
	check(
		"visible village paving uses stone",
		PlayerFootsteps.surface_at(game, Iso.project(Vector2(0, 0))) == "stone"
	)
	check(
		"the actual bridge uses its stone deck",
		PlayerFootsteps.surface_at(game, game.village.bridge.axis_point(0.5)) == "stone"
	)
	var trail := CaveTrailPlan3D.points(game.village)
	var frame := CaveTrailPlan3D.frame(game.village)
	var midpoint := trail[3].lerp(trail[4], 0.5)
	var point := SpatialWorld3D.projected(frame * Vector3(midpoint.x, 0, midpoint.y))
	check(
		"the shared cave trail produces earth footsteps",
		PlayerFootsteps.surface_at(game, point) == "earth"
	)
	check(
		"open grass has its own surface sound",
		PlayerFootsteps.surface_at(game, Iso.project(Vector2(9000, 10000))) == "grass"
	)
	game.dungeon.active = true
	check(
		"dungeon relief is stone rather than field grass",
		PlayerFootsteps.surface_at(game, player.position) == "stone"
	)
	game.dungeon.active = false
	game.queue_free()
	await _frames(3)
