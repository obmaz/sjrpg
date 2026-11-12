extends TestCase
## 밟기 전/후 저장·빛, 열린 배치, 실제 하강 보행과 다리 높이를 검증한다.
func run() -> void:
	var game := await make_game("mage")
	game.player.set_process(false)
	game.exploration.set_process(false)
	game._spawn_timer = 10000.0
	var renderer: WorldRenderer3D = game.world_renderer
	var props: TownPropRenderer3D = renderer._town_props
	for id: String in ["tree","cave"]:
		var source: IsoSprite = game.village.portal_sprites[id]
		var at := source.position
		props.sync()
		var entry: Dictionary = props._entries[source.get_instance_id()]
		var material: ShaderMaterial = entry["fluid"]
		check("unvisited field waypoint stays dark: "+id,float(material.get_shader_parameter("strength"))==0.0 and not entry["motes"].visible and entry["lights"].size()==4 and entry["lights"].all(func(light: OmniLight3D): return not light.visible))
		game.player.position = at+Iso.project(Vector2(1.8,0)*WorldSpace3D.GROUND_UNITS_PER_METER)
		game.exploration.discover_current()
		check("walking beside the seal does not activate it: "+id,not GameState.discovered_sanctuaries.has(id))
		game.spatial_world.teleport_source_actor(game.player,at,Player.RADIUS)
		check("ground waypoint centre is physically walkable: "+id,game.player.position.distance_to(at)<1.0 and not game._blocked(at,Player.RADIUS))
		game.exploration.discover_current()
		props.sync()
		check("stepping on the seal persists discovery and turns on its light: "+id,GameState.discovered_sanctuaries.has(id) and float(material.get_shader_parameter("strength"))==1.0 and entry["motes"].visible and entry["lights"].all(func(light: OmniLight3D): return light.visible and not light.shadow_enabled and light.light_energy<=0.25))
		var lights: Array = entry["lights"]
		check("four lights occupy distinct corners instead of a central glow: "+id,lights[0].position.x<0 and lights[0].position.z<0 and lights[1].position.x>0 and lights[1].position.z<0 and lights[2].position.x<0 and lights[2].position.z>0 and lights[3].position.x>0 and lights[3].position.z>0)
		check("field waypoint has no upright portal volume: "+id,entry["root"].get_node("EngravedGroundSeal").get_aabb().size.y<0.05)
		for landmark: Landmark in game.village.landmarks:
			var distance := INF
			for i: int in landmark.top.size():
				distance = minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,landmark.top[i],landmark.top[(i+1)%landmark.top.size()])))
			check("field waypoint has open space beside raised land: "+id,distance>=229.0 and not Geometry2D.is_point_in_polygon(at,landmark.top))
		var cave_centre := NativeCavePlan.body_center(game.dungeon.entry_point())
		check("field waypoint is separated from the cave hill: "+id,at.distance_to(cave_centre)>NativeCavePlan.SOURCE_RADIUS+250.0)
	check("waypoint discoveries survive reload",GameState.load_game() and GameState.discovered_sanctuaries.has("tree") and GameState.discovered_sanctuaries.has("cave"))
	var river := GroundRelief3D.river_outline(game.village)
	var mid := (river[0]+river[1])*0.5
	var dry := Iso.project((mid-Vector2(0,2.1))*WorldSpace3D.GROUND_UNITS_PER_METER)
	var wet := Iso.project((mid-Vector2(0,0.65))*WorldSpace3D.GROUND_UNITS_PER_METER)
	game.spatial_world.teleport_source_actor(game.player,dry,Player.RADIUS)
	for i: int in 40:
		game.spatial_world.move_source_actor(game.player,game.player.position.move_toward(wet,4.0),Player.RADIUS)
	var bank_y: float = game.spatial_world.height_at(game.player.position)
	check("real player walks down the river bank below surrounding land",bank_y < -0.35 and bank_y > GroundRelief3D.BED_LEVEL)
	check("bridge deck remains above the sunken river",absf(game.spatial_world.height_at(game.village.bridge.axis_point(0.5)))<0.01 and GroundRelief3D.WATER_LEVEL < -1.0)
	game.queue_free()
	await _frames(2)
