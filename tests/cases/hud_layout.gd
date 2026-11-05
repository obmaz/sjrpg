extends TestCase
## Check visible composition and actual touch ownership through portrait/landscape rotation.

func _bounds(button: Dictionary) -> Rect2:
	var half: Vector2 = button.get("half_size", Vector2.ONE * float(button["radius"]))
	return Rect2(button["center"] - half, half * 2.0)


func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.new_game("mage")
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	await _frames(3)
	var controls: TouchControls = game.hud.controls
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(720, 1560), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(4)
		controls._layout()
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var header: Dictionary = game.hud.status_geometry()
		var confirmation: Rect2 = game.hud.toast_rect()
		check("confirmation fits and avoids map %s" % dimensions, bounds.encloses(confirmation) and not confirmation.intersects(header["map"]))
		var hp: Rect2 = header["hp"]
		var map: Rect2 = header["map"]
		check("status and map stay separate %s" % dimensions, bounds.encloses(hp) and bounds.encloses(map) and hp.end.x + 20 < map.position.x)
		check("status leaves the scene visible %s" % dimensions, hp.size.y < 36.0 and header["xp"].end.y < dimensions.y * 0.25)
		for name in controls._buttons:
			var button: Dictionary = controls._buttons[name]
			check("target remains inside screen %s/%s" % [dimensions, name], bounds.encloses(_bounds(button)))
			check("touch owns visible center %s/%s" % [dimensions, name], controls._hit_button(button["center"]) == name)
			check("touch remains at least 64 units %s/%s" % [dimensions, name], _bounds(button).size.x >= 64.0 and _bounds(button).size.y >= 64.0)
			if name == "near_shop":
				var plaque := controls.interaction_visual_rect(button["center"], button["half_size"])
				check("quiet interaction plaque keeps a larger touch area", _bounds(button).encloses(plaque) and plaque.size.y < _bounds(button).size.y)
				var outer_touch := Vector2(plaque.get_center().x, _bounds(button).end.y - 1.0)
				check("interaction remains tappable beyond its smaller plate", not plaque.has_point(outer_touch) and controls._hit_button(outer_touch) == name)
			for other in controls._buttons:
				if name >= other:
					continue
				var b: Dictionary = controls._buttons[other]
				if button.has("half_size") or b.has("half_size"):
					check("interaction avoids menu targets %s/%s" % [name, other], not _bounds(button).intersects(_bounds(b)))
				else:
					check("touch circles do not overlap %s/%s" % [name, other], button["center"].distance_to(b["center"]) >= float(button["radius"]) + float(b["radius"]))
		for slot in 5:
			var button: Dictionary = controls._buttons["slot%d" % slot]
			var visual := controls.slot_visual_radius(slot)
			if str(GameState.slots[slot]).is_empty():
				check("empty hints leave more scenery visible without shrinking input", visual < float(button["visual_radius"]) and controls._hit_button(button["center"] + Vector2.RIGHT * (float(button["radius"]) - 1.0)) == "slot%d" % slot)
		var main: Vector2 = controls._buttons["slot0"]["center"]
		var roll: Vector2 = controls._buttons["roll"]["center"]
		check("dodge is beside primary skill", roll.x > main.x and absf(roll.y - main.y) < 3.0)
		check("joystick avoids combat fan", controls._stick_center.distance_to(main) > controls.stick_radius() + float(controls._buttons["slot0"]["radius"]) + 40.0)
		if dimensions == Vector2i(720, 1280):
			check("primary skill follows reference composition", absf(main.x / dimensions.x - 0.783) < 0.02 and absf(main.y / dimensions.y - 0.741) < 0.015)
			check("bottom menu leaves reference breathing room", controls._buttons["bar_bag"]["center"].y < dimensions.y * 0.93)
	for id in ["cleave", "shadowAssault", "battleSprint", "sorceressAttack"]:
		var art := SkillIcons.source(id)
		var uv: Rect2 = art["uv"]
		check("extra attack has actual illustrated art: " + id, art["texture"] is Texture2D and Rect2(0, 0, 1, 1).encloses(uv))
	view.queue_free()
	await _frames(2)
