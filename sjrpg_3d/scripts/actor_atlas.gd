class_name ActorAtlas
extends RefCounted
## Sprite atlas ported from the Flutter `ActorAtlas` (lib/src/rendering/actor_atlas.dart).
## The JSON bounds files keep the original layout: frame rects, feet anchors and clips.

static var _cache: Dictionary = {}

var _texture: Texture2D
var _texture_path := ""
var _texture_attempted := false
## Explicit texture consumers still work; metadata acquisition alone never decodes a sheet.
var texture: Texture2D:
	get:
		if _texture == null and not _texture_attempted and not _texture_path.is_empty():
			_texture_attempted = true
			_texture = load(_texture_path) as Texture2D
		return _texture
	set(value):
		_texture = value
		_texture_attempted = true
var regions: Array[Rect2] = []
var anchors: Array[Vector2] = []
var ref_height := 1.0
## "motion" (16-dir idle + run), "action" (16-dir one-shot) or "walk" (8-dir walk + attack).
var kind := ""
var directions := 16
var frames_per_direction := 8
var run_offset := 16
var idle_offset := 0
var phase_major := true
var attack_offset := -1
var attack_frames := 0


static func get_atlas(name: String) -> ActorAtlas:
	if _cache.has(name):
		return _cache[name]
	var atlas := ActorAtlas.new()
	atlas._load(name)
	_cache[name] = atlas
	return atlas


## No texture getter here: profiling must not itself force an upload.
func is_texture_loaded() -> bool:
	return _texture != null


static func texture_snapshot() -> Dictionary:
	var atlases: Array[Dictionary] = []
	var loaded := 0
	var rgba8_base_estimate := 0
	for name: String in _cache:
		var atlas: ActorAtlas = _cache[name]
		var size := Vector2i.ZERO
		if atlas._texture != null:
			size = Vector2i(atlas._texture.get_size())
			loaded += 1
			rgba8_base_estimate += size.x * size.y * 4
		atlases.append({"name": name, "texture_loaded": atlas.is_texture_loaded(),
			"dimensions": [size.x, size.y], "frames": atlas.regions.size()})
	return {"metadata_atlases": _cache.size(), "loaded_textures": loaded,
		"rgba8_base_bytes_estimate": rgba8_base_estimate, "atlases": atlases}


func _load(name: String) -> void:
	var base := "res://assets/art/actors/" + name
	for ext in [".webp", ".png"]:
		if ResourceLoader.exists(base + ext):
			_texture_path = base + ext
			break
	var file := FileAccess.open(base + ".json", FileAccess.READ)
	if file == null:
		push_error("Missing atlas data: " + base)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var feet: Array = data.get("feet", [])
	var raw_frames: Array = data["frames"]
	for i in raw_frames.size():
		var r: Array = raw_frames[i]
		var rect := Rect2(r[0], r[1], r[2], r[3])
		regions.append(rect)
		if i < feet.size():
			anchors.append(Vector2(feet[i][0], feet[i][1]) - rect.position)
		else:
			anchors.append(Vector2(rect.size.x / 2.0, rect.size.y))
	ref_height = float(data["sizes"][0][1])
	if data.has("motion"):
		var m: Dictionary = data["motion"]
		kind = "motion"
		directions = int(m["directions"])
		frames_per_direction = int(m["runFrames"])
		run_offset = int(m["runOffset"])
		idle_offset = int(m["idleOffset"])
		phase_major = m["layout"] == "phase-major"
	elif data.has("action"):
		var a: Dictionary = data["action"]
		kind = "action"
		directions = int(a["directions"])
		frames_per_direction = int(a["frames"])
		phase_major = a["layout"] == "phase-major"
	elif data.has("walk"):
		var w: Dictionary = data["walk"]
		kind = "walk"
		directions = int(w["directions"])
		frames_per_direction = int(w["frames"])
		phase_major = false
		if data.has("enemyAttack"):
			attack_offset = int(data["enemyAttack"]["offset"])
			attack_frames = int(data["enemyAttack"]["frames"])


## Same mapping as `facingFrame` in world_model.dart: index 0 faces the viewer (down).
static func facing(angle: float, count: int) -> int:
	return posmod(roundi((angle - PI / 2.0) * count / TAU), count)


func _index(direction: int, phase: int, offset: int) -> int:
	if phase_major:
		return offset + phase * directions + direction
	return offset + direction * frames_per_direction + phase


func idle_frame(angle: float) -> int:
	return idle_offset + facing(angle, directions)


func run_frame(angle: float, phase: int) -> int:
	return _index(facing(angle, directions), posmod(phase, frames_per_direction), run_offset)


func action_frame(angle: float, progress: float) -> int:
	var phase := clampi(floori(clampf(progress, 0.0, 1.0) * frames_per_direction), 0, frames_per_direction - 1)
	return _index(facing(angle, directions), phase, 0)


func walk_frame(angle: float, cycle: float) -> int:
	var phase := floori(fposmod(cycle, 1.0) * frames_per_direction)
	return facing(angle, 8) * frames_per_direction + phase


func attack_frame(angle: float, progress: float) -> int:
	if attack_offset < 0:
		return walk_frame(angle, progress)
	var phase := clampi(floori(clampf(progress, 0.0, 1.0) * attack_frames), 0, attack_frames - 1)
	return attack_offset + facing(angle, 8) * attack_frames + phase
