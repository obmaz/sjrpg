extends TestCase
## 필드 확장, 포장길과 분리된 암반 진입로, 실제 장거리 하강과 두꺼운 표식.
func run() -> void:
	var game := await make_game("mage")
	game.player.set_process(false)
	game.encounters.set_process(false)
	game._spawn_timer = 1000000.0
	check("map retains its northwest corner and quadruples area",game.FIELD.position==Vector2(-3600,-3600) and game.FIELD.size==Vector2(14400,14400))
	var far_ground := Iso.project(Vector2(10000,9800))
	game.spatial_world.teleport_source_actor(game.player,far_ground,Player.RADIUS)
	check("expanded southeast has actual walkable native floor",game.player.position.distance_to(far_ground)<5.0 and absf(game.spatial_world.height_at(far_ground))<0.01)
	var frame := NativeCavePlan.frame(game.dungeon.entry_point())
	var centre := Vector2(frame.origin.x,frame.origin.z)
	var road_distance := INF
	for road: PackedVector2Array in game.village.map_roads:
		for i: int in road.size():
			var a := Iso.unproject(road[i])/65.0
			var b := Iso.unproject(road[(i+1)%road.size()])/65.0
			road_distance = minf(road_distance,centre.distance_to(Geometry2D.get_closest_point_to_segment(centre,a,b)))
	check("cave rocky district is separated from every paved road",road_distance>NativeCavePlan.SITE_RADIUS+8.0)
	var start := SpatialWorld3D.projected(frame*Vector3(0,0,22))
	var target := SpatialWorld3D.projected(frame*Vector3(0,0,0.4))
	game.spatial_world.teleport_source_actor(game.player,start,Player.RADIUS)
	var previous: float = game.spatial_world.height_at(game.player.position)
	var initial := previous
	var maximum_step := 0.0
	for i: int in 500:
		if game.player.position.distance_to(target)<3.0:
			break
		game.spatial_world.move_source_actor(game.player,game.player.position.move_toward(target,4.0),Player.RADIUS)
		var current: float = game.spatial_world.height_at(game.player.position)
		maximum_step = maxf(maximum_step,absf(current-previous))
		previous = current
	check("a continuous long downhill reaches the cave mouth",initial>-0.05 and previous< -3.0 and maximum_step<0.15 and game.player.position.distance_to(target)<6.0,"start=%f end=%f step=%f remaining=%f" % [initial,previous,maximum_step,game.player.position.distance_to(target)])
	check("bridge stands near the far end of the extended river",game.village.forecourt_g.x>=9000.0 and game.village.river_band.size.x>9000.0)
	var props: NativeTownProps3D = game.ortho_preview._town_props
	props.sync()
	var source: IsoSprite = game.village.portal_sprites["cave"]
	var root: Node3D = props._entries[source.get_instance_id()]["root"]
	var body: MeshInstance3D = root.get_node("BeveledStonePlinth")
	check("waypoint has a real thick bevel and matching walking floor",body.get_aabb().size.y>0.23 and absf(game.spatial_world.height_at(source.position)-root.position.y-NativeWaypoint3D.HEIGHT)<0.01)
	var env: Ortho3DEnvironment = game.ortho_preview._world_environment
	game.ortho_preview.set_process(false)
	var phase: float = env._water_material.get_shader_parameter("phase")
	env.sync(1.0,false)
	var advanced: float = env._water_material.get_shader_parameter("phase")
	env.sync(5.0,true)
	check("actual native river flow advances and respects pause",advanced>phase+0.99 and is_equal_approx(float(env._water_material.get_shader_parameter("phase")),advanced))
	game.queue_free()
	await _frames(2)
