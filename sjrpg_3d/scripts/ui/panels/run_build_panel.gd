class_name RunBuildPanel
extends PanelFrame
## 원정에서는 포인트를 배분하지 않고, 습득한 기술과 룬을 재배치한다.
var _selected := ""
var _skill_grid: GridContainer


func _ready() -> void:
	super._ready()
	_rebuild()


func _rebuild() -> void:
	clear_body()
	set_header("원정 스킬과 지원 룬", "기술당 룬 2개 · 언제든 재조합")
	if not GameState.save_error.is_empty():
		body.add_child(wrap_label(GameState.save_error, 19, Color.SALMON))
	body.add_child(
		wrap_label(
			"주 공격은 시작할 때 선택한 기술로 고정되며 자원을 소모하지 않습니다. 습득한 기술을 고른 뒤 보조 슬롯이나 룬을 선택하세요.",
			19,
			UiKit.MUTED
		)
	)
	body.add_child(section("습득한 기술"))
	_skill_grid = GridContainer.new()
	_skill_grid.add_theme_constant_override("h_separation", 12)
	_skill_grid.add_theme_constant_override("v_separation", 12)
	_skill_grid.resized.connect(_fit_skill_choices)
	body.add_child(_skill_grid)
	for id: String in GameState.ranks:
		var skill := GameState.skill(id)
		if GameState.rank(id) == 0 or skill.get("passive", true):
			continue
		var label_text := str(skill["name"])
		if id == GameState.expedition.get("signature"):
			label_text += " · 주 공격"
		if id == _selected:
			label_text += " · 선택됨"
		var choice := _button(
			label_text,
			func():
				_selected = id
				_rebuild(),
			true,
			_skill_grid
		)
		choice.set_meta("gamepad_key", "run_skill:" + id)
		choice.set_meta("run_skill", id)
		UiKit.style_button(choice, false, id == _selected)
	if _selected.is_empty():
		return
	body.add_child(section(GameState.skill(_selected)["name"]))
	body.add_child(ExpeditionPanel.skill_art(_selected))
	body.add_child(wrap_label(SkillDefs.describe(_selected, 1), 19))
	if _selected != GameState.expedition.get("signature"):
		for index in range(1, 5):
			var current := str(GameState.slots[index])
			body.add_child(wrap_label("보조 %d · %s" % [index, GameState.skill(current).get("name", "비어 있음")], 17, UiKit.MUTED))
			var assign := _button(
				"보조 %d에 배치" % index,
				func():
					_assign_slot(index)
					_rebuild()
			)
			assign.set_meta("gamepad_key", "run_slot:" + str(index))
			UiKit.style_button(assign, false, current == _selected)
	body.add_child(section("지원 룬 · %d / 2" % RunBuild.supports(_selected).size()))
	for rune: String in GameState.expedition["rune_inventory"]:
		var data: Dictionary = ExpeditionContent.runes()[rune]
		var attached := "미장착"
		for skill_id: String in GameState.expedition["runes"]:
			if RunBuild.supports(skill_id).has(rune):
				attached = str(GameState.skill(skill_id)["name"])
		body.add_child(UiKit.divider())
		body.add_child(section(str(data["name"])))
		body.add_child(wrap_label("장착 위치 · " + attached, 17, UiKit.MUTED))
		body.add_child(wrap_label(str(data["desc"]), 19))
		var here := RunBuild.supports(_selected).has(rune)
		var attach := _button(
			"해제" if here else "이 기술에 장착",
			func():
				var before: Dictionary = GameState.expedition["runes"].duplicate(true)
				if RunBuild.equip_rune("" if here else _selected, rune):
					if not GameState.save_game():
						GameState.expedition["runes"] = before
				_rebuild(),
			(
				here
				or (
					RunBuild.supports(_selected).size() < 2
					and RunBuild.can_support(_selected, rune)
				)
			)
		)
		attach.set_meta("gamepad_key", "run_rune:" + rune)
		if not attach.disabled:
			continue
		body.add_child(wrap_label(
			"이 기술은 이 룬을 지원하지 않습니다." if not RunBuild.can_support(_selected, rune) else "룬은 기술마다 2개까지 장착합니다. 장착한 룬을 해제한 뒤 다시 선택하세요.",
			17,
			UiKit.MUTED
		))
	_fit_skill_choices.call_deferred()


func _button(text: String, callback: Callable, enabled := true, holder: Container = null) -> Button:
	var button := UiKit.button(text, 21)
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.pressed.connect(callback)
	var parent: Container = body if holder == null else holder
	parent.add_child(button)
	return button


func _fit_skill_choices() -> void:
	if not is_instance_valid(_skill_grid):
		return
	var scale := UiMetrics.units_per_display_pixel(get_viewport())
	var gap := float(_skill_grid.get_theme_constant("h_separation"))
	# Keep names readable as the device folds; every choice stays a full touch target.
	_skill_grid.columns = clampi(floori((_skill_grid.size.x + gap) / (120.0 * scale + gap)), 1, 3)


func _assign_slot(index: int) -> void:
	var before := GameState.slots.duplicate()
	GameState.assign_slot(index, _selected)
	if not GameState.save_error.is_empty():
		GameState.slots = before
