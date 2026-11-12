class_name IsoSprite
extends Node2D
## Native generated art with its measured ground contact (원본 IsometricSprite).
## The node origin is the feet point; the per-asset ground camera correction
## (groundVerticalScale/Skew) is applied exactly like the Flutter renderer.

signal texture_changed(value: Texture2D)

var def: Dictionary
var _texture: Texture2D
var _texture_path := ""
var _texture_attempted := false
## Metadata-only sprites do not decode their sheet until an actual renderer asks.
var texture: Texture2D:
	get:
		if _texture == null and not _texture_attempted and not _texture_path.is_empty():
			_texture_attempted = true
			_texture = IsoSprite.sheet(_texture_path)
			texture_changed.emit(_texture)
		return _texture
	set(value):
		_texture = value
		_texture_attempted = true
		_warp_mesh = null
		texture_changed.emit(value)
		queue_redraw()
var k := 1.0  # world pixels per atlas pixel
var modulate_color := Color.WHITE
var flip := false
## Optional vertical strip of the atlas (`clip` = atlas x range) for tall one-piece art such as the gatehouse: each
## strip is its own node whose origin is the strip's lowest ground point, so actors depth-sort against the strip
## beside them instead of the whole sprite. `draw_shift` re-anchors the art to the sprite's foot.
var clip := Vector2.ZERO
var draw_shift := Vector2.ZERO
var _warp_mesh: ArrayMesh

static var _textures := {}


static func sheet_path(name: String) -> String:
	if name.begins_with("res://"):
		return name
	var sheet_name := name.replace("forest-isometric-", "")
	if sheet_name == "rock":
		return "res://assets/materials/terrain/rock_base.webp"
	return "res://assets/sprites/village/%s.webp" % sheet_name


static func sheet(name: String) -> Texture2D:
	var path := sheet_path(name)
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


## Read-only inspection never invokes the lazy texture getter.
func is_texture_loaded() -> bool:
	return _texture != null


func texture_if_loaded() -> Texture2D:
	return _texture


func has_texture_source() -> bool:
	return _texture != null or (not _texture_attempted and not _texture_path.is_empty())


static func texture_snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	var loaded := 0
	var rgba8_base_estimate := 0
	for path: String in _textures:
		var resident: Texture2D = _textures[path]
		var dimensions := Vector2i.ZERO
		if resident != null:
			dimensions = Vector2i(resident.get_size())
			loaded += 1
			rgba8_base_estimate += dimensions.x * dimensions.y * 4
		entries.append({"path": path, "texture_loaded": resident != null,
			"dimensions": [dimensions.x, dimensions.y]})
	return {"cached_paths": _textures.size(), "loaded_textures": loaded,
		"rgba8_base_bytes_estimate": rgba8_base_estimate, "textures": entries}


## `height` is in original world units (before Iso.S).
func setup(d: Dictionary, height: float) -> IsoSprite:
	def = d
	_texture = null
	_texture_path = sheet_path(str(d["sheet"]))
	_texture_attempted = false
	_warp_mesh = null
	texture_changed.emit(null)
	k = height / float(d["height"]) * Iso.S
	return self


func _ground_delta(delta: Vector2) -> Vector2:
	return Vector2(delta.x, delta.y * float(def["gvs"]) + delta.x * float(def["gvk"]))


## Atlas pixel → world position.
func atlas_point(pixel: Vector2) -> Vector2:
	var foot := Vector2(def["foot"][0], def["foot"][1])
	pixel = _projected_pixel(pixel)
	foot = _projected_pixel(foot)
	return position + _ground_delta(pixel - foot) * k


func _projected_pixel(pixel: Vector2) -> Vector2:
	if not def.has("warp"):
		return pixel
	var source := Vector2(def["source"][0], def["source"][1])
	var origin := Vector2(def["origin"][0], def["origin"][1])
	var packing: float = def["packing"]
	return source + (ArtWarp.point(def["warp"], origin + (pixel - source) / packing) - origin) * packing


## Source2D drawing and retained native cutouts both use the exact calibrated mesh.
## Hidden/replaced sprites never need its texture-dependent UV normalization.
func ensure_warp_mesh() -> void:
	if _warp_mesh != null or not def.has("warp"):
		return
	var source_texture: Texture2D = texture
	if source_texture != null:
		_build_warp_mesh(source_texture.get_size())


func _build_warp_mesh(texture_size: Vector2) -> void:
	var calibration := ArtWarp.data(def["warp"])
	var source := Vector2(def["source"][0], def["source"][1])
	var origin := Vector2(def["origin"][0], def["origin"][1])
	var foot := _projected_pixel(Vector2(def["foot"][0], def["foot"][1]))
	var packing: float = def["packing"]
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row in calibration["points"]:
		var local := _ground_delta(source + (Vector2(row[2], row[3]) - origin) * packing - foot) * k
		vertices.append(Vector3(local.x, local.y, 0.0))
		uvs.append((source + (Vector2(row[0], row[1]) - origin) * packing) / texture_size)
	var indices := PackedInt32Array()
	for triangle in calibration["triangles"]:
		indices.append_array(PackedInt32Array(triangle))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_warp_mesh = ArrayMesh.new()
	_warp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Original (pre-packing) measurement pixel → world position.
func native_point(native: Vector2) -> Vector2:
	if def.has("baked_warp"):
		native = ArtWarp.point(def["baked_warp"], native)
	var src := Vector2(def["source"][0], def["source"][1])
	var origin := Vector2(def["origin"][0], def["origin"][1])
	return atlas_point(src + (native - origin) * float(def["packing"]))


func atlas_polygon(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(atlas_point(Vector2(p[0], p[1])))
	return out


func native_polygon(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(native_point(Vector2(p[0], p[1])))
	return out


## The strip of this sprite between atlas x `x0`..`x1` whose depth-sort point is the atlas pixel `sort_at`.
## Call after this sprite's `position` is set; add the result to the same parent.
func make_strip(x0: float, x1: float, sort_at: Vector2) -> IsoSprite:
	var strip := IsoSprite.new()
	strip.def = def
	strip._texture = _texture
	strip._texture_path = _texture_path
	strip._texture_attempted = _texture_attempted
	strip.k = k
	strip.clip = Vector2(x0, x1)
	var delta := _ground_delta(sort_at - Vector2(def["foot"][0], def["foot"][1])) * k
	strip.position = position + delta
	strip.draw_shift = -delta
	return strip


func _draw() -> void:
	var frame_texture: Texture2D = texture
	if frame_texture == null:
		return
	ensure_warp_mesh()
	if _warp_mesh != null:
		draw_mesh(_warp_mesh, frame_texture, Transform2D.IDENTITY, modulate_color)
		return
	var src := Rect2(def["source"][0], def["source"][1], def["source"][2], def["source"][3])
	if clip != Vector2.ZERO:
		src = Rect2(clip.x, src.position.y, clip.y - clip.x, src.size.y)
	var foot := Vector2(def["foot"][0], def["foot"][1])
	var sx := -k if flip else k
	draw_set_transform_matrix(Transform2D(Vector2(sx, k * float(def["gvk"])), Vector2(0, k * float(def["gvs"])), draw_shift))
	draw_texture_rect_region(frame_texture, Rect2(src.position - foot, src.size), src, modulate_color)


func _ready() -> void:
	if material == null and WorldLighting.belongs_to_forest(self):
		material = WorldLighting.material()
	var source := Rect2(def["source"][0], def["source"][1], def["source"][2], def["source"][3])
	if clip != Vector2.ZERO:
		source = Rect2(clip.x, source.position.y, clip.y - clip.x, source.size.y)
	var foot := _projected_pixel(Vector2(def["foot"][0], def["foot"][1]))
	var transform := Transform2D(Vector2(-k if flip else k, k * float(def["gvk"])), Vector2(0, k * float(def["gvs"])), global_position + draw_shift)
	WorldOcclusion.attach(self, WorldOcclusion.bounds_of(Rect2(source.position - foot, source.size), transform))
