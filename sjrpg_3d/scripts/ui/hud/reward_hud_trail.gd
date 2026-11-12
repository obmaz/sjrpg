class_name RewardHudTrail
extends Control
## 이미 지급된 보상만 HUD에 연결한다. 애니메이션 완료가 지급·저장을 호출하지 않는다.
const LIMIT := 8
const DURATION := 0.62
const GLINT_REGION := Rect2(122, 108, 28, 28)
const ATLAS := preload("res://assets/effects/textures/reward-atlas.webp")
const COLORS := {"gold": Color("f0ce79"), "xp": Color("b5dfea"), "gear": Color("d4b4e9")}
const PRIORITY := {"xp": 0, "gold": 1, "gear": 2}
var game: Node
var flights: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var confirmed := 0
var arrived := 0
var _scope := false


func _ready() -> void:
	name = "ConfirmedRewardTrails"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)


func destination(kind: String) -> Vector2:
	if kind == "xp":
		var bar: Rect2 = game.hud.status_geometry()["xp"]
		return bar.get_center()
	var button: Dictionary = game.hud.controls._buttons.get("bar_bag", {})
	return button.get("center", get_viewport_rect().size * Vector2(0.4, 0.9))


func offer(kind: String, ground: Vector2) -> void:
	if not COLORS.has(kind) or game.player.dead or game.player.warp_locked or game.hud.panel_open():
		return
	var renderer := game.world_renderer as WorldRenderer3D
	if renderer == null or not is_instance_valid(renderer.camera):
		return
	var native := WorldSpace3D.projected_to_world(ground, renderer.surface_height(ground) + 0.65)
	var screen := (
		renderer.display.position
		+ (
			renderer.camera.unproject_position(native)
			* renderer.display.size
			/ Vector2(renderer.viewport.size)
		)
	)
	if not get_viewport_rect().grow(24.0).has_point(screen):
		return
	if _scope != game.dungeon.active:
		clear()
	_scope = game.dungeon.active
	confirmed += 1
	if Prefs.reduce_motion:
		_add_pulse(kind)
		set_process(true)
		return
	# 같은 상자의 금화·장비는 보상 묶음 하나로 합친다. 밀집 처치도 한도를 넘지 않는다.
	for entry: Dictionary in flights:
		if float(entry["age"]) <= 0.08 and ground.distance_to(entry["ground"]) < 32.0:
			if int(PRIORITY[kind]) > int(PRIORITY[entry["kind"]]):
				entry["kind"] = kind
			return
	if flights.size() >= LIMIT:
		return
	flights.append(
		{
			"kind": kind,
			"ground": ground,
			"start": screen / get_viewport_rect().size,
			"age": 0.0,
			"scope": game.dungeon.active
		}
	)
	set_process(true)
	queue_redraw()


func clear() -> void:
	flights.clear()
	pulses.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if (
		game.player.dead
		or game.player.warp_locked
		or game.hud.panel_open()
		or _scope != game.dungeon.active
	):
		clear()
		return
	# 먼저 기존 펄스를 진행시켜 느린 도착 프레임에도 새 펄스가 한 번은 보이게 한다.
	for index in range(pulses.size() - 1, -1, -1):
		pulses[index]["age"] += delta
		if float(pulses[index]["age"]) >= 0.20:
			pulses.remove_at(index)
	for index in range(flights.size() - 1, -1, -1):
		var entry: Dictionary = flights[index]
		if bool(entry["scope"]) != game.dungeon.active or Prefs.reduce_motion:
			if Prefs.reduce_motion:
				_add_pulse(entry["kind"])
			flights.remove_at(index)
			continue
		entry["age"] += delta
		if float(entry["age"]) >= DURATION:
			_add_pulse(entry["kind"])
			arrived += 1
			if entry["kind"] != "xp":
				game.hud.controls._feedback["bar_bag"] = 0.20
			flights.remove_at(index)
	set_process(not flights.is_empty() or not pulses.is_empty())
	queue_redraw()


func _add_pulse(kind: String) -> void:
	# 줄인 동작은 이동 없이 도착점에서 부드럽게 한 번만 밝아진다.
	for pulse: Dictionary in pulses:
		if pulse["kind"] == kind:
			return
	if pulses.size() < 3:
		pulses.append({"kind": kind, "age": 0.0})


func _draw() -> void:
	var view := get_viewport_rect().size
	for entry: Dictionary in flights:
		var t := clampf(float(entry["age"]) / DURATION, 0.0, 1.0)
		var start: Vector2 = entry["start"] * view
		var end := destination(entry["kind"])
		var at := start.lerp(end, smoothstep(0.08, 1.0, t))
		at.y -= sin(t * PI) * minf(75.0, start.distance_to(end) * 0.16)
		var color: Color = COLORS[entry["kind"]]
		color.a = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.88, 1.0, t))
		var size: float = 30.0 * lerpf(1.0, 0.78, t) * game.hud.unit()
		draw_texture_rect_region(
			ATLAS, Rect2(at - Vector2.ONE * size * 0.5, Vector2.ONE * size), GLINT_REGION, color
		)
	for pulse: Dictionary in pulses:
		var size: float = 28.0 * game.hud.unit()
		var color: Color = COLORS[pulse["kind"]]
		color.a = 0.65 * (1.0 - float(pulse["age"]) / 0.20)
		draw_texture_rect_region(
			ATLAS,
			Rect2(destination(pulse["kind"]) - Vector2.ONE * size * 0.5, Vector2.ONE * size),
			GLINT_REGION,
			color
		)
