extends TestCase
## 독립 패키지가 실제 런타임 표면으로 연결되고 임포트 품질을 보존하는지 검사한다.
func run() -> void:
	var textures := {}
	for id: String in ["shop", "smith", "stable", "home", "chapel", "bridge"]:
		var material := NativeAssetSurface.material(id, Vector3(6, 5, 4))
		var texture: Texture2D = material.get_shader_parameter("atlas")
		textures[texture.get_instance_id()] = true
		check("independent authored asset loads full adopted pixels " + id, texture.get_width() == 1254 and texture.get_height() == 1254 and material.get_meta("asset_id") == id)
		var metadata := ConfigFile.new()
		var path := NativeAssetSurface.ROOT + id + "/albedo.png"
		check("authored wall retains loss compression and mipmaps " + id, metadata.load(path + ".import") == OK and metadata.get_value("params", "compress/mode") == 1 and metadata.get_value("params", "mipmaps/generate"))
	check("all six roles use independent authored atlases", textures.size() == 6)
