class_name PlayerActionBuffer
extends RefCounted
## 종료 직전의 단발 입력 하나만 보존한다. 판정·쿨다운을 앞당기지 않는다.
const WINDOW := 0.10
var slot := -1
var skill := ""
var age := 0.0


func offer(index: int, id: String, ready_in: float) -> void:
	# 너무 이른 새 입력도 이전 의도를 취소한다. 오래된 명령이 나중에 나가지 않는다.
	clear()
	if ready_in > 0.0 and ready_in <= WINDOW:
		slot = index
		skill = id


func advance(delta: float) -> void:
	if slot < 0:
		return
	age += maxf(0.0, delta)
	# 입력 창은100ms다. 창 안의 준비 완료를 다음 렌더 프레임에서 처리하는 오차만 허용한다.
	if age > WINDOW + minf(maxf(delta, 0.0), 1.0 / 30.0) + 0.00001:
		clear()


func clear() -> void:
	slot = -1
	skill = ""
	age = 0.0
