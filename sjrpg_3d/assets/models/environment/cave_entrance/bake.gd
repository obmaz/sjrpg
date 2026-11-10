extends Node
func _ready() -> void:
	var recipe := load("res://assets/models/environment/cave_entrance/sculpt.gd")
	var mesh: ArrayMesh = recipe.mesh(NativeCavePlan.HILL_HEIGHT,SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS))
	var error := ResourceSaver.save(mesh,"res://assets/models/environment/cave_entrance/model.res",ResourceSaver.FLAG_COMPRESS)
	print("CAVE_BAKE ",error," triangles=",mesh.surface_get_array_len(0)/3," bounds=",mesh.get_aabb())
	get_tree().quit(error)
