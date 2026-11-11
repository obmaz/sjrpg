class_name Chest
extends Node2D
## 숲의 목재 상자와 동굴의 쇠·황금 상자. 보상은 확정된 개봉에서 한 번만 지급한다.
## Quacks like an Enemy for the area queries (hp / dead / take_damage and no-op statuses).

## Projected-ground radius; native metre collider and full lid sweep share this envelope.
const COLLISION_RADIUS := 60.0
const OPEN_SECONDS := .32
const RATTLE_SECONDS := .22

var game: Node
var index := 0
var hp := 1.0
var dead := false
var body_sprite: IsoSprite
var _open_time := 0.0
var _impact_time := 0.0
var variant := "wood"
var persistent := true
var max_hp := 1.0


func setup(
	g: Node, i: int, at: Vector2, def: Dictionary, broken_def: Dictionary, kind := "wood"
) -> Chest:
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
	_open_time = OPEN_SECONDS if opened else 0.0
	set_process(false)
	return self


## 반응이 진행되는 동안만 처리한다. 메뉴와 비활성 숲의 처리 모드도 그대로 따른다.
func _process(delta: float) -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	if Prefs.reduce_motion:
		_impact_time = 0.0
		_open_time = OPEN_SECONDS if dead else 0.0
	else:
		_impact_time = maxf(0.0, _impact_time - maxf(0.0, delta))
		if dead:
			_open_time = minf(OPEN_SECONDS, _open_time + maxf(0.0, delta))
	set_process(_impact_time > 0.0 or (dead and _open_time < OPEN_SECONDS))


## 표시 전용 값이다. 원래 닫힘~열림의 힌지 범위 안에서만 움직인다.
func lid_fraction() -> float:
	if dead:
		if Prefs.reduce_motion or _open_time >= OPEN_SECONDS:
			return 1.0
		var progress := clampf(_open_time / OPEN_SECONDS, 0.0, 1.0)
		return 1.0 - pow(1.0 - progress, 3)
	if Prefs.reduce_motion or _impact_time <= 0.0:
		return 0.0
	var age := 1.0 - _impact_time / RATTLE_SECONDS
	return .10 * pow(sin(age * TAU * 1.5), 2) * (1.0 - age)


func take_damage(_amount: float, _source: Node2D) -> void:
	if dead or _amount <= 0.0:
		return
	hp = maxf(0.0, hp - 1.0)
	if hp > 0.0:
		_impact_time = 0.0 if Prefs.reduce_motion else RATTLE_SECONDS
		set_process(_impact_time > 0.0)
		SoundFx.play("tick")
		game.float_text(position + Vector2(0, -130), "내구도 -1", Color("c9d1d3")).anchor_text_ground(position)
		return
	dead = true
	_impact_time = 0.0
	_open_time = OPEN_SECONDS if Prefs.reduce_motion else 0.0
	set_process(_open_time < OPEN_SECONDS)
	if persistent:
		GameState.opened_chests.append(index)
	var broken: Dictionary = game.village.data["sprites"]["chest-broken"]
	body_sprite.queue_free()
	body_sprite = IsoSprite.new().setup(
		broken,
		(
			float(broken["height"])
			* 68.0
			/ float(game.village.data["sprites"]["chest"]["body"][2])
			* 2.6
		)
	)
	add_child(body_sprite)
	game.on_chest_broken(self)


# Status effects never apply to chests.
func slow(_d: float) -> void:
	pass


func freeze(_d: float) -> void:
	pass


func stun(_d: float) -> void:
	pass


func fear(_d: float, _from: Vector2) -> void:
	pass


func taunt(_d: float) -> void:
	pass


func cry(_d: float, _v: float) -> void:
	pass


func knock(_from: Vector2, _s: float) -> void:
	pass
