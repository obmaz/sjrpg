extends TestCase
## 공용 계산/트리 탐색의 경계: 높이를 지면 좌표에 섞거나 소유자 없는 노드를 누락하지 않는다.


func run() -> void:
	for ground: Vector2 in [Vector2.ZERO, Vector2(92, -180), Vector2(-3400, 7850)]:
		for elevation_m: float in [-3.2, 0.0, 2.85]:
			var world := WorldSpace3D.projected_to_world(ground, elevation_m)
			check("ground projection round trips independently of elevation", WorldSpace3D.world_to_projected(world).distance_to(ground) < 0.002 and is_equal_approx(world.y, elevation_m))
			var raised := ground - Vector2(0, elevation_m * WorldSpace3D.VERTICAL_PIXELS_PER_METER)
			check("elevated effect projection returns the same foot and height", WorldSpace3D.elevated_projected_to_world(raised, elevation_m).distance_to(world) < 0.0001)
	var origin := WorldSpace3D.projected_to_world(Iso.project(Vector2.ZERO))
	var one_metre := WorldSpace3D.projected_to_world(Iso.project(Vector2(65, 0)))
	check("authored ground units retain a one metre physical step", is_equal_approx(origin.distance_to(one_metre), 1.0))
	check("camera zoom scales presentation without changing world units", is_equal_approx(WorldSpace3D.pixels_per_meter(2.0), WorldSpace3D.pixels_per_meter(1.0) * 2.0))
	var root := MeshInstance3D.new()
	var branch := Node3D.new()
	var mesh := MeshInstance3D.new()
	var animator := AnimationPlayer.new()
	var skeleton := Skeleton3D.new()
	root.add_child(branch)
	branch.add_child(mesh)
	mesh.add_child(animator)
	branch.add_child(skeleton)
	check("mesh traversal includes root and unowned descendants in depth order", ModelTree3D.meshes_including_root(root) == [root, mesh])
	check("animation search finds nested imported players", ModelTree3D.first_animation_player(root) == animator)
	check("skeleton search handles optional roots and nested skeletons", ModelTree3D.first_skeleton(null) == null and ModelTree3D.first_skeleton(root) == skeleton)
	root.scene_file_path = "res://assets/models/heroes/mage/visual.tscn"
	branch.scene_file_path = "res://assets/models/heroes/warrior/visual.tscn"
	mesh.scene_file_path = root.scene_file_path
	check("scene diagnostics retain unique nested scene paths and include root", ModelTree3D.scene_paths(root) == [branch.scene_file_path, root.scene_file_path])
	root.free()
	check("headless UI scaling is independent of window size", is_equal_approx(UiMetrics.units_per_display_pixel(get_viewport()), 1.0))
