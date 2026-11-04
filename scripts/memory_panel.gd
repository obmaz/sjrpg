class_name MemoryPanel
extends PanelFrame
## 숲의 기억 (원본 stageMemories): 서쪽·북쪽·동쪽 길의 상자에서 얻는 이야기. 셋을 모으면 스킬 포인트 +1.

const MEMORIES := [
	{"title": "끊어진 맹세", "hint": "서쪽 숲길의 상자", "story": "파수꾼은 한때 숲의 뿌리를 지키던 수호자였다. 마을의 종이 멎은 밤, 그가 지키던 맹세도 함께 깨졌다."},
	{"title": "마지막 종소리", "hint": "마을 북쪽 길의 상자", "story": "옛 기록에는 숲보다 오래된 모래시계의 유적이 나온다. 파수꾼이 잠든 뒤 유적의 시간도 깨지기 시작했다."},
	{"title": "물 아래의 문", "hint": "동쪽 목교 앞 숲길의 상자", "story": "수면 아래 수정에서 낯선 푸른 신호가 흐른다. 아직 세워지지 않은 도시가 도움을 청하고 있다. 유적의 균열은 과거와 미래를 함께 가리킨다."},
]
const FIRST_CHEST := 5

var index := 0


func setup(i: int) -> MemoryPanel:
	index = i
	return self


static func recovered() -> int:
	var n := 0
	for i in MEMORIES.size():
		if GameState.opened_chests.has(FIRST_CHEST + i):
			n += 1
	return n


func _ready() -> void:
	super._ready()
	var m: Dictionary = MEMORIES[index]
	set_header("숲의 기억", "기억 %d / %d" % [recovered(), MEMORIES.size()])
	body.add_child(PanelFrame.section(m["title"]))
	body.add_child(PanelFrame.wrap_label(m["story"], 22, Color(0.95, 0.93, 0.85)))
	if GameState.memory_rewarded:
		body.add_child(PanelFrame.wrap_label("세 기억을 모두 모았습니다 · 스킬 포인트 +1", 20, Color(1, 0.88, 0.5)))
	add_footer("닫기", func(): closed.emit(), true)
