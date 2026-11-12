extends TestCase
## Runtime atlas, class identity and real mobile hit geometry; browser verifies the actual pictures/actions.

class PhoneTree:
	extends SkillTreePanel
	var test_css_scale := 2.25
	func graph_css_scale() -> float:
		return test_css_scale


class PhoneSettings:
	extends SettingsPanel
	func display_pixel_scale() -> float:
		return 720.0 / 320.0


class SettingsGame:
	extends Node
	var dungeon := {"active": false}


func run() -> void:
	check("painted HUD atlas has its actual delivered dimensions", UiToneArt.icons().get_size() == Vector2(1536, 1024))
	check("painted avatars have their actual delivered dimensions", UiToneArt.portraits().get_size() == Vector2(1774, 887))
	var regions := {}
	for key in ["bag", "skills", "quests", "settings", "hp", "mp"]:
		var frame := UiToneArt.frame(key)
		check("each actual HUD region is a full distinct source cell", Rect2(Vector2.ZERO, UiToneArt.icons().get_size()).encloses(frame) and frame.size == Vector2(512, 512) and not regions.has(frame.position))
		regions[frame.position] = true
	var warrior := HudArt.portrait_uv("warrior")
	var mage := HudArt.portrait_uv("mage")
	check("class portraits remain separate and inside actual texture UVs", not warrior.intersects(mage) and Rect2(0, 0, 1, 1).encloses(warrior) and Rect2(0, 0, 1, 1).encloses(mage))
	check("real skill-node input supports a 44px phone target without neighboring overlap", (SkillTreePanel.NODE_SIDE + 16.0) / 2.25 >= 44.0 and (SkillTreePanel.TREE_MIN_WIDTH - SkillTreePanel.TIER_LABEL_WIDTH - 12.0) / 3.0 >= SkillTreePanel.NODE_SIDE + 16.0)
	for scale in [720.0 / 390.0, 720.0 / 320.0, 1280.0 / 568.0]:
		for preferred in [19, 18, 17]:
			var pixels := SkillTreePanel.graph_font_size(preferred, scale)
			check("canvas graph labels remain at least 12 CSS pixels", float(pixels) / scale >= 12.0)
		var rank_pixels := SkillTreePanel.graph_font_size(18, scale)
		check("measured rank ribbon fits its existing row gap", UiKit.BOLD_FONT.get_height(rank_pixels) + 10.0 <= SkillTreePanel.TIER_HEIGHT - SkillTreePanel.NODE_SIDE)
		for count in [0, 7, 99, 999, 5000]:
			var target: float = 22.0 * float(scale)
			var geometry := PotionArt.count_geometry(Vector2.ZERO, 20.0 * scale, count, scale, target)
			var rect: Rect2 = geometry["rect"]
			check("actual potion count remains at least 12 CSS pixels", float(geometry["font_size"]) / scale >= 12.0)
			if count < 10:
				check("common potion counts clear the vial centre in a lower-right badge", rect.position.x > 0.0 and rect.position.y > 0.0)
			for point in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
				check("measured potion count ribbon stays inside its actual touch circle", point.length() <= target + 0.01)
		var point_scale: float = float(scale)
		for points: int in [1, 99]:
			var point_geometry: Dictionary = TouchControls.skill_points_geometry(Vector2.ZERO, 20.0 * point_scale, points, point_scale, 22.0 * point_scale)
			var point_rect: Rect2 = point_geometry["rect"]
			check("live skill-point quantity stays at least 12 CSS pixels", float(point_geometry["font_size"]) / point_scale >= 12.0)
			for corner: Vector2 in [point_rect.position, point_rect.end, Vector2(point_rect.position.x, point_rect.end.y), Vector2(point_rect.end.x, point_rect.position.y)]:
				check("skill-point badge stays within its existing menu touch circle", corner.length() <= 22.0 * point_scale + 0.01)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var panel := PhoneTree.new()
	view.add_child(panel)
	await _frames(4)
	panel._selected = str(GameState.starter_ids()[0])
	panel._build_detail()
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		view.size = dimensions
		panel.test_css_scale = 720.0 / 320.0 if dimensions.y > dimensions.x else 1280.0 / 568.0
		panel._fit()
		await _frames(5)
		for node in panel._detail.find_children("*", "Control", true, false):
			var control := node as Control
			if control is Label or control is Button:
				check("actual skill description/info/effects/slot controls retain 12 CSS pixels", float(control.get_theme_font_size("font_size")) / panel.test_css_scale >= 12.0)
			if control is Button:
				check("real learn and equip buttons retain 44 CSS pixel targets", control.size.x / panel.test_css_scale >= 44.0 and control.size.y / panel.test_css_scale >= 44.0)
		var clipping := panel._detail.get_parent() as ScrollContainer
		check("larger skill text wraps within the real detail scroll viewport", panel._detail.size.x <= clipping.size.x + 1.0)
	panel.queue_free()
	await _frames(2)
	view.size = Vector2i(720, 1280)
	var settings_game := SettingsGame.new()
	view.add_child(settings_game)
	var settings := PhoneSettings.new()
	settings.setup(settings_game)
	view.add_child(settings)
	await _frames(5)
	check("all real supported zoom choices are present", settings._zoom_buttons.size() == Prefs.WORLD_ZOOMS.size())
	for button in settings._zoom_buttons:
		check("actual zoom controls retain 44 CSS pixel targets", button.size.x / settings.display_pixel_scale() >= 44.0 and button.size.y / settings.display_pixel_scale() >= 44.0)
	view.queue_free()
	await _frames(2)
