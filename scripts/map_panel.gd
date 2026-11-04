class_name MapPanel
extends PanelFrame

var game: Node
var _tab := 0

func setup(g: Node) -> MapPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	set_header("바람 동굴 지도" if game.dungeon.active else "숲의 지도", "미니맵을 누르거나 M 키로 열기")
	_rebuild()
	add_footer("탐험 계속하기", func(): closed.emit(), true)


func _rebuild() -> void:
	if game.dungeon.active:
		_tab = 0
	set_tabs(["동굴 지도"] if game.dungeon.active else ["전체 지도", "안식처 이동"], _tab, func(index):
		_tab = index
		_rebuild())
	clear_body()
	if _tab == 0:
		var canvas := MapCanvas.new()
		canvas.game = game
		canvas.custom_minimum_size = Vector2(0, 460)
		body.add_child(canvas)
		body.add_child(PanelFrame.wrap_label("흰 화살표: 내 위치 · 노랑: 의뢰 · 청록: 시설 · 보라: 발견한 안식처 · 주황: 파수꾼", 17))
		body.add_child(PanelFrame.wrap_label(game.dungeon.objective() if game.dungeon.active else Quests.main_objective(), 20, UiKit.GOLD))
		for marker in MapGeometry.markers(game):
			body.add_child(PanelFrame.wrap_label(marker["label"], 18, marker["color"]))
		return
	var reason: String = game.exploration.travel_block_reason()
	body.add_child(PanelFrame.wrap_label(reason if reason != "" else "발견한 안식처로 무료 이동합니다. 도착 시 생명과 자원을 회복합니다.", 20))
	for id in Exploration.NAMES:
		var found := GameState.discovered_sanctuaries.has(id)
		var destination: String = id
		var button := UiKit.button(Exploration.NAMES[id] + ("" if found else " · 직접 방문해 발견하세요"), 21)
		button.custom_minimum_size = Vector2(0, 76)
		button.disabled = not found or reason != "" or id == game.exploration.nearby()
		button.pressed.connect(func():
			if game.exploration.travel(destination):
				closed.emit())
		body.add_child(button)


class MapCanvas:
	extends Control
	var game: Node

	func _draw() -> void:
		draw_style_box(UiKit.panel_style(Color("1d3028")), Rect2(Vector2.ZERO, size))
		var boundary := PackedVector2Array()
		for point in [game.FIELD.position, Vector2(game.FIELD.end.x, game.FIELD.position.y), game.FIELD.end, Vector2(game.FIELD.position.x, game.FIELD.end.y)]:
			boundary.append(Iso.project(point))
		var bounds: Rect2 = game.dungeon.layout.bounds if game.dungeon.active else Iso.poly_bounds(boundary)
		var scale_factor := minf((size.x - 36.0) / bounds.size.x, (size.y - 36.0) / bounds.size.y)
		var origin := size / 2.0 - bounds.get_center() * scale_factor
		for shape in game.map_shapes:
			var polygon := PackedVector2Array()
			for point in shape["poly"]:
				polygon.append(origin + point * scale_factor)
			if polygon.size() >= 3:
				draw_colored_polygon(polygon, shape["color"])
		var labels: Array[Rect2] = []
		if game.dungeon.active:
			for enemy in game.enemies:
				if not enemy.dead:
					draw_circle(origin + enemy.position * scale_factor, 3.5, Color("ed6856"))
		for marker in MapGeometry.markers(game):
			var at: Vector2 = origin + marker["pos"] * scale_factor
			draw_circle(at, 5.0, marker["color"])
			var label_size := Vector2(UiKit.BOLD_FONT.get_string_size(marker["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 10.0, 25.0)
			var label := Rect2(Vector2(clampf(at.x + 8.0, 6.0, size.x - label_size.x - 6.0), clampf(at.y - 28.0, 6.0, size.y - 31.0)), label_size)
			for attempt in 14:
				var overlap := false
				for used in labels:
					if label.intersects(used):
						overlap = true
						break
				if not overlap:
					break
				label.position.y += 27.0
				if label.end.y > size.y - 6.0:
					label.position.y = 6.0
			labels.append(label)
			draw_line(at, label.position + Vector2(0, 13), marker["color"], 1.0, true)
			draw_rect(label, Color(0.04, 0.08, 0.06, 0.9))
			draw_string(UiKit.BOLD_FONT, label.position + Vector2(5, 19), marker["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, marker["color"])
		var hero: Vector2 = origin + game.player.position * scale_factor
		draw_circle(hero, 11.0, Color("10201a"))
		draw_arc(hero, 10.0, 0, TAU, 24, Color.WHITE, 2.0, true)
		var direction := Vector2.from_angle(game.player.facing)
		draw_colored_polygon(PackedVector2Array([hero + direction * 9.0, hero + direction.rotated(2.5) * 7.0, hero + direction.rotated(-2.5) * 7.0]), Color.WHITE)
