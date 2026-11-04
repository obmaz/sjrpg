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
		_sheet = load("res://assets/art/village/landmarks.webp")
	var d: Dictionary = data()[i]
	top = _poly(d["outline"])
	var outline: Array = d["outline"]
	for f in d["faces"]:
		blockers.append(_poly(f))
	for s in d["solids"]:
		blockers.append(_poly(s))
	for w in d["water"]:
		water.append(_poly(w))
		blockers.append(_poly(w))
	for k in outline.size():
		if k == int(d["entrance"]):
			continue
		var a := _pt(outline[k])
		var b := _pt(outline[(k + 1) % outline.size()])
		var n := (b - a).orthogonal().normalized() * 4.0
		ledges.append(PackedVector2Array([a + n, b + n, b - n, a - n]))
	# Depth: sorts like a ground object whose contact line is the footprint bottom.
	position = Vector2(center.x, center.y + 0.15 * side)
	return self


func _pt(p) -> Vector2:
	return top_left + Vector2(p[0], p[1]) * (side / CELL)


func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_pt(p))
	return out


func contains_top(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, top)


## Rect (world px) covering the art plus a margin, for keeping scatter off it.
func footprint_rect() -> Rect2:
	return Rect2(top_left, Vector2(side, side)).grow(60.0)


func _draw() -> void:
	var col := index % 2
	var row := index / 2
	var src := Rect2(col * CELL, row * CELL, CELL, CELL)
	draw_texture_rect_region(_sheet, Rect2(top_left - position, Vector2(side, side)), src)
