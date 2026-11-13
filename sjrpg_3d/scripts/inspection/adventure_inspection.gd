class_name AdventureInspection
extends Node
## 배치·상태 덮어쓰기는 inspection=1을 명시한 검수 세션에서만 실행한다.
var zoom_multiplier := 1.0
var focus_point := Vector2.ZERO
var scenes: AdventureReviewScenes
var _game: Node2D
var _parameters: Dictionary
var _applied := false


static func parameters(query: String) -> Dictionary:
	var result: Dictionary = {}
	for part: String in query.trim_prefix("?").split("&", false):
		var pair := part.split("=", true, 1)
		if pair.size() == 2:
			var key := pair[0].replace("+", " ").uri_decode()
			result[key] = pair[1].replace("+", " ").uri_decode()
	return result


static func create_for_web(game: Node2D) -> AdventureInspection:
	if not OS.has_feature("web"):
		return null
	var query: Variant = JavaScriptBridge.eval("window.location.search", true)
	return create(game, query) if query is String else null


static func web_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	var query: Variant = JavaScriptBridge.eval("window.location.search", true)
	return query is String and parameters(query).get("inspection", "") == "1"


static func create(game: Node2D, query: String) -> AdventureInspection:
	var values := parameters(query)
	if values.get("inspection", "") != "1":
		return null
	var inspection := AdventureInspection.new()
	inspection.name = "AdventureInspection"
	inspection._game = game
	inspection._parameters = values
	game.add_child(inspection)
	inspection.scenes = AdventureReviewScenes.new().setup(game, inspection)
	inspection.add_child(inspection.scenes)
	game.encounters.state_captured.connect(inspection.scenes.publish_encounter_state)
	return inspection


func _open_panel(which: String) -> void:
	if which == "expedition" and not _game.native_ready:
		await _game.get_tree().process_frame
		_open_panel.call_deferred(which)
		return
	# Debug rewards may have opened a memory; always show the requested capture panel.
	if _game.hud.panel_open():
		_game.hud.close_panel()
	match which:
		"warp":
			_game.hud.interact("워프게이트")
		"bag":
			_game.hud.open_bag(false)
		"shop":
			_game.hud.open_bag(true)
		"skills":
			_game.hud.open_skill_tree()
		"settings":
			_game.hud.open_settings()
		"journal":
			_game.hud.open_journal()
		"expedition":
			_game.hud.open_expedition()
		"elin":
			_game.hud.interact("수녀 엘린")
		"mira":
			_game.hud.interact("보급원 미라")
		"smith":
			_game.hud.open_smith()
		"dungeon":
			_game.player.position = _game.dungeon.entry_point()
			_game.dungeon.enter()
		"dungeon_map":
			_game.player.position = _game.dungeon.entry_point()
			_game.dungeon.enter()
			_game.hud._bars.queue_redraw()
			_game.hud.minimap.queue_redraw()
			_game.hud.controls._layout()
			_game.hud.controls.queue_redraw()
			_game.hud.open_map()
		"map":
			_game.hud.open_map()
		"travel":
			_game.hud.open_map(true)
		"boss":
			_game.hud._open(BossPanel.new().setup(_game))
		"victory":
			_game.hud.open_victory()


func apply() -> void:
	if _applied:
		return
	_applied = true
	for option: String in _parameters:
		var value: String = _parameters[option]
		if option == "zoom":
			zoom_multiplier = clampf(float(value), 0.1, 4.0)
		elif option == "benchmark" and value == "1":
			_game.add_child(RenderProbe.new().setup(_game))
		elif option == "defender_preview" and value == "1":
			scenes.preview_defender_feedback.call_deferred()
		elif option == "quality":
			Prefs.set_low_resolution(value == "low")
		elif option == "lighting":
			_game.forest_lighting.set_enabled(value != "off")
			WorldLighting.set_enabled(_game.forest_lighting.enabled)
		elif option == "atmosphere":
			_game.forest_atmosphere.set_enabled(value == "trial")
		elif option == "panel":
			var which: String = value
			_game.get_tree().create_timer(1.5).timeout.connect(_open_panel.bind(which))
		elif option == "hud_preview" and value in ["full", "low", "nearfull", "large", "danger"]:
			scenes.preview_hud.call_deferred(value)
		elif option == "encounter_preview" and value in ["ready", "active", "empty"]:
			scenes.preview_encounter.call_deferred(value)
		elif (
			option == "dungeon_preview"
			and (
				value
				in [
					"entry",
					"room",
					"branch",
					"exit",
					"upper",
					"lower",
					"dodge",
					"spikes",
					"spikes_warn",
					"spikes_live",
					"flame",
					"flame_warn",
					"flame_live",
					"entry_live",
					"room_clear",
					"all_clear_live"
				]
			)
		):
			scenes.preview_dungeon.call_deferred(value)
		elif option == "warp_preview" and value == "1":
			scenes.preview_warp.call_deferred()
		elif option == "hitfeel_preview" and value in ["1", "peak"]:
			scenes.preview_hit_feel.call_deferred()
		elif option == "hitfeel_preview" and value == "multi":
			scenes.preview_multi_hit.call_deferred()
		elif option == "tree_preview" and value in ForestTreeRuntime.STATES:
			TreeDestructionReview.run.call_deferred(_game, value)
		elif option == "waypoint_preview" and value == "1":
			scenes.preview_waypoint_discovery.call_deferred()
		elif option == "combat_preview":
			scenes.preview_combat.call_deferred()
		elif option == "combat_text_preview" and value == "1":
			scenes.preview_damage_stream.call_deferred()
		elif (
			option == "fx_preview"
			and value in ["cleave", "whirlwind", "leapAttack", "iceBolt", "frostNova", "meteor"]
		):
			scenes.preview_reference_fx.call_deferred(value)
		elif option == "gate_preview" and value in ["0", "1", "2", "3"]:
			scenes.preview_gate_closure.call_deferred(int(value))
		elif option == "enemy_warning" and value in ["wolf", "goblin", "skeleton"]:
			NativeEnemyReview.run.call_deferred(_game, value)
		elif option == "dodge_feedback" and value == "enemy":
			NativeEnemyReview.run.call_deferred(_game, "goblin", true)
		elif option == "chest_response" and value in ["hit", "opening", "open", "closed"]:
			NativeChestReview.run.call_deferred(_game, value)
		elif option == "corpse_preview" and value in ["1", "bridge", "terrace", "beasts"]:
			scenes.preview_corpse.call_deferred(value)
		elif option == "aim_preview" and value == "1":
			var review := DirectionalAimReview.new()
			_game.add_child(review)
			review.start.call_deferred(_game)
		elif option == "feel_preview" and value == "1":
			var review := GameFeelReview.new()
			_game.add_child(review)
			review.start.call_deferred(_game)
		elif option == "reward_preview" and value in ["1", "levelup"]:
			scenes.preview_reward.call_deferred(value)
		elif option == "village_review" and value == "1":
			VillageReviewSnapshot.publish.call_deferred(_game)
		elif option == "gold":
			GameState.gold = int(value)
		elif option == "chests":
			for c in _game.chests:
				c.take_damage(1.0, null)
		elif option == "at":
			match value:
				"npc_nw", "npc_ne", "npc_sw", "npc_se":
					var key := value.trim_prefix("npc_")
					for service in Village.NPCS:
						if service[0] == key:
							var resident: Vector2 = _game.village.npc_points[service[1]]
							_game.player.position = _game.resolve_movement(
								resident, resident + Vector2(65, 75), Player.RADIUS
							)
							focus_point = resident + Vector2(25, -60)
				"npc_courtyard":
					var middle: Vector2 = (
						(_game.village.npc_points["탈것 상인"] + _game.village.npc_points["촌장"]) * 0.5
					)
					_game.player.position = _game.resolve_movement(
						middle, middle + Vector2(0, 70), Player.RADIUS
					)
					focus_point = middle + Vector2(0, -140)
				"portal":
					_game.player.position = _game.exploration.gate_approach("town")
				"waypoint_tree", "waypoint_cave", "waypoint_tree_active", "waypoint_cave_active":
					var id := "tree" if value.contains("tree") else "cave"
					var at: Vector2 = _game.village.portal_points[id]
					_game.player.position = (
						at if value.ends_with("active") else at + Vector2(0, 165)
					)
					focus_point = at
				"boss":
					_game.player.position = _game.village.boss_point + Vector2(0, 130)
				"field":
					_game.player.position = _game.village.point(Vector2(0.5, 1.15))
				"gate0", "gate1", "gate2", "gate3":
					_game.player.position = (
						_game.village.gate_points[int(value.substr(4))] + Vector2(0, 150)
					)
				"cave_trail", "cave_trail_middle":
					var trail := CaveTrailPlan3D.points(_game.village)
					var index := 0 if value == "cave_trail" else 3
					var frame := CaveTrailPlan3D.frame(_game.village)
					_game.player.position = WorldSpace3D.world_to_projected(
						frame * Vector3(trail[index].x, 0, trail[index].y)
					)
					focus_point = _game.player.position
				"cave_descent":
					var cave_frame := NativeCavePlan.frame(_game.dungeon.entry_point())
					_game.player.position = WorldSpace3D.world_to_projected(
						cave_frame * Vector3(0, 0, 18)
					)
					focus_point = WorldSpace3D.world_to_projected(cave_frame * Vector3(0, 0, 6))
				"cave_exterior":
					_game.player.position = _game.dungeon.entry_point() + Vector2(0, 180)
					focus_point = _game.dungeon.entry_point() + Vector2(0, -180)
				"bridge":
					_game.player.position = _game.village.bridge.axis_point(0.5)
				"mira":
					var approach: Vector2 = _game.village.spawn_point.lerp(
						_game.village.npc_points["보급원 미라"], 0.55
					)
					_game.player.position = _game.resolve_movement(
						_game.village.spawn_point, approach, Player.RADIUS
					)
				"elin":
					_game.player.position = _game.village.quest_sites["roots"] + Vector2(60, 40)
				"rowen":
					_game.player.position = _game.village.quest_sites["sun"] + Vector2(-90, 110)
				"lm0", "lm1", "lm2", "lm3":
					var lmk: Landmark = _game.village.landmarks[int(value.substr(2))]
					_game.player.position = lmk.position + Vector2(0, 140)
				"tree_occlusion":
					var tree: IsoSprite = _game.village.town_trees[0]
					_game.player.position = WorldSpace3D.world_to_projected(
						WorldSpace3D.projected_to_world(tree.position) - Vector3(1.7, 0, 1.7)
					)
				"occlusion":
					var building: IsoSprite = _game.village.buildings["nw"]
					var footprint := building.atlas_polygon(
						_game.village.data["frames"]["nw"]["ground"]
					)
					var bounds := Iso.poly_bounds(footprint)
					_game.player.position = Vector2(
						bounds.get_center().x, bounds.position.y - Player.RADIUS - 10.0
					)
				"chapel":
					_game.player.position = _game.village.chapel_steps[
						_game.village.chapel_steps.size() - 1
					]
				"chapel_reference":
					scenes.place_at_chapel()
				"house_nw", "house_ne", "house_sw", "house_se":
					scenes.place_at_house(value.trim_prefix("house_"))
				"plaza_detail":
					var outline: PackedVector2Array = _game.village.fountain.atlas_polygon(
						_game.village.data["frames"]["pool"]["ground"]
					)
					var middle := Vector2.ZERO
					for point: Vector2 in outline:
						middle += point / outline.size()
					_game.spatial_world.teleport_source_actor(
						_game.player, middle + Vector2(0, 230), Player.RADIUS
					)
					focus_point = middle - Vector2(0, 90)
				"bank":
					_game.player.position = Iso.project(_game.village.forecourt_g + Vector2(0, -60))
				"corner0":
					_game.player.position = (
						_game.village.point(Vector2(0.04, 0.10)) + Vector2(0, 150)
					)
				"corner1":
					_game.player.position = (
						_game.village.point(Vector2(0.94, 0.10)) + Vector2(0, 150)
					)
				"corner2":
					_game.player.position = (
						_game.village.point(Vector2(0.04, 0.90)) + Vector2(0, 150)
					)
				"corner3":
					_game.player.position = (
						_game.village.point(Vector2(0.94, 0.90)) + Vector2(0, 150)
					)
			_game.camera.position = _game.player.position
			_game.camera.reset_smoothing()
	# Debug zoom is parsed after initial camera setup. Apply it independent of
	# query ordering or whether a quality setting happens to emit a resize.
	_game._update_zoom()
