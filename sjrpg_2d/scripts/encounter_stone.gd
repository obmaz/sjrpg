class_name EncounterStone
extends Node2D
## The original rechargeable encounter marker: a solid prop, not a destructible chest.

var runtime: Node
var id := ""
var art: IsoSprite
var _flash := 0.0


func setup(owner_runtime: Node, key: String, at: Vector2, definition: Dictionary) -> EncounterStone:
	runtime = owner_runtime
	id = key
	position = at
	art = IsoSprite.new().setup(definition, 112.0)
	add_child(art)
	return self


func body() -> PackedVector2Array:
	var center := Iso.unproject(position)
	var points := PackedVector2Array()
	for point in [Vector2(-26, -16), Vector2(26, -16), Vector2(26, 16), Vector2(-26, 16)]:
		points.append(Iso.project(center + point))
	return points


func take_damage(amount: float, source: Node2D) -> bool:
	if amount <= 0.0 or not runtime.strike(id, source):
		return false
	_flash = 0.18
	return true


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var ready: bool = runtime.can_summon(id)
	art.modulate_color = Color.WHITE if ready else Color(0.58, 0.66, 0.63)
	if _flash > 0.0 and not Prefs.reduce_motion:
		art.modulate_color = art.modulate_color.lerp(Color(0.55, 1.0, 0.9), _flash / 0.18)
	art.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var game: Node = runtime.game
	if game.dungeon.active or position.distance_to(game.player.position) > 240.0:
		return
	var state: Dictionary = runtime.states[id]
	var living: int = runtime.living(id)
	var text := "주변의 적을 정리하세요 · %d" % living
	if living == 0:
		text = "공격해 재소환 · %d/3" % int(state["charges"])
		if int(state["charges"]) == 0:
			text = "충전까지 %d초" % ceili(EncounterRuntime.RECHARGE_SECONDS - float(state["recharge"]))
	var width := HudArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0
	var rect := Rect2(-width * 0.5, -128.0, width, 25.0)
	draw_style_box(UiKit.panel_style(Color(0.04, 0.07, 0.06, 0.88), Color(0.4, 0.55, 0.47), 4), rect)
	HudArt.text_outlined(self, text, rect.position + Vector2(0, 18), width, 15, Color("d4e3cd"))
	for index in 3:
		draw_circle(Vector2((index - 1) * 9, -95), 2.5, Color("a7ebd2") if index < int(state["charges"]) else Color("334139"))
