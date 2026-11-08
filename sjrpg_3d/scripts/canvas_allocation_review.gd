extends Node
## Worker-only attribution, active for exactly20 actual process frames.
## CanvasItem.draw precedes its scripted _draw in Godot4.7.2.
## Connections hold WeakRef owners and are removed once the bounded sample ends.

const FRAME_LIMIT := 20
var _started := -1
var _clear_pending := false
var _connections: Array[Dictionary] = []


func _ready() -> void:
	set_process(OS.has_feature("web"))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgCanvasAllocationProbe={status:'waiting',process_frames:0}")


func _process(_delta: float) -> void:
	if _started < 0:
		if not bool(JavaScriptBridge.eval("window.__sjrpgCanvasAllocationStart===true")):
			return
		_started = Engine.get_process_frames()
		get_tree().node_added.connect(_observe)
		_walk(get_tree().root)
		JavaScriptBridge.eval("window.__sjrpgCanvasAllocationProbe={status:'collecting',process_frames:0}")
	elif Engine.get_process_frames() - _started >= FRAME_LIMIT:
		_stop()


func _walk(node: Node) -> void:
	_observe(node)
	for child: Node in node.get_children():
		_walk(child)


func _observe(node: Node) -> void:
	if not node is CanvasItem:
		return
	var script: Script = node.get_script()
	if script == null:
		# Bare controls such as Hud._bars draw through a scripted signal receiver.
		for connection: Dictionary in node.get_signal_connection_list("draw"):
			var listener: Callable = connection["callable"]
			var receiver: Object = listener.get_object()
			if is_instance_valid(receiver):
				script = receiver.get_script()
				if script != null:
					break
	if script == null:
		return
	var item: CanvasItem = node as CanvasItem
	var command: String = "window.__sjrpgCanvasDrawOwner=" + JSON.stringify({"script": script.resource_path, "name": str(item.name), "path": str(item.get_path())}) + ";window.__sjrpgCanvasDrawMark?.(window.__sjrpgCanvasDrawOwner)"
	var callback: Callable = _mark_owner.bind(command)
	# Bare controls render in existing draw-signal receivers rather than _draw.
	# Put the marker first, preserving the original receiver order and flags.
	# Removing only our marker later leaves the original ordering unchanged.
	var listeners: Array[Dictionary] = item.get_signal_connection_list("draw")
	for listener: Dictionary in listeners:
		item.draw.disconnect(listener["callable"])
	item.draw.connect(callback)
	for listener: Dictionary in listeners:
		item.draw.connect(listener["callable"], int(listener["flags"]))
	_connections.append({"owner": weakref(item), "callback": callback})


func _mark_owner(command: String) -> void:
	JavaScriptBridge.eval(command)
	if not _clear_pending:
		_clear_pending = true
		_clear_owner.call_deferred()


func _clear_owner() -> void:
	_clear_pending = false
	JavaScriptBridge.eval("window.__sjrpgCanvasDrawOwner=null")


func _stop() -> void:
	set_process(false)
	if get_tree().node_added.is_connected(_observe):
		get_tree().node_added.disconnect(_observe)
	for connection: Dictionary in _connections:
		var item: CanvasItem = connection["owner"].get_ref()
		var callback: Callable = connection["callback"]
		if is_instance_valid(item) and item.draw.is_connected(callback):
			item.draw.disconnect(callback)
	_connections.clear()
	_clear_owner()
	JavaScriptBridge.eval("window.__sjrpgCanvasAllocationProbe={status:'complete',process_frames:" + str(Engine.get_process_frames() - _started) + "}")
