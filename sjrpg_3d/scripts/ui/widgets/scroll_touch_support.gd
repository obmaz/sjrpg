class_name ScrollTouchSupport
extends RefCounted
## 버튼의 입력은 유지하면서 부모 ScrollContainer가 드래그/휠을 받을 수 있게 한다.
## 슬라이더·스크롤바와 패널 바깥 버튼의 입력 소유권은 변경하지 않는다.


static func prepare_button(node: Node, panel: Control) -> void:
	if not node is Control or not panel.is_ancestor_of(node):
		return
	var button := node as BaseButton
	var cursor := node.get_parent()
	while button == null and cursor != null and cursor != panel:
		if cursor is Range or cursor is ScrollContainer:
			return
		if cursor is BaseButton:
			button = cursor as BaseButton
		cursor = cursor.get_parent()
	if button == null:
		return
	var ancestors: Array[Control] = [button]
	var parent := button.get_parent()
	while parent != null and parent != panel:
		if parent is Range:
			return
		if parent is ScrollContainer:
			# 장식용 자식이 버튼보다 먼저 터치를 가로채는 경우도 같은 전달 경계를 쓴다.
			_prepare_decoration(button)
			for control: Control in ancestors:
				if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					control.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		if parent is Control:
			ancestors.append(parent as Control)
		parent = parent.get_parent()


static func _prepare_decoration(button: Node) -> void:
	for child: Node in button.get_children():
		# 중첩된 실제 입력과 독립 스크롤의 소유권은 그대로 둔다.
		if child is BaseButton or child is Range or child is ScrollContainer:
			continue
		if child is Control and child.mouse_filter == Control.MOUSE_FILTER_STOP:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_prepare_decoration(child)
