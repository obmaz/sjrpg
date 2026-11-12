extends TestCase


## 실제 Viewport 신호가 정지된 HUD의 그림/터치 영역을 갱신하되 시계는 멈춰야 한다.
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.delete_save()
	GameState.new_game("mage")
	var game := preload("res://scripts/gameplay/game.gd").new()
	view.add_child(game)
	await _frames(4)
	var hud: Hud = game.hud
	hud.toast("멈춘 화면에서도 보이는 확인 알림")
	await _frames(2)
	get_tree().paused = true
	var held := hud._toast_time
	var resource: float = game.player.resource
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(1600, 720)]:
		view.size = dimensions
		await _frames(4)
		var geometry := hud.status_geometry()
		var expected: Rect2 = geometry["map"]
		check(
			"paused minimap follows the actual new header geometry %s" % dimensions,
			(
				hud.minimap.position.distance_to(expected.position) < .01
				and hud.minimap.size.distance_to(expected.size) < .01
			)
		)
		check(
			"retained map layers follow their resized Control %s" % dimensions,
			hud.minimap._paint_center.distance_to(expected.size * .5) < .01
		)
		check(
			"confirmation follows its current responsive anchor %s" % dimensions,
			hud._toast_plaque.position.distance_to(hud.toast_rect().position) < .01
		)
		var main: Vector2 = hud.controls._buttons["slot0"]["center"]
		var valid := Rect2(Vector2.ZERO, Vector2(dimensions)).has_point(main)
		valid = valid and hud.controls._hit_button(main) == "slot0"
		check(
			"paused controls draw and hit-test at their current screen positions %s" % dimensions,
			valid
		)
		check(
			"rotation does not advance notification time or mana %s" % dimensions,
			hud._toast_time == held and game.player.resource == resource
		)
	get_tree().paused = false
	view.queue_free()
	await _frames(2)
