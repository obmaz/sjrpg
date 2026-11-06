class_name TerrainLevels
extends RefCounted
## Physical walkable surfaces and their open stair/bank entrances, independent
## of actor drawing Z. Numeric rise comes from the measured cliff-face pixels.

const STEP_REACH := 25.0


static func _rise(faces: Array[PackedVector2Array]) -> float:
	var result := 0.0
	var slopes: Array[float] = []
	for face in faces:
		for i in face.size():
			var edge := face[(i + 1) % face.size()] - face[i]
			if absf(edge.x) <= absf(edge.y) * 0.15:
				result = maxf(result, absf(edge.y))
		# Natural cliff faces can lean: their model stores a top chain followed
		# by the reversed bottom chain. Measure those actual paired vertices
		# instead of treating every non-vertical face as a zero-height floor.
		if face.size() >= 4 and face.size() % 2 == 0:
			for i in face.size() / 2:
				var rise := face[face.size() - 1 - i].y - face[i].y
				if rise > 0.0:
					slopes.append(rise)
	if result > 0.0 or slopes.is_empty():
		return result
	slopes.sort()
	return slopes[slopes.size() / 2]


static func _surfaces(village: Village) -> Array[Dictionary]:
	if village.has_meta("melee_surfaces"):
		var cached: Array[Dictionary] = village.get_meta("melee_surfaces")
		return cached
	var surfaces: Array[Dictionary] = []
	var chapel: IsoSprite = village.buildings["chapel"]
	var chapel_faces: Array[PackedVector2Array] = []
	for face: Array in village.data["chapel"]["faces"]:
		chapel_faces.append(chapel.native_polygon(face))
	var steps := village.chapel_steps
	surfaces.append({"id": "chapel", "top": village.terrace, "ramp": village.terrace,
		"bottom": steps[0], "upper": steps[steps.size() - 1], "rise": _rise(chapel_faces),
		"entrance": PackedVector2Array([village.terrace[0], village.terrace[1]]), "blockers": chapel_faces})
	for landmark: Landmark in village.landmarks:
		var definition: Dictionary = Landmark.data()[landmark.index]
		var outline: Array = definition["outline"]
		var entrance := int(definition["entrance"])
		var count := outline.size()
		var a := landmark._pt(outline[entrance])
		var b := landmark._pt(outline[(entrance + 1) % count])
		var c := landmark._pt(outline[(entrance + 2) % count])
		var d := landmark._pt(outline[(entrance + count - 1) % count])
		var faces: Array[PackedVector2Array] = []
		for face: Array in definition["faces"]:
			faces.append(landmark._poly(face))
		var blockers := faces.duplicate()
		blockers.append_array(landmark.ledges)
		var rise := _rise(faces)
		# Flat decorative tops without any measured rise are the ground plane;
		# they must not acquire an invisible separate combat-height domain.
		if rise <= 0.001:
			continue
		surfaces.append({"id": "landmark_%d" % landmark.index, "top": landmark.top,
			"ramp": PackedVector2Array([a, b, c, d]), "bottom": (a + b) * 0.5,
			"upper": (c + d) * 0.5, "rise": rise,
			"entrance": PackedVector2Array([a, b]), "blockers": blockers})
	var deck := village.bridge.deck_polygon()
	surfaces.append({"id": "bridge", "top": deck, "rise": 0.0,
		"entrances": [PackedVector2Array([deck[3], deck[0]]), PackedVector2Array([deck[1], deck[2]])],
		"blockers": village.bridge.solids()})
	village.set_meta("melee_surfaces", surfaces)
	return surfaces


static func sample(village: Village, at: Vector2) -> Dictionary:
	for surface in _surfaces(village):
		var top: PackedVector2Array = surface["top"]
		if not Geometry2D.is_point_in_polygon(at, top):
			continue
		var height := float(surface["rise"])
		if surface.has("ramp"):
			var ramp: PackedVector2Array = surface["ramp"]
			if Geometry2D.is_point_in_polygon(at, ramp):
				var bottom: Vector2 = surface["bottom"]
				var upper: Vector2 = surface["upper"]
				var along := upper - bottom
				height *= clampf((at - bottom).dot(along) / maxf(along.length_squared(), 0.001), 0.0, 1.0)
		return {"id": surface["id"], "height": height, "surface": surface}
	return {"id": "ground", "height": 0.0}


static func _crosses_segment(from: Vector2, to: Vector2, edge: PackedVector2Array) -> bool:
	return Geometry2D.segment_intersects_segment(from, to, edge[0], edge[1]) != null


static func _crosses_blocker(from: Vector2, to: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(from, polygon) or Geometry2D.is_point_in_polygon(to, polygon):
		return true
	for i in polygon.size():
		if Geometry2D.segment_intersects_segment(from, to, polygon[i], polygon[(i + 1) % polygon.size()]) != null:
			return true
	return false


static func _wall_blocked(village: Village, from: Vector2, to: Vector2) -> bool:
	var walls: Array[Dictionary] = []
	if village.has_meta("melee_wall_bounds"):
		walls = village.get_meta("melee_wall_bounds")
	else:
		for polygon: PackedVector2Array in village.wall_footprints:
			walls.append({"polygon": polygon, "bounds": Iso.poly_bounds(polygon).grow(0.01)})
		village.set_meta("melee_wall_bounds", walls)
	var path := Rect2(from, Vector2.ZERO).expand(to).grow(0.01)
	for wall in walls:
		var bounds: Rect2 = wall["bounds"]
		if bounds.intersects(path) and _crosses_blocker(from, to, wall["polygon"]):
			return true
	return false


static func can_reach(village: Village, from: Vector2, to: Vector2) -> bool:
	if _wall_blocked(village, from, to):
		return false
	var source := sample(village, from)
	var target := sample(village, to)
	if absf(float(source["height"]) - float(target["height"])) > STEP_REACH:
		return false
	if source["id"] != target["id"]:
		if source["id"] != "ground" and target["id"] != "ground":
			return false
		var raised: Dictionary = target["surface"] if source["id"] == "ground" else source["surface"]
		var entrance_crossing := false
		if raised.has("entrance"):
			entrance_crossing = _crosses_segment(from, to, raised["entrance"])
		else:
			for edge: PackedVector2Array in raised["entrances"]:
				entrance_crossing = entrance_crossing or _crosses_segment(from, to, edge)
		if not entrance_crossing:
			return false
	# Even equal-height endpoints cannot swing through an intervening cliff or parapet.
	for surface in _surfaces(village):
		for blocker: PackedVector2Array in surface["blockers"]:
			if _crosses_blocker(from, to, blocker):
				return false
	return true
