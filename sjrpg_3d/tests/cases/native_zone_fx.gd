extends TestCase
const Fixture := preload("res://tests/native_combat_fixture.gd")


func _cast(game: Node, skill: String) -> Effect:
	var hero: Player = game.player
	hero._cancel_actions()
	hero.cooldowns.clear()
	hero.resource = hero.resource_max
	GameState.ranks[skill] = 1
	GameState.slots[0] = skill
	check("actual equipped zone action begins: " + skill, hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.51)
	for child in game.world.get_children():
		if child is Effect and child.kind == "zone" and not child.is_queued_for_deletion():
			child.set_process(false)
			return child
	return null


func run() -> void:
	var old_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	var fx: AreaEffects3D = renderer._zone_fx
	var floor_body := Fixture.box(game.spatial_world, Fixture.remote_at(Vector3(120, 2.5, 120)), Vector3(30, 1, 30), SpatialWorld3D.FLOOR)
	await Fixture.settle(get_tree())
	game.spatial_world.teleport_source_actor(game.player, SpatialWorld3D.projected(Fixture.remote_at(Vector3(120, 3, 120))), Player.RADIUS)
	game.player.facing = 0.0
	var meteor := _cast(game, "meteor")
	if not check("real meteor creates the skipped persistent source", meteor != null and str(meteor.params["visual"]) == "meteor"):
		game.queue_free()
		await _frames(2)
		return
	var id := meteor.get_instance_id()
	renderer._sync_cards()
	fx.sync()
	check("meteor warning now renders natively once while source Canvas is hidden", fx._entries.has(id) and not renderer._cards.has(id) and not game.field_root.visible)
	var entry: Dictionary = fx._entries[id]
	var root: Node3D = entry["root"]
	var marker: MeshInstance3D = entry["marker"]
	var glows := entry["glows"] as MultiMeshInstance3D
	check("marker follows actual raised floor and does not double-project its height", root.global_position.is_equal_approx(meteor.native_position()) and is_equal_approx(root.global_position.y, 3.0) and is_equal_approx(marker.position.y, AreaEffects3D.SURFACE_LIFT))
	check("zone picture has two surfaces and generated atlas glows in a bounded MultiMesh", root.get_child_count() == 2 and marker.mesh.get_surface_count() == 1 and glows.multimesh.mesh.get_surface_count() == 1 and glows.multimesh.instance_count == AreaEffects3D.MAX_GLOWS)
	check("warning uses real depth instead of drawing through walls", "depth_test_disabled" not in (glows.material_override as ShaderMaterial).shader.code and not (marker.material_override as StandardMaterial3D).no_depth_test)
	var points: PackedVector2Array = entry["points"]
	var matches := true
	for point in points:
		matches = matches and absf(point.length() - meteor.radius) < 0.001
		var native := AreaEffects3D._local_ground(point)
		matches = matches and SpatialWorld3D.projected(native).distance_to(point) < 0.001
	check("warning perimeter inverse-projects the actual source distance budget", matches and points.size() == AreaEffects3D.SEGMENTS)
	var before_age := meteor.age
	var before_params := meteor.params.duplicate(true)
	var before_resource: float = game.player.resource
	var before_children: int = game.world.get_child_count()
	var first_fall: Vector3 = entry["glow_offsets"][0]
	for repeat in 4:
		fx.sync()
	check("renderer does not advance age, trigger impact, consume resources or spawn effects", meteor.age == before_age and meteor.params == before_params and game.player.resource == before_resource and game.world.get_child_count() == before_children)
	check("steady source does not rebuild the ground mesh", int(entry["mesh_builds"]) == 1)
	meteor._process(0.35)
	fx.sync()
	check("falling generated cue follows the source delay clock", str(entry["phase"]) == "warning" and (Vector3(entry["glow_offsets"][0])).y < first_fall.y)
	var paused_at := root.global_transform
	var paused_offset: Vector3 = entry["glow_offsets"][0]
	var paused_age := meteor.age
	meteor.set_process(true)
	get_tree().paused = true
	await _frames(3)
	fx.sync()
	check("pause holds source timer, native floor and falling cue", meteor.age == paused_age and root.global_transform.is_equal_approx(paused_at) and (Vector3(entry["glow_offsets"][0])).is_equal_approx(paused_offset))
	get_tree().paused = false
	meteor.set_process(false)
	Prefs.reduce_motion = true
	fx.sync()
	check("reduced motion retains warning footprint with one quiet fixed falling cue", glows.multimesh.visible_instance_count == 1 and (Vector3(entry["glow_offsets"][0])).is_equal_approx(Vector3(0, 0.45, 0)) and marker.visible)
	Prefs.reduce_motion = false
	meteor._process(float(meteor.params["delay"]) - meteor.age + 0.02)
	fx.sync()
	check("actual source impact switches to quiet continuing damage-zone cue", bool(meteor.params.get("impacted", false)) and str(entry["phase"]) == "active" and glows.multimesh.visible_instance_count == 5)
	var impacts: int = game.world.get_children().filter(func(node): return node is Effect and node.kind == "skill_fx" and str(node.params.get("visual", "")) == "meteor").size()
	fx.sync()
	check("native zone does not duplicate the existing one-shot authored meteor impact", impacts == 1 and game.world.get_children().filter(func(node): return node is Effect and node.kind == "skill_fx" and str(node.params.get("visual", "")) == "meteor").size() == impacts)
	meteor._process(meteor.life + 0.1)
	fx.sync()
	check("actual expiry removes the persistent picture", not fx._entries.has(id))
	await _frames(2)
	var wall := _cast(game, "firewall")
	if check("actual firewall creates a wall-shaped persistent source", wall != null and wall.params.has("wall")):
		fx.sync()
		var wall_entry: Dictionary = fx._entries[wall.get_instance_id()]
		var axis := Vector2.from_angle(float(wall.params["wall"]))
		var strip := true
		var spread := 0.0
		for point: Vector2 in wall_entry["points"]:
			strip = strip and absf(point.dot(axis.orthogonal())) <= 26.01 and point.length() <= wall.radius + 10.01
			spread = maxf(spread, absf(point.dot(axis)))
		check("firewall footprint respects its actual narrow attack strip rather than a full disk", strip and spread > wall.radius * 0.9)
		check("firewall flames share one instanced atlas draw", (wall_entry["glows"] as MultiMeshInstance3D).multimesh.visible_instance_count == 9)
		wall.queue_free()
	await _frames(2)
	var ice := _cast(game, "blizzard")
	if check("actual blizzard creates its sustained cold source", ice != null and bool(ice.params["shards"])):
		fx.sync()
		var ice_entry: Dictionary = fx._entries[ice.get_instance_id()]
		check("cold zone displays its own generated elemental cell", int(ice_entry["cell"]) == Effect._element_cell(ice.color) and (ice_entry["glows"] as MultiMeshInstance3D).multimesh.visible_instance_count == 5)
		ice.queue_free()
	await _frames(2)
	var forest_world: Node = game.world
	for index in AreaEffects3D.MAX_ZONES + 3:
		game.spawn_zone({"pos": game.player.position + Vector2(index, 0), "radius": 70.0, "duration": 4.0, "tick": 0.3, "damage": 0.0, "color": SkillDefs.FIRE})
	fx.sync()
	check("zone picture budget never deletes excess gameplay sources", fx._entries.size() == AreaEffects3D.MAX_ZONES and game.world.get_children().filter(func(node): return node is Effect and node.kind == "zone" and not node.is_queued_for_deletion()).size() == AreaEffects3D.MAX_ZONES + 3)
	game.player.position = game.dungeon.entry_point()
	check("zone scope fixture enters the actual cave", game.dungeon.enter())
	fx.sync()
	check("actual cave transition removes forest zone pictures", game.world != forest_world and fx._entries.is_empty())
	game.dungeon.leave("")
	await Fixture.settle(get_tree())
	fx.sync()
	check("actual forest return observes only living forest source zones", game.world == forest_world and fx._entries.size() > 0 and fx._entries.size() <= AreaEffects3D.MAX_ZONES)
	floor_body.queue_free()
	Prefs.reduce_motion = old_motion
	game.queue_free()
	await _frames(2)
