extends TestCase
## 실제 공간 이동 전후 전체 배우 알파·재질 복원·일시정지·입력/중복 이동을 검증한다.


func run() -> void:
	for hero: String in ["mage", "warrior"]:
		var game := await make_game(hero)
		game.player.set_process(false)
		game._spawn_timer = 10000.0
		var route: Exploration = game.exploration
		var travel: WarpTravel = route.transition
		travel.set_process(false)
		GameState.discovered_sanctuaries.append("tree")
		game.spatial_world.teleport_source_actor(
			game.player, route.gate_approach("town"), Player.RADIUS
		)
		var origin: Vector2 = game.player.position
		var destination := route.gate_approach("tree")
		check(
			"warp starts with the hero still at the departure point " + hero,
			route.warp("tree") and game.player.position == origin and game.player.warp_locked
		)
		check(
			"duplicate requests cannot skip the disappearance phase " + hero, not route.warp("tree")
		)
		var health: float = game.player.hp
		game.player.take_damage(100.0)
		check(
			"hidden travel cannot attack or take incidental damage " + hero,
			not game.player.cast_slot(0) and game.player.hp == health
		)
		var energy: float = game.player.resource
		game.player.hp -= 20
		game.player.resource = 0
		var potions := GameState.potions
		var mana := GameState.mana_potions
		game.player.use_potion()
		game.player.use_mana_potion()
		check(
			"warp input cannot spend potions before the free arrival recovery " + hero,
			(
				GameState.potions == potions
				and GameState.mana_potions == mana
				and game.player.hp == health - 20
				and game.player.resource == 0
			)
		)
		game.player.hp = health
		game.player.resource = energy
		game.player.cooldowns["test"] = 2.0
		game.player.buffs["storm"] = {"time": 3.0, "rank": 1}
		game.player._storm_timer = .1
		var held_position: Vector2 = game.player.position
		game.player.move_input = Vector2.RIGHT
		game.player._process(.2)
		check(
			"warp keeps simulation cooldowns and buffs ticking " + hero,
			(
				is_equal_approx(game.player.cooldowns["test"], 1.8)
				and is_equal_approx(game.player.buffs["storm"]["time"], 2.8)
				and game.player.position == held_position
				and game.player._storm_timer <= 0
			)
		)
		game.player.buffs.clear()
		game.player.cooldowns.erase("test")
		_advance(travel, WarpTravel.OUT * .5)
		game.ortho_preview._sync_actor(0)
		var effect: NativeWarpFx = game.ortho_preview._warp_fx
		effect.sync()
		var uniform := not effect.fade.slots.is_empty()
		for slot in effect.fade.slots:
			var ink := slot.fade
			uniform = (uniform and absf(ink.albedo_color.a - slot.color.a * .5) < .001)
		check(
			"every actor surface fades together at the original location " + hero,
			uniform and effect.root.visible and game.player.position == origin
		)
		var held := travel.age
		get_tree().paused = true
		travel._process(1.0)
		check("pause holds the complete warp transition " + hero, travel.age == held)
		get_tree().paused = false
		_advance(travel, WarpTravel.OUT * .5 + .01)
		effect.sync()
		check(
			"the real transfer occurs only after full disappearance " + hero,
			(
				travel.transferred
				and travel.opacity() == 0
				and game.player.position.distance_to(destination) < .01
				and GameState.last_sanctuary == "tree"
			)
		)
		_advance(travel, .18)
		effect.sync()
		check(
			"arrival reveals the hero gradually at the safe destination " + hero,
			(
				travel.opacity() > 0
				and travel.opacity() < 1
				and (
					effect.root.position.distance_to(game.ortho_preview.actor_foot(game.player))
					< .001
				)
			)
		)
		_advance(travel, 1.0)
		effect.sync()
		var restored := true
		for slot in effect.fade.slots:
			var mesh: MeshInstance3D = slot.mesh
			var material := (
				mesh.material_override
				if slot.index < 0
				else mesh.get_surface_override_material(slot.index)
			)
			restored = restored and material == slot.original
		check(
			"completion restores original shared materials and controls " + hero,
			(
				restored
				and not effect.root.visible
				and not travel.active
				and not game.player.warp_locked
			)
		)
		check("a hitch test can start " + hero, route.warp("town"))
		travel._process(1.0)
		effect.sync()
		check(
			"a one-second hitch cannot skip departure and arrival " + hero,
			(
				travel.active
				and not travel.transferred
				and travel.opacity() > 0
				and travel.opacity() < 1
				and game.player.position.distance_to(destination) < .01
			)
		)
		_advance(travel, 1.0)
		effect.sync()
		check("restore the tree departure for blocker test " + hero, route.warp("tree"))
		_advance(travel, 1.0)
		effect.sync()
		# 새 장애물이 도착지를 막으면 사라짐 뒤에도 출발점에서 안전하게 취소한다.
		origin = game.player.position
		check("a return transition can start " + hero, route.warp("town"))
		var cylinder := CylinderShape3D.new()
		cylinder.radius = SpatialWorld3D.radius_metres(350)
		cylinder.height = 8
		var at := SpatialWorld3D.native_point(route.gate_point("town"), 4)
		var blocker: StaticBody3D = game.spatial_world._shape_body(
			cylinder,
			Transform3D(Basis.IDENTITY, at),
			SpatialWorld3D.SOLID,
			"WarpAfterDepartureBlocker"
		)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_advance(travel, WarpTravel.OUT + .01)
		effect.sync()
		check(
			"a newly blocked arrival cancels without invisible or stuck controls " + hero,
			(
				not travel.active
				and game.player.position == origin
				and not game.player.warp_locked
				and not effect.root.visible
			)
		)
		blocker.collision_layer = 0
		blocker.queue_free()
		game.queue_free()
		await _frames(2)


func _advance(travel: WarpTravel, duration: float) -> void:
	# 실제 렌더 프레임 간격으로 진행한다. 큰 delta 회귀는 별도로 호출한다.
	while duration > .00001:
		var step := minf(duration, 1.0 / 60.0)
		travel._process(step)
		duration -= step
