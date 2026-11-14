class_name AdventureReviewScenes
extends Node
## 명시적으로 요청한 검수 장면만 구성한다. 실제 게임의 이동·전투·보상 경로를 사용한다.
var _game: Node2D
var _inspection: Node
var _encounter_audit := false


func setup(game: Node2D, inspection: Node) -> AdventureReviewScenes:
	_game = game
	_inspection = inspection
	return self


func place_at_house(key: String) -> void:
	var id: String = NativeHousePlan.STYLES[key]["wall"]
	var layout := (
		load(ArchitectureSceneLibrary.ARCHITECTURE_SCENE_ROOT + id + "/layout.tres") as Resource
	)
	var report: Dictionary = layout.get_meta("report")
	var entry: Rect2 = report["door_approach"]
	var pose := TownPlazaPlan3D.frame(key)
	var at := pose * Vector3(entry.get_center().x, 0, entry.position.y + 1.2)
	_game.spatial_world.teleport_source_actor(
		_game.player, WorldSpace3D.world_to_projected(at), Player.RADIUS
	)
	# 정상 플레이의 인물 추적으로 문 앞 가독성과 UI 겹침을 함께 검수한다.
	_inspection.focus_point = Vector2.ZERO


func place_at_chapel() -> void:
	# Use the same real walkable entry for direct links and saved adventures.
	var entry: Vector2 = _game.village.chapel_steps[0]
	_game.player.position = entry
	for offset: Vector2 in [Vector2(80, 75), Vector2(100, 100), Vector2(120, 130)]:
		if not _game._blocked(entry + offset, Player.RADIUS):
			_game.player.position = entry + offset
			break


func publish_encounter_state() -> void:
	if not _encounter_audit or not OS.has_feature("web"):
		return
	var state: Dictionary = _game.encounters.states["west"]
	JavaScriptBridge.eval(
		(
			"window.__sjrpgEncounterAudit = "
			+ JSON.stringify(
				{
					"charges": state["charges"],
					"living": _game.encounters.living("west"),
					"ready": _game.encounters.can_summon("west")
				}
			)
		)
	)


## Explicit cave-art review only: enter the real instance and freeze a reproducible view.
func preview_dungeon(which: String) -> void:
	JavaScriptBridge.eval("window.__sjrpgDungeonPreviewReady = false")
	await _game.get_tree().create_timer(1.5, false).timeout
	if _game.is_queued_for_deletion():
		return
	if _game.hud.panel_open():
		_game.hud.close_panel()
	_game.player.position = _game.dungeon.entry_point()
	if not _game.dungeon.enter():
		push_error("Cave preview could not enter the actual dungeon")
		return
	var ground := Vector2.ZERO
	match which:
		"room", "room_clear", "all_clear_live":
			ground = DungeonLayout.ROOMS[0]
		"branch":
			ground = Vector2(1125, -500)
		"exit":
			# 원래 완료 판정이 빠지던 문 반대편의 실제 보행 지점을 검수한다.
			ground = Iso.unproject(_game.dungeon.return_portal().position + Vector2(110, 0))
		"upper":
			ground = Vector2(1125, -500)
		"lower":
			ground = Vector2(2825, 500)
		"dodge":
			var target: DungeonTrap = _game.dungeon.hazards.traps[1]
			target.phase = DungeonTrap.Phase.ACTIVE
			target.age = .3
			ground = Iso.unproject(target.position)
		"spikes", "spikes_warn", "spikes_live", "flame", "flame_warn", "flame_live":
			var target: DungeonTrap = _game.dungeon.hazards.traps[
				5 if which.begins_with("flame") else 0
			]
			target.phase = (
				DungeonTrap.Phase.WARNING if which.ends_with("warn") else DungeonTrap.Phase.ACTIVE
			)
			target.age = .40
			ground = (
				Iso.unproject(target.position)
				+ (Vector2(0, 225) if target.kind == "flame" else Vector2(-130, 0))
			)
			_inspection.focus_point = (
				target.position + Iso.project(Vector2(0, 75))
				if target.kind == "flame"
				else target.position
			)

	if which in ["room_clear", "all_clear_live"]:
		for enemy: Enemy in _game.enemies.duplicate():
			if (
				which == "all_clear_live"
				or enemy.patrol_center == Iso.project(DungeonLayout.ROOMS[0])
			):
				enemy.take_damage(enemy.hp, null)
	_game.player.position = Iso.project(ground)
	_game.player.move_input = Vector2.ZERO
	if which == "dodge":
		_game.spatial_world.teleport_source_actor(
			_game.player, _game.player.position, Player.RADIUS
		)
		_game.player.set_process(false)
		_game.player.move_input = Vector2.RIGHT
		var before: float = _game.player.hp
		_game.player.try_roll()
		_game.player._process(.04)
		_game.dungeon.hazards.tick(.01)
		for effect: Effect in Effect.in_world(_game.world):
			if effect.kind in ["text", "nova", "dodge_echo"]:
				effect._process(.08)
		if not _game.player._roll_confirmed or _game.player.hp != before:
			push_error("Cave dodge review failed to avoid actual spike contact")
			return
		JavaScriptBridge.eval("window.__sjrpgDodgeFeedback = {confirmed:true, mode:'trap'}")
	_game.hud.controls.release_all()
	_game._impact_offset = Vector2.ZERO
	_game.camera.offset = Vector2.ZERO
	_game.camera.position = _game._camera_focus()
	_game.camera.reset_smoothing()
	_game.camera.force_update_scroll()
	WorldOcclusion.update(_game.player.global_position, false)
	_game.hud._update_layout()
	_game.hud.controls._layout()
	_game.hud.controls.queue_redraw()
	_game.hud._bars.queue_redraw()
	_game.hud.minimap.queue_redraw()
	# The fresh entry notice would otherwise stay frozen across the cave artwork.
	if which != "entry_live":
		_game.hud._toast_plaque.hide()
	_game.get_tree().paused = not which.ends_with("live")
	if which.ends_with("live"):
		for enemy: Enemy in _game.enemies:
			enemy.set_process(false)
	JavaScriptBridge.eval("window.__sjrpgDungeonPreviewReady = true")


## Explicit visual audit only: freeze genuine numeric state at difficult fill/label cases.
func preview_encounter(which: String) -> void:
	await _game.get_tree().create_timer(2.0, false).timeout
	if _game.is_queued_for_deletion():
		return
	_encounter_audit = true
	_game._spawn_timer = 10000.0
	_game.encounters.set_process(false)
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	for id in _game.encounters._members:
		_game.encounters._members[id] = []
	var stone: EncounterStone = _game.encounters.stones["west"]
	_game.player.position = _game.resolve_movement(
		stone.position + Vector2(60, 45), stone.position + Vector2(60, 45), Player.RADIUS
	)
	_game.player.facing = (stone.position - _game.player.position).angle()
	_game.encounters.states["west"]["initial_spawned"] = true
	if which == "empty":
		_game.encounters.states["west"]["charges"] = 0
	elif which == "active":
		_game.encounters.spawn_wave("west", false)
	_game.camera.position = _game._camera_focus()
	_game.camera.reset_smoothing()
	_game.hud._toast_queue.clear()
	_game.hud._toast_time = 0.0
	_game.hud._toast_plaque.hide()
	publish_encounter_state()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgEncounterPreviewReady = true")


func preview_hud(which: String) -> void:
	await _game.get_tree().create_timer(2.0, false).timeout
	if _game.is_queued_for_deletion():
		return
	match which:
		"low", "danger":
			_game.player.hp = _game.player.max_hp * 0.05
			_game.player.resource = _game.player.resource_max * 0.01
			GameState.xp = 1
		"nearfull":
			_game.player.hp = _game.player.max_hp * 0.99
			_game.player.resource = _game.player.resource_max * 0.99
			GameState.xp = GameState.xp_to_next() - 1
		"large":
			GameState.level = 100
			_game.player.max_hp = 99999.99
			_game.player.hp = 79543.21
			_game.player.resource_max = 99999.9
			_game.player.resource = 12345.6
		_:
			_game.player.hp = _game.player.max_hp
			_game.player.resource = _game.player.resource_max
	# Inspect the steady fill rather than a transient damage trail.
	_game.hud._health_trail = _game.player.hp / _game.player.max_hp
	_game.hud._last_hp = _game.player.hp
	_game.hud._last_max_hp = _game.player.max_hp
	_game.hud._hurt_feedback = 0.0
	_game.hud._heal_feedback = 0.0
	_game.hud._update_critical_warning(0.0)
	_game.hud._update_layout()
	_game.hud._bars.queue_redraw()
	_game.hud.minimap.queue_redraw()
	if which == "danger":
		# Keep the genuine HUD pulse running while holding the audit hero and enemies still.
		_game.set_process(false)
		_game.player.set_process(false)
		_game.exploration.set_process(false)  # The portal's independent rest healing would clear the audit warning.
		for enemy in _game.enemies:
			enemy.set_process(false)
	else:
		_game.get_tree().paused = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgHudPreviewReady = true")


## Explicit browser review only: discover by visiting, then exercise a real destination button.
func preview_warp() -> void:
	await _game.get_tree().create_timer(2.0, false).timeout
	if _game.is_queued_for_deletion():
		return
	_game.player.position = _game.exploration.gate_approach("tree")
	_game.exploration.discover_current()
	_game.player.position = _game.exploration.gate_approach("town")
	_game.exploration.discover_current()
	_game.camera.position = _game.player.position
	_game.camera.reset_smoothing()
	_game.hud.interact("워프게이트")
	var panel: WarpGatePanel = _game.hud._panel
	for frame in 3:
		await _game.get_tree().process_frame
	var button: Button = panel.destination_buttons["tree"]
	panel.scroll.ensure_control_visible(button)
	for frame in 3:
		await _game.get_tree().process_frame
	var center := button.get_global_rect().get_center() / _game.get_viewport_rect().size
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__sjrpgWarpPreviewButton = " + JSON.stringify([center.x, center.y])
		)
	await panel.closed
	if _game.exploration.transition.active:
		await _game.exploration.transition.finished
	if not _game.is_queued_for_deletion() and OS.has_feature("web"):
		var arrived: bool = (
			GameState.last_sanctuary == "tree"
			and _game.exploration.gate_origin() == "tree"
			and not _game._blocked(_game.player.position, Player.RADIUS)
		)
		JavaScriptBridge.eval(
			"window.__sjrpgWarpPreviewArrived = " + ("true" if arrived else "false")
		)


## Explicit visual-review query only: real equipped-skill casts against a stationary target.
## 기본 체력의 실제 적에게 실제 기본 공격을 반복한다. 피해/모션을 가짜로 재생하지 않는다.
func preview_hit_feel() -> void:
	_game.encounters.set_process(false)
	_game._spawn_timer = 10000.0
	for foe: Enemy in _game.enemies:
		foe.queue_free()
	_game.enemies.clear()
	await _game.get_tree().create_timer(2.0).timeout
	var target: Enemy
	var species := ["goblin", "skeleton", "wolf", "boar"]
	var round := 0
	for index in 160:
		if not _game.is_inside_tree() or _game.is_queued_for_deletion():
			return
		if not is_instance_valid(target) or target.dead:
			target = Enemy.new()
			target.setup(_game, species[round % species.size()], 1)
			target.xp_reward = 0
			round += 1
			target.position = _game.player.position + Vector2(65, 10)
			target.facing = (_game.player.position - target.position).angle()
			_game.world.add_child(target)
			_game.enemies.append(target)
			target.stun(90.0)
		if (
			_game.player._attack_time <= 0.0
			and float(_game.player.cooldowns.get(GameState.slots[0], 0.0)) <= 0.0
		):
			target.position = _game.player.position + Vector2(65, 10)
			target._knockback = Vector2.ZERO
			# 실제 방향 공격 규칙을 따르며 표적을 보지 않는 헛스윙을 검수하지 않는다.
			_game.player.facing = (target.position - _game.player.position).angle()
			_game.player.cast_slot(0, true)
		await _game.get_tree().create_timer(0.37, false).timeout


## 실제 전방 부채꼴 공격으로 네 표적을 맞히고 접촉 박자를 연속 검수한다.
func preview_multi_hit() -> void:
	_game.encounters.set_process(false)
	_game._spawn_timer = 10000.0
	for foe: Enemy in _game.enemies:
		foe.queue_free()
	_game.enemies.clear()
	await _game.get_tree().create_timer(2.0).timeout
	var targets: Array[Enemy] = []
	var offsets: Array[Vector2] = [Vector2(65, -25), Vector2(80, -8), Vector2(80, 8), Vector2(65, 25)]
	for offset: Vector2 in offsets:
		var foe := Enemy.new()
		foe.setup(_game, "goblin", 1)
		foe.hp = 100000.0
		foe.max_hp = foe.hp
		foe.xp_reward = 0
		foe.position = _game.player.position + offset
		_game.world.add_child(foe)
		_game.enemies.append(foe)
		foe.stun(90.0)
		targets.append(foe)
	for index in 80:
		if not _game.is_inside_tree() or _game.is_queued_for_deletion():
			return
		if _game.player._attack_time <= 0.0:
			for target_index in targets.size():
				var target := targets[target_index]
				target.position = _game.player.position + offsets[target_index]
				target._knockback = Vector2.ZERO
			_game.player.facing = 0.0
			_game.player.cast_slot(0, true)
		await _game.get_tree().create_timer(0.75, false).timeout


func preview_combat() -> void:
	_game.encounters.set_process(false)
	_game._spawn_timer = 10000.0
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	await _game.get_tree().create_timer(2.0).timeout
	var target := Enemy.new()
	target.setup(_game, "goblin", 1)
	target.position = _game.player.position + Vector2(65, 10)
	target.hp = 100000.0
	target.max_hp = target.hp
	_game.world.add_child(target)
	_game.enemies.append(target)
	# Keep presentation and timers running; only prevent this review target from attacking.
	target.stun(60.0)
	for i in 120:
		if not _game.is_inside_tree() or _game.is_queued_for_deletion():
			return
		if (
			_game.player._attack_time <= 0.0
			and float(_game.player.cooldowns.get(GameState.slots[0], 0.0)) <= 0.0
		):
			# Re-seat the review dummy between swings after real knockback moved it away.
			target.position = _game.player.position + Vector2(65, 10)
			target._knockback = Vector2.ZERO
			_game.player.cast_slot(0, true)
		await _game.get_tree().create_timer(0.37, false).timeout


## Real zone ticks create the per-monster streams for an explicit visual review.
func preview_damage_stream() -> void:
	_game.encounters.set_process(false)
	_game._spawn_timer = 10000.0
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	await _game.get_tree().create_timer(2.0, false).timeout
	var targets: Array[Enemy] = []
	for offset in [Vector2(70, 75), Vector2(-70, 75)]:
		var enemy := Enemy.new()
		enemy.setup(_game, "goblin", 1)
		enemy.position = _game.player.position + offset
		enemy.hp = 100000.0
		enemy.max_hp = enemy.hp
		_game.world.add_child(enemy)
		_game.enemies.append(enemy)
		enemy.stun(60.0)
		targets.append(enemy)
	_game.spawn_zone(
		{
			"pos": _game.player.position + Vector2(0, 75),
			"radius": 110.0,
			"duration": 2.0,
			"tick": 0.10,
			"damage": 16.81,
			"color": SkillDefs.FIRE
		}
	)
	for frame in 200:
		await _game.get_tree().process_frame
		var rows := 0
		for effect in _game.cosmetic_effects:
			if (
				is_instance_valid(effect)
				and not effect.is_queued_for_deletion()
				and effect is Effect
				and effect.kind == "text"
				and effect.age >= 0.0
				and effect._text_target_id == targets[0].get_instance_id()
			):
				rows += 1
		if rows >= 4:
			_game.get_tree().paused = true
			JavaScriptBridge.eval("window.__sjrpgDamageStreamReady = true")
			return


## Explicit visual review only: equip one existing skill, perform its real cast,
## then pause the actual simulation near the authored effect's peak for inspection.
func preview_reference_fx(which: String) -> void:
	_game.encounters.set_process(false)
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	_game._spawn_timer = 10000.0
	await _game.get_tree().create_timer(4.0, false).timeout
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	GameState.ranks[which] = 1
	GameState.slots[0] = which
	_game.player.resource = _game.player.resource_max
	var offsets: Array[Vector2] = [Vector2(60, 0), Vector2(-55, 10), Vector2(0, -65)]
	if which in ["iceBolt", "meteor"]:
		offsets = [Vector2(430 if which == "iceBolt" else 240, -50)]
	_inspection.focus_point = _game.player.position + offsets[0] * 0.45 + Vector2(0, -65)
	_game.camera.position = _inspection.focus_point
	_game.camera.reset_smoothing()
	for offset in offsets:
		var target := Enemy.new()
		target.setup(_game, "goblin", 1)
		target.position = _game.player.position + offset
		target.hp = 100000.0
		target.max_hp = target.hp
		target.xp_reward = 0
		_game.world.add_child(target)
		_game.enemies.append(target)
		target.stun(60.0)
	var cast_started: bool = _game.player.cast_slot(0)
	JavaScriptBridge.eval(
		(
			"window.__sjrpgFxReviewStatus = "
			+ JSON.stringify({"started": cast_started, "skill": which})
		)
	)
	var key: String = {
		"cleave": "slash",
		"whirlwind": "spin",
		"leapAttack": "slam",
		"iceBolt": "bolt",
		"frostNova": "frost",
		"meteor": "meteor"
	}[which]
	for frame in 300:
		await _game.get_tree().process_frame
		for node in _game.world.get_children():
			var effect := node as Effect
			if effect == null or effect.is_queued_for_deletion():
				continue
			var matches: bool = (
				(effect.kind == "slash" and key == "slash")
				or str(effect.params.get("visual", "")) == key
			)
			if (
				matches
				and (
					(key == "bolt" and effect.kind == "proj" and effect.age >= 0.10)
					or (effect.kind in ["slash", "skill_fx"] and effect.visual_phase() >= 0.24)
				)
			):
				_game.get_tree().paused = true
				JavaScriptBridge.eval(
					(
						"window.__sjrpgFxReview = "
						+ JSON.stringify(
							{
								"skill": which,
								"key": key,
								"phase": effect.visual_phase(),
								"actual_cast": true
							}
						)
					)
				)
				return


## Isolated visual inspection: one real threat completes its attack against the protected NPC.
func preview_defender_feedback() -> void:
	_game.encounters.set_process(false)
	_game.quest_runtime.set_process(false)
	_game._spawn_timer = 10000.0
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	_game.quest_runtime.accept("sun")
	_game.quest_runtime.start_protection()
	var defender := _game.quest_runtime.defender as Villager
	_game.player.position = _game.resolve_movement(
		_game.player.position, defender.position + Vector2(-90, 110), Player.RADIUS
	)
	_inspection.focus_point = defender.position + Vector2(0, -45)
	_game.camera.position = _inspection.focus_point
	_game.camera.reset_smoothing()
	await _game.get_tree().create_timer(4.0, false).timeout
	var target := Enemy.new()
	target.setup(_game, "goblin", 1)
	target.position = defender.position + Vector2(30, 0)
	target.is_threat = true
	target.force_chase()
	_game.world.add_child(target)
	_game.enemies.append(target)
	var hp: float = Quests.state("sun")["defender_hp"]
	for frame in 300:
		await _game.get_tree().process_frame
		if float(Quests.state("sun")["defender_hp"]) < hp and defender._hurt_flash > 0.0:
			_game.get_tree().paused = true
			JavaScriptBridge.eval("window.__sjrpgDefenderReview = true")
			return


## Actual threat scan and door animation; the dummy cannot attack during visual review.
func preview_gate_closure(index: int) -> void:
	# 원화/가림 셰이더 준비는 장치마다 다르다. 준비 전의 고정 프레임 수를
	# 성문 동작 시간으로 사용하지 않고 실제 운영 월드가 처리 가능한지 기다린다.
	var preparation_started := Time.get_ticks_msec()
	while is_instance_valid(_game) and not _game.is_queued_for_deletion():
		if _game.native_ready and not Gamepad.loading_blocked() and _game.can_process() and _game.town_gates.can_process() and _game.town_gates.is_processing():
			break
		if Time.get_ticks_msec() - preparation_started >= 120000:
			_publish_gate_review(index, null, "preparation_timeout")
			return
		await _game.get_tree().process_frame
	if not is_instance_valid(_game) or _game.is_queued_for_deletion():
		return
	_game.encounters.set_process(false)
	_game.quest_runtime.set_process(false)
	for enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	_game._spawn_timer = 10000.0
	_game.hud.controls.release_all()
	_game.player.move_input = Vector2.ZERO
	_game.player.held_slots.clear()
	_game.player.set_process(false)
	_game.spatial_world.teleport_source_actor(_game.player, _game.village.spawn_point, Player.RADIUS)
	# 이전 적의 네이티브 몸체가 물리 공간에서 제거된 뒤 새 위협을 배치한다.
	await _game.get_tree().physics_frame
	await _game.get_tree().process_frame
	if not is_instance_valid(_game) or _game.is_queued_for_deletion():
		return
	var at: Vector2 = _game.village.gate_points[index]
	_inspection.focus_point = at + Vector2(0, 20)
	_game.camera.position = _inspection.focus_point
	_game.camera.reset_smoothing()
	_game.camera.force_update_scroll()
	var normal := FortificationRenderer3D._outward_normal(
		_game.village.safe_zone, WorldSpace3D.projected_to_world(at)
	)
	var direction := Iso.project(Vector2(normal.x, normal.z)).normalized()
	var target := Enemy.new()
	target.setup(_game, "goblin", 1)
	target.position = at + direction * 140.0
	target.is_threat = true
	target.stun(60.0)
	target.set_process(false)
	_game.world.add_child(target)
	_game.enemies.append(target)
	_game.spatial_world.teleport_source_actor(target, target.position, target.radius, true)
	await _game.get_tree().physics_frame
	await _game.get_tree().process_frame
	if not is_instance_valid(_game) or _game.is_queued_for_deletion():
		return
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000:
		await _game.get_tree().process_frame
		if not is_instance_valid(_game) or _game.is_queued_for_deletion():
			return
		if _game.town_gates.closed[index] and _game.town_gates.progress[index] >= 0.99:
			_publish_gate_review(index, target, "closed")
			return
	_publish_gate_review(index, target, "closure_timeout")


## 검수 실패도 관측한 실제 상태로 남긴다. 문 상태나 운영 시계를 주입하지 않는다.
func _publish_gate_review(index: int, target: Enemy, reason: String) -> void:
	if not OS.has_feature("web") or not is_instance_valid(_game):
		return
	var gates: TownGateRuntime = _game.town_gates
	var distance := INF
	var target_state := {"valid": is_instance_valid(target)}
	if is_instance_valid(target):
		for polygon: PackedVector2Array in gates._walls:
			distance = minf(distance, TownGateRuntime.distance_to_polygon(target.position, polygon))
		target_state["position"] = [target.position.x, target.position.y]
		target_state["dead"] = target.dead
		target_state["queued"] = target.is_queued_for_deletion()
		var body := _game.spatial_world.actor_bodies.get(target.get_instance_id()) as CharacterBody3D
		if is_instance_valid(body):
			var projected := WorldSpace3D.world_to_projected(body.position)
			target_state["body_position"] = [projected.x, projected.y]
	var state := {
		"gate": index,
		"closed": gates.closed[index] and gates.progress[index] >= .99,
		"reason": reason,
		"paused": _game.get_tree().paused,
		"nativeReady": _game.native_ready,
		"loading": Gamepad.loading_blocked(),
		"game_can_process": _game.can_process(),
		"gates_can_process": gates.can_process(),
		"gates_processing": gates.is_processing(),
		"target": target_state,
		"distance": distance if is_finite(distance) else -1.0,
		"danger": gates.danger,
		"hero_access": gates.hero_access[index],
		"progress": gates.progress[index]
	}
	JavaScriptBridge.eval("window.__sjrpgGateReview = " + JSON.stringify(state))


## Explicit art review only: real deaths keep all five body illustrations visible in the plaza.
func preview_corpse(surface := "1") -> void:
	await _game.get_tree().create_timer(2.0, false).timeout
	if _game.is_queued_for_deletion():
		return
	_game.player.position = _game.resolve_movement(
		_game.village.spawn_point, _game.village.spawn_point + Vector2(0, -10), Player.RADIUS
	)
	var positions: Array[Vector2] = []
	var kinds: Array[String] = []
	if surface == "beasts":
		_game.player.position = _game.village.point(Vector2(0.5, 1.15))
		positions = [
			_game.player.position + Vector2(-130, -70), _game.player.position + Vector2(130, -70)
		]
		kinds = ["boar", "goblin"]
	elif surface == "bridge":
		_game.player.position = _game.village.bridge.axis_point(0.5)
		positions = [_game.village.bridge.axis_point(0.4), _game.village.bridge.axis_point(0.65)]
		kinds = ["wolf", "skeleton"]
	elif surface == "terrace":
		_game.player.position = _game.village.chapel_steps[_game.village.chapel_steps.size() - 2]
		var body: Vector2 = _game.village.chapel_steps[_game.village.chapel_steps.size() - 1]
		var further := body + Vector2(-60, -35)
		if (
			Geometry2D.is_point_in_polygon(further, _game.village.terrace)
			and not _game._blocked(further, Enemy.radius_for("goblin"))
		):
			body = further
		positions = [body]
		kinds = ["goblin"]
	else:
		var offsets := [
			Vector2(-330, 70),
			Vector2(-175, 70),
			Vector2(-20, 70),
			Vector2(140, 70),
			Vector2(330, 70)
		]
		var offset_index := 0
		for kind in Enemy.KINDS:
			kinds.append(kind)
			positions.append(_game.player.position + offsets[offset_index])
			offset_index += 1
	_game.camera.position = _game.player.position
	_game.camera.reset_smoothing()
	var index := 0
	var review_bodies: Array = []
	for kind in kinds:
		var enemy := Enemy.new()
		enemy.setup(_game, kind, 1)
		if surface == "beasts" and kind == "goblin":
			enemy.set_meta("visual_variant", EnemyRenderer3D.CRAWLER)
		enemy.position = positions[index]
		enemy.xp_reward = 0
		_game.world.add_child(enemy)
		_game.enemies.append(enemy)
		enemy.take_damage(enemy.hp + 1.0, null)
		review_bodies.append(_game.corpses.back())
		index += 1
	await _game.get_tree().create_timer(0.25, false).timeout
	if not _game.is_queued_for_deletion() and OS.has_feature("web"):
		if surface == "beasts":
			_game.get_tree().paused = true
		JavaScriptBridge.eval("window.__sjrpgCorpsePreviewReady = true")
	await _game.get_tree().create_timer(_game.CORPSE_LIFETIME + 0.1, false).timeout
	if not _game.is_queued_for_deletion() and OS.has_feature("web"):
		# Read-only browser assertion: normal gameplay ticks, without aging or removing the review bodies here.
		var expired := review_bodies.all(
			func(body): return float(body["time"]) <= 0.0 and body["used"]
		)
		JavaScriptBridge.eval(
			"window.__sjrpgCorpsePreviewExpired = " + ("true" if expired else "false")
		)


## Explicit review query only. Exercise real grant/chest paths, never run in a normal adventure.
## 실제 첫 활성화가 발생한 뒤 표시 시계만 진행하여 검수 장면을 고정한다.
func preview_waypoint_discovery() -> void:
	for frame in 180:
		await _game.get_tree().process_frame
		if _game.is_queued_for_deletion():
			return
		if not _game.native_ready:
			continue
		for effect: Effect in _game.cosmetic_effects:
			if effect.is_queued_for_deletion() or not effect.params.has("waypoint_position"):
				continue
			effect._process(0.16)
			effect._process(0.16)
			_game.hud._level_up._process(0.06)
			_game.hud._level_up._process(0.12)
			_game.world_renderer._process(0.0)
			_game.world_renderer._publish_probe()
			_game.get_tree().paused = true
			JavaScriptBridge.eval("window.__sjrpgWaypointDiscoveryReview = true")
			return


func preview_reward(mode := "1") -> void:
	await _game.get_tree().create_timer(2.0, false).timeout
	if _game.is_queued_for_deletion():
		return
	if mode == "1":
		for chest in _game.chests:
			if not chest.dead:
				_game.player.position = chest.position + Vector2(70, 35)
				chest.take_damage(1.0, _game.player)
				break
	await _game.get_tree().create_timer(0.8, false).timeout
	if not _game.is_queued_for_deletion():
		if mode == "levelup":
			_game.hud._toast_queue.clear()
			_game.hud._toast_time = 0.0
			_game.hud._toast_plaque.hide()
			_game.camera.position = _game._camera_focus()
			_game.camera.reset_smoothing()
		_game.grant_xp(GameState.xp_to_next())
		if mode == "levelup" and OS.has_feature("web"):
			# Let the real character effect rise before the explicit capture pause.
			await _game.get_tree().create_timer(0.30, false).timeout
		if OS.has_feature("web"):
			_game.hud._update_vital_feedback(0.0)
			_game.hud._update_layout()
			if is_instance_valid(_game.hud._level_up):
				_game.hud._level_up._process(0.06)
				_game.hud._level_up._process(0.06)
			_game.hud._bars.queue_redraw()
			_game.hud.controls.queue_redraw()
			_game.get_tree().paused = true  # Explicit capture preview freezes the confirmed reward at its visual peak.
			JavaScriptBridge.eval("window.__sjrpgRewardPreviewReady = true")
