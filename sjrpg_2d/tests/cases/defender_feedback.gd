extends TestCase
## Drive the threat's real hit callback, including protected-NPC layout and body-only feedback.


func _impacts(game: Node) -> Array:
	return game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "impact")


func _clears_header(label: Effect, defender: Villager) -> bool:
	var header := defender.header_layout()
	var rectangles: Array[Rect2] = [defender.body_rect(), header["bar"], header["name_bounds"]]
	if defender.marker.is_valid() and defender.marker.call():
		rectangles.append(header["marker_bounds"])
	for rect in rectangles:
		rect.position += defender.position
		if label.text_bounds().intersects(rect):
			return false
	return true


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	var runtime: QuestRuntime = game.quest_runtime
	runtime.set_process(false)
	var defender := runtime.defender as Villager
	defender.set_process(false)
	var ordinary := defender.header_layout()
	check("inactive protection keeps the original resident header", ordinary["name_y"] == -Villager.BODY_HEIGHT - 10.0 and ordinary["marker_y"] == -Villager.BODY_HEIGHT - 40.0)
	runtime.accept("sun")
	runtime.start_protection()
	var header := defender.header_layout()
	var bar: Rect2 = header["bar"]
	var name_bounds: Rect2 = header["name_bounds"]
	var marker_bounds: Rect2 = header["marker_bounds"]
	check("protection bar clears the measured head silhouette", bar.end.y <= defender.body_rect().position.y - 9.0)
	check("protected name and bobbing marker clear the bar and each other", name_bounds.end.y <= bar.position.y - 3.999 and marker_bounds.end.y <= name_bounds.position.y - 5.999)
	var center := runtime.defender_position()
	game.player.position = center + Vector2(1500, 0)
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = center + Vector2(30, 0)
	enemy.is_threat = true
	enemy.force_chase()
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	var state := Quests.state("sun")
	var before: float = state["defender_hp"]
	seed(7281)
	var expected := enemy.damage * randf_range(0.85, 1.15)
	seed(7281)
	enemy._process(0.01)
	enemy._process(0.56)
	check("real threat hit preserves exact defender damage", is_equal_approx(before - float(state["defender_hp"]), expected))
	var impacts := _impacts(game)
	check("real defender hit emits one bounded chest contact", impacts.size() == 1 and impacts[0].position.is_equal_approx(center + Vector2(0, -Villager.BODY_HEIGHT * 0.55)) and game.cosmetic_effects.size() <= 64)
	var overlay_material := defender._hurt_overlay.material as ShaderMaterial
	check("hit flash belongs only to the original NPC body draw", defender._hurt_flash > 0.0 and defender._hurt_overlay != null and defender._hurt_overlay.label == defender.display_name and defender._hurt_overlay.get_parent() == defender and overlay_material.shader == ActorSprite.FLASH_SHADER and defender.material == null and defender.modulate == Color.WHITE and defender.self_modulate == Color.WHITE)
	var after_hit := defender.header_layout()
	check("hit feedback leaves header geometry and the distant hero camera unchanged", after_hit["bar"] == header["bar"] and after_hit["name_bounds"] == header["name_bounds"] and after_hit["marker_bounds"] == header["marker_bounds"] and game._impact_offset == Vector2.ZERO and game.camera.offset == Vector2.ZERO)
	var labels: Array = game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "text")
	check("defender damage label keeps its original amount and color", labels.size() == 1 and labels[0].text == HudArt.stat(expected) and labels[0].color == Color(1, 0.55, 0.45))
	check("placed damage text clears the protected body, health bar, and name", labels.size() == 1 and _clears_header(labels[0], defender))
	var flash := defender._hurt_flash
	get_tree().paused = true
	defender.set_process(true)
	await _frames(2)
	check("pause freezes NPC flash and its contact effect", defender._hurt_flash == flash and impacts[0].age == 0.0)
	get_tree().paused = false
	defender.set_process(false)
	defender._process(1.0)
	check("slow first frame still presents the defender hit", defender._hurt_flash > 0.0 and defender._hurt_overlay.visible)
	var decayed := defender._hurt_flash
	defender.show_hurt()
	check("rapid hits reuse one overlay without extending a flash", defender._hurt_flash == decayed and defender.get_child_count() == 1)
	defender._process(1.0)
	check("defender hit expires after its bounded first presentation", defender._hurt_flash == 0.0 and not defender._hurt_overlay.visible)
	Prefs.reduce_motion = true
	defender.marker = func() -> bool: return true
	runtime.damage_defender(5.0)
	var marked_labels: Array = game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "text")
	check("placed damage text also clears a visible quest marker", marked_labels.size() == 2 and _clears_header(marked_labels.back(), defender))
	check("reduced motion retains a restrained body flash", defender._hurt_flash > 0.0 and defender._hurt_flash <= 0.35 and overlay_material.get_shader_parameter("flash_strength") <= 0.65 * 0.35 + 0.0001)
	var position_before := defender.position
	defender._process(0.2)
	check("reduced hit feedback stays still and expires", defender.position == position_before and defender._hurt_flash == 0.0 and not defender._hurt_overlay.visible)
	var cue_count := _impacts(game).size()
	runtime.damage_defender(0.0)
	state["defender_hp"] = 0.0
	runtime.damage_defender(5.0)
	check("zero actual damage cannot trigger a body flash or contact", defender._hurt_flash == 0.0 and _impacts(game).size() == cue_count)
	state["phase"] = "failed"
	state["started"] = false
	check("ending protection restores the ordinary NPC header", defender.header_layout() == ordinary)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)
