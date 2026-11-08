extends TestCase
## Stable minimap pictures stay uploaded while their transforms follow live game state.


func _dot_requests(minimap: Minimap) -> int:
	var count := 0
	for dot: Minimap.MarkerDot in minimap._dots:
		count += dot.redraw_requests
	return count


func _check_arrow(minimap: Minimap, angle: float) -> void:
	minimap.game.player.facing = angle
	minimap._sync_retained()
	var r := minimap.radius
	var expected := PackedVector2Array([Vector2.from_angle(angle) * r * 0.09,
		Vector2.from_angle(angle + 2.5) * r * 0.055,
		Vector2.from_angle(angle + PI) * 2.0,
		Vector2.from_angle(angle - 2.5) * r * 0.055])
	var points := minimap._arrow_points()
	var maximum := 0.0
	for index in points.size():
		var actual := minimap._player_arrow.transform * points[index]
		maximum = maxf(maximum, actual.distance_to(minimap.size / 2.0 + expected[index]))
	check("retained player rotation preserves all original arrow points at " + str(angle), maximum < 0.0001)


func run() -> void:
	var game := await make_game("mage")
	# Freeze simulation, not Canvas rendering, so all source changes below are explicit.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var minimap: Minimap = game.hud.minimap
	minimap._sync_retained()
	await _frames(2)
	var terrain := minimap.terrain_redraw_requests
	var decoration := minimap.decoration_redraw_requests
	var dots := _dot_requests(minimap)
	var identities: Array = minimap._dots.duplicate()
	var mesh: ArrayMesh = minimap._geometry_mesh
	for frame in 120:
		minimap._sync_retained()
	check("idle minimap retains terrain and bezel commands",
		minimap.terrain_redraw_requests == terrain and minimap.decoration_redraw_requests == decoration
		and minimap._geometry_mesh == mesh)
	check("idle marker circles retain their commands and nodes",
		_dot_requests(minimap) == dots and minimap._dots == identities)
	check("original painter order keeps backdrop behind terrain and bezel above the dots and arrow",
		minimap._backdrop.show_behind_parent
		and minimap._marker_layer.get_index() < minimap._player_arrow.get_index()
		and minimap._player_arrow.get_index() < minimap._bezel.get_index())

	var original_position: Vector2 = game.player.position
	game.player.position += Vector2(80, 20)
	minimap._sync_retained()
	var marker: Dictionary = MapGeometry.markers(game)[0]
	check("moving the player moves current map dots by the original projection",
		minimap._dots[0].position.is_equal_approx(minimap._to_map(marker["pos"], game.player.position)))
	check("moving terrain does not repaint circles or static decoration",
		minimap.terrain_redraw_requests > terrain and minimap.decoration_redraw_requests == decoration
		and _dot_requests(minimap) == dots and minimap._dots == identities)
	for angle in [0.0, 0.75, -2.1]:
		_check_arrow(minimap, angle)
	check("turning the player does not repaint terrain or decoration",
		minimap.decoration_redraw_requests == decoration and _dot_requests(minimap) == dots)

	var count := minimap._dots.size()
	var enemy := Enemy.new()
	enemy.position = game.player.position + Vector2(100, 0)
	game.enemies.append(enemy)
	minimap._sync_retained()
	var enemy_dot: Minimap.MarkerDot = minimap._dots.back()
	check("a live enemy adds one correctly colored circle without retaining an actor",
		minimap._dots.size() == count + 1 and enemy_dot.visible
		and enemy_dot.ink == Color(0.74, 0.26, 0.18, 0.88))
	var enemy_draws := enemy_dot.redraw_requests
	enemy.position += Vector2(30, 25)
	minimap._sync_retained()
	check("a moving enemy updates only its circle transform",
		enemy_dot.position.is_equal_approx(minimap._to_map(enemy.position, game.player.position))
		and enemy_dot.redraw_requests == enemy_draws)
	enemy.position = game.player.position + Vector2(Minimap.WORLD_RADIUS * 2.0, 0)
	minimap._sync_retained()
	check("outside markers are hidden without making another circle",
		not enemy_dot.visible and enemy_dot.redraw_requests == enemy_draws)
	enemy.dead = true
	minimap._sync_retained()
	check("dead enemies release excess marker nodes", minimap._dots.size() == count and not is_instance_valid(enemy_dot))
	game.enemies.erase(enemy)
	enemy.free()

	decoration = minimap.decoration_redraw_requests
	minimap.radius += 16.0
	minimap.size += Vector2(32, 32)
	minimap._sync_retained()
	check("resizing refreshes decoration and keeps current circle radii and center",
		minimap.decoration_redraw_requests == decoration + 1
		and is_equal_approx(minimap._dots[0].dot_radius, maxf(2.0, minimap.radius * 0.035))
		and minimap._bezel.position == minimap.size / 2.0)
	_check_arrow(minimap, 1.25)

	var forest_shapes: Array[Dictionary] = game.map_shapes
	game.dungeon.active = true
	game.map_shapes = [] as Array[Dictionary]
	game.player.position = Vector2.ZERO
	minimap._sync_retained()
	check("realm changes remove forest markers and terrain",
		minimap._dots.size() == 2 and minimap._geometry.is_empty())
	var cave_marker: Dictionary = MapGeometry.markers(game)[0]
	check("cave markers retain their actual source positions and colors",
		minimap._dots[0].position.is_equal_approx(minimap._to_map(cave_marker["pos"], game.player.position))
		and minimap._dots[0].ink == Color(cave_marker["color"], 0.82))
	game.dungeon.active = false
	game.map_shapes = forest_shapes
	game.player.position = original_position
	minimap._sync_retained()
	check("returning to the forest restores its current markers",
		minimap._dots.size() == MapGeometry.markers(game).size() and not minimap._geometry.is_empty())

	var opened: Array[int] = [0]
	minimap.open_requested.connect(func() -> void: opened[0] += 1)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = minimap.size / 2.0
	minimap._gui_input(touch)
	check("retained children leave the existing minimap touch action intact",
		opened[0] == 1 and minimap.mouse_filter == Control.MOUSE_FILTER_STOP)
	# The tap also opens the real HUD map panel; close it before freeing the fixture.
	game.hud.close_panel()
	check("the real map modal closes without leaving the next game paused", not get_tree().paused)
	game.queue_free()
	await _frames(2)
