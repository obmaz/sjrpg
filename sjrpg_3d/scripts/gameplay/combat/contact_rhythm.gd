class_name ContactRhythm
extends RefCounted
## 확정 피해의 소리·접촉 효과만 짧게 나눈다. 판정·보상·몸 반응은 즉시 유지한다.
const STEP := Effect.TEXT_STAGGER_SECONDS
const MAX_PENDING := 3
var _clock := 0.0
var _next_beat := 0.0
var _scope_id := 0
var _pending: Array[Dictionary] = []
var beats := 0
var peak_pending := 0


func _scope(world: Node) -> void:
	if _scope_id == world.get_instance_id():
		return
	clear()
	_scope_id = world.get_instance_id()


func clear() -> void:
	for beat: Dictionary in _pending:
		for reference: WeakRef in beat["sources"]:
			var source: Effect = reference.get_ref()
			if is_instance_valid(source) and source.age < 0.0:
				source.queue_free()
	_pending.clear()
	_clock = 0.0
	_next_beat = 0.0
	_scope_id = 0


func confirm(game: Node, impact: Effect, tier: int, element: int, species: String) -> void:
	_scope(game.world)
	if impact.params.get("rhythm_scheduled", false):
		return
	impact.params["rhythm_scheduled"] = true
	if game.player.warp_locked:
		return
	var beat := {
		"due": _clock,
		"tier": tier,
		"element": element,
		"species": species,
		"followup": false,
		"sources": [weakref(impact)],
		"at": impact.params["camera_position"]
	}
	if _pending.is_empty() and _clock + 0.000001 >= _next_beat:
		_present(game, beat, true)
		_next_beat = _clock + STEP
		return
	if _pending.size() >= MAX_PENDING:
		var last: Dictionary = _pending.back()
		if last["sources"].size() >= Effect.COSMETIC_LIMIT:
			var oldest: WeakRef = last["sources"].pop_front()
			var retired: Effect = oldest.get_ref()
			if is_instance_valid(retired) and retired.age < 0.0:
				retired.queue_free()
		last["sources"].append(weakref(impact))
		if tier > int(last["tier"]):
			for key: String in ["tier", "element", "species", "at"]:
				last[key] = beat[key]
		impact.age = -maxf(0.0, float(last["due"]) - _clock)
		return
	var due := maxf(_clock, _next_beat)
	if not _pending.is_empty():
		due = maxf(due, float(_pending.back()["due"]) + STEP)
	beat["due"] = due
	beat["followup"] = true
	impact.age = -maxf(0.0, due - _clock)
	_pending.append(beat)
	peak_pending = maxi(peak_pending, _pending.size())


func tick(game: Node, delta: float) -> void:
	_scope(game.world)
	if game.get_tree().paused:
		return
	if game.player.warp_locked:
		clear()
		return
	_clock += maxf(0.0, delta)
	var ready: Array[Dictionary] = []
	while not _pending.is_empty() and float(_pending[0]["due"]) <= _clock + 0.000001:
		ready.append(_pending.pop_front())
	# 느린 프레임에 지난 소리를 한꺼번에 재생하지 않고 가장 강한 한 박자만 남긴다.
	var strongest := -1
	for index in ready.size():
		if _has_live_source(ready[index], game.world):
			if strongest < 0 or int(ready[index]["tier"]) > int(ready[strongest]["tier"]):
				strongest = index
	for index in ready.size():
		_present(game, ready[index], index == strongest)
	if not ready.is_empty():
		_next_beat = _clock + STEP
	for beat: Dictionary in _pending:
		for reference: WeakRef in beat["sources"]:
			var source: Effect = reference.get_ref()
			if (
				is_instance_valid(source)
				and not source.is_queued_for_deletion()
				and source.age < source.life
			):
				source.age = -maxf(0.0, float(beat["due"]) - _clock)


func _has_live_source(beat: Dictionary, world: Node) -> bool:
	for reference: WeakRef in beat["sources"]:
		var source: Effect = reference.get_ref()
		if (
			is_instance_valid(source)
			and not source.is_queued_for_deletion()
			and source.age < source.life
			and source.get_parent() == world
		):
			return true
	return false


func _present(game: Node, beat: Dictionary, sound: bool) -> void:
	var visible := _has_live_source(beat, game.world)
	for reference: WeakRef in beat["sources"]:
		var source: Effect = reference.get_ref()
		if (
			is_instance_valid(source)
			and not source.is_queued_for_deletion()
			and source.age < source.life
			and source.get_parent() == game.world
		):
			source.age = 0.0
	if not visible or not sound:
		return
	beats += 1
	SoundFx.play_hit(
		int(beat["tier"]), int(beat["element"]), str(beat["species"]), bool(beat["followup"])
	)
	game.combat_feedback(beat["at"], float([0.36, 0.55, 0.92, 1.0][int(beat["tier"])]))


func snapshot() -> Dictionary:
	var sources := 0
	for beat: Dictionary in _pending:
		sources += beat["sources"].size()
	return {
		"peak_pending": peak_pending,
		"pending": _pending.size(),
		"beats": beats,
		"max_pending": MAX_PENDING,
		"sources": sources
	}
