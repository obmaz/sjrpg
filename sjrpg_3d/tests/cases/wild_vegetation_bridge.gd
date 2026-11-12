extends TestCase
## 새 식생의 실제 메시, 바닥 접점·수관 폭과 다리의 기존 통행 경계를 검사한다.
func _check_closed_surface(mesh: Mesh, label: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var volume := 0.0
	var wrong_normals := 0
	for i: int in range(0, vertices.size(), 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		volume += a.dot(b.cross(c)) / 6.0
		if (b - a).cross(c - a).dot(normals[i] + normals[i + 1] + normals[i + 2]) >= 0.0:
			wrong_normals += 1
	check("bridge detail has closed outward volume and clockwise normals: " + label, volume < 0.0 and wrong_normals == 0)

func run() -> void:
	var library := TreeGeometry3D.mesh_library()
	check("five distinct native tree silhouettes are actually available", library.size() == 5)
	for i: int in library.size():
		var mesh: Mesh = library[i]["mesh"]
		check("every tree is a rooted two-surface 3D mesh", mesh != null and mesh.get_surface_count() == 2 and absf(mesh.get_aabb().position.y) < 0.001 and mesh.get_aabb().size.z > 1.0)
		if i >= 2:
			var leaves := mesh.surface_get_material(1) as StandardMaterial3D
			check("new conifers use shared dark needle cutouts with real lighting", leaves == TreeGeometry3D._needle_material and leaves.albedo_texture.resource_path == WildVegetationRenderer3D.NEEDLES and leaves.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and leaves.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	var game := await make_game("mage")
	var before: Array = game.village.bridge.solids().duplicate(true)
	var environment: EnvironmentRenderer3D = game.world_renderer._world_environment
	var bridge := environment.forest.get_node("NativeDetailedBridge") as Node3D
	var report: Dictionary = bridge.get_meta("bridge_detail")
	check("detailed bridge preserves the actual playable deck and rail endpoints", report["deck"] == game.village.bridge.deck_polygon() and report["foundation_parts"] == 9 and before == game.village.bridge.solids())
	check("bridge has real arches, closed recess backing and a bounded material budget", report["arches"] >= 4 and report["solid_arcade_backing"] and report["triangles"] < 6000 and report["surfaces"] == 4)
	check("bridge does not mirror front faces or add hidden colliders", bridge.basis.determinant() > 0.0 and bridge.find_children("*", "CollisionObject3D", true, false).is_empty())
	for child: MeshInstance3D in bridge.find_children("*", "MeshInstance3D", true, false):
		_check_closed_surface(child.mesh, child.name)
	var world_shrubs: Array[Node] = environment.forest.find_children("NativeUnderbrush", "Node3D", true, false)
	var count := 0
	for node: Node in world_shrubs:
		var shrubs: Dictionary = node.get_meta("underbrush")
		count += int(shrubs["count"])
		check("underbrush reuses two non-billboard meshes without changing solids", shrubs["variants"] == 2 and shrubs["solid_changes"] == 0)
		for batch: MultiMeshInstance3D in node.get_children():
			check("shrub chunk contains all transformed volume", batch.multimesh.custom_aabb.size.y > 0.0 and batch.multimesh.mesh.get_surface_count() == 2)
	check("the real forest includes visible underbrush clumps", count >= 20)
	game.queue_free()
	await _frames(2)
