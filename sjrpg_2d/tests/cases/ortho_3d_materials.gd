extends TestCase
## Guard actual authored materials and metre-scale mapping on both roof slopes.


func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/preview3d/materials.json"))
	for key: String in manifest["materials"]:
		var entry: Dictionary = manifest["materials"][key]
		check("generated material preserves its reviewed source: " + key, FileAccess.get_sha256("res://" + str(entry["source"])) == entry["source_sha256"])
		check("runtime material has recorded content: " + key, FileAccess.get_sha256("res://" + str(entry["path"])) == entry["sha256"])
		var texture := load("res://" + str(entry["path"])) as Texture2D
		check("native material avoids enlarged tiny facade crops: " + key, texture != null and texture.get_width() >= 600 and texture.get_height() >= 600)
	var mesh := Ortho3DPreview.roof_mesh(Vector2(3.4, 6.1))
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var checked_slope := false
	var checked_ridge := false
	var aligned := true
	for a in vertices.size():
		for b in vertices.size():
			if is_equal_approx(vertices[a].z, vertices[b].z) and absf(vertices[a].x - vertices[b].x) > 0.1:
				checked_slope = true
				aligned = aligned and is_equal_approx(uv[a].x, uv[b].x) and absf(uv[a].y - uv[b].y) > 0.9
			if is_equal_approx(vertices[a].x, vertices[b].x) and absf(vertices[a].z - vertices[b].z) > 0.1:
				checked_ridge = true
				aligned = aligned and is_equal_approx(uv[a].y, uv[b].y) and absf(uv[a].x - uv[b].x) > 0.9
	check("actual roof UV rows cross the slope and follow the ridge", checked_slope and checked_ridge and aligned)
	var game := await make_game("mage")
	game._enable_ortho_preview()
	await _frames(2)
	var preview: Ortho3DPreview = game.ortho_preview
	var stone: StandardMaterial3D = preview._materials["stone"]
	check("all stone faces share world-space32cm masonry courses", stone.uv1_triplanar and stone.uv1_world_triplanar and stone.uv1_scale.is_equal_approx(Vector3.ONE / 2.56))
	check("sloping material retains mipmaps and anisotropic filtering", preview._materials["slate"].texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	game.queue_free()
	await _frames(2)
