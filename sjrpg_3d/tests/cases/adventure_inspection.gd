extends TestCase
## 일반 쿼리는 플레이 상태를 바꾸지 않고 명시적 검수 세션만 상태를 적용한다.


func run() -> void:
	var game := await make_game()
	var gold := GameState.gold
	var position: Vector2 = game.player.position
	var child_count := game.get_child_count()
	var connections: int = game.encounters.state_captured.get_connections().size()
	check("normal adventures have no inspection owner", game.inspection == null)
	for query: String in [
		"gold=99999&zoom=0.5&at=portal",
		"inspection=0&gold=99999",
		"inspection=01&gold=99999",
		"inspection=1&inspection=0&gold=99999",
	]:
		var disabled := AdventureInspection.create(game, query)
		check("queries cannot opt in by changing only gameplay parameters", disabled == null)
	check(
		"unrequested queries leave currency, position and nodes unchanged",
		(
			GameState.gold == gold
			and game.player.position == position
			and game.get_child_count() == child_count
		)
	)
	var baseline: Vector2 = game.camera.zoom
	var world_zoom := Prefs.world_zoom
	game.inspection = AdventureInspection.create(game, "?inspection=1&gold=321&zoom=0.75")
	var session: AdventureInspection = game.inspection
	check(
		"explicit review owns its scene fixtures under the adventure",
		session.get_parent() == game and session.scenes.get_parent() == session
	)
	session.apply()
	check(
		"explicit parameters use the same relative camera and numeric state",
		(
			GameState.gold == 321
			and game.camera.zoom.is_equal_approx(baseline * 0.75)
			and is_equal_approx(Prefs.world_zoom, world_zoom)
		)
	)
	GameState.gold = 700
	session.apply()
	check("one inspection request is applied only once", GameState.gold == 700)
	session.focus_point = Vector2(13, 27)
	check("inspection owns its optional camera focus", game._camera_focus() == session.focus_point)
	var fixtures: WeakRef = weakref(session.scenes)
	session.queue_free()
	await _frames(2)
	game.encounters.capture()
	game._update_zoom()
	check(
		"removing inspection releases fixtures and encounter callbacks",
		(
			fixtures.get_ref() == null
			and game.encounters.state_captured.get_connections().size() == connections
		)
	)
	check(
		"normal camera scale resumes without an inspection owner",
		game.camera.zoom.is_equal_approx(baseline)
	)
