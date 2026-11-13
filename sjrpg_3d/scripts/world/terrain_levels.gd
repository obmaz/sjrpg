class_name TerrainLevels
extends RefCounted
## Physical walkable surfaces and their open stair/bank entrances, independent
## of actor drawing Z. Numeric rise comes from the measured cliff-face pixels.

const STEP_REACH := 25.0


static func measured_rise(faces: Array[PackedVector2Array]) -> float:
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


static func surfaces(village: Village) -> Array[Dictionary]:
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
		"bottom": steps[0], "upper": steps[steps.size() - 1], "rise": measured_rise(chapel_faces),
		"entrance": PackedVector2Array([village.terrace[0], village.terrace[1]]), "blockers": chapel_faces})
	for landmark: Landmark in village.landmarks:
		var definition: Dictionary = Landmark.data()[landmark.index]
		var outline: Array = definition["outline"]
		var entrance := int(definition["entrance"])
		var count := outline.size()
		var a := landmark.atlas_to_world(outline[entrance])
		var b := landmark.atlas_to_world(outline[(entrance + 1) % count])
		var c := landmark.atlas_to_world(outline[(entrance + 2) % count])
		var d := landmark.atlas_to_world(outline[(entrance + count - 1) % count])
		var faces: Array[PackedVector2Array] = []
		for face: Array in definition["faces"]:
			faces.append(landmark.atlas_polygon_to_world(face))
		var blockers := faces.duplicate()
		blockers.append_array(landmark.ledges)
		var rise := measured_rise(faces)
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
	for surface in surfaces(village):
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
