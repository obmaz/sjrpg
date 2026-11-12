class_name WildVegetationRenderer3D
extends RefCounted
## 고정된 입체 가지와 곡면 바늘잎. 원래 나무의 충돌은 그대로 유지한다.
const NEEDLES := "res://assets/materials/shared/needle_sprays.webp"
const SHRUB_PATHS := ["res://assets/models/vegetation/juniper/visual.tscn", "res://assets/models/vegetation/thorn_bramble/visual.tscn"]
static var _shrubs: Array[Mesh] = []

static func build_shrubs(renderer: Node, parent: Node3D, trees: Array) -> Node3D:
	if _shrubs.is_empty():
		TreeGeometry3D.mesh_library()
		for path: String in SHRUB_PATHS:
			var id := path.trim_prefix("res://assets/models/").trim_suffix("/visual.tscn")
			var mesh := ModelSceneLibrary.mesh(id, "Body").duplicate() as Mesh
			mesh.surface_set_material(0, TreeGeometry3D._bark_material)
			mesh.surface_set_material(1, TreeGeometry3D._needle_material)
			_shrubs.append(mesh)
	var root := Node3D.new()
	root.name = "NativeUnderbrush"
	parent.add_child(root)
	var buckets := {}
	var count := 0
	for index: int in trees.size():
		if index % 4 != 0:
			continue
		var tree := trees[index] as IsoSprite
		var point := tree.global_position
		var radius := ForestTreeRenderer3D._collision_radius(tree, renderer.game.village.circles)
		if radius <= 0.0:
			continue
		var seed := ForestTreeRenderer3D.placement_seed(ForestTreeRenderer3D.source_key(tree))
		var variant := seed % _shrubs.size()
		var at := WorldSpace3D.projected_to_world(point, renderer.surface_height(point))
		var chunk := Vector2i(floori(at.x / 24.0), floori(at.z / 24.0))
		var key := "%d,%d:%d" % [chunk.x, chunk.y, variant]
		if not buckets.has(key):
			buckets[key] = {"variant": variant, "positions": []}
		var scale := minf(0.85, SpatialWorld3D.radius_metres(radius) * 0.70)
		var basis := Basis(Vector3.UP, float(seed % 360) * PI / 180.0).scaled(Vector3.ONE * scale)
		buckets[key]["positions"].append(Transform3D(basis, at))
		count += 1
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		var transforms: Array = bucket["positions"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _shrubs[int(bucket["variant"])]
		multi.instance_count = transforms.size()
		var bounds := AABB()
		for i: int in transforms.size():
			var transform: Transform3D = transforms[i]
			multi.set_instance_transform(i, transform)
			var box: AABB = transform * multi.mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		multi.custom_aabb = bounds.grow(0.02)
		var node := MultiMeshInstance3D.new()
		node.set_meta("occlusion_static_instances", true)
		node.multimesh = multi
		root.add_child(node)
	root.set_meta("underbrush", {"count": count, "variants": _shrubs.size(), "solid_changes": 0, "chunk_metres": 24.0})
	return root
