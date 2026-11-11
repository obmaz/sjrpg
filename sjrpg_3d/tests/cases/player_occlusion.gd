extends TestCase


func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var fade := preview._occlusion
	var foot := preview.actor_foot(game.player)
	check(
		"loading prepares shared geometry and transparency variants",
		fade.triangle_builds > 0 and not fade._templates.is_empty()
	)
	var fixture := Node3D.new()
	preview.stage.add_child(fixture)
	var object := Node3D.new()
	NativePlayerOcclusion.mark_object(object)
	fixture.add_child(object)
	object.global_position = foot + preview.camera.global_basis.z * 4.0
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 3.5, 2.5)
	var original := StandardMaterial3D.new()
	original.albedo_color = Color("786b54")
	var wall := MeshInstance3D.new()
	wall.mesh = box
	wall.material_override = original
	object.add_child(wall)
	var moving := Node3D.new()
	moving.set_meta("occlusion_dynamic", true)
	object.add_child(moving)
	var door := MeshInstance3D.new()
	door.mesh = box
	door.material_override = original
	moving.add_child(door)
	var custom := ShaderMaterial.new()
	custom.shader = load("res://assets/models/environment/cave_entrance/surface.gdshader")
	var roof := MeshInstance3D.new()
	roof.mesh = box
	roof.material_override = custom
	object.add_child(roof)
	roof.position = preview.camera.global_basis.x * 15.0
	# 같은 등록 컨테이너의 실제 몬스터도 정적 모델로 표시하지 않으면 제외된다.
	var monster: Node3D = NativeEnemyModels.build(NativeEnemyModels.KINDS[0])["root"]
	fixture.add_child(monster)
	monster.global_position = object.global_position
	var monster_materials := {}
	for part: MeshInstance3D in monster.find_children("*", "MeshInstance3D", true, false):
		monster_materials[part] = part.material_override
	var hollow := MeshInstance3D.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		tool.append_from(
			box, 0, Transform3D(Basis.IDENTITY, preview.camera.global_basis.x * side * 5.0)
		)
	hollow.mesh = tool.commit()
	hollow.material_override = original
	NativePlayerOcclusion.mark_object(hollow)
	fixture.add_child(hollow)
	hollow.global_position = object.global_position
	fade._register(fixture)
	fade.sync(0.1)
	check(
		"sightline queries inspect nearby cells instead of the whole expanded map",
		fade.query_candidates < fade._entries.size() / 3
	)
	check(
		"all parts share intermediate opacity even when only one part occludes",
		(
			is_equal_approx(wall.material_override.albedo_color.a, 0.55)
			and is_equal_approx(
				roof.material_override.get_shader_parameter("occlusion_opacity"), 0.55
			)
		)
	)
	fade.sync(0.1)
	check(
		"entire static object fades while shared originals stay intact",
		(
			wall.material_override != original
			and original.albedo_color.a == 1.0
			and is_equal_approx(wall.material_override.albedo_color.a, 0.2)
			and is_equal_approx(
				roof.material_override.get_shader_parameter("occlusion_opacity"), 0.2
			)
		)
	)
	var monsters_unchanged := true
	for part: MeshInstance3D in monster_materials:
		monsters_unchanged = (
			monsters_unchanged and part.material_override == monster_materials[part]
		)
	check(
		"empty space inside a merged model bounds does not trigger transparency",
		hollow.material_override == original
	)
	check(
		"monsters intersecting the same sightline are never faded",
		not monster_materials.is_empty() and monsters_unchanged
	)
	check("moving parts under a static model remain opaque", door.material_override == original)
	check("world ground is not a fade object", not fade._entries.any(_is_world_ground))
	check(
		"custom surface has uniform alpha without aperture or dithering",
		(
			not "hero_view" in roof.material_override.shader.code
			and not "discard;" in roof.material_override.shader.code
			and "ALPHA = 1.0 * occlusion_opacity" in roof.material_override.shader.code
		)
	)
	var wall_ink: Material = wall.material_override
	var builds := fade.material_builds
	var triangles := fade.triangle_builds
	object.global_position += preview.camera.global_basis.x * 20.0
	fade.sync(0.25)
	check(
		"leaving cover restores every original material together",
		wall.material_override == original and roof.material_override == custom
	)
	object.global_position = foot + preview.camera.global_basis.z * 4.0
	fade.sync(0.25)
	check(
		"returning behind the same object reuses its exact materials and BVH",
		(
			wall.material_override == wall_ink
			and fade.material_builds == builds
			and fade.triangle_builds == triangles
		)
	)
	object.global_position = foot - preview.camera.global_basis.z * 4.0
	fade.sync(0.25)
	check(
		"objects behind the hero stay opaque",
		wall.material_override == original and roof.material_override == custom
	)
	# 서로 다른 원본 부품이 재질별로 묶인 뒤에도 오브젝트 소속을 보존한다.
	var batched := Node3D.new()
	NativePlayerOcclusion.mark_object(batched)
	fixture.add_child(batched)
	batched.global_position = foot + preview.camera.global_basis.z * 4.0
	for index in 2:
		var part := MeshInstance3D.new()
		part.mesh = box
		part.material_override = original
		part.position = preview.camera.global_basis.x * float(index) * 15.0
		batched.add_child(part)
	var report := Ortho3DStaticBatch.apply(batched)
	fade._register(batched)
	fade.sync(0.1)
	var batch: MultiMeshInstance3D = report["batches"].values()[0]
	check(
		"batching preserves whole-object membership and equal opacity",
		(
			batch.get_child_count() == 2
			and batch.multimesh.instance_count == 2
			and batch.material_override == original
			and batch.get_children().all(_has_transition_opacity)
		)
	)
	fade.sync(0.0)
	check(
		"pause holds the whole object at one opacity",
		batch.get_children().all(_has_transition_opacity)
	)
	var draws := batch.get_children()
	var instances := fade.instance_builds
	builds = fade.material_builds
	batched.global_position += preview.camera.global_basis.x * 20.0
	fade.sync(0.25)
	check(
		"uncovered batch restores the original slot and parks cached draws",
		(
			draws.all(_is_hidden)
			and batch.multimesh.get_instance_transform(0).basis.determinant() > 0.1
		)
	)
	batched.global_position -= preview.camera.global_basis.x * 20.0
	fade.sync(0.1)
	check(
		"repeated batch cover creates no new draw nodes or materials",
		(
			batch.get_children() == draws
			and fade.instance_builds == instances
			and fade.material_builds == builds
			and draws.all(_is_visible)
		)
	)
	var wall_key := "%s:-1" % wall.get_instance_id()
	fixture.queue_free()
	await _frames(4)
	fade.sync(0.25)
	check("removed models leave no stale fade", not fade._active.has(wall_key))
	game.queue_free()
	await _frames(2)


static func _is_world_ground(entry: Dictionary) -> bool:
	return is_instance_valid(entry["node"]) and entry["node"].name == "NativeNaturalGround"


static func _has_transition_opacity(part: MeshInstance3D) -> bool:
	return is_equal_approx(part.material_override.albedo_color.a, 0.55)


static func _is_hidden(part: MeshInstance3D) -> bool:
	return not part.visible


static func _is_visible(part: MeshInstance3D) -> bool:
	return part.visible
