class_name GameTempo
extends RefCounted
## Action tempo only: UI, quest/stone clocks, status durations and Engine.time_scale stay real-time.
const RATE := 1.5

static func speed(base: float) -> float:
	return base * RATE

static func duration(base: float) -> float:
	return base / RATE


## Real actor-local contact stop. Cooldowns/status clocks tick before consume(); projectiles/UI keep running.
class ContactStop:
	extends RefCounted
	var remaining := 0.0
	var recovery := 0.0
	var _requested := 0.0

	## 호출자가 강타·처치 상한을 지정한다. 기본값은 일반 접촉의55ms다.
	func trigger(seconds: float, limit := 0.055) -> void:
		if Prefs.reduce_motion:
			return
		var requested := clampf(seconds, 0.0, limit)
		if remaining > 0.0:
			# 가장 강한 확인 타격까지만 승격한다. 같은 세기의 연타는 연장하지 않는다.
			remaining += maxf(0.0, requested - _requested)
			_requested = maxf(_requested, requested)
			return
		if recovery > 0.0:
			return
		remaining = requested
		_requested = requested
		recovery = 0.14

	func consume(delta: float) -> float:
		recovery = maxf(0.0, recovery - delta)
		if Prefs.reduce_motion:
			remaining = 0.0
		var withheld := minf(delta, remaining)
		remaining = maxf(0.0, remaining - withheld)
		return maxf(0.0, delta - withheld)

	func clear() -> void:
		_requested = 0.0
		remaining = 0.0
		recovery = 0.0
