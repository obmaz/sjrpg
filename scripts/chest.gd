class_name Chest
extends Node2D
## 마을 상자 (원본 destructible chest): 공격 기술로 한 번 맞으면 부서지며 보상이 나옵니다.
## Quacks like an Enemy for the area queries (hp / dead / take_damage and no-op statuses).

var game: Node
var index := 0
var hp := 1.0
var dead := false
var body_sprite: IsoSprite
var _open_time := 0.0


func setup(g: Node, i: int, at: Vector2, def: Dictionary, broken_def: Dictionary) -> Chest:
	game = g
	index = i
	position = at
	var opened := GameState.opened_chests.has(i)
	var d := broken_def if opened else def
	body_sprite = IsoSprite.new().setup(d, float(d["height"]) * 68.0 / float(def["body"][2]) * 1.3)
	add_child(body_sprite)
	dead = opened
	return self


func take_damage(_amount: float, _source: Node2D) -> void:
	if dead:
		return
	dead = true
	GameState.opened_chests.append(index)
	var broken: Dictionary = game.village.data["sprites"]["chest-broken"]
	body_sprite.queue_free()
	body_sprite = IsoSprite.new().setup(broken, float(broken["height"]) * 68.0 / float(game.village.data["sprites"]["chest"]["body"][2]) * 1.3)
	add_child(body_sprite)
	game.on_chest_broken(self)


# Status effects never apply to chests.
func slow(_d: float) -> void: pass
func freeze(_d: float) -> void: pass
func stun(_d: float) -> void: pass
func fear(_d: float, _from: Vector2) -> void: pass
func taunt(_d: float) -> void: pass
func cry(_d: float, _v: float) -> void: pass
func knock(_from: Vector2, _s: float) -> void: pass
