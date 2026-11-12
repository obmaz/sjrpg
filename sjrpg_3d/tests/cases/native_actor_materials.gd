extends TestCase
## Actor material data must be usable without GPU readback or whole-atlas UV leakage.
func run() -> void:
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/materials/actors/provenance.json"))
	check("actor runtime preserves the actual generated PNG and approved tool reference", FileAccess.get_sha256(ActorSurfaceMaterials.ATLAS) == str(provenance["runtime"]["sha256"]) and FileAccess.get_sha256("res://assets/source/materials/actors/surface-atlas.png") == str(provenance["source"]["sha256"]) and FileAccess.get_sha256("res://assets/source/style/approved-game-reference.jpg") == str(provenance["actual_tool_references"][0]["sha256"]))
	for kind: String in ActorSurfaceMaterials.KINDS:
		var image := ActorSurfaceMaterials.image(kind)
		check("generated material crop decodes with real headless CPU pixels " + kind, image != null and image.get_size() == Vector2i(512, 512) and image.has_mipmaps())
		if image == null:
			continue
		var value := 0.0
		var neutral := true
		var minimum := 1.0
		var maximum := 0.0
		for y in 8:
			for x in 8:
				var pixel := image.get_pixel(x * 64 + 32, y * 64 + 32)
				neutral = neutral and absf(pixel.r - pixel.g) < 0.01 and absf(pixel.g - pixel.b) < 0.01
				value += pixel.r
				minimum = minf(minimum, pixel.r)
				maximum = maxf(maximum, pixel.r)
		check("actor tint receives a neutral light base with actual surface variation " + kind, neutral and value / 64.0 > 0.70 and maximum - minimum > 0.01)
		var material := ActorSurfaceMaterials.material(kind)
		check("native actor material uses shared texture and bounded physical triplanar scale " + kind, material.albedo_texture != null and material.vertex_color_use_as_albedo and material.uv1_triplanar and not material.uv1_world_triplanar and material.uv1_scale.x >= 1.0 and material.uv1_scale.x <= 4.0)
		check("actor material cache retains its resource " + kind, ActorSurfaceMaterials.material(kind) == material)
		var independent := material.duplicate() as StandardMaterial3D
		independent.albedo_color = Color.RED
		check("per-actor hit tint cannot alter another actor's material", material.albedo_color == Color.WHITE and independent.albedo_texture == material.albedo_texture)
	check("bone and bronze retain the intended shared surface families", ActorSurfaceMaterials.canonical("bone") == "skin" and ActorSurfaceMaterials.canonical("bronze") == "iron")
