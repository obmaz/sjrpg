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

	# A cave visit stows the forest collision and brings the same bodies back.
	var builds := world.forest_builds
	var blocked_before := world.blocked(game.village.npc_points["촌장"], Player.RADIUS)
	game.player.position = game.dungeon.entry_point()
	check("the real cave can be entered", game.dungeon.enter())
	world.sync_scope()
	await _frames(3)
	check("forest collision leaves the physics space in the cave", world.realm == "cave" and not gate.is_inside_tree() and is_instance_valid(gate))
	game.dungeon.leave("", false)
	world.sync_scope()
	await _frames(3)
	check("returning restores the same forest bodies without a rebuild", world.realm == "forest" and world.forest_builds == builds and gate.is_inside_tree() and world._gates[0] == gate)
	check("restored forest collision still blocks a resident's spot", blocked_before and world.blocked(game.village.npc_points["촌장"], Player.RADIUS))
	check("autosave is a 30 second safety net", is_equal_approx(game.AUTOSAVE_SECONDS, 30.0))

	# Combat text and effect cards are recycled instead of rebuilt per hit.
	var renderer: WorldRenderer3D = game.world_renderer
	game.float_text(game.player.position, "12", Color.WHITE)
	await _frames(3)
	var label_builds := renderer.label_builds
	check("combat text appears as a native label", label_builds > 0 and not renderer._labels.is_empty())
	for effect in Effect.in_world(game.world):
		if effect.kind == "text":
			effect.queue_free()
	await _frames(3)
	check("an expired label waits hidden in the pool", renderer._labels.is_empty() and not renderer._label_pool.is_empty() and not renderer._label_pool[0].visible)
	game.float_text(game.player.position, "34", Color.WHITE)
	await _frames(3)
	var reused := false
	for entry: Dictionary in renderer._labels.values():
		var label: Label3D = entry["node"]
		reused = reused or (label.visible and label.text == "34")
	check("the next combat text reuses that label", reused and renderer.label_builds == label_builds)
	check("camera cards share one quad mesh", renderer._new_card(ForestArt.texture("grass"), Rect2(0, 0, 8, 8), true).mesh == renderer._new_card(ForestArt.texture("grass"), Rect2(0, 0, 8, 8), false).mesh)
	game.queue_free()
	await _frames(2)
