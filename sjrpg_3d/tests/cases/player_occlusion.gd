extends TestCase

func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var fade := preview._occlusion
	var foot := preview.actor_foot(game.player)
	var fixture := Node3D.new()
	preview.stage.add_child(fixture)
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 3.5, 2.5)
	var original := StandardMaterial3D.new()
	original.albedo_color = Color("786b54")
	var wall := MeshInstance3D.new()
	wall.mesh = box
	wall.material_override = original
	fixture.add_child(wall)
	wall.global_position = foot + preview.camera.global_basis.z * 4.0
	fade._register(fixture)
	fade.sync(0.25)
	check("foreground geometry fades while shared source material stays opaque", wall.material_override != original and is_equal_approx(original.albedo_color.a, 1.0) and wall.material_override.albedo_color.a <= 0.21)
	check("fade keeps mesh and collision authority intact", wall.mesh == box and wall.find_children("*", "CollisionObject3D", true, false).is_empty())
	wall.global_position += preview.camera.global_basis.x * 15.0
	fade.sync(0.25)
	check("moving out of cover restores exact original material", wall.material_override == original)
	wall.global_position = foot - preview.camera.global_basis.z * 4.0
	fade.sync(0.25)
	check("geometry behind the hero never fades", wall.material_override == original)
	var custom := ShaderMaterial.new()
	custom.shader = load("res://assets/models/environment/cave_entrance/surface.gdshader")
	var inks: Array[Material] = []
	var adapted := fade._ink(custom, inks) as ShaderMaterial
	check("large cave and relief use a depth-limited local aperture", adapted != custom and "hero_view.z + 0.20" in adapted.shader.code and "smoothstep(0.65, 1.0" in adapted.shader.code and not "occlusion_opacity" in custom.shader.code)
	var second := fade._ink(custom, inks) as ShaderMaterial
	check("independent fade materials share one compiled shader and keep opaque depth ordering", adapted != second and adapted.shader == second.shader and not "ALPHA =" in adapted.shader.code and "discard;" in adapted.shader.code)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = 2
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi
	batch.material_override = original
	fixture.add_child(batch)
	var selected := Transform3D(Basis.IDENTITY, Vector3(2, 0, 0))
	var state := fade._activate({"node": batch, "index": 0, "transform": selected})
	check("one batched object gets an independent fade without changing shared mesh or material", state["draw"].mesh == multi.mesh and state["draw"].transform == selected and batch.material_override == original and multi.instance_count == 2 and batch.get_child_count() == 1)
	fade._restore(state)
	check("leaving a batched occluder retires its temporary draw", state["draw"].is_queued_for_deletion())
	wall.global_position = foot + preview.camera.global_basis.z * 4.0
	fade.sync(0.1)
	var before: float = wall.material_override.albedo_color.a
	fade.sync(0.0)
	check("paused presentation freezes opacity", is_equal_approx(before, wall.material_override.albedo_color.a))
	var wall_key := "%s:-1" % wall.get_instance_id()
	fixture.queue_free()
	await _frames(2)
	fade.sync(0.25)
	check("removed scenery leaves no stale active fade", not fade._active.has(wall_key))
	game.queue_free()
	await _frames(2)
