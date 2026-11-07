class_name NativeStyleReview
extends Node
## Read-only inspection of the actual native scene; enabled only by explicit URL.
var _root: Node
var _elapsed := 0.0
var _callback: JavaScriptObject
var _gallery: Control
func setup(root: Node) -> NativeStyleReview:
	_root = root
	return self
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_callback = JavaScriptBridge.create_callback(_action)
		var window := JavaScriptBridge.get_interface("window")
		window.__sjrpgNativeStyleAction = _callback
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.25 or not OS.has_feature("web"):
		return
	_elapsed = 0.0
	if not is_instance_valid(_root) or not (_root.current is NativeAdventure):
		return
	var game: Node = _root.current.simulation
	if not is_instance_valid(game) or not is_instance_valid(game.hud):
		return
	var hud: Hud = game.hud
	var buttons := {}
	for key: String in hud.controls._buttons:
		var b: Dictionary = hud.controls._buttons[key]
		var center: Vector2 = b["center"]
		var radius: float = b["radius"]
		var half: Vector2 = b.get("half_size", Vector2.ONE * radius)
		buttons[key] = [center.x - half.x, center.y - half.y, half.x * 2.0, half.y * 2.0]
	var geometry: Dictionary = hud.status_geometry()
	var portrait: Vector2 = geometry["portrait"]
	var radius: float = geometry["radius"]
	var panel := {}
	if is_instance_valid(hud._panel):
		var p: PanelFrame = hud._panel
		var targets := []
		for child in p.find_children("*", "Button", true, false):
			var button := child as Button
			if button.is_visible_in_tree():
				targets.append({"text": button.text, "rect": rect(button), "disabled": button.disabled, "in_body": p.body.is_ancestor_of(button), "world_zoom": button.get_meta("world_zoom", -1.0)})
		panel = {"rect": rect(p._panel), "title": rect(p.title_label), "subtitle": rect(p.subtitle_label), "body": rect(p.body_holder), "body_clip": rect(p.scroll), "subtitle_text": p.subtitle_label.text, "subtitle_visible": p.subtitle_label.is_visible_in_tree(), "buttons": targets, "type": p.get_script().resource_path}
		if p is SkillTreePanel:
			var nodes := []
			for id: String in p._nodes:
				var box: Rect2 = p._nodes[id]
				box.position += p._tree.global_position
				nodes.append({"id": id, "rect": [box.position.x, box.position.y, box.size.x, box.size.y], "hit_rect": rect_value(box.grow(8.0)), "rank": GameState.rank(id), "reason": GameState.learn_block_reason(GameState.skill(id))})
			panel["nodes"] = nodes
			panel["tree_clip"] = rect(p._tree_scroll)
			panel["selected"] = p._selected
	var coverage := {}
	var preview: Node = game.ortho_preview
	if is_instance_valid(preview):
		coverage["environment"] = preview._world_environment.report if is_instance_valid(preview._world_environment) else {}
		var retained := []
		for entry: Dictionary in preview._cards.values():
			var source: Node = entry["owner"].get_ref()
			if not is_instance_valid(source) or source is Effect:
				continue
			var foot: Vector2 = source.position
			retained.append({"id": source.get_instance_id(), "name": source.name, "type": source.get_script().resource_path, "foot": [foot.x, foot.y]})
		coverage["actor_cards"] = retained
		for property: Dictionary in preview.get_property_list():
			var key: String = property["name"]
			if key.begins_with("_native_") or key.begins_with("_resident") or key.begins_with("_enemy"):
				var renderer: Variant = preview.get(key)
				if renderer is Object and is_instance_valid(renderer):
					if renderer.has_method("review_snapshot"):
						coverage[key] = renderer.review_snapshot()
					elif renderer.has_method("snapshot"):
						coverage[key] = renderer.snapshot()
	var view := hud.controls.get_viewport_rect().size
	var report := {"viewport": [view.x, view.y], "frame": Engine.get_process_frames(), "class": GameState.hero_class, "buttons": buttons, "avatar": [portrait.x-radius, portrait.y-radius, radius*2.0, radius*2.0], "hp": rect_value(geometry["hp"]), "mp": rect_value(geometry["mp"]), "level_badge": rect_value(geometry["level_badge"]), "level": GameState.level, "panel": panel, "paused": get_tree().paused, "native": game.native_ready, "coverage": coverage, "player": [game.player.position.x, game.player.position.y], "potions": [GameState.potions, GameState.mana_potions], "zoom": game.camera.zoom.x, "world_zoom": Prefs.world_zoom}
	report["gallery_available"] = ResourceLoader.exists("res://scripts/native_model_gallery.gd")
	if is_instance_valid(_gallery) and _gallery.visible:
		report["gallery"] = _gallery.review_snapshot()
	JavaScriptBridge.eval("window.__sjrpgNativeStyleReview = " + JSON.stringify(report), true)
static func rect(control: Control) -> Array:
	return rect_value(control.get_global_rect())
static func rect_value(box: Rect2) -> Array:
	return [box.position.x, box.position.y, box.size.x, box.size.y]

func _action(arguments: Array) -> void:
	if arguments.size() != 2 or str(arguments[0]) != "gallery":
		return
	var face := int(arguments[1])
	if face < 0:
		if is_instance_valid(_gallery):
			_gallery.hide()
		return
	if face > 3 or not ResourceLoader.exists("res://scripts/native_model_gallery.gd") or not (_root.current is NativeAdventure):
		return
	if not is_instance_valid(_gallery):
		var source: Script = load("res://scripts/native_model_gallery.gd")
		_gallery = source.new().setup(_root.current.simulation)
		add_child(_gallery)
	_gallery.show()
	_gallery.set_face(face)
