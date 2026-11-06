extends TestCase
## Fluid movement must never redraw Polygon2D UV/index data on Godot 4.7 WebGL.


func run() -> void:
	var river := River.new().setup(-200, 200, -80, 80, 100)
	add_child(river)
	await _frames(2)
	var water_vertices := river._water.polygon.duplicate()
	var shimmer_vertices := river._shimmer.polygon.duplicate()
	var water_uv := river._water.uv.duplicate()
	var shimmer_uv := river._shimmer.uv.duplicate()
	var time := river._time
	var water_offset: Vector2 = river._water_material.get_shader_parameter("flow_offset")
	var shimmer_offset: Vector2 = river._shimmer_material.get_shader_parameter("flow_offset")
	await _frames(3)
	var elapsed := river._time - time
	var size := river._water.texture.get_size()
	var new_water: Vector2 = river._water_material.get_shader_parameter("flow_offset")
	var new_shimmer: Vector2 = river._shimmer_material.get_shader_parameter("flow_offset")
	check("river sample uniforms retain both original flow velocities", elapsed > 0.0 and (new_water - water_offset).distance_to(Vector2(38, 6) * elapsed / size) < 0.0001 and (new_shimmer - shimmer_offset).distance_to(Vector2(-24, 11) * elapsed / size) < 0.0001)
	check("flow never changes Polygon2D geometry or texture UVs", river._water.polygon == water_vertices and river._shimmer.polygon == shimmer_vertices and river._water.uv == water_uv and river._shimmer.uv == shimmer_uv and river._water.texture_offset == Vector2.ZERO and river._shimmer.texture_offset == Vector2.ZERO)
	check("generated water keeps its reviewed color with a restrained translucent shimmer", river._water.modulate.is_equal_approx(Color.WHITE) and river._shimmer.modulate.is_equal_approx(Color(1, 1, 1, 0.07)))
	check("both layers keep mirrored texture repetition", river._water.texture_repeat == CanvasItem.TEXTURE_REPEAT_MIRROR and river._shimmer.texture_repeat == CanvasItem.TEXTURE_REPEAT_MIRROR)
	time = river._time
	get_tree().paused = true
	await _frames(3)
	check("pause freezes simulation time and both sample uniforms", river._time == time and river._water_material.get_shader_parameter("flow_offset") == new_water and river._shimmer_material.get_shader_parameter("flow_offset") == new_shimmer)
	get_tree().paused = false
	await _frames(2)
	check("resuming advances the existing fluid phase", river._time > time)
	river.queue_free()
	await _frames(2)
