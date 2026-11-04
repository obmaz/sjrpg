class_name BossPanel
extends PanelFrame

var game: Node

func setup(g: Node) -> BossPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	set_header("파수꾼의 공터", "제1장 · 숲의 마지막 도전")
	body.add_child(PanelFrame.wrap_label("세 의뢰 덕분에 봉인이 열렸습니다. 파수꾼의 붉은 공격 예고를 피하며 싸우세요. 쓰러지거나 공터에서 멀어지면 처음부터 다시 도전할 수 있습니다.", 22))
	body.add_child(PanelFrame.wrap_label("최초 처치 보상 · 파수꾼의 심장(고유 부적) · 제1장 완료", 20, UiKit.GOLD))
	add_footer("나중에", func(): closed.emit())
	add_footer("파수꾼에게 도전", func():
		closed.emit()
		game.quest_runtime.start_boss(), true)
