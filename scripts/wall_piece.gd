class_name WallPiece
extends Node2D
## One short span of the stone town wall, extruded in quarter view so it
## depth-sorts with actors. a/b are ground points in original units.

var footprint: PackedVector2Array  # world pixels, for collision
var _faces: Array = []  # [PackedVector2Array points, PackedVector2Array uvs, Color]
var _texture: Texture2D


func setup(a: Vector2, b: Vector2, height: float, thick: float, tex: Texture2D) -> void:
	_texture = tex
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var dir := (b - a).normalized()
	var n := dir.orthogonal() * thick * 0.5
	var g := [a - n, b - n, b + n, a + n]
	var base := PackedVector2Array()
	for p in g:
		base.append(Iso.project(p))
	var center := (base[0] + base[1] + base[2] + base[3]) / 4.0
	# Sort by the front-most ground point so actors pass correctly.
	var front := base[0]
	for p in base:
		if p.y > front.y:
			front = p
	position = Vector2(center.x, front.y)
	footprint = base
	var h := height * Iso.S
	var up := Vector2(0, -h)
	var local := PackedVector2Array()
	for p in base:
		local.append(p - position)
	var length := a.distance_to(b)
	# Side faces that look toward the camera (light from the upper left).
	for i in 4:
		var p0 := local[i]
		var p1 := local[(i + 1) % 4]
		var edge := p1 - p0
		var outward := Vector2(edge.y, -edge.x)
		var centroid_dir := (p0 + p1) / 2.0 - (local[0] + local[1] + local[2] + local[3]) / 4.0
		if outward.dot(centroid_dir) < 0:
			outward = -outward
		if outward.y <= 0.0:
			continue
		var span := length if i % 2 == 0 else thick
		var shade := 0.5 + 0.22 * clampf(-outward.normalized().x * 0.6 + 0.5, 0.0, 1.0)
		_faces.append([
			PackedVector2Array([p0 + up, p1 + up, p1, p0]),
			PackedVector2Array([Vector2(0, 0), Vector2(span * 2.2, 0), Vector2(span * 2.2, height * 2.2), Vector2(0, height * 2.2)]),
			Color(shade, shade * 0.99, shade * 0.97),
		])
	var top := PackedVector2Array()
	for p in local:
		top.append(p + up)
	_faces.append([top, PackedVector2Array([Vector2(0, 0), Vector2(length * 2.2, 0), Vector2(length * 2.2, thick * 2.2), Vector2(0, thick * 2.2)]), Color(0.68, 0.67, 0.64)])


func _draw() -> void:
	for f in _faces:
		var cols := PackedColorArray([f[2], f[2], f[2], f[2]])
		var pts: PackedVector2Array = f[0]
		var uvs: PackedVector2Array = f[1]
		var norm := PackedVector2Array()
		for uv in uvs:
			norm.append(uv / 418.0)
		draw_polygon(pts, cols, norm, _texture)
	# Cap line along the top edge.
	var top: PackedVector2Array = _faces[_faces.size() - 1][0]
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), Color(0.25, 0.24, 0.22, 0.6), 1.5)
