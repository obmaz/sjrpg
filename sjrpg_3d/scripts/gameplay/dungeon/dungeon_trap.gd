class_name DungeonTrap
extends RefCounted
## 함정의 주기·예고·피격 범위를 소유한다. 표시기는 이 시계만 읽는다.
enum Phase { REST, WARNING, ACTIVE, RECOVER }
const SPIKE_TIMES := [2.4, 1.1, .65, .35]
const FIRE_TIMES := [2.7, 1.35, 1.1, .6]
const NOZZLE := .18
var id := ""
var kind := "spike"
var position := Vector2.ZERO
var direction := Vector2.DOWN
var width := 1.65
var length := 1.85
var phase: int = Phase.REST
var age := 0.0
var activation := 0
var hit_actors: Dictionary = {}


func setup(
	key: String, type: String, flat: Vector2, toward := Vector2.DOWN, stagger := 0.0
) -> DungeonTrap:
	id = key
	kind = type
	position = Iso.project(flat)
	direction = toward.normalized()
	age = clampf(stagger, 0, .8)
	if kind == "flame":
		width = 1.4
		length = 2.8
	return self


func duration() -> float:
	return float((FIRE_TIMES if kind == "flame" else SPIKE_TIMES)[phase])


func step(delta: float) -> bool:
	if delta <= 0:
		return false
	age += delta
	if age < duration():
		return false
	# 한 프레임에 예고 단계 전체를 건너뛰지 않는다. 늦은 프레임의 초과 시간은 버린다.
	age = 0.0
	phase = (phase + 1) % 4
	if phase == Phase.ACTIVE:
		activation += 1
		hit_actors.clear()
	return true


func strength() -> float:
	if phase == Phase.ACTIVE:
		return smoothstep(0, .14 if kind == "flame" else .18, age)
	if phase == Phase.RECOVER:
		return 1.0 - smoothstep(0, duration(), age)
	return 0.0


func dangerous() -> bool:
	return phase == Phase.ACTIVE and age >= (.12 if kind == "flame" else .18)


func contains_foot(foot: Vector3, radius: float) -> bool:
	var flat := Iso.unproject(position) / WorldSpace3D.GROUND_UNITS_PER_METER
	var centre := Vector3(flat.x, DungeonRelief.at(position), flat.y)
	if absf(foot.y - centre.y) > .55:
		return false
	var offset := Vector2(foot.x - centre.x, foot.z - centre.z)
	var along := offset.dot(direction)
	var across := absf(offset.dot(direction.orthogonal()))
	if kind == "flame":
		along -= NOZZLE
		var half_width := lerpf(.20, width * .5, clampf(along / length, 0, 1))
		return along >= -radius and along <= length + radius and across <= half_width + radius
	return absf(along) <= length * .5 + radius and across <= width * .5 + radius


func title() -> String:
	return "벽 화염" if kind == "flame" else "가시판"


func detail() -> String:
	var labels: Array[String] = ["휴식 · 통과 가능", "분출 예고 · 피하세요", "발동 중 · 위험", "가라앉는 중"]
	return "%s · %.1f초" % [labels[phase], maxf(0, duration() - age)]
