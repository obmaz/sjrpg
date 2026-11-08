extends TestCase
## Persistent 2D mesh must paint the same clipped terrain in the same order.


class MapSource:
	extends Node
	var map_shapes: Array[Dictionary] = []


func _shape(points: PackedVector2Array, color: Color) -> Dictionary:
	return {"poly": points, "color": color, "bounds": Iso.poly_bounds(points)}


func _color_near(a: Color, b: Color) -> bool:
	# ArrayMesh vertex colors use the renderer's byte channels.
	var tolerance := 1.0 / 255.0 + 0.00001
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance and absf(a.a - b.a) <= tolerance


func _check_mesh(label: String, minimap: Minimap) -> void:
	var mesh: ArrayMesh = minimap._geometry_mesh
	check(label + " has one persistent 2D triangle surface", mesh != null and mesh.get_surface_count() == 1
		and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES
		and bool(mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_2D_VERTICES))
	if mesh == null or mesh.get_surface_count() != 1:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pieces: Array[Dictionary] = [{"poly": minimap._circle, "color": Minimap.PARCHMENT}]
	pieces.append_array(minimap._geometry)
	var source_count := 0
	var vertices_match := true
	var colors_match := true
	var bounds_match := true
	var ranges: Array[Vector2i] = []
	for piece: Dictionary in pieces:
		var polygon: PackedVector2Array = piece["poly"]
		ranges.append(Vector2i(source_count, source_count + polygon.size()))
		for index: int in polygon.size():
			var offset := source_count + index
			if offset >= points.size() or offset >= colors.size():
				vertices_match = false
				colors_match = false
				continue
			vertices_match = vertices_match and points[offset].is_equal_approx(polygon[index])
			colors_match = colors_match and _color_near(colors[offset], piece["color"])
			bounds_match = bounds_match and points[offset].length() <= minimap.content_radius() + 0.0001
		source_count += polygon.size()
	check(label + " preserves every clipped source point without changing its coordinates",
		vertices_match and points.size() == source_count)
	check(label + " preserves each polygon color and the circle fill", colors_match and colors.size() == points.size())
	check(label + " keeps all terrain inside the same inset circle", bounds_match)
	check(label + " has complete indexed triangles", indices.size() % 3 == 0)
	if indices.size() % 3 != 0:
		return
	var painter_order := true
	var triangles_inside := true
	var previous_piece := -1
	var areas: Array[float] = []
	areas.resize(pieces.size())
	areas.fill(0.0)
	for index: int in range(0, indices.size(), 3):
		var a: int = indices[index]
		var b: int = indices[index + 1]
		var c: int = indices[index + 2]
		if a < 0 or b < 0 or c < 0 or a >= points.size() or b >= points.size() or c >= points.size():
			triangles_inside = false
			continue
		var selected := -1
		for piece_index: int in ranges.size():
			var span: Vector2i = ranges[piece_index]
			if a >= span.x and a < span.y:
				selected = piece_index
				triangles_inside = triangles_inside and b >= span.x and b < span.y and c >= span.x and c < span.y
				break
		if selected < 0:
			triangles_inside = false
			continue
		painter_order = painter_order and selected >= previous_piece
		previous_piece = selected
		var area := absf((points[b] - points[a]).cross(points[c] - points[a])) * 0.5
		areas[selected] += area
		var polygon: PackedVector2Array = pieces[selected]["poly"]
		if area > 0.000001:
			triangles_inside = triangles_inside and Geometry2D.is_point_in_polygon((points[a] + points[b] + points[c]) / 3.0, polygon)
	var areas_match := indices.size() % 3 == 0
	for index: int in pieces.size():
		var polygon: PackedVector2Array = pieces[index]["poly"]
		var expected := absf(minimap._area(polygon))
		areas_match = areas_match and absf(areas[index] - expected) <= maxf(0.01, expected * 0.00001)
	check(label + " keeps circle then terrain painter order", painter_order)
	check(label + " triangulates each concave clipped source without connecting different polygons", triangles_inside and areas_match)


func run() -> void:
	var source := MapSource.new()
	source.map_shapes = [
		_shape(PackedVector2Array([Vector2(-1700, -1600), Vector2(1700, -1600), Vector2(1700, 1600), Vector2(-1700, 1600)]), Color("49623e")),
		_shape(PackedVector2Array([Vector2(-300, -1600), Vector2(150, -1600), Vector2(150, -150), Vector2(1400, -150), Vector2(1400, 250), Vector2(-300, 250)]), Color("b59e7b")),
		_shape(PackedVector2Array([Vector2(-200, -300), Vector2(500, -300), Vector2(500, 500), Vector2(-200, 500)]), Color(0.70, 0.45, 0.35, 0.65))
	]
	var untouched: Array[Dictionary] = source.map_shapes.duplicate(true)
	var minimap := Minimap.new()
	minimap.game = source
	minimap.radius = 64.0
	minimap.size = Vector2.ONE * 136.0
	var origin := Vector2.ZERO
	minimap._update_geometry(origin)
	check("mesh preparation keeps the original map array and metadata untouched",
		is_same(minimap._geometry_source, source.map_shapes) and source.map_shapes == untouched)
	_check_mesh("initial terrain", minimap)
	var mesh: ArrayMesh = minimap._geometry_mesh
	var original: Array = mesh.surface_get_arrays(0)
	var rebuilds := minimap.geometry_rebuilds
	for index in 120:
		minimap._update_geometry(origin)
	check("idle redraws reuse the same mesh and buffers without rebuilding geometry",
		minimap._geometry_mesh == mesh and minimap.geometry_rebuilds == rebuilds
		and mesh.surface_get_arrays(0) == original)
	var threshold := Minimap.WORLD_RADIUS / minimap.radius * 0.25
	minimap._update_geometry(origin + Vector2.RIGHT * threshold * 0.5)
	check("the existing subpixel movement tolerance also reuses the uploaded mesh",
		minimap.geometry_rebuilds == rebuilds and minimap._geometry_mesh == mesh
		and mesh.surface_get_arrays(0) == original)
	minimap._update_geometry(origin + Vector2.RIGHT * threshold * 1.1)
	check("visible movement rebuilds one surface without replacing the mesh resource",
		minimap.geometry_rebuilds == rebuilds + 1 and minimap._geometry_mesh == mesh
		and mesh.get_surface_count() == 1 and mesh.surface_get_arrays(0) != original)
	_check_mesh("moved terrain", minimap)
	rebuilds = minimap.geometry_rebuilds
	minimap.radius += 10.0
	minimap._update_geometry(origin)
	check("radius changes refresh the original circle and one cached mesh", minimap.geometry_rebuilds == rebuilds + 1 and minimap._geometry_mesh == mesh)
	_check_mesh("resized terrain", minimap)
	rebuilds = minimap.geometry_rebuilds
	source.map_shapes.append(_shape(PackedVector2Array([Vector2(600, 100), Vector2(800, 100), Vector2(800, 300), Vector2(600, 300)]), Color("cc9855")))
	minimap._update_geometry(origin)
	check("in-place source count changes still invalidate the cache", minimap.geometry_rebuilds == rebuilds + 1)
	rebuilds = minimap.geometry_rebuilds
	source.map_shapes = source.map_shapes.duplicate(true)
	minimap._update_geometry(origin)
	check("equal contents in a replacement source array still invalidate the cache", minimap.geometry_rebuilds == rebuilds + 1)
	source.map_shapes = []
	minimap._update_geometry(origin)
	var empty_arrays: Array = mesh.surface_get_arrays(0)
	var empty_points: PackedVector2Array = empty_arrays[Mesh.ARRAY_VERTEX]
	check("an empty realm clears old terrain and retains only the original background disc",
		minimap._geometry.is_empty() and minimap._geometry_mesh == mesh
		and empty_points.size() == minimap._circle.size())
	_check_mesh("empty realm", minimap)
	source.map_shapes = untouched
	minimap._update_geometry(origin)
	check("restoring source geometry repopulates the same mesh", not minimap._geometry.is_empty() and minimap._geometry_mesh == mesh)
	_check_mesh("restored realm", minimap)
	minimap.free()
	source.free()
