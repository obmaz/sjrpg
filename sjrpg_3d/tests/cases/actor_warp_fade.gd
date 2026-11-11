extends TestCase
## 표준/ORM/사용자 셰이더와 장비 교체를 실제 메시 인스턴스로 검증한다.


func run() -> void:
	var actor := Node3D.new()
	add_child(actor)
	var first := MeshInstance3D.new()
	first.mesh = BoxMesh.new()
	var standard := StandardMaterial3D.new()
	standard.albedo_color = Color(.3, .4, .5, .8)
	first.material_override = standard
	var overlay := StandardMaterial3D.new()
	first.material_overlay = overlay
	actor.add_child(first)
	var second := MeshInstance3D.new()
	var box := BoxMesh.new()
	var orm := ORMMaterial3D.new()
	box.material = orm
	second.mesh = box
	actor.add_child(second)
	var fade := ActorWarpFade.new()
	fade.prepare(actor)
	fade.sync(actor, true, .25)
	check(
		"standard and ORM materials share the same opacity contract",
		(
			fade.smooth_fade
			and fade.slots.size() == 2
			and is_equal_approx((first.material_override as BaseMaterial3D).albedo_color.a, .2)
			and is_equal_approx(
				(second.get_surface_override_material(0) as BaseMaterial3D).albedo_color.a, .25
			)
		)
	)
	fade.sync(actor, false, 1)
	check(
		"finish restores overrides, overlays and shadows exactly",
		(
			first.material_override == standard
			and first.material_overlay == overlay
			and first.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and second.get_surface_override_material(0) == null
			and actor.visible
		)
	)
	var replacement := StandardMaterial3D.new()
	replacement.albedo_color = Color(.8, .2, .1, .6)
	first.material_override = replacement
	fade.sync(actor, true, .5)
	check(
		"a later equipment material is captured at the next departure",
		is_equal_approx((first.material_override as BaseMaterial3D).albedo_color.a, .3)
	)
	fade.sync(actor, false, 1)
	check("completion preserves newly equipped materials", first.material_override == replacement)
	var custom := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(0.3, 0.4, 0.5); }"
	custom.shader = shader
	second.material_override = custom
	fade.sync(actor, true, .2)
	check(
		"unsupported shaders hide the whole actor without touching any surface",
		(
			not fade.smooth_fade
			and not actor.visible
			and first.material_override == replacement
			and second.material_override == custom
		)
	)
	fade.sync(actor, true, .8)
	check("arrival reveals all custom-shader parts together", actor.visible)
	fade.sync(actor, true, 0)
	fade.sync(actor, false, 1)
	check(
		"cancellation restores custom materials and visibility",
		actor.visible and second.material_override == custom and first.material_overlay == overlay
	)
	second.material_override = null
	box.material = null
	fade.sync(actor, true, 0)
	check("default materials also use a safe whole-actor fallback", not actor.visible)
	fade.sync(actor, false, 1)
	actor.visible = false
	fade.sync(actor, true, .8)
	fade.sync(actor, false, 1)
	check("a previously hidden actor stays hidden after cancellation", not actor.visible)
	actor.queue_free()
	await _frames(2)
