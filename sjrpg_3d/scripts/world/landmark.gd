class_name Landmark
extends Node2D
## 지형 랜드마크 (원본 FieldLandmark + forestIsometricTerraces): 768px 칸의 원화,
## 걸을 수 있는 윗면(outline), 열린 입구(entrance), 절벽면(faces), 영구 구조물(solids).
## 윗면 가장자리는 입구를 뺀 모든 변이 낭떠러지라 계단으로만 오를 수 있습니다.

const CELL := 768.0
const SIDES := [920.0, 1000.0, 900.0, 960.0]
const NAMES := ["바람 언덕", "숲의 석조 정원", "고목의 쉼터", "계곡 폭포"]

static var _sheet: Texture2D
static var _data: Array

var index := 0
var side := 920.0  # world pixels
var top_left := Vector2.ZERO
var top: PackedVector2Array  # walkable top (world px)
var ledges: Array[PackedVector2Array] = []
var blockers: Array[PackedVector2Array] = []
var water: Array[PackedVector2Array] = []
var _warp_mesh: ArrayMesh


static func data() -> Array:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.open("res://assets/data/landmarks.json", FileAccess.READ).get_as_text())
	return _data


## `center` is the footprint centre in world pixels (原本 center).
func setup(i: int, center: Vector2) -> Landmark:
	index = i
	side = SIDES[i] * Iso.S
	top_left = Vector2(center.x - side / 2.0, center.y + 0.15 * side - side + side * (32.0 / 768.0))
	if _sheet == null:
		_sheet = load("res://assets/sprites/village/landmarks.webp")
	var d: Dictionary = data()[i]
	top = atlas_polygon_to_world(d["outline"])
	var outline: Array = d["outline"]
	for f in d["faces"]:
		blockers.append(atlas_polygon_to_world(f))
	for s in d["solids"]:
		blockers.append(atlas_polygon_to_world(s))
	for w in d["water"]:
		water.append(atlas_polygon_to_world(w))
		blockers.append(atlas_polygon_to_world(w))
	for k in outline.size():
		if k == int(d["entrance"]):
			continue
		var a := atlas_to_world(outline[k])
		var b := atlas_to_world(outline[(k + 1) % outline.size()])
		var n := (b - a).orthogonal().normalized() * 4.0
		ledges.append(PackedVector2Array([a + n, b + n, b - n, a - n]))
	# Depth: sorts like a ground object whose contact line is the footprint bottom.
	position = Vector2(center.x, center.y + 0.15 * side)
	return self


## JSON 좌표 배열 또는 Vector2를 월드 좌표로 옮긴다.
func atlas_to_world(point: Variant) -> Vector2:
	var d: Dictionary = data()[index]
	var source := Vector2(point[0], point[1])
	if d.has("warp"):
		var native_size: float = d["native_size"]
		source = ArtWarp.point(d["warp"], source * native_size / CELL) * CELL / native_size
	var delta := source - Vector2(384, 600)
	var corrected := Vector2(delta.x, delta.y * float(d.get("gvs", 1.0)) + delta.x * float(d.get("gvk", 0.0))) + Vector2(384, 600)
	return top_left + corrected * (side / CELL)


func atlas_polygon_to_world(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(atlas_to_world(p))
	return out


func contains_top(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, top)


## Rect (world px) covering the art plus a margin, for keeping scatter off it.
func footprint_rect() -> Rect2:
	return Iso.poly_bounds(atlas_polygon_to_world([[0, 0], [CELL, 0], [CELL, CELL], [0, CELL]])).grow(60.0)


func _draw() -> void:
	if _warp_mesh != null:
		draw_mesh(_warp_mesh, _sheet)
		return
	var col := index % 2
	var row := index / 2
	var src := Rect2(col * CELL, row * CELL, CELL, CELL)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in [Vector2.ZERO, Vector2(CELL, 0), Vector2(CELL, CELL), Vector2(0, CELL)]:
		points.append(atlas_to_world([point.x, point.y]) - position)
		uvs.append((src.position + point) / _sheet.get_size())
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, _sheet)


func _ready() -> void:
	if WorldLighting.belongs_to_forest(self):
		material = WorldLighting.material()
	var d: Dictionary = data()[index]
	if d.has("warp"):
		var calibration := ArtWarp.data(d["warp"])
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var native_size: float = d["native_size"]
		var atlas_origin := Vector2((index % 2) * CELL, (index / 2) * CELL)
		for row in calibration["points"]:
			var source := Vector2(row[0], row[1]) * CELL / native_size
			var local := atlas_to_world([source.x, source.y]) - position
			vertices.append(Vector3(local.x, local.y, 0.0))
			uvs.append((atlas_origin + source) / _sheet.get_size())
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
	WorldOcclusion.attach(self, footprint_rect().grow(-60.0))
