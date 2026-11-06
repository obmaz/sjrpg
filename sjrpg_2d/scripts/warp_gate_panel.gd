class_name WarpGatePanel
extends PanelFrame
## A physical gate offers only discovered destinations in the current forest chapter.

var game: Node
var _notice := ""
var destination_buttons: Dictionary = {}


func setup(g: Node) -> WarpGatePanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	game.exploration.discover_current()
	set_header("워프게이트", "제1장 · 발견한 안식처로 이동")
	_rebuild()
	add_footer("모험 계속하기", func(): closed.emit(), true)


func _rebuild() -> void:
	destination_buttons.clear()
	clear_body()
	var origin: String = game.exploration.gate_origin()
	var source: String = Exploration.NAMES.get(origin, "워프게이트 밖")
	body.add_child(PanelFrame.wrap_label("현재 위치 · " + source, 23, UiKit.GOLD))
	var reason: String = game.exploration.gate_block_reason()
	body.add_child(PanelFrame.wrap_label(_notice if _notice != "" else reason if reason != "" else "발견한 안식처로 무료 이동합니다. 도착하면 생명과 자원을 회복합니다.", 20))
	for id in _destination_order(origin):
		var found := GameState.discovered_sanctuaries.has(id)
		var destination: String = id
		var current: bool = origin == id
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.SURFACE))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		card.add_child(column)
		var label: String = Exploration.NAMES[id] + (" · 현재 위치" if current else "")
		column.add_child(PanelFrame.wrap_label(label, 23, UiKit.TEXT))
		column.add_child(PanelFrame.wrap_label("현재 연결된 게이트입니다." if current else "발견한 목적지 · 무료 이동" if found else "직접 방문하면 워프 목적지로 등록됩니다.", 18, UiKit.MUTED))
		var travel_action := found and not current
		var button := UiKit.button("현재 위치" if current else Exploration.NAMES[id] + "로 이동" if found else "미발견", 26 if travel_action else 22)
		button.custom_minimum_size = Vector2(0, 96 if travel_action else 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.style_button(button, travel_action)
		button.disabled = current or not found or reason != ""
		destination_buttons[id] = button
		button.pressed.connect(func(): _choose(destination))
		column.add_child(button)
		body.add_child(card)


## Put a usable destination before current/undiscovered cards so larger actions
## remain immediately reachable on a short landscape screen.
func _destination_order(origin: String) -> Array:
	var order: Array = Exploration.NAMES.keys()
	var ids := order.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var rank_a := 1 if a == origin else 0 if GameState.discovered_sanctuaries.has(a) else 2
		var rank_b := 1 if b == origin else 0 if GameState.discovered_sanctuaries.has(b) else 2
		return rank_a < rank_b if rank_a != rank_b else order.find(a) < order.find(b))
	return ids


func _choose(destination: String) -> void:
	if game.exploration.warp(destination):
		closed.emit()
	else:
		_notice = game.exploration.destination_block_reason(destination, true)
		if _notice.is_empty():
			_notice = "도착 지점이 막혀 이동할 수 없습니다."
		_rebuild()
