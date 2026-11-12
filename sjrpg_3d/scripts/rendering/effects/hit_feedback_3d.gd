class_name HitFeedback3D
extends RefCounted
## 실제 명중만 관찰한다. 모든 파편은 공유 메시·재질과 최대12개 재사용 묶음이다.
const MAX_BURSTS := 12
const SPARKS := 8
const SPARK_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
 ALBEDO = COLOR.rgb;
 ALPHA = COLOR.a * pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 1.4) * smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.60, 1.0, UV.y));
}
"""
const FOCUS_CODE := """
shader_type canvas_item;
uniform float pulse = 0.0;
uniform vec2 focus = vec2(0.5);
uniform float aspect = 1.0;
uniform bool chromatic = false;
void fragment() {
 vec4 ink = texture(TEXTURE, UV);
 if (pulse > 0.001) {
  vec2 radial = (UV - focus) * vec2(aspect, 1.0);
  float edge = smoothstep(0.12, 0.72, length(radial));
  if (chromatic) {
   vec2 shift = (UV - focus) * pulse * 0.002;
   ink.r = texture(TEXTURE, UV + shift).r;
   ink.b = texture(TEXTURE, UV - shift).b;
  }
  float grey = dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722));
  ink.rgb = mix(ink.rgb, vec3(grey), edge * pulse * 0.20) * (1.0 - edge * pulse * 0.12);
 }
 COLOR = ink;
}
"""
var renderer: WorldRenderer3D
var entries := {}
var _seen := {}
var _pool: Array[MultiMeshInstance3D] = []
var _spark_ink: ShaderMaterial
var _focus_ink: ShaderMaterial
var _quad: QuadMesh
var _pulse_left := 0.0
var _pulse_duration := 0.13
var _pulse_tier := HitTier.LIGHT
var _pulse_at := Vector3.ZERO
var _realm := false
var builds := 0
var _pause_for_review := false

func setup(presenter: WorldRenderer3D) -> HitFeedback3D:
	renderer = presenter
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_spark_ink = ShaderMaterial.new()
	_spark_ink.shader = Shader.new()
	_spark_ink.shader.code = SPARK_CODE
	_focus_ink = ShaderMaterial.new()
	_focus_ink.shader = Shader.new()
	_focus_ink.shader.code = FOCUS_CODE
	renderer.display.material = _focus_ink
	_realm = renderer.game.dungeon.active
	if OS.has_feature("web") and renderer._probe_enabled:
		_pause_for_review = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('hitfeel_preview') === 'peak'"))
	return self

func _new_burst() -> MultiMeshInstance3D:
	if not _pool.is_empty():
		return _pool.pop_back()
	builds += 1
	var node := MultiMeshInstance3D.new()
	node.name = "ConfirmedHitStreaks"
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = _quad
	mesh.instance_count = SPARKS
	node.multimesh = mesh
	node.material_override = _spark_ink
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer.stage.add_child(node)
	return node

func _retire(id: int) -> void:
	var node: MultiMeshInstance3D = entries[id]["node"]
	node.hide()
	_pool.append(node)
	entries.erase(id)

func sync(delta: float) -> void:
	if _realm != renderer.game.dungeon.active:
		for id: int in entries.keys():
			_retire(id)
		_seen.clear()
		_pulse_left = 0.0
		_realm = renderer.game.dungeon.active
	_pulse_left = maxf(0.0, _pulse_left - delta)
	var current := {}
	var hits: Array[Effect] = Effect.in_world(renderer.game.world)
	var view := renderer.source_view_rect()
	for source: Effect in hits:
		if source.kind != "impact" or not source.params.has("contact_position") or source.is_queued_for_deletion() or source.age >= source.life:
			continue
		if not view.has_point(source.position):
			continue
		var id := source.get_instance_id()
		current[id] = true
		var at: Vector3 = source.params["contact_position"]
		var tier: int = source.params.get("tier", HitTier.LIGHT)
		if not _seen.has(id):
			_seen[id] = weakref(source)
			if tier >= HitTier.HEAVY and not Prefs.reduce_motion and at.distance_to(renderer.actor_foot(renderer.game.player)) < 10.0:
				# 같은 프레임의 약한 명중이 강한 마무리의 초점을 빼앗지 않는다.
				if _pulse_left <= 0.0 or tier >= _pulse_tier:
					_pulse_tier = tier
					_pulse_duration = 0.15 if tier == HitTier.KILL else 0.11
					_pulse_left = _pulse_duration
					_pulse_at = at
		if Prefs.reduce_motion:
			continue
		if not entries.has(id):
			if entries.size() >= MAX_BURSTS or source.age > 0.12:
				continue
			entries[id] = {"node": _new_burst(), "source": weakref(source)}
		_update(entries[id]["node"], source, at, tier)
	for id: int in entries.keys():
		if not current.has(id) or Prefs.reduce_motion:
			_retire(id)
	for id in _seen.keys():
		if _seen[id].get_ref() == null:
			_seen.erase(id)
	if Prefs.reduce_motion:
		_pulse_left = 0.0
	var pulse := pow(_pulse_left / _pulse_duration, 2.0)
	_focus_ink.set_shader_parameter("pulse", pulse)
	_focus_ink.set_shader_parameter("focus", renderer.camera.unproject_position(_pulse_at) / Vector2(renderer.viewport.size))
	_focus_ink.set_shader_parameter("aspect", float(renderer.viewport.size.x) / maxf(1.0, renderer.viewport.size.y))
	_focus_ink.set_shader_parameter("chromatic", not Prefs.low_resolution and not Prefs.reduce_motion)
	if _pause_for_review and _pulse_left > 0.0 and not entries.is_empty():
		# 실제 배우 자세·명중 효과가 적용된 뒤의 프레임만 검수용으로 정지한다.
		_pause_for_review = false
		renderer.get_tree().paused = true
		JavaScriptBridge.eval("window.__sjrpgHitFeelReview = {actual_hit:true, paused:true}")

func _update(node: MultiMeshInstance3D, source: Effect, at: Vector3, tier: int) -> void:
	var forward := WorldSpace3D.projected_to_world(Vector2.from_angle(source.angle)).normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var view := renderer.camera.global_basis.z
	var colors := [Color(1.0, 0.87, 0.63), Color(1.0, 0.34, 0.08), Color(0.70, 0.62, 1.0), Color(0.50, 0.84, 1.0)]
	var ink: Color = colors[int(source.params.get("cell", 0))]
	var count := 4 if tier == HitTier.LIGHT else (6 if tier == HitTier.MEDIUM else SPARKS)
	var life := minf(source.life, 0.21 if tier < HitTier.HEAVY else 0.27)
	var t := maxf(0.008, source.age)
	var fade := pow(clampf(1.0 - t / life, 0.0, 1.0), 1.5)
	node.multimesh.visible_instance_count = count
	node.position = at
	for index in count:
		# 고정된 방향 분산은 재생·일시정지·느린 프레임에서 흔들리지 않는다.
		var spread := lerpf(-1.12, 1.12, float(index) / maxf(1.0, count - 1))
		# 접촉면 바깥으로 튀어 몸통 깊이에 가려지거나 내부에서 시작하지 않는다.
		var travel := (-forward * cos(spread) + side * sin(spread) + Vector3.UP * (0.25 + float(index % 3) * 0.23)).normalized()
		var speed := (2.0 + float(index % 4) * 0.45) * (1.15 if tier >= HitTier.HEAVY else 1.0)
		var projected := travel - view * travel.dot(view)
		var y := projected.normalized() if projected.length_squared() > 0.001 else renderer.camera.global_basis.y
		var x := y.cross(view).normalized()
		var length := (0.13 + float(index % 3) * 0.04) * (1.0 - 0.45 * t / life)
		var position := travel * speed * t + Vector3.DOWN * 2.8 * t * t
		var frame := Transform3D(Basis(x * 0.035, y * maxf(0.02, length), view), position - y * length * 0.25)
		node.multimesh.set_instance_transform(index, frame)
		node.multimesh.set_instance_color(index, Color(ink, fade * 0.85))
	node.visible = fade > 0.001

func snapshot() -> Dictionary:
	return {"bursts": entries.size(), "pool": _pool.size(), "builds": builds, "pulse": _pulse_left / _pulse_duration, "sparks_limit": MAX_BURSTS * SPARKS}
