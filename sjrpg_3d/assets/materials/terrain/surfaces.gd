class_name NativeTerrainSurfaces
extends RefCounted
## 가져온 GPU 압축 데이터를 그대로 묶어 열 가지 그림을 한 샘플러로 공유한다.
const COUNT := 10
static var _arrays: Dictionary = {}


static func layers(kind: String) -> Texture2DArray:
	assert(kind in ["grass", "water"])
	if _arrays.has(kind):
		return _arrays[kind]
	var images: Array[Image] = []
	for index in COUNT:
		var path := "res://assets/materials/%s/%s-%d.png" % [kind, kind, index]
		images.append(_imported_image(path))
	var texture := Texture2DArray.new()
	var error := texture.create_from_images(images)
	assert(error == OK, "표면 배열 생성 실패: %s (%s)" % [kind, error])
	texture.resource_name = "Native%s10" % kind.capitalize()
	_arrays[kind] = texture
	return texture


static func _imported_image(path: String) -> Image:
	var codec := "s3tc" if OS.has_feature("s3tc") else ("etc2" if OS.has_feature("etc2") else "")
	if codec.is_empty():
		# 헤드리스/압축 미지원 렌더러는 엔진의 원래 변환 경로를 사용한다.
		var source := (
			ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		)
		return source.get_image()
	# WebGL의 Texture2D.get_image()는 GPU 읽기와 RGBA 전개를 일으킨다.
	# 고정된 Godot4.7.2의 CTEX v1/raw GPU 블록만 검증 후 그대로 묶는다.
	var remap := ConfigFile.new()
	var error := remap.load(path + ".import")
	assert(error == OK, "표면 임포트 정보 없음: " + path)
	var imported: String = remap.get_value("remap", "path." + codec, "")
	var bytes := FileAccess.get_file_as_bytes(imported)
	assert(bytes.size() > 52 and bytes.slice(0, 4).get_string_from_ascii() == "GST2", path)
	assert(bytes.decode_u32(4) == 1 and bytes.decode_u32(36) == 0, "CTEX 형식 변경: " + path)
	var width := bytes.decode_u16(40)
	var height := bytes.decode_u16(42)
	var mips := bytes.decode_u32(44)
	var format := bytes.decode_u32(48)
	assert(format == (Image.FORMAT_DXT1 if codec == "s3tc" else Image.FORMAT_ETC2_RGB8), path)
	assert(width == 1256 and height == 1256 and mips > 0 and bytes.decode_u32(16) & (1 << 23), path)
	var expected := 0
	for level in mips + 1:
		expected += ceili(maxi(1, width >> level) / 4.0) * ceili(maxi(1, height >> level) / 4.0) * 8
	assert(bytes.size() - 52 == expected, "CTEX 블록 길이 불일치: " + path)
	return Image.create_from_data(width, height, true, format as Image.Format, bytes.slice(52))
