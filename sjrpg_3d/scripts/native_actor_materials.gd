class_name NativeActorMaterials
extends RefCounted
## Neutral generated albedo grain over real sculpted actor geometry.
## Raw PNG bytes avoid a GPU texture readback on web and headless renderers.
const ATLAS := "res://assets/art/native-actors/surface-atlas.bin"
const SIZE := Vector2i(1536, 1024)
const CELL := 512
const KINDS := ["cloth", "leather", "iron", "skin", "hair", "rock"]
const ALIASES := {"metal": "iron", "steel": "iron", "bronze": "iron", "stone": "rock", "fur": "hair", "bone": "skin", "flesh": "skin", "wood": "leather"}
const METRES := {"cloth": 0.40, "leather": 0.30, "iron": 0.40, "skin": 0.30, "hair": 0.50, "rock": 0.60}
const ROUGHNESS := {"cloth": 0.96, "leather": 0.87, "iron": 0.55, "skin": 0.92, "hair": 0.90, "rock": 0.98}
static var _atlas: Image
static var _images := {}
static var _textures := {}
static var _materials := {}

static func canonical(kind: String) -> String:
	return str(ALIASES.get(kind, kind))

static func image(kind: String) -> Image:
	kind = canonical(kind)
	if not kind in KINDS:
		push_error("Unknown native actor surface: " + kind)
		return null
	if _images.has(kind):
		return _images[kind]
	if _atlas == null:
		var candidate := Image.new()
		var bytes := FileAccess.get_file_as_bytes(ATLAS)
		if bytes.is_empty() or candidate.load_png_from_buffer(bytes) != OK or candidate.get_size() != SIZE:
			push_error("Missing or invalid native actor material atlas: " + ATLAS)
			return null
		candidate.convert(Image.FORMAT_RGBA8)
		_atlas = candidate
	var index := KINDS.find(kind)
	var region := _atlas.get_region(Rect2i(Vector2i(index % 3, index / 3) * CELL, Vector2i.ONE * CELL))
	# Preserve the generated texture relief but remove source hue, then set a
	# consistent light mean so vertex-color palettes are not multiplied twice.
	var mean := 0.0
	for y in 8:
		for x in 8:
			var pixel := region.get_pixel(x * 64 + 32, y * 64 + 32)
			mean += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
	mean /= 64.0
	region.adjust_bcs(clampf(0.85 / maxf(mean, 0.01), 0.5, 2.0), 1.0, 0.0)
	region.generate_mipmaps()
	_images[kind] = region
	return region

static func texture(kind: String) -> Texture2D:
	kind = canonical(kind)
	if _textures.has(kind):
		return _textures[kind]
	var source := image(kind)
	if source == null:
		return null
	var result := ImageTexture.create_from_image(source)
	_textures[kind] = result
	return result

static func material(kind: String, tint := Color.WHITE) -> StandardMaterial3D:
	kind = canonical(kind)
	var key := kind + ":" + tint.to_html(true)
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.resource_name = "NativeActor_" + kind
	result.albedo_texture = texture(kind)
	result.albedo_color = tint
	result.vertex_color_use_as_albedo = true
	result.roughness = float(ROUGHNESS.get(kind, 0.94))
	result.metallic = 0.50 if kind == "iron" else 0.0
	result.uv1_triplanar = true
	result.uv1_world_triplanar = false
	result.uv1_scale = Vector3.ONE / float(METRES.get(kind, 0.4))
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	result.set_meta("actor_surface_kind", kind)
	result.set_meta("actor_surface_metres", float(METRES.get(kind, 0.4)))
	_materials[key] = result
	return result
