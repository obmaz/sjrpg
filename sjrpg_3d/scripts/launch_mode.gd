class_name LaunchMode
extends RefCounted
## The dedicated entry remains3D even when a browser drops its query string.


static func preview_3d(pathname: String, query: String) -> bool:
	if pathname.get_file() == "3d.html":
		return true
	for part in query.trim_prefix("?").split("&"):
		var pair := part.split("=", true, 1)
		if pair.size() == 2 and pair[0].uri_decode() == "preview3d" and pair[1].uri_decode() == "1":
			return true
	return false


static func web_preview_3d() -> bool:
	# This is an independent native project, including desktop editor execution.
	return true
