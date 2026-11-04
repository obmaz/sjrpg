class_name SaveStore
extends RefCounted
## Write to a temporary file first. Keep the previous readable primary as a backup.

static func read(path: String, valid: Callable) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var data := _read_one(candidate)
		if not data.is_empty() and valid.call(data):
			return {"data": data, "backup": candidate != path}
	return {}


static func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


static func write(path: String, data: Dictionary, valid: Callable) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	var primary := _read_one(path)
	if not primary.is_empty() and valid.call(primary):
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK:
			return error
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temporary, path)
