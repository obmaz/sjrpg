extends TestCase
## 실제 건물 재질 연결과 공유 몬스터 메시의 곡면 법선을 검사한다.
func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var walls := {}
	var doors := {}
	for key: String in NativeHouse3D.STYLES:
		var id: String = {"nw":"shop","ne":"smith","sw":"stable","se":"home"}[key]
		var wall := NativeAssetSurface.material(id, Vector3(6,5,6))
		var texture: Texture2D = wall.get_shader_parameter("atlas")
		var door: StandardMaterial3D = preview._materials[NativeHouse3D.resource_key(key, "wood")]
		walls[texture.get_instance_id()] = true
		doors[door.albedo_texture.get_instance_id()] = true
		check("house wall uses a dedicated nonrepeating four-face atlas " + key, wall.get_shader_parameter("tile") == false and texture.get_width() >= 1254)
	check("houses retain four distinct facades and share clean generated oak without painted door frames", walls.size() == 4 and doors.size() == 1 and (preview._materials["door"] as StandardMaterial3D).albedo_texture == load(NativeVillageSurfaces.ROOT + "oak.png"))
	for kind: String in ["wolf", "boar", "goblin", "skeleton"]:
		var model: Dictionary = NativeEnemyModels.build(kind)
		var root: Node3D = model["root"]
		var curved := 0
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i: int in range(0, points.size(), 3):
				var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i]).normalized()
				var alignment: float = face.dot(normals[i])
				if alignment > 0.1 and alignment < 0.995:
					curved += 1
		check("organic anatomy exports real smooth corner normals " + kind, curved > 30)
		root.free()
	game.queue_free()
	await _frames(2)
