extends TestCase
## CI-only recorder. Copy temporarily into tests/cases/record_house_family.gd.
## Writes a review candidate under build/, never modifies the source proof or refs.

func run() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/preview3d/houses/provenance.json"))
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var geometry := {}
	var all_valid := true
	for key: String in ["nw", "ne", "sw", "se"]:
		var report: Dictionary = preview._houses[key]
		var meshes: Array[MeshInstance3D] = report["meshes"]
		var bounds := AABB()
		var first := true
		var triangles := 0
		var surfaces := 0
		for model: MeshInstance3D in meshes:
			var local: AABB = model.mesh.get_aabb()
			bounds = local if first else bounds.merge(local)
			first = false
			surfaces += model.mesh.get_surface_count()
			for surface in model.mesh.get_surface_count():
				var arrays := model.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if not indices.is_empty() else points.size()) / 3
		var footprint: Vector2 = report["footprint"]
		var approach: Rect2 = report["door_approach"]
		geometry[key] = {"width": footprint.x, "depth": footprint.y, "height_max": bounds.end.y,
			"bounds_min": [bounds.position.x, bounds.position.y, bounds.position.z], "bounds_max": [bounds.end.x, bounds.end.y, bounds.end.z],
			"triangles": triangles, "surfaces": surfaces, "door_x": report["door_x"], "door_width": report["door_width"], "door_height": report["door_height"],
			"door_approach": {"x": approach.position.x, "z": approach.position.y, "width": approach.size.x, "depth": approach.size.y},
			"openings": report["openings"].size(), "corner_quoins": report["corner_quoins"], "slate_tiles": report["slate_tiles"],
			"timber_tile_m": report["timber_tile_m"], "slate_tile_m": report["slate_tile_m"], "roof_overhang_m": report["roof_overhang"]}
		all_valid = all_valid and triangles >= 6000 and triangles <= 12000 and surfaces == 5
		print("ART_AUDIT HOUSE_FAMILY_MEASURED ", JSON.stringify({"key": key, "geometry": geometry[key]}))
	check("actual house candidate obeys the existing geometry/material cap", all_valid)
	if all_valid:
		var proof: Dictionary = baseline.duplicate(true)
		proof["prior_geometry"] = {"generator_sha256": baseline["generator"]["sha256"], "geometry": baseline["geometry"], "validation": baseline["validation"]}
		proof["generator"]["sha256"] = FileAccess.get_sha256("res://scripts/native_house_3d.gd")
		proof["materials"]["provenance_sha256"] = FileAccess.get_sha256("res://assets/art/preview3d/materials.json")
		var material_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/preview3d/materials.json"))
		for texture: Dictionary in proof["materials"]["textures"]:
			texture["sha256"] = FileAccess.get_sha256("res://" + str(texture["path"]))
		proof["materials"]["shared_resource_keys"] = ["stone", "slate", "door", "iron", "glass"]
		proof["materials"]["timber_mapping"] = {"resource_key": "door", "texture": "assets/art/preview3d/timber.webp", "uv_source": "beam-local longitudinal, original vertical plank UVs", "tile_m": NativeHouse3D.TIMBER_TILE, "extra_materials": 0}
		proof["materials"]["actual_material_record"] = material_data
		proof["geometry"] = geometry
		proof["generation"]["operation"] = "Native bonded corner masonry, staggered overlapping slate and beam-aligned metre UVs. Shared family limestone is recorded independently in materials.json."
		proof["generation"]["new_images_generated"] = true
		proof["generation"]["image_scope"] = "Shared limestone basecolor through its recorded generator; existing slate/timber pixels unchanged."
		proof["validation"] = {"case": "tests/cases/native_house_family.gd", "case_sha256": FileAccess.get_sha256("res://tests/cases/native_house_family.gd"), "engine": Engine.get_version_info()["string"],
			"recording": "actual runtime four-house meshes and material/source SHA-256 measured by CI-only recorder",
			"geometry_budget": "pass, 6000-12000 triangles and five shared surfaces per house",
			"source_record": "actual bytes; full contract tests and paired browser review run only after this candidate proof is committed",
			"actual_browser_views": "Pending fresh same-source paired portrait/landscape and reverse-angle captures."}
		DirAccess.make_dir_recursive_absolute("res://build/house-family-record")
		var output := FileAccess.open("res://build/house-family-record/provenance.json", FileAccess.WRITE)
		if check("candidate house proof opens only under the ignored build directory", output != null):
			output.store_string(JSON.stringify(proof, "\t") + "\n")
			output.close()
			print("ART_AUDIT HOUSE_FAMILY_PROVENANCE_READY ", JSON.stringify({"path": "sjrpg_3d/build/house-family-record/provenance.json", "generator_sha256": proof["generator"]["sha256"], "textures": proof["materials"]["textures"]}))
	game.queue_free()
	await _frames(2)
