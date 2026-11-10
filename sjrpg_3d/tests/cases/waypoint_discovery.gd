extends TestCase

func _discoveries(game: Node) -> Array:
	return game.cosmetic_effects.filter(func(effect: Effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.params.has("waypoint_position"))

func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.exploration.set_process(false)
	game.encounters.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	preview.set_process(false)
	var at: Vector2 = game.village.portal_points["cave"]
	game.spatial_world.teleport_source_actor(game.player,at+Iso.project(Vector2(2.0,0)*65.0),Player.RADIUS)
	game.exploration.discover_current()
	check("passing beside a waypoint produces no discovery effect or banner",_discoveries(game).is_empty() and game.hud._level_up==null)
	game.spatial_world.teleport_source_actor(game.player,at,Player.RADIUS)
	game.exploration.discover_current()
	var sources := _discoveries(game)
	check("first physical activation creates exactly one confirmed discovery cue",sources.size()==1 and GameState.discovered_sanctuaries.has("cave") and GameState.level==1)
	if sources.is_empty():
		game.queue_free()
		return
	var source: RewardFx = sources[0]
	source.set_process(false)
	var banner: LevelUpBanner = game.hud._level_up
	banner.set_process(false)
	check("discovery announces the location in the nonblocking level-up banner",banner.active and banner.heading=="웨이포인트 발견" and banner.detail.contains(Exploration.NAMES["cave"]) and banner.detail.contains("워프 이동 가능") and banner.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	preview._process(0.0)
	var celebration: Ortho3DLevelUp = preview._level_up_fx
	var entry: Dictionary = celebration._entries[source.get_instance_id()]
	var root: Node3D = entry["root"]
	var ring: MeshInstance3D = entry["ring"]
	var anchor := root.position
	check("discovery surrounds the whole actual waypoint on its raised floor",root.name=="WaypointDiscovery" and (ring.mesh as TorusMesh).inner_radius>NativeWaypoint3D.RADIUS and anchor.distance_to(Ortho3DPreview.ground_position(at,preview.surface_height(at)))<0.01)
	game.player.position += Vector2(400,400)
	source._process(0.1)
	preview._process(0.0)
	check("discovery stays at the waypoint when the hero leaves",root.position==anchor and source.owner_node==null)
	var spark: MeshInstance3D = entry["sparks"][0]
	Prefs.reduce_motion = true
	preview._process(0.0)
	var stationary := spark.position
	source._process(0.2)
	preview._process(0.0)
	check("reduced motion holds the discovery glints in place",spark.position==stationary and banner.rise_offset()==0.0)
	Prefs.reduce_motion = false
	source.set_process(true)
	banner.set_process(true)
	preview.set_process(true)
	get_tree().paused = true
	var age := source.age
	var banner_age := banner.age
	await _frames(2)
	check("menus pause the discovery source and screen announcement",source.age==age and banner.age==banner_age)
	get_tree().paused = false
	source.set_process(false)
	banner.set_process(false)
	preview.set_process(false)
	game.spatial_world.teleport_source_actor(game.player,at,Player.RADIUS)
	game.exploration.discover_current()
	check("stepping on the discovered seal never repeats its cue",_discoveries(game).size()==1 and banner._pending.is_empty())
	banner.show_level(2)
	check("a simultaneous level-up preserves the queued discovery announcement",banner.heading==LevelUpBanner.TITLE and banner._pending.size()==1)
	banner._process(0.1)
	banner._process(LevelUpBanner.DURATION+0.1)
	check("the discovery announcement follows the level-up instead of being lost",banner.heading=="웨이포인트 발견" and banner.active and banner._pending.is_empty())
	source._process(2.0)
	preview._process(0.0)
	check("discovery geometry expires with the real source",source.is_queued_for_deletion() and not celebration._entries.has(source.get_instance_id()))
	check("discovery is persisted before resuming a saved game",GameState.load_game() and GameState.discovered_sanctuaries.has("cave"))
	game.exploration.discover_current()
	check("loading an already discovered waypoint cannot replay the effect",_discoveries(game).is_empty())
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)
