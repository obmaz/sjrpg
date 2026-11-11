class_name Chest
extends Node2D
## 숲의 목재 상자와 동굴의 쇠·황금 상자. 보상은 확정된 개봉에서 한 번만 지급한다.
## Quacks like an Enemy for the area queries (hp / dead / take_damage and no-op statuses).

## Projected-ground radius; native metre collider and full lid sweep share this envelope.
const COLLISION_RADIUS := 60.0

var game: Node
var index := 0
var hp := 1.0
var dead := false
var body_sprite: IsoSprite
var _open_time := 0.0
var variant := "wood"
var persistent := true
var max_hp := 1.0


func setup(g: Node, i: int, at: Vector2, def: Dictionary, broken_def: Dictionary, kind := "wood") -> Chest:
	game = g
	index = i
	position = at
	variant = kind
	persistent = not game.dungeon.active
	max_hp = 4.0 if variant == "iron" else 1.0
	hp = max_hp
	var opened := persistent and GameState.opened_chests.has(i)
	var d := broken_def if opened else def
	body_sprite = IsoSprite.new().setup(d, float(d["height"]) * 68.0 / float(def["body"][2]) * 2.6)
	add_child(body_sprite)
	dead = opened
	return self


func take_damage(_amount: float, _source: Node2D) -> void:
	if dead or _amount <= 0.0:
		return
	hp = maxf(0.0, hp - 1.0)
	if hp > 0.0:
		game.float_text(position + Vector2(0,-85), "쇠 상자 %d/%d" % [int(hp),int(max_hp)], Color("c9d1d3"))
		return
	dead = true
	if persistent:
		GameState.opened_chests.append(index)
	var broken: Dictionary = game.village.data["sprites"]["chest-broken"]
	body_sprite.queue_free()
	body_sprite = IsoSprite.new().setup(broken, float(broken["height"]) * 68.0 / float(game.village.data["sprites"]["chest"]["body"][2]) * 2.6)
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
