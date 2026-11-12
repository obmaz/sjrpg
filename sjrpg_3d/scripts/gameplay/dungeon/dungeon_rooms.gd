class_name DungeonRooms
extends RefCounted
## 입장 때 배정한 적만 추적한다. 몬스터가 방 밖으로 추격해도 출신 방의 진행에 반영한다.
var remaining: Array[int] = []
var _owners: Dictionary = {}
var cleared := 0


func _init() -> void:
	remaining.resize(DungeonLayout.ROOMS.size())
	remaining.fill(0)


func register(enemy: Enemy, room: int) -> void:
	var id := enemy.get_instance_id()
	if _owners.has(id):
		return
	_owners[id] = room
	remaining[room] += 1


## 알 수 없거나 중복된 사망은 무시한다. 실제 등록된 적의 방 번호만 돌려준다.
func defeat(enemy: Enemy) -> int:
	if not is_instance_valid(enemy) or not enemy.dead:
		return -1
	var id := enemy.get_instance_id()
	if not _owners.has(id):
		return -1
	var room: int = _owners[id]
	_owners.erase(id)
	remaining[room] -= 1
	if remaining[room] == 0:
		cleared += 1
	return room


func nearest_remaining(projected: Vector2) -> int:
	var flat := Iso.unproject(projected)
	var selected := -1
	var distance := INF
	for room in remaining.size():
		if remaining[room] == 0:
			continue
		var next := flat.distance_squared_to(DungeonLayout.ROOMS[room])
		if next < distance:
			distance = next
			selected = room
	return selected


func detail(room: int) -> String:
	return "정리 완료" if remaining[room] == 0 else "남은 적 %d마리 · 방 밖으로 추격한 적도 포함" % remaining[room]
