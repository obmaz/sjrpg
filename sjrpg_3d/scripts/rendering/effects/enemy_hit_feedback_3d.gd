class_name EnemyHitFeedback3D
extends RefCounted
## 실제 적 상태에서 체력·공격 준비·우두머리 범위를 입체 공간에 표시한다.
## 체력/공격 준비는 같은 쿼드를 공유하고 우두머리는 원래 지면 예고를 유지한다.
const BAR_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, fog_disabled;
uniform vec2 health_ratios = vec2(1.0);
uniform float bar_width = 56.0;
uniform bool preparing = false;
void fragment() {
	vec2 pixel = UV * vec2(bar_width + 2.0, 8.0);
	ALBEDO = vec3(0.0);
	ALPHA = 0.7;
	if (pixel.x >= 1.0 && pixel.x <= bar_width + 1.0 && pixel.y >= 1.0 && pixel.y <= 7.0) {
		float x = pixel.x - 1.0;
		if (x < bar_width * health_ratios.y) {
			ALBEDO = vec3(1.0, 0.86, 0.72);
			ALPHA = 0.9;
		}
		if (x < bar_width * health_ratios.x) {
			ALBEDO = preparing ? vec3(1.0, 0.70, 0.20) : vec3(0.85, 0.2, 0.18);
			ALPHA = 1.0;
		}
	}
}
"""
const RING_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;
uniform float progress = 0.0;
uniform float edge_width = 0.02;
void fragment() {
	float distance_from_center = length(UV * 2.0 - vec2(1.0));
	if (distance_from_center > 1.0) {
		discard;
	}
	bool edge = distance_from_center >= 1.0 - edge_width;
	ALBEDO = edge ? vec3(1.0, 0.35, 0.2) : vec3(1.0, 0.2, 0.1);
	ALPHA = edge ? 0.9 : 0.12 + 0.2 * progress;
}
"""
const RING_LIFT := 0.018
const PREPARATION_WIDTH := 32.0
const PREPARATION_HEIGHT := 5.0
const PREPARATION_LIFT := 24.0
static var _bar_mesh: QuadMesh
static var _ring_mesh: ArrayMesh
static var _bar_shader: Shader
static var _ring_shader: Shader
var _renderer: Node
var entries := {}


func setup(presenter: Node) -> EnemyHitFeedback3D:
	_renderer = presenter
	if _bar_mesh == null:
		_bar_mesh = QuadMesh.new()
		_bar_mesh.size = Vector2.ONE
		_bar_shader = Shader.new()
		_bar_shader.code = BAR_CODE
		_ring_shader = Shader.new()
		_ring_shader.code = RING_CODE
		_ring_mesh = _ground_quad()
	return self


static func _ground_quad() -> ArrayMesh:
	# The original boss hit test is a screen ellipse (y/0.55), not a native XZ circle.
	# Map that exact ellipse to the actual horizontal plane; the shader clips its disk.
	var vertices := PackedVector3Array()
	for point: Vector2 in [
		Vector2(-1, -0.55), Vector2(1, -0.55), Vector2(1, 0.55), Vector2(-1, 0.55)
	]:
		vertices.append(WorldRenderer3D.ground_position(point))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(
		[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _new_entry(enemy: Enemy) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeEnemyFeedback"
	_renderer.stage.add_child(root)
	return {
		"root": root,
		"owner": weakref(enemy),
		"bar": null,
		"ring": null,
		"preparation": null,
		"preparation_progress": -1.0,
		"ratios": Vector2(-1, -1),
		"width": -1.0,
		"progress": -1.0,
		"radius": -1.0,
		"foot": Vector3.ZERO
	}


func _mesh(parent: Node3D, mesh: Mesh, shader: Shader) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = shader
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result


func sync() -> void:
	var current := {}
	for candidate in _renderer.game.enemies:
		var enemy := candidate as Enemy
		if (
			not is_instance_valid(enemy)
			or enemy.is_queued_for_deletion()
			or enemy.dead
			or enemy.get_parent() != _renderer.game.world
		):
			continue
		var id := enemy.get_instance_id()
		current[id] = true
		var bar_visible := enemy.visible and enemy.sprite.visible and enemy.hp < enemy.max_hp
		var ring_visible := (
			enemy.visible and enemy.sprite.visible and enemy.is_boss and enemy._state == "windup"
		)
		var preparing := (
			enemy.visible
			and enemy.sprite.visible
			and not enemy.is_boss
			and enemy._state == "windup"
		)
		if not entries.has(id):
			if not bar_visible and not ring_visible and not preparing:
				continue
			entries[id] = _new_entry(enemy)
		var entry: Dictionary = entries[id]
		var bar: MeshInstance3D = entry["bar"]
		var ring: MeshInstance3D = entry["ring"]
		var preparation: MeshInstance3D = entry["preparation"]
		if bar != null:
			bar.visible = bar_visible
		if ring != null:
			ring.visible = ring_visible
		if preparation != null:
			preparation.visible = preparing
		if not bar_visible and not ring_visible and not preparing:
			continue
		var foot: Vector3 = _renderer.actor_foot(enemy)
		entry["foot"] = foot
		if preparing:
			_sync_preparation(entry, enemy, foot)
		if bar_visible:
			if bar == null:
				bar = _mesh(entry["root"], _bar_mesh, _bar_shader)
				bar.name = "Health"
				(bar.material_override as ShaderMaterial).render_priority = 10
				entry["bar"] = bar
			var ratio := clampf(enemy.hp / maxf(enemy.max_hp, 0.0001), 0.0, 1.0)
			var ghost := (
				ratio
				if Prefs.reduce_motion
				else clampf(maxf(enemy.ghost_hp, enemy.hp) / maxf(enemy.max_hp, 0.0001), 0.0, 1.0)
			)
			var ratios := Vector2(ratio, ghost)
			var ink := bar.material_override as ShaderMaterial
			if entry["ratios"] != ratios:
				ink.set_shader_parameter("health_ratios", ratios)
				entry["ratios"] = ratios
			var width := 120.0 if enemy.is_boss else 56.0
			if float(entry["width"]) != width:
				ink.set_shader_parameter("bar_width", width)
				entry["width"] = width
			var factor := WorldRenderer3D.GROUND_PER_METER * WorldRenderer3D.PROJECTION_FACTOR
			var basis: Basis = _renderer.camera.global_transform.basis
			# Original eight-pixel background spans [-body_height-15, -body_height-7].
			var anchor := _billboard_anchor(enemy, foot, 11.0, factor)
			bar.global_transform = Transform3D(
				Basis(basis.x * ((width + 2.0) / factor), basis.y * (8.0 / factor), basis.z), anchor
			)
			bar.show()
		if ring_visible:
			if ring == null:
				ring = _mesh(entry["root"], _ring_mesh, _ring_shader)
				ring.name = "BossWindup"
				entry["ring"] = ring
			var progress := clampf(
				1.0 - enemy._timer / maxf(enemy._windup_duration, 0.0001), 0.0, 1.0
			)
			var radius := enemy.attack_range + 60.0
			var ink := ring.material_override as ShaderMaterial
			if not is_equal_approx(float(entry["progress"]), progress):
				ink.set_shader_parameter("progress", progress)
				entry["progress"] = progress
			if float(entry["radius"]) != radius:
				ink.set_shader_parameter("edge_width", minf(1.0, 4.0 / maxf(radius, 0.0001)))
				entry["radius"] = radius
			ring.transform = Transform3D(
				Basis.IDENTITY.scaled(Vector3(radius, 1.0, radius)), foot + Vector3.UP * RING_LIFT
			)
			ring.show()
	for id in entries.keys():
		if not current.has(id):
			(entries[id]["root"] as Node3D).queue_free()
			entries.erase(id)


## 공격 타이머만 읽는다. 별도 준비 시계·판정·광원/텍스처를 추가하지 않는다.
func _sync_preparation(entry: Dictionary, enemy: Enemy, foot: Vector3) -> void:
	var bar: MeshInstance3D = entry["preparation"]
	if bar == null:
		bar = _mesh(entry["root"], _bar_mesh, _bar_shader)
		bar.name = "AttackPreparation"
		var ink := bar.material_override as ShaderMaterial
		ink.render_priority = 10
		ink.set_shader_parameter("preparing", true)
		ink.set_shader_parameter("bar_width", PREPARATION_WIDTH)
		entry["preparation"] = bar
	var progress := clampf(1.0 - enemy._timer / maxf(enemy._windup_duration, .0001), 0.0, 1.0)
	if not is_equal_approx(float(entry["preparation_progress"]), progress):
		(bar.material_override as ShaderMaterial).set_shader_parameter(
			"health_ratios", Vector2(progress, progress)
		)
		entry["preparation_progress"] = progress
	var factor := WorldRenderer3D.GROUND_PER_METER * WorldRenderer3D.PROJECTION_FACTOR
	var basis: Basis = _renderer.camera.global_basis
	var at := _billboard_anchor(enemy, foot, PREPARATION_LIFT, factor)
	bar.global_transform = Transform3D(
		Basis(
			basis.x * ((PREPARATION_WIDTH + 2) / factor),
			basis.y * (PREPARATION_HEIGHT / factor),
			basis.z
		),
		at
	)
	bar.show()


## 도약은 실제 GLB 뼈를 따라간다. 발이 보이는 적의 머리가 위로 나가면 두 게이지를 쌓아 보존한다.
func _billboard_anchor(enemy: Enemy, foot: Vector3, lift: float, factor: float) -> Vector3:
	var camera: Camera3D = _renderer.camera
	var at := foot + camera.global_basis.y * ((enemy.sprite.body_height + lift) / factor)
	if _renderer.has_method("enemy_pose_lift"):
		at.y += float(_renderer.enemy_pose_lift(enemy))
	var view := camera.get_viewport().get_visible_rect().size
	if (
		camera.is_position_behind(foot)
		or not Rect2(Vector2.ZERO, view).has_point(camera.unproject_position(foot))
	):
		return at
	var point := camera.unproject_position(at)
	var margin := (
		2.0
		+ (
			(PREPARATION_HEIGHT * .5 + PREPARATION_LIFT - lift)
			/ factor
			* view.y
			/ maxf(.001, camera.size)
		)
	)
	if point.y < margin:
		point.y = margin
		var depth := -(camera.global_transform.affine_inverse() * at).z
		at = camera.project_position(point, depth)
	return at


func snapshot() -> Dictionary:
	var bars := 0
	var rings := 0
	var preparations := 0
	var sources := []
	for id in entries:
		var entry: Dictionary = entries[id]
		var bar: MeshInstance3D = entry["bar"]
		var ring: MeshInstance3D = entry["ring"]
		var visible_bar := bar != null and bar.visible
		var visible_ring := ring != null and ring.visible
		var preparation: MeshInstance3D = entry["preparation"]
		var preparing := preparation != null and preparation.visible
		bars += 1 if visible_bar else 0
		rings += 1 if visible_ring else 0
		preparations += 1 if preparing else 0
		if visible_bar or visible_ring or preparing:
			var foot: Vector3 = entry["foot"]
			var ratios: Vector2 = entry["ratios"]
			sources.append(
				{
					"id": id,
					"health": visible_bar,
					"telegraph": visible_ring,
					"preparing": preparing,
					"ratio": ratios.x,
					"ghost": ratios.y,
					"progress": entry["preparation_progress"] if preparing else entry["progress"],
					"radius": entry["radius"],
					"foot": [foot.x, foot.y, foot.z]
				}
			)
	return {
		"entries": entries.size(),
		"bars": bars,
		"telegraphs": rings,
		"preparations": preparations,
		"sources": sources
	}
