extends TestCase
## The exact user-input path that exposed capsule/ramp hemisphere steering.


func run() -> void:
	var game := await make_game("warrior")
	game._spawn_timer = 10000.0
	game.encounters.set_process(false)
	game.exploration.set_process(false)
	game.quest_runtime.set_process(false)
	var player: Player = game.player
	var landmark: Landmark = game.village.landmarks[1]
	var definition: Dictionary = Landmark.data()[landmark.index]
	var outline: Array = definition["outline"]
	var entrance: int = definition["entrance"]
	var a := landmark.atlas_to_world(outline[entrance])
	var b := landmark.atlas_to_world(outline[(entrance + 1) % outline.size()])
	var middle := (a + b) * 0.5
	var center := Vector2.ZERO
	for point in landmark.top:
		center += point
	center /= landmark.top.size()
	var start := middle + (middle - center).normalized() * 70.0
	player.position = start
	var body: CharacterBody3D = game.spatial_world.register_actor(player, Player.RADIUS)
	await _walk(player, middle, 120)
	check("native garden entrance is reachable through actual player input", player.position.distance_to(middle) < 6.0, str(player.position))
	await _walk(player, center, 360)
	check("actual CharacterBody3D climbs the full garden stair route", landmark.contains_top(player.position), "source=%s foot=%s" % [player.position, game.spatial_world.actor_foot(player)])
	check("garden traversal preserves the persistent native actor body", game.spatial_world.register_actor(player, Player.RADIUS) == body)
	game.queue_free()
	await _frames(2)
