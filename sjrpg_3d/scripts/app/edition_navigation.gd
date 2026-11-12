class_name EditionNavigation
extends RefCounted
## Return to the root chooser after a durable web save; this project stays3D.


static func open(edition: String) -> bool:
	if not edition.is_empty() or not OS.has_feature("web"):
		return false
	# Do not leave on a failed save; the settings panel can surface the error.
	if not GameState.save_game():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.current_scene
	var prepared := root != null and root.has_method("prepare_edition_exit")
	var accepted = JavaScriptBridge.eval("Boolean(window.__sjrpgNavigateEdition && window.__sjrpgNavigateEdition(\"\"," + ("true" if prepared else "false") + "))", true)
	if bool(accepted) and prepared:
		root.call_deferred("prepare_edition_exit")
	return bool(accepted)
