class_name DungeonPanel
extends PanelFrame

var game: Node

func setup(g: Node) -> DungeonPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	set_header("바람 동굴", "선택 탐험 · 숲 의뢰와 독립")
	if game.dungeon.active:
		body.add_child(PanelFrame.wrap_label(game.dungeon.objective(), 22, UiKit.GOLD))
		body.add_child(PanelFrame.wrap_label("모든 적을 처치하고 마지막 귀환문에서 완료하면 추가 골드를 받습니다. 중도 퇴장해도 이미 획득한 보상은 유지됩니다.", 21))
		if game.dungeon.at_exit() and game.dungeon.defeated >= game.dungeon.total:
			add_footer("탐험 완료", func():
				closed.emit()
				game.dungeon.complete(), true)
		else:
			add_footer("돌아가기", func(): closed.emit(), true)
		var leave_button := UiKit.button("동굴에서 나가기", 21)
		leave_button.custom_minimum_size = Vector2(0, 76)
		leave_button.pressed.connect(func():
			closed.emit()
			game.dungeon.leave("동굴 입구로 돌아왔습니다"))
		body.add_child(leave_button)
		return
	body.add_child(PanelFrame.wrap_label("5분 동안 다섯 전투 구역과 두 갈림길을 탐험합니다. 적 레벨은 입장할 때 내 레벨+2로 고정됩니다. 모든 적을 처치하고 마지막 귀환문에 도착하면 추가 골드를 받습니다.", 22))
	body.add_child(PanelFrame.wrap_label("사망·시간 종료·퇴장·재접속 시 입구 밖으로 돌아오며 획득한 장비·경험치·골드는 유지됩니다. 일시정지 중에는 시간이 멈춥니다.", 20))
	var reason: String = game.dungeon.enter_block_reason()
	if reason != "":
		body.add_child(PanelFrame.wrap_label(reason, 20, UiKit.GOLD))
	add_footer("나중에", func(): closed.emit())
	var enter_button := add_footer("동굴 입장", func():
		closed.emit()
		game.dungeon.enter(), true)
	enter_button.disabled = reason != ""
