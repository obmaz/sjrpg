class_name EditionNavigation
extends RefCounted
## A deliberate edition change navigates to a separate project and save domain.


static func open(edition: String) -> bool:
	if edition not in ["", "2d", "3d"]:
		return false
	# Do not leave on a failed save; the settings panel can surface the error.
	if not GameState.save_game():
		return false
	if OS.has_feature("web"):
		var tree := Engine.get_main_loop() as SceneTree
		var root := tree.current_scene
		var prepared := root != null and root.has_method("prepare_edition_exit")
		var accepted = JavaScriptBridge.eval("Boolean(window.__sjrpgNavigateEdition && window.__sjrpgNavigateEdition(" + JSON.stringify(edition) + "," + ("true" if prepared else "false") + "))", true)
		if bool(accepted) and prepared:
			root.call_deferred("prepare_edition_exit")
		return bool(accepted)
	else:
		OS.shell_open("https://obmaz.github.io/sjrpg/" + (edition + "/" if not edition.is_empty() else ""))
	return true
