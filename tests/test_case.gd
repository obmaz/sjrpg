class_name TestCase
extends Node
## 테스트 케이스 기반 클래스. `tests/cases/*.gd`가 이 클래스를 상속해 `run()`을 구현합니다.
## 실패는 `failures += 1` 또는 `check()`로 기록하며, 케이스 하나는 독립된 게임 인스턴스를 만들어 씁니다.

var failures := 0


func run() -> void:
	pass


## 조건을 검사해 `ok`/`FAIL` 한 줄로 출력하고 실패를 센다.
func check(label: String, ok: bool, detail := "") -> bool:
	print("%s %s%s" % ["ok  " if ok else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not ok:
		failures += 1
	return ok


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 입력으로 `target`까지 걷는다 (최대 `frames`프레임).
func _walk(player: Player, target: Vector2, frames: int) -> void:
	for i in frames:
		var d := target - player.position
		if d.length() < 6.0:
			break
		player.move_input = d.normalized()
		await get_tree().process_frame
	player.move_input = Vector2.ZERO


## 새 게임을 시작하고 몬스터를 비운 게임 장면을 돌려준다.
func make_game(cls := "warrior") -> Node:
	GameState.new_game(cls)
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	for e in game.enemies:
		e.queue_free()
	game.enemies.clear()
	return game
