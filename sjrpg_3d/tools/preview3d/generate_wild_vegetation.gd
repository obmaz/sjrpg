extends "res://tools/prop_art/bake.gd"
## 기존 제작 명령도 GLB·씬과 동일한 개별 형상 기록을 만든다.


func _ready() -> void:
	super._ready()
	var records: Array[Dictionary] = []
	for index: int in VEGETATION.size():
		var folder := "res://assets/models/vegetation/" + str(VEGETATION[index]) + "/"
		var proof: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(folder + "geometry.json")
		)
		var geometry := WildVegetationBuilder.make_mesh(index)
		records.append(
			{
				"path": (folder + "model.glb").trim_prefix("res://"),
				"scene": (folder + "visual.tscn").trim_prefix("res://"),
				"sha256": FileAccess.get_sha256(folder + "model.glb"),
				"triangles": proof["triangles"],
				"surfaces": geometry.get_surface_count(),
				"bounds": str(geometry.get_aabb()),
				"authoring": geometry.get_meta("authored_vegetation")
			}
		)
	var recipe := "res://tools/prop_art/vegetation_builder.gd"
	var file := FileAccess.open(
		"res://assets/source/preview3d/wild-vegetation/meshes.json", FileAccess.WRITE
	)
	file.store_string(
		(
			JSON.stringify(
				{
					"generator": recipe.trim_prefix("res://"),
					"generator_sha256": FileAccess.get_sha256(recipe),
					"original_geometry": true,
					"billboards": false,
					"variants": records
				},
				"\t"
			)
			+ "\n"
		)
	)
