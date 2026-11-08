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
		proof["generation"]["image_scope"] = "Shared limestone and blue slate basecolors through their recorded generators; existing timber pixels unchanged."
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
		_record_chapel(preview)
	game.queue_free()
	await _frames(2)


func _record_chapel(preview: Ortho3DPreview) -> void:
	var report: Dictionary = {}
	for candidate: Node in preview._world_environment.forest.find_children("*", "Node3D", true, false):
		if candidate.has_meta("chapel_detail"):
			report = candidate.get_meta("chapel_detail")
	if not check("actual chapel is present for the shared roof record", not report.is_empty()):
		return
	if not check("aligned chapel roof retains the original geometry and surface cap", int(report["triangles"]) < 30000 and int(report["surfaces"]) <= 8):
		return
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/preview3d/chapel/refinement.json"))
	var proof: Dictionary = baseline.duplicate(true)
	var material_inputs := ["assets/art/preview3d/materials.json", "assets/art/preview3d/limestone.webp", "assets/art/preview3d/slate.webp"]
	var retained_inputs := true
	for input: Dictionary in proof["inputs"]:
		var actual := FileAccess.get_sha256("res://" + str(input["path"]))
		if str(input["path"]) in material_inputs:
			input["sha256"] = actual
		else:
			retained_inputs = retained_inputs and actual == str(input["sha256"])
	if not check("canonical chapel reference, glass and timber source bytes remain unchanged", retained_inputs):
		return
	proof["prior_runtime_record"] = {"generator": baseline["generator"], "budget": baseline["budget"], "coordinate_contract": baseline["coordinate_contract"], "verification": baseline["verification"]}
	proof["purpose"] = "Native chapel and shared eight-course village roof refinement; 3D edition only."
	proof["generator"]["sha256"] = FileAccess.get_sha256("res://scripts/ortho_3d_chapel.gd")
	proof["source_derivations"] = "Shared generated limestone/slate sources, references and exact pixels are recorded in materials.json. Original glass and timber sources remain unchanged. No normal or roughness data was fabricated."
	proof["budget"]["triangles"] = report["triangles"]
	proof["budget"]["merged_surfaces"] = report["surfaces"]
	var bounds: AABB = report["bounds"]
	proof["coordinate_contract"]["aabb_min_m"] = [bounds.position.x, bounds.position.y, bounds.position.z]
	proof["coordinate_contract"]["aabb_max_m"] = [bounds.end.x, bounds.end.y, bounds.end.z]
	proof["roof_course_contract"] = {"tile_m": Ortho3DChapel.SLATE_TILE, "courses": Ortho3DChapel.SLATE_COURSES, "pitch_m": Ortho3DChapel.SLATE_PITCH, "actual_rows_per_slope": report["roof_rows"], "last_row": "partial course clipped at the unchanged ridge", "lip_m": 0.022}
	for index in proof["changes"].size():
		if str(proof["changes"][index]).begins_with("Twelve restrained slate rows"):
			proof["changes"][index] = "Fixed32.5cm slate courses share the eight-row2.6m village texture, with a covered underlay,22mm real lips and a partial ridge course; no coplanar roof overlap."
	proof["verification"] = {"engine": Engine.get_version_info()["string"], "renderer": "GL Compatibility", "case": "ortho_3d_chapel", "test_path": "tests/cases/ortho_3d_chapel.gd", "test_sha256": FileAccess.get_sha256("res://tests/cases/ortho_3d_chapel.gd"),
		"recording": "actual native chapel report and protected/source material hashes measured by the CI-only recorder",
		"result": "Candidate record; unchanged full aperture/normal/winding/budget gates plus actual slate-lip UV alignment run after temporary installation",
		"visual_review": "Pending fresh same-source paired portrait/landscape and reverse-angle captures; no user approval claim."}
	DirAccess.make_dir_recursive_absolute("res://build/house-family-record")
	var output := FileAccess.open("res://build/house-family-record/chapel-refinement.json", FileAccess.WRITE)
	if check("candidate chapel proof opens only under ignored build storage", output != null):
		output.store_string(JSON.stringify(proof, "\t") + "\n")
		output.close()
		print("ART_AUDIT CHAPEL_FAMILY_PROVENANCE_READY ", JSON.stringify({"path": "sjrpg_3d/build/house-family-record/chapel-refinement.json", "generator_sha256": proof["generator"]["sha256"], "triangles": report["triangles"], "surfaces": report["surfaces"], "roof_rows": report["roof_rows"], "bounds_min": proof["coordinate_contract"]["aabb_min_m"], "bounds_max": proof["coordinate_contract"]["aabb_max_m"]}))
