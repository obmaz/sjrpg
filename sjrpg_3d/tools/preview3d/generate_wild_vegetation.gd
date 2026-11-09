extends Node
func _ready() -> void:
	var records: Array = []
	var paths: Array = NativeWildVegetation.TREE_PATHS + NativeWildVegetation.SHRUB_PATHS
	for i: int in paths.size():
		var mesh := NativeWildVegetation.make_mesh(i)
		var path: String = paths[i]
		var saved := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		assert(saved == OK)
		var triangles := 0
		for surface: int in mesh.get_surface_count():
			triangles += mesh.surface_get_array_len(surface) / 3
		records.append({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "triangles": triangles, "surfaces": mesh.get_surface_count(), "bounds": str(mesh.get_aabb()), "authoring": mesh.get_meta("authored_vegetation")})
	var file := FileAccess.open("res://assets/source/preview3d/wild-vegetation/meshes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"generator": "scripts/native_wild_vegetation.gd", "generator_sha256": FileAccess.get_sha256("res://scripts/native_wild_vegetation.gd"), "original_geometry": true, "billboards": false, "variants": records}, "\t") + "\n")
	print("WILD_VEGETATION ", JSON.stringify(records))
	get_tree().quit()
