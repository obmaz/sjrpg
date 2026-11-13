class_name LandmarkRenderer3D
extends RefCounted
const WATER_SHADER := preload("res://assets/materials/water/landmark_water.gdshader")
const EARTH_STRATUM_DEPTH := 0.20
const UPPER_GRASS_TINT := Color(1.26, 1.52, 1.65, 1.0)
## Native terrain/solid picture built from the same authored footprint as physics.
## Simulation and colliders remain SpatialWorld3D's responsibility.

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() < 0.00000001:
		return
	if (b - a).cross(c - a).dot(normal) < 0:
		var swap := b
		b = c
		c = swap
	# The caller supplies an outward orientation hint; tapered/broken faces need
	# their actual triangle plane normal, not the hint projected onto a wall axis.
	normal = (b - a).cross(c - a).normalized()
	for point in [a, c, b]:
		tool.set_normal(normal)
		var uv := Vector2(point.x, point.z)
		if absf(normal.y) < 0.7:
			var tangent := Vector3(normal.z, 0, -normal.x).normalized()
			uv = Vector2(point.dot(tangent), -point.y)
		tool.set_uv(uv / 2.56)
		tool.add_vertex(point)

static func _finish(tool: SurfaceTool, material: Material, parent: Node3D, name: String) -> MeshInstance3D:
	var mesh := tool.commit()
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node

static func _prism(polygon: PackedVector2Array, bottom: float, top: float, material: Material, parent: Node3D, name: String) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var native := PackedVector3Array()
	var flat := PackedVector2Array()
	var center := Vector3.ZERO
	for point in polygon:
		var p := WorldSpace3D.projected_to_world(point, top)
		native.append(p)
		flat.append(Vector2(p.x, p.z))
		center += p
	center /= maxf(1.0, native.size())
	var indices := Geometry2D.triangulate_polygon(flat)
	for index in range(0, indices.size(), 3):
		var a := native[indices[index]]
		var b := native[indices[index + 1]]
		var c := native[indices[index + 2]]
		_tri(tool, a, b, c, Vector3.UP)
		_tri(tool, Vector3(a.x, bottom, a.z), Vector3(c.x, bottom, c.z), Vector3(b.x, bottom, b.z), Vector3.DOWN)
	for i in native.size():
		var a := native[i]
		var b := native[(i + 1) % native.size()]
		var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		if Geometry2D.is_point_in_polygon(Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5) + Vector2(normal.x, normal.z) * 0.01, flat):
			normal = -normal
		var low_a := Vector3(a.x, bottom, a.z)
		var low_b := Vector3(b.x, bottom, b.z)
		_tri(tool, a, low_a, low_b, normal)
		_tri(tool, a, low_b, b, normal)
	return _finish(tool, material, parent, name)

static func build(renderer: Node, parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeLandmarks"
	parent.add_child(root)
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_texture = load("res://assets/materials/terrain/rock_base.webp")
	rock_material.roughness = 0.96
	rock_material.uv1_triplanar = true
	rock_material.uv1_world_triplanar = true
	rock_material.uv1_scale = Vector3.ONE / 2.56
	var earth := rock_material.duplicate() as StandardMaterial3D
	earth.albedo_texture = load("res://assets/sprites/forest/earth.webp")
	earth.albedo_color = Color(0.72, 0.65, 0.52)
	var terrain_materials := {}
	for role: int in [0, 2, 3]:
		for cliff: bool in [false, true]:
			var material := ShaderMaterial.new()
			material.shader = load("res://assets/materials/terrain/terrain.gdshader")
			material.set_shader_parameter("grass_layers", NativeTerrainSurfaces.layers("grass"))
			material.set_shader_parameter("habitat_bias", 1.25 if role == 3 else 0.45)
			material.set_shader_parameter("surface_tint", Color(UPPER_GRASS_TINT.r / ForestArt.GRASS_TINT.r, UPPER_GRASS_TINT.g / ForestArt.GRASS_TINT.g, UPPER_GRASS_TINT.b / ForestArt.GRASS_TINT.b))
			material.set_shader_parameter("rock_texture", rock_material.albedo_texture)
			material.set_shader_parameter("earth_texture", earth.albedo_texture)
			material.set_shader_parameter("rock_shelf", role == 0)
			material.set_shader_parameter("cliff", cliff)
			terrain_materials["%s:%s" % [role, cliff]] = material
	var owned := {}
	var entries: Array[Dictionary] = []
	var water_materials: Array[ShaderMaterial] = []
	var surfaces := {}
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(renderer.game.village):
		surfaces[str(surface["id"])] = surface
	for source: Landmark in renderer.game.village.landmarks:
		if source.index == 2:
			var trees := TreeGeometry3D.mesh_library()
			if trees.is_empty() or trees[0]["mesh"] == null:
				continue
		var id := "landmark_%d" % source.index
		var surface: Dictionary = surfaces.get(id, {"id": id, "top": source.top, "rise": 0.0})
		var points := SpatialWorld3D.surface_faces(surface)
		if points.is_empty():
			continue
		var group := Node3D.new()
		group.name = "Landmark%d" % source.index
		NativePlayerOcclusion.mark_object(group)
		root.add_child(group)
		var floor_tool := SurfaceTool.new()
		floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in range(0, points.size(), 3):
			var a := points[index] + Vector3.UP * 0.008
			var b := points[index + 1] + Vector3.UP * 0.008
			var c := points[index + 2] + Vector3.UP * 0.008
			var normal := (b - a).cross(c - a).normalized()
			if normal.y < 0:
				normal = -normal
			_tri(floor_tool, a, b, c, normal)
		var grassy_rise := source.index in [0, 2, 3] and float(surface["rise"]) > 0.001
		var floor_material: Material = terrain_materials["%s:false" % source.index] if grassy_rise else renderer._materials["paving"]
		_finish(floor_tool, floor_material, group, "WalkableTop")
		var sides := SurfaceTool.new()
		sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		var has_sides := false
		var soil_edges := SurfaceTool.new()
		soil_edges.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top: PackedVector2Array = surface["top"]
		var used := {}
		for triangle in range(0, points.size(), 3):
			for edge in 3:
				var a := points[triangle + edge]
				var b := points[triangle + (edge + 1) % 3]
				var from := WorldSpace3D.world_to_projected(a)
				var to := WorldSpace3D.world_to_projected(b)
				var on_boundary := false
				for i in top.size():
					if Geometry2D.get_closest_point_to_segment(from, top[i], top[(i + 1) % top.size()]).distance_squared_to(from) < 0.0001 and Geometry2D.get_closest_point_to_segment(to, top[i], top[(i + 1) % top.size()]).distance_squared_to(to) < 0.0001:
						on_boundary = true
						break
				if not on_boundary or maxf(a.y, b.y) < 0.001:
					continue
				var first := "%.5f:%.5f:%.5f" % [a.x, a.y, a.z]
				var second := "%.5f:%.5f:%.5f" % [b.x, b.y, b.z]
				var key := first + "|" + second if first < second else second + "|" + first
				if used.has(key):
					continue
				used[key] = true
				var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
				var middle := (from + to) * 0.5
				var test_point := middle + Iso.project(Vector2(normal.x, normal.z) * WorldSpace3D.GROUND_UNITS_PER_METER).normalized()
				if Geometry2D.is_point_in_polygon(test_point, top):
					normal = -normal
				var low_a := Vector3(a.x, -0.02, a.z)
				var low_b := Vector3(b.x, -0.02, b.z)
				# Exposed earth belongs only to the existing vertical cliff faces.
				# Split their upper 20cm instead of laying a rim over the walkable
				# top, roads or ponds. It tapers to zero at the open ramp entrance.
				var rock_a := a
				var rock_b := b
				if grassy_rise:
					rock_a.y = maxf(0.0, a.y - EARTH_STRATUM_DEPTH)
					rock_b.y = maxf(0.0, b.y - EARTH_STRATUM_DEPTH)
					_tri(soil_edges, a, rock_a, rock_b, normal)
					_tri(soil_edges, a, rock_b, b, normal)
				_tri(sides, rock_a, low_a, low_b, normal)
				_tri(sides, rock_a, low_b, rock_b, normal)
				has_sides = true
		if has_sides:
			_finish(sides, terrain_materials["%s:true" % source.index] if grassy_rise else rock_material, group, "CliffSides")
			if grassy_rise:
				_finish(soil_edges, earth, group, "ExposedEarth")
		if grassy_rise:
			var geology := SurfaceTool.new()
			geology.begin(Mesh.PRIMITIVE_TRIANGLES)
			var geology_faces := TerrainForms3D.faces(surface)
			for i in range(0, geology_faces.size(), 3):
				var a := geology_faces[i]
				var b := geology_faces[i + 1]
				var c := geology_faces[i + 2]
				_tri(geology, a, b, c, (b - a).cross(c - a).normalized())
			_finish(geology, terrain_materials["%s:true" % source.index], group, "NaturalGeology")
		var definition: Dictionary = Landmark.data()[source.index]
		for i in definition["solids"].size():
			var polygon := source.atlas_polygon_to_world(definition["solids"][i])
			var at := Iso.poly_bounds(polygon).get_center()
			var base := SpatialWorld3D.surface_height_at(renderer.game.village, at)
			# Existing native Obstacle colliders use exactly base+3.5m.
			if source.index == 2:
				_ancient_tree(renderer, group, polygon, base)
			else:
				_weathered_rock(polygon, base, base + 3.5, renderer._materials["stone"] if source.index == 1 else rock_material, group, "WeatheredStone%d" % i)
		for i in source.water.size():
			var water: PackedVector2Array = source.water[i]
			var water_centre := Iso.poly_bounds(water).get_center()
			var height := SpatialWorld3D.surface_height_at(renderer.game.village, water_centre) + 0.052
			_prism(water, height - 0.15, height - 0.015, rock_material, group, "PondBed%d" % i)
			var inset := _inset_water(water, 0.07)
			var material := _water_material(false)
			water_materials.append(material)
			var pool := _prism(inset, height - 0.01, height, material, group, "Water%d" % i)
			if pool != null:
				pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_shore_stones(water, height, rock_material, group, i)
		if source.index == 3 and source.water.size() >= 2:
			water_materials.append(_waterfall(renderer, source, group))
		owned[source.get_instance_id()] = true
		entries.append({"source_id": source.get_instance_id(), "role": source.index, "surface": surface, "faces": points, "root": group})
	var report := {"owned_source_ids": owned, "entries": entries, "root": root, "billboards": false, "water_materials": water_materials}
	root.set_meta("native_landmark_report", report)
	return report

static func _weathered_rock(polygon: PackedVector2Array, bottom: float, top: float, material: Material, parent: Node3D, name: String) -> void:
	var outline := PackedVector2Array()
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	var centre := WorldSpace3D.projected_to_world(Iso.poly_bounds(polygon).get_center())
	for i in polygon.size():
		var a := WorldSpace3D.projected_to_world(polygon[i], bottom)
		lower.append(a)
		var b := a.lerp(Vector3(centre.x, bottom, centre.z), 0.12)
		b.y = top - 0.08 - 0.14 * (0.5 + 0.5 * sin(i * 2.4))
		upper.append(b)
		outline.append(Vector2(b.x, b.z))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0, indices.size(), 3):
		var a := upper[indices[i]]
		var b := upper[indices[i + 1]]
		var c := upper[indices[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.y < 0:
			normal = -normal
		_tri(tool, a, b, c, normal)
	for i in lower.size():
		var next := (i + 1) % lower.size()
		var a := lower[i]
		var b := lower[next]
		var high_a := upper[i]
		var high_b := upper[next]
		var mid_a := a.lerp(high_a, 0.48)
		var mid_b := b.lerp(high_b, 0.48)
		# Broad weathered planes instead of perfect rectangular pillars.
		var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		if normal.dot((a + b) * 0.5 - centre) < 0:
			normal = -normal
		for pair in [[a, b, mid_a, mid_b], [mid_a, mid_b, high_a, high_b]]:
			_tri(tool, pair[0], pair[2], pair[3], normal)
			_tri(tool, pair[0], pair[3], pair[1], normal)
	_finish(tool, material, parent, name)

static func _ancient_tree(renderer: Node, parent: Node3D, polygon: PackedVector2Array, base: float) -> void:
	var entry: Dictionary = TreeGeometry3D.mesh_library()[0]
	var mesh := entry["mesh"] as Mesh
	if mesh == null:
		return
	var bounds := mesh.get_aabb()
	var source := Iso.poly_bounds(polygon).get_center()
	var centre := WorldSpace3D.projected_to_world(source, base)
	var factor := 7.2 / maxf(0.1, bounds.size.y)
	var tree := MeshInstance3D.new()
	tree.name = "AncientOak"
	tree.mesh = mesh
	tree.scale = Vector3.ONE * factor
	tree.position = centre - Vector3.UP * bounds.position.y * factor
	parent.add_child(tree)
	var bark: Material = mesh.surface_get_material(0)
	if bark == null:
		bark = renderer._materials["wood"]
	var native_polygon := PackedVector2Array()
	for point in polygon:
		var native := WorldSpace3D.projected_to_world(point)
		native_polygon.append(Vector2(native.x, native.z))
	var radius := 1000.0
	var native_center := Vector2(centre.x, centre.z)
	for i in native_polygon.size():
		radius = minf(radius, native_center.distance_to(Geometry2D.get_closest_point_to_segment(native_center, native_polygon[i], native_polygon[(i + 1) % native_polygon.size()])))
	# The root bed visibly marks the existing broad solid footprint; it must not
	# turn into a narrow visible trunk inside a large invisible obstacle.
	_weathered_rock(polygon, base, base + 0.32, bark, parent, "RootMound")
	for i in 7:
		var angle := TAU * i / 7.0
		var start := centre + Vector3(cos(angle), 0, sin(angle)) * minf(radius * 0.8, 1.7)
		var end := centre + Vector3(cos(angle) * 0.18, 1.25, sin(angle) * 0.18)
		var root := CylinderMesh.new()
		root.radial_segments = 8
		root.rings = 1
		root.bottom_radius = 0.15
		root.top_radius = 0.10
		root.height = start.distance_to(end)
		var node := MeshInstance3D.new()
		node.name = "AncientRoot%d" % i
		node.mesh = root
		node.material_override = bark
		node.position = (start + end) * 0.5
		node.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))
		parent.add_child(node)

static func _inset_water(polygon: PackedVector2Array, distance: float) -> PackedVector2Array:
	var native := PackedVector2Array()
	for point in polygon:
		var p := WorldSpace3D.projected_to_world(point)
		native.append(Vector2(p.x, p.z))
	var offset := Geometry2D.offset_polygon(native, -distance)
	if offset.is_empty():
		return polygon
	var result := PackedVector2Array()
	for point in offset[0]:
		result.append(Iso.project(point * WorldSpace3D.GROUND_UNITS_PER_METER))
	return result

static func _water_material(falling: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("source_water", load("res://assets/sprites/village/water.webp"))
	material.set_shader_parameter("falling", falling)
	return material

static func _shore_stones(polygon: PackedVector2Array, height: float, material: Material, parent: Node3D, index: int) -> void:
	var center := Iso.poly_bounds(polygon).get_center()
	var primitive := SphereMesh.new()
	primitive.radius = 0.11
	primitive.height = 0.15
	primitive.radial_segments = 8
	primitive.rings = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = primitive
	multi.instance_count = polygon.size()
	var bounds := AABB()
	for i in polygon.size():
		var source := polygon[i].lerp(center, 0.07)
		var position := WorldSpace3D.projected_to_world(source, height + 0.025)
		var transform := Transform3D(Basis.IDENTITY, position)
		multi.set_instance_transform(i, transform)
		var box: AABB = transform * primitive.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	multi.custom_aabb = bounds.grow(0.01)
	var batch := MultiMeshInstance3D.new()
	batch.name = "ShoreStones%d" % index
	batch.multimesh = multi
	batch.material_override = material
	parent.add_child(batch)

static func _flow_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0:
		var swap := b
		b = c
		c = swap
		var uv_swap := uv_b
		uv_b = uv_c
		uv_c = uv_swap
		normal = -normal
	for pair in [[a, uv_a], [c, uv_c], [b, uv_b]]:
		tool.set_normal(normal)
		tool.set_uv(pair[1])
		tool.add_vertex(pair[0])

static func _waterfall(renderer: Node, source: Landmark, parent: Node3D) -> ShaderMaterial:
	var upper: PackedVector2Array = source.water[0]
	var lower: PackedVector2Array = source.water[1]
	var top := upper[0]
	var bottom := lower[0]
	var distance := INF
	# Join closest actual shores, not both pond centres: the old diagonal mint
	# ribbon crossed entire pools and grass before reaching the cliff edge.
	for direction in 2:
		var from: PackedVector2Array = upper if direction == 0 else lower
		var to: PackedVector2Array = lower if direction == 0 else upper
		for point in from:
			for i in to.size():
				var p := WorldSpace3D.projected_to_world(point)
				var a := WorldSpace3D.projected_to_world(to[i])
				var b := WorldSpace3D.projected_to_world(to[(i + 1) % to.size()])
				var closest := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
				var gap := Vector2(p.x, p.z).distance_squared_to(closest)
				if gap < distance:
					distance = gap
					var projected := Iso.project(closest * WorldSpace3D.GROUND_UNITS_PER_METER)
					top = point if direction == 0 else projected
					bottom = projected if direction == 0 else point
	var top_centre := Iso.poly_bounds(upper).get_center()
	var bottom_centre := Iso.poly_bounds(lower).get_center()
	var a := WorldSpace3D.projected_to_world(top, SpatialWorld3D.surface_height_at(renderer.game.village, top_centre) + 0.052)
	var b := WorldSpace3D.projected_to_world(bottom, SpatialWorld3D.surface_height_at(renderer.game.village, bottom_centre) + 0.052)
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var t0 := float(i) / 10.0
		var t1 := float(i + 1) / 10.0
		var from := a.lerp(b, t0)
		var to := a.lerp(b, t1)
		from.y = lerpf(a.y, b.y, smoothstep(0.10, 0.90, t0))
		to.y = lerpf(a.y, b.y, smoothstep(0.10, 0.90, t1))
		var width_a := 0.26 - sin(t0 * PI) * 0.04
		var width_b := 0.26 - sin(t1 * PI) * 0.04
		_flow_triangle(tool, from - side * width_a, to + side * width_b, to - side * width_b, Vector2(0, t0), Vector2(1, t1), Vector2(0, t1))
		_flow_triangle(tool, from - side * width_a, from + side * width_a, to + side * width_b, Vector2(0, t0), Vector2(1, t0), Vector2(1, t1))
	var water := _water_material(true)
	var node := _finish(tool, water, parent, "FallingWater")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("source_shores", [top, bottom])
	return water

static func source_water_phase(village: Village) -> float:
	if Prefs.reduce_motion:
		return 0.0
	for child in village.fountain.get_children():
		if child is PlazaWater:
			return child.phase
	return 0.0

static func sync_water(forest: Node3D, village: Village) -> void:
	var root := forest.get_node_or_null("NativeLandmarks")
	if root == null:
		return
	var report: Dictionary = root.get_meta("native_landmark_report")
	var phase := source_water_phase(village)
	for material: ShaderMaterial in report.get("water_materials", []):
		material.set_shader_parameter("phase", phase)
		material.set_shader_parameter("motion", 0.0 if Prefs.reduce_motion else 1.0)
