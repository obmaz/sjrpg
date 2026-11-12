class_name ScrollTouchSupport
extends RefCounted
## 버튼의 입력은 유지하면서 부모 ScrollContainer가 드래그/휠을 받을 수 있게 한다.
## 슬라이더·스크롤바와 패널 바깥 버튼의 입력 소유권은 변경하지 않는다.


static func prepare_button(node: Node, panel: Control) -> void:
	if not node is BaseButton or not panel.is_ancestor_of(node):
		return
	var ancestors: Array[Control] = [node as Control]
	var parent := node.get_parent()
	while parent != null and parent != panel:
		if parent is Range:
			return
		if parent is ScrollContainer:
			for control: Control in ancestors:
				if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					control.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		if parent is Control:
			ancestors.append(parent as Control)
		parent = parent.get_parent()
