extends TestCase
## Check visible composition and actual touch ownership through portrait/landscape rotation.

func _bounds(button: Dictionary) -> Rect2:
	var half: Vector2 = button.get("half_size", Vector2.ONE * float(button["radius"]))
	return Rect2(button["center"] - half, half * 2.0)


func _check_toasts(hud: Hud, dimensions: Vector2i) -> void:
	var old_text := hud._toast.text
	var old_warning := hud._save_warning.visible
	hud._toast.text = "의뢰를 수락했습니다\n조사관을 지키세요\n90초 동안 습격을 막으세요"
	var margins := PanelFrame.safe_margins(hud.get_viewport())
	var available := Vector2(dimensions) - Vector2(margins.x + margins.z, margins.y + margins.w)
	var screen := Rect2(Vector2(margins.x, margins.y), available)
	for warning in [false, true]:
		hud._save_warning.visible = warning
		hud._update_layout()
		await _frames(2)
		hud._update_layout()
		var confirmation := hud.toast_rect()
		var plaque := hud._toast_plaque.get_global_rect()
		var geometry := hud.status_geometry()
		var u := hud.unit()
		var h: float = geometry["unit"]
		var origin: Vector2 = geometry["origin"]
		var status_ink: Rect2 = geometry["paint_bounds"]
		var map_ink := hud.minimap.paint_bounds()
		map_ink.position += hud.minimap.position
		var hp: Rect2 = geometry["hp"]
		var objective := Rect2(origin + Vector2(103, 105) * h, Vector2(hp.size.x + 10.0 * h, 27.0 * h))
		var buffs := Rect2(hud._status.position - Vector2(11, 1) * h, Vector2(hud._status.size.x + 12.0 * h, 27.0 * h))
		check("three-line confirmation fits its actual plaque %s/save=%s" % [dimensions, warning], screen.encloses(confirmation) and screen.encloses(plaque) and plaque.encloses(hud._toast.get_global_rect()) and hud._toast.get_visible_line_count() == 3 and plaque.size.y <= 100.0 * u)
		check("confirmation clears painted status/map progression text %s/save=%s" % [dimensions, warning], not plaque.intersects(status_ink) and not plaque.intersects(map_ink) and not plaque.intersects(objective) and not plaque.intersects(buffs))
		if warning:
			check("save retry keeps its original separate confirmation row %s" % dimensions, not plaque.intersects(hud._save_warning.get_global_rect()) and is_equal_approx(confirmation.position.y, origin.y + 306.0 * u))
		elif dimensions.x > dimensions.y and map_ink.position.x - status_ink.end.x - 40.0 * u >= 320.0 * u:
			var top := margins.y + 16.0 * u
			check("wide confirmation uses the empty status/map gap %s" % dimensions, plaque.position.x >= status_ink.end.x + 20.0 * u - 0.01 and plaque.end.x <= map_ink.position.x - 20.0 * u + 0.01 and plaque.size.x <= 520.0 * u and is_equal_approx(plaque.position.y, top))
		else:
			check("portrait/narrow fallback retains its approved position and width %s" % dimensions, is_equal_approx(confirmation.position.y, origin.y + 194.0 * u) and is_equal_approx(confirmation.size.x, minf(520.0 * u, available.x - 40.0 * u)) and is_equal_approx(confirmation.get_center().x, margins.x + available.x * 0.5))
	hud._toast.text = old_text
	hud._save_warning.visible = old_warning
	hud._update_layout()


func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.delete_save()
	GameState.new_game("mage")
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	await _frames(3)
	game.hud.set_process(false)
	var controls: TouchControls = game.hud.controls
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(720, 1560), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(4)
		game.hud._update_layout()
		await _check_toasts(game.hud, dimensions)
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
			if name.begins_with("bar_"):
				var drawn: float = button["visual_radius"]
				var menu_unit: float = controls._unit
				check("menu illustration stays inside its touch target", drawn + 0.75 * menu_unit <= float(button["radius"]))
				if dimensions.y > dimensions.x:
					check("portrait menus are slightly larger with clear spacing", drawn / menu_unit > 33.0 and drawn / menu_unit < 36.0)
				else:
					check("landscape menu illustration keeps its existing size", is_equal_approx(drawn / menu_unit, 31.0))
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
			if slot == 0:
				check("primary skill illustration keeps its existing size", is_equal_approx(float(button["visual_radius"]) / controls._unit, 67.0))
			else:
				check("auxiliary skills leave more space while preserving their touch circle", float(button["visual_radius"]) < float(button["radius"]) * 0.95 and controls._hit_button(button["center"] + Vector2.DOWN * (float(button["radius"]) - 1.0)) == "slot%d" % slot)
			if str(GameState.slots[slot]).is_empty():
				check("empty hints leave more scenery visible without shrinking input", visual < float(button["visual_radius"]) and controls._hit_button(button["center"] + Vector2.RIGHT * (float(button["radius"]) - 1.0)) == "slot%d" % slot)
		var main: Vector2 = controls._buttons["slot0"]["center"]
		var roll: Vector2 = controls._buttons["roll"]["center"]
		check("dodge is beside primary skill", roll.x > main.x and absf(roll.y - main.y) < 3.0)
		check("joystick avoids combat fan", controls._stick_center.distance_to(main) > controls.stick_radius() + float(controls._buttons["slot0"]["radius"]) + 40.0)
		if dimensions == Vector2i(720, 1280):
			check("primary skill follows reference composition", absf(main.x / dimensions.x - 0.783) < 0.02 and absf(main.y / dimensions.y - 0.741) < 0.015)
			check("bottom menu leaves reference breathing room", controls._buttons["bar_bag"]["center"].y < dimensions.y * 0.93)
	# A landscape viewport without enough painted top gap must retain the fallback.
	view.size = Vector2i(860, 720)
	await _frames(4)
	await _check_toasts(game.hud, view.size)
	for id in ["cleave", "shadowAssault", "battleSprint", "sorceressAttack"]:
		var art := SkillIcons.source(id)
		var uv: Rect2 = art["uv"]
		check("extra attack has actual illustrated art: " + id, art["texture"] is Texture2D and Rect2(0, 0, 1, 1).encloses(uv))
	view.queue_free()
	await _frames(2)
