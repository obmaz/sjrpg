extends TestCase
## 반복 예고/피해 시계와 실제 GLB 이동·한 번의 피격·일시정지·지역 수명을 확인한다.


func run() -> void:
	var spike := DungeonTrap.new().setup("test", "spike", Vector2.ZERO)
	spike.step(100)
	check(
		"even a long frame cannot skip an entire warning",
		spike.phase == DungeonTrap.Phase.WARNING and spike.age == 0 and not spike.dangerous()
	)
	spike.step(1.2)
	check(
		"entering the active stage does not hit before the spikes rise",
		spike.phase == DungeonTrap.Phase.ACTIVE and not spike.dangerous()
	)
	spike.step(.2)
	check(
		"raised spikes become dangerous after their rise",
		spike.dangerous() and spike.strength() > .99
	)
	check(
		"the marked rectangle covers feet on its own floor", spike.contains_foot(Vector3.ZERO, .1)
	)
	check(
		"another height and distant ground are never hit",
		(
			not spike.contains_foot(Vector3(0, 1.5, 0), .1)
			and not spike.contains_foot(Vector3(4, 0, 0), .1)
		)
	)
	spike.step(.6)
	check(
		"retraction is a safe phase",
		spike.phase == DungeonTrap.Phase.RECOVER and not spike.dangerous()
	)
	spike.step(.5)
	check("every cycle returns to a readable rest", spike.phase == DungeonTrap.Phase.REST)
	var flame := DungeonTrap.new().setup("cone", "flame", Vector2.ZERO, Vector2.RIGHT)
	check(
		"flame cone rotates with its nozzle and keeps its finite width and reach",
		(
			flame.contains_foot(Vector3(1.5, 0, .3), 0)
			and not flame.contains_foot(Vector3(1.5, 0, .8), 0)
			and not flame.contains_foot(Vector3(-.1, 0, 0), 0)
			and not flame.contains_foot(Vector3(3.1, 0, 0), 0)
		)
	)
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("normal entry installs the hazard lifecycle", game.dungeon.enter())
	await _frames(4)
	var hazards: DungeonHazards = game.dungeon.hazards
	var visual: DungeonHazardRenderer3D = game.world_renderer._world_environment._hazards
	check(
		"all authored traps have real imported scenes",
		hazards.traps.size() == 9 and visual.displays.size() == 9
	)
	var model_contract := true
	for display in visual.displays:
		model_contract = (
			model_contract
			and display.root.scene_file_path.ends_with("visual.tscn")
			and display.root.get_node("Geometry").scene_file_path.ends_with("model.glb")
		)
		if display.spikes != null:
			model_contract = model_contract and display.spikes.position.y < -1
		else:
			model_contract = model_contract and display.fire.multimesh.instance_count == 8
	check(
		"rest hides metal spikes below the floor and flame particles stay bounded", model_contract
	)
	var clear_vents := true
	var mounted := true
	for trap: DungeonTrap in hazards.traps:
		if trap.kind != "flame":
			continue
		for chest: Chest in game.chests:
			var foot := WorldSpace3D.projected_to_world(chest.position)
			foot.y = DungeonRelief.at(chest.position)
			clear_vents = clear_vents and not trap.contains_foot(foot, 1.2)
		var source := WorldSpace3D.projected_to_world(trap.position)
		source.y = DungeonRelief.at(trap.position) + .8
		var ray := PhysicsRayQueryParameters3D.create(
			source, source + Vector3(0, 0, -.8), SpatialWorld3D.SOLID
		)
		mounted = (
			mounted
			and not (
				game.spatial_world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
			)
		)
	check("loot chests do not block a flame cone", clear_vents)
	check("flame nozzles are mounted against actual solid cave walls", mounted)
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	var target: DungeonTrap = hazards.traps[0]
	game.spatial_world.teleport_source_actor(game.player, target.position, Player.RADIUS)
	game.player._invulnerable = 0
	target.phase = DungeonTrap.Phase.ACTIVE
	target.age = .2
	target.activation = 1
	target.hit_actors.clear()
	var victim: Enemy = game.enemies[0]
	game.spatial_world.teleport_source_actor(victim, target.position, victim.radius, true)
	var enemy_before: float = victim.hp
	var before: float = game.player.hp
	hazards.tick(.01)
	check("a raised spike field damages a hero standing on it", game.player.hp < before)
	check("enemies can be lured into a timed trap", victim.hp < enemy_before)
	var enemy_hurt: float = victim.hp
	var hurt: float = game.player.hp
	game.player._invulnerable = 0
	hazards.tick(.01)
	check(
		"one activation cannot damage the same hero or enemy twice",
		game.player.hp == hurt and victim.hp == enemy_hurt
	)
	var age := target.age
	var clock := hazards.clock
	get_tree().paused = true
	hazards.tick(2)
	check(
		"pause holds both the cue and damage clock",
		target.age == age and hazards.clock == clock and game.player.hp == hurt
	)
	get_tree().paused = false
	target.hit_actors.clear()
	game.player._invulnerable = 1
	hazards.tick(.01)
	check(
		"a dodge invulnerability window remains effective",
		game.player.hp == hurt and not target.hit_actors.has(game.player.get_instance_id())
	)
	var far: DungeonTrap = hazards.traps.back()
	far.phase = DungeonTrap.Phase.ACTIVE
	far.age = .3
	far.hit_actors.clear()
	var distant: Enemy = game.enemies[1]
	game.spatial_world.teleport_source_actor(
		distant, far.position + Iso.project(far.direction * 65.0), distant.radius, true
	)
	var untouched := distant.hp
	var far_age := far.age
	hazards.tick(.01)
	check(
		"remote phases keep flowing without exhausting an untouched chamber",
		(
			far.age > far_age
			and distant.hp == untouched
			and not far.hit_actors.has(distant.get_instance_id())
		)
	)
	game.spatial_world.teleport_source_actor(
		game.player, far.position + Iso.project(Vector2(100, 100)), Player.RADIUS
	)
	hazards.tick(.01)
	check(
		"approaching a running trap enables the same environmental combat",
		distant.hp < untouched and far.hit_actors.has(distant.get_instance_id())
	)
	var nearby_damage := distant.hp
	game.spatial_world.teleport_source_actor(game.player, target.position, Player.RADIUS)
	hazards.tick(.01)
	check("moving away never repeats one activation's damage", distant.hp == nearby_damage)
	game.player._invulnerable = 0
	target.age = .35
	visual.sync()
	check(
		"the scene part rises using the damage phase rather than a second tween",
		visual.displays[0].spikes.position.y == 0
	)
	var saved: Array = visual.displays.duplicate()
	# 자연 사망의 실제 지연 귀환도 같은 장치 시계를 정리한다.
	target.hit_actors.clear()
	game.player._invulnerable = 0
	game.player.hp = 1
	target.age = .3
	hazards.tick(.01)
	check("trap death stops further damage immediately", game.player.dead)
	var stopped := hazards.clock
	hazards.tick(1)
	check("dead heroes cannot advance an old trap clock", hazards.clock == stopped)
	await get_tree().create_timer(2.6, false).timeout
	await _frames(3)
	check(
		"death returns to the forest and drops the clock and warning UI",
		(
			game.dungeon.hazards == null
			and not game.dungeon.active
			and not game.player.dead
			and not is_instance_valid(game.dungeon._hazard_hint)
		)
	)
	var restored: float = game.player.hp
	hazards.tick(10)
	check(
		"an old cave clock cannot hurt the revived hero in the forest", game.player.hp == restored
	)
	game.queue_free()
	saved.clear()
	await _frames(2)
