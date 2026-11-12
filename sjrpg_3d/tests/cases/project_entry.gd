extends TestCase
## 씬 경로가 유효해도 진입 스크립트의 preload 오류로 실행 불능이 될 수 있다.


func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check("production entry scene loads", scene != null)
	if scene == null:
		return
	var entry := scene.instantiate()
	check("production entry keeps its executable script", entry.get_script() != null)
	entry.free()
