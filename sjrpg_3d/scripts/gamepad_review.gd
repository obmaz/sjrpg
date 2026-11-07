class_name GamepadReview
extends Node
## Explicit virtual-controller review only. Saves are isolated; gameplay is observed, never driven here.
const PREFIX := "user://tests/gamepad-review"
var _root: Node
var _original_path := ""
var _original_slot := 1
var _original_settings := ""
var _ready_ok := false
var _error := ""
var _elapsed := 0.0
var _actions: Dictionary = {}


func setup(root: Node) -> GamepadReview:
	_root = root
	return self


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_path = GameState.slot_path(1)
	_original_slot = GameState.active_slot
	DirAccess.make_dir_recursive_absolute("user://tests")
	GameState.save_path = PREFIX + "-%d.json" % Time.get_ticks_usec()
	_original_settings = Prefs.settings_path
	Prefs.settings_path = PREFIX + "-settings-%d.cfg" % Time.get_ticks_usec()
	_ready_ok = prepare()
	if not _ready_ok:
		_error = "Cannot prepare isolated controller save: " + GameState.save_error
	var pad: Node = get_node_or_null("/root/Gamepad")
	if pad != null and pad.has_signal("action_pressed"):
		pad.connect("action_pressed", _observe_action)
	_publish()


## Prepared progression supplies legal spells; every tested action still enters through real joypad input.
static func prepare() -> bool:
	if not GameState.slot_path(1).begins_with(PREFIX):
		return false
	if not GameState.create_slot(1, "mage"):
		return false
	GameState.level = 12
	GameState.ranks = {"firebolt": 1, "sorceressAttack": 1, "chargedBolt": 1, "staticField": 1, "frostNova": 1, "fireball": 1, "nova": 1, "lightning": 1}
	GameState.slots = ["firebolt", "fireball", "frostNova", "nova", "lightning"]
	GameState.skill_points = maxi(0, GameState.points_for_level(GameState.level) - GameState.invested_points())
	return GameState.save_game()


func _exit_tree() -> void:
	if not _original_settings.is_empty():
		Prefs.settings_path = _original_settings
	if not _original_path.is_empty():
		GameState.save_path = _original_path
		GameState.select_slot(_original_slot)


func _observe_action(action: String) -> void:
	_actions[action] = int(_actions.get(action, 0)) + 1


func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_elapsed += delta
	if _elapsed >= 0.10:
		_elapsed = 0.0
		_publish()


static func _file_hashes() -> Dictionary:
	var files: Dictionary = {}
	if not GameState.slot_path(1).begins_with(PREFIX):
		return files
	for number: int in range(1, 5):
		var hashes: Dictionary = {}
		for suffix: String in GameState.SAVE_SUFFIXES:
			var path: String = GameState.slot_path(number) + suffix
			hashes[suffix] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		files[str(number)] = hashes
	return files


static func _rect(control: Control) -> Array:
	var box: Rect2 = control.get_global_rect()
	return [box.position.x, box.position.y, box.size.x, box.size.y]


func _publish() -> void:
	if not is_instance_valid(_root):
		return
	var report: Dictionary = {"ready": _ready_ok, "error": _error, "actions": _actions.duplicate(), "file_hashes": _file_hashes(), "preferences": {"music": Prefs.music_enabled, "sound": Prefs.sound_enabled, "world_zoom": Prefs.world_zoom}, "slot": GameState.active_slot, "class": GameState.hero_class, "level": GameState.level, "slots": GameState.slots.duplicate(), "potions": GameState.potions, "mana_potions": GameState.mana_potions, "paused": get_tree().paused, "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]}
	var pad: Node = get_node_or_null("/root/Gamepad")
	if pad != null and pad.has_method("review_snapshot"):
		report["pad"] = pad.call("review_snapshot")
	var nav: Node = pad.get_node_or_null("Navigation") if pad != null else null
	if nav != null and nav.has_method("review_snapshot"):
		report["navigation"] = nav.call("review_snapshot")
	var focus: Control = get_viewport().gui_get_focus_owner()
	report["focus"] = {"path": str(focus.get_path()), "rect": _rect(focus), "text": str(focus.get("text")) if focus is Button or focus is Label else ""} if is_instance_valid(focus) else {}
	var current: Node = _root.get("current")
	report["screen"] = "adventure" if current is NativeAdventure else "selection" if is_instance_valid(current) and current.has_method("refresh_slots") else "title"
	if current is NativeAdventure:
		var game: Node = current.simulation
		if is_instance_valid(game) and is_instance_valid(game.player):
			var player: Player = game.player
			report["native_ready"] = game.native_ready
			report["player"] = {"position": [player.position.x, player.position.y], "facing": player.facing, "move": [player.move_input.x, player.move_input.y], "target": player.has_move_target, "held": player.held_slots.duplicate(), "serial": player._action_serial, "attack_time": player._attack_time, "roll_time": player._roll_time, "roll_cooldown": player._roll_cooldown, "cooldowns": player.cooldowns.duplicate(), "hp": player.hp, "max_hp": player.max_hp, "resource": player.resource, "resource_max": player.resource_max, "dead": player.dead}
			report["near"] = game.near_npc()
			var panel: PanelFrame = game.hud._panel
			if is_instance_valid(panel):
				var targets: Array = []
				for child: Node in panel.find_children("*", "BaseButton", true, false):
					var button: BaseButton = child as BaseButton
					if button.is_visible_in_tree():
						targets.append({"text": (button as Button).text if button is Button else "", "rect": _rect(button), "disabled": button.disabled, "focus": button.has_focus(), "key": button.get_meta("gamepad_key", "")})
				report["panel"] = {"script": panel.get_script().resource_path, "title": panel.title_label.text, "rect": _rect(panel._panel), "buttons": targets, "scroll": panel.scroll.scroll_vertical, "scroll_max": maxf(0.0, panel.scroll.get_v_scroll_bar().max_value - panel.scroll.get_v_scroll_bar().page)}
				if panel is SkillTreePanel:
					report["panel"]["selected"] = panel._selected
					report["panel"]["scroll"] = panel._tree_scroll.scroll_vertical
				if panel is BagPanel:
					report["panel"]["shopping"] = panel.shopping
			else:
				report["panel"] = {}
	JavaScriptBridge.eval("window.__sjrpgGamepadReview = " + JSON.stringify(report), true)
