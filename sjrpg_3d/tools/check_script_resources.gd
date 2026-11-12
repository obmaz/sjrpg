extends SceneTree
## 에디터 임포트는 모든 GD 본문을 컴파일하지 않으므로 실행 검사 전에 따로 확인한다.
var _script_count := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _scan(path: String) -> void:
	if FileAccess.file_exists(path.path_join(".gdignore")):
		return
	for folder: String in DirAccess.get_directories_at(path):
		_scan(path.path_join(folder))
	for file: String in DirAccess.get_files_at(path):
		if not file.ends_with(".gd"):
			continue
		_script_count += 1
		var script: Script = load(path.path_join(file))
		if script == null or not script.can_instantiate():
			_failures += 1
			push_error("SCRIPT_RESOURCE_FAIL " + path.path_join(file))


func _run() -> void:
	for folder: String in ["res://scripts", "res://assets", "res://tests", "res://tools"]:
		_scan(folder)
	print("SCRIPT_RESOURCE_RESULT files=%d failures=%d" % [_script_count, _failures])
	quit(0 if _failures == 0 else 1)
