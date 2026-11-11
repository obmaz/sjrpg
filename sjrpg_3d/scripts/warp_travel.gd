class_name WarpTravel
extends Node
## 이동을 수락한 뒤 사라짐→실제 공간 이동→나타남을 같은 일시정지 시계로 처리한다.
const OUT := .30
const HIDDEN := .06
const IN := .34
const DURATION := OUT + HIDDEN + IN
signal finished
var game: Node
var active := false
var age := 0.0
var transferred := false
var destination := ""


func setup(source: Node) -> WarpTravel:
	game = source
	return self


func begin(id: String) -> void:
	destination = id
	age = 0.0
	transferred = false
	active = true
	game.player.warp_locked = true
	SoundFx.play("warp")
	Prefs.pulse("dodge")


func opacity() -> float:
	if not active:
		return 1.0
	if age < OUT:
		return 1.0 - smoothstep(0.0, OUT, age)
	return smoothstep(OUT + HIDDEN, DURATION, age)


func _process(delta: float) -> void:
	if not active or get_tree().paused:
		return
	age += delta
	if game.player.dead or game.dungeon.active:
		_finish()
		return
	if not transferred and age >= OUT:
		# 출발 연출 동안 성문·장애물이 바뀌어도 안전한 도착 지점을 다시 찾는다.
		if not game.exploration._complete_warp(destination):
			_finish()
			return
		transferred = true
	if age >= DURATION:
		_finish()


func _finish() -> void:
	active = false
	game.player.warp_locked = false
	game.exploration._clear_warp_input()
	finished.emit()
