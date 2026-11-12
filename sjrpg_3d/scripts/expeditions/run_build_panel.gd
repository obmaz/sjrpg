class_name RunBuildPanel
extends PanelFrame
## 원정에서는 포인트를 배분하지 않고, 습득한 기술과 룬을 재배치한다.
var _selected := ""


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
	for id: String in GameState.ranks:
		var skill := GameState.skill(id)
		if GameState.rank(id) == 0 or skill.get("passive", true):
			continue
		var label_text := str(skill["name"])
		if id == GameState.expedition.get("signature"):
			label_text += " · 주 공격"
		if id == _selected:
			label_text += " · 선택됨"
		_button(
			label_text,
			func():
				_selected = id
				_rebuild()
		)
	if _selected.is_empty():
		return
	body.add_child(section(GameState.skill(_selected)["name"]))
	body.add_child(ExpeditionPanel.skill_art(_selected))
	body.add_child(wrap_label(SkillDefs.describe(_selected, 1), 19))
	if _selected != GameState.expedition.get("signature"):
		for index in range(1, 5):
			var current := str(GameState.slots[index])
			_button(
				"보조 %d · %s → 선택 기술 배치" % [index, GameState.skill(current).get("name", "비어 있음")],
				func():
					_assign_slot(index)
					_rebuild()
			)
	body.add_child(section("지원 룬 · %d / 2" % RunBuild.supports(_selected).size()))
	for rune: String in GameState.expedition["rune_inventory"]:
		var data: Dictionary = ExpeditionContent.runes()[rune]
		var attached := "미장착"
		for skill_id: String in GameState.expedition["runes"]:
			if RunBuild.supports(skill_id).has(rune):
				attached = str(GameState.skill(skill_id)["name"])
		body.add_child(wrap_label("%s · %s\n%s" % [data["name"], attached, data["desc"]], 19))
		var here := RunBuild.supports(_selected).has(rune)
		_button(
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


func _button(text: String, callback: Callable, enabled := true) -> void:
	var button := UiKit.button(text, 21)
	button.custom_minimum_size.y = 76
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.pressed.connect(callback)
	body.add_child(button)


func _assign_slot(index: int) -> void:
	var before := GameState.slots.duplicate()
	GameState.assign_slot(index, _selected)
	if not GameState.save_error.is_empty():
		GameState.slots = before
