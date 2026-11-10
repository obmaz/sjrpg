extends TestCase
## Per-frame work that only served the hidden source canvas stays off in native 3D.


func run() -> void:
	var game := await make_game("warrior")
	game.spawn_nova(game.player.position, 60.0, Color.WHITE)
	var listed := Effect.in_world(game.world)
	var walked: Array[Effect] = []
	for child in game.world.get_children():
		if child is Effect:
			walked.append(child)
	check("effect group lists the world's effects in child order", not listed.is_empty() and listed == walked)
	var stray := Effect.new()
	stray.kind = "nova"
	add_child(stray)
	check("an effect outside the world is not presented", not Effect.in_world(game.world).has(stray))
	stray.queue_free()

	await _frames(3)
	check("source canvas stays hidden", not game.field_root.is_visible_in_tree())
	var polling := 0
	for shade in game.forest_lighting.shades:
		if is_instance_valid(shade) and shade.is_processing():
			polling += 1
	check("hidden canopy shades do not poll every frame", polling == 0)
	check("hidden canvas selects no hero occluders", WorldOcclusion._active.is_empty())

	# A closed gate must still block immediately even though layers are written on change only.
	var world: SpatialWorld3D = game.spatial_world
	var gate: StaticBody3D = world._gates[0]
	var before: bool = game.town_gates.closed[0]
	game.town_gates.closed[0] = true
	world.sync_scope()
	check("closing a gate makes its body solid on the next query", gate.collision_layer == SpatialWorld3D.SOLID)
	game.town_gates.closed[0] = false
	world.sync_scope()
	check("opening a gate clears its body on the next query", gate.collision_layer == 0)
	game.town_gates.closed[0] = before
	game.queue_free()
	await _frames(2)
