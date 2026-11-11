extends TestCase
## Inspect visible product text through actual realm/settings flows, not variable names.


func _technical_text(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	if node is Control and node.is_visible_in_tree():
		var text := ""
		if node is Label or node is RichTextLabel or node is Button:
			text = str(node.get("text"))
		var folded := text.to_lower()
		# 필수 저작자 Dm3d와 원본 URL의 3d는 렌더러/에디션 UI가 아니다.
		if not node.get_meta("asset_credit", false) and ("3d" in folded or "2d" in folded):
			found.append(text)
	for child in node.get_children():
		found.append_array(_technical_text(child))
	return found


func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	check(
		"forest gameplay has no renderer or current-edition product label",
		_technical_text(game).is_empty()
	)
	game.hud.open_settings()
	await _frames(2)
	var settings: SettingsPanel = game.hud._panel
	check(
		"paused settings use adventure wording without technical edition text",
		(
			get_tree().paused
			and _technical_text(game).is_empty()
			and settings.find_child("CurrentEdition", true, false) == null
		)
	)
	var credit_count := 0
	var golem_credit := false
	for label: Label in settings.find_children("*", "Label", true, false):
		if label.get_meta("asset_credit", false):
			credit_count += 1
			if "Dm3d" in label.text and "CC-BY-3.0" in label.text and "rock-golem" in label.text:
				golem_credit = true
	check("all adopted credits retain the actual creator name", credit_count >= 6 and golem_credit)
	var select := settings.find_child("VersionSelect", true, false) as Button
	check(
		"web settings retain the save-and-return chooser action",
		(
			(select != null) == OS.has_feature("web")
			and (select == null or select.text == "저장하고 선택 화면으로")
		)
	)
	game.hud.close_panel()
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	var entered: bool = game.dungeon.enter()
	check("cave entry remains available after label removal", entered)
	if entered:
		preview._sync_scope()
		preview._world_environment.sync(0.0, true)
		check(
			"cave keeps its actual realm without a renderer badge",
			(
				preview._world_environment.cave.visible
				and not preview._world_environment.forest.visible
				and _technical_text(game).is_empty()
			)
		)
		game.hud.open_settings()
		await _frames(2)
		check(
			"cave settings also omit technical renderer text",
			get_tree().paused and _technical_text(game).is_empty()
		)
		game.hud.close_panel()
		game.dungeon.leave("")
		preview._sync_scope()
		preview._world_environment.sync(0.0, true)
		check(
			"forest return does not recreate a renderer label",
			preview._world_environment.forest.visible and _technical_text(game).is_empty()
		)
	game.queue_free()
	await _frames(2)
