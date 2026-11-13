class_name DungeonArt
extends Node2D
## The generated cave's actual stone, cutaway ledges and lantern art share the playable layout.

const DATA_PATH := "res://assets/data/cave_art.json"
var layout: DungeonLayout
var visuals: Array[Node2D] = []
var floor_nodes: Array[Polygon2D] = []
var boundary_segments: Array[Dictionary] = []
var _world: Node2D
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


func setup(cave_layout: DungeonLayout, world: Node2D) -> DungeonArt:
	layout = cave_layout
	_world = world
	return self


func _ready() -> void:
	boundary_segments = layout.relief.boundary_segments
	_build_floor()
	_build_walls()
	_build_passages()
	_build_lanterns()


func _build_floor() -> void:
	var textures: Dictionary = data()["textures"]
	var bounds := layout.bounds.grow(1800.0)
	var backdrop := _floor(PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]), textures["dark"]["path"])
	backdrop.modulate = Color(0.27, 0.3, 0.32)
	backdrop.z_index = -5
	for polygon in layout.polygons:
		var surface := _floor(polygon, textures["floor"]["path"])
		surface.z_index = -3
		floor_nodes.append(surface)


func _floor(polygon: PackedVector2Array, path: String) -> Polygon2D:
	var surface := Polygon2D.new()
	surface.polygon = polygon
	surface.texture = load("res://" + path)
	surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var uvs := PackedVector2Array()
	for point in polygon:
		# All pieces sample one world-space stone surface, including room/corridor overlaps.
		uvs.append(Iso.unproject(point) * 1.1)
	surface.uv = uvs
	add_child(surface)
	return surface


func _build_walls() -> void:
	var frames: Dictionary = data()["frames"]
	for edge in boundary_segments:
		var a: Vector2 = edge["a"]
		var b: Vector2 = edge["b"]
		var outward: Vector2 = edge["outward"]
		# Nearby branch corridors must not raise a second high wall across a combat room.
		# Only the back sides of the main chambers rise; passages remain cut away.
		var high := Iso.project(outward).y < 0.0 and _borders_chamber(a, b, outward)
		var family := "wall" if high else "ledge"
		var key := family + ("_positive" if a.x != b.x else "_negative")
		var frame: Dictionary = frames[key]
		var height: float = frame["world_height"]
		var base: Array = frame["baseline"]
		var delta := Vector2(base[1][0] - base[0][0], base[1][1] - base[0][1])
		delta = Vector2(delta.x, delta.y * float(frame["gvs"]) + delta.x * float(frame["gvk"]))
		var tile_length := delta.length() * height / float(frame["height"])
		var length := a.distance_to(b)
		var steps := maxi(1, ceili(length / (tile_length * 0.96)))
		var step := length / steps
		for index in steps:
			# Fit a complete illustration uniformly: cutting across an irregular ridge
			# exposes thin, flat rock blades at the joins.
			var piece := IsoSprite.new().setup(frame, height * step / tile_length)
			var center_x: float = frame["foot"][0]
			piece.clip = Vector2(frame["source"][0], float(frame["source"][0]) + float(frame["source"][2]))
			var ground := a.lerp(b, (index + 0.5) / steps) + outward * 2.0
			if high:
				# Sort a long diagonal cliff at each local contact, so its nearer end
				# cannot incorrectly paint over a lantern or hero beside its farther end.
				piece.position = Iso.project(ground)
				var slope := float(base[1][1] - base[0][1]) / float(base[1][0] - base[0][0])
				var slices := maxi(1, ceili(step / 32.0))
				for slice in slices:
					var left := lerpf(piece.clip.x, piece.clip.y, float(slice) / slices)
					var right := lerpf(piece.clip.x, piece.clip.y, float(slice + 1) / slices)
					var middle := (left + right) * 0.5
					var contact_x := clampf(middle, minf(base[0][0], base[1][0]), maxf(base[0][0], base[1][0]))
					var contact := Vector2(contact_x, float(frame["foot"][1]) + (contact_x - center_x) * slope)
					_register_visual(piece.make_strip(left, right, contact), "wall")
				piece.free()
			else:
				_add_visual(piece, ground, "wall")
		# Natural rock end caps cover the joins without adding a walkable obstruction.
		for point in [a, b]:
			var inward := (b - a).normalized() if point == a else (a - b).normalized()
			var at: Vector2 = point + inward * minf(16.0, length * 0.25) + outward * 4.0
			if layout._inside(Iso.project(at)):
				continue
			var cap := IsoSprite.new().setup(frames["boulder"], 88.0 if high else 45.0)
			_add_visual(cap, at, "wall")


func _borders_chamber(a: Vector2, b: Vector2, outward: Vector2) -> bool:
	for fraction in [0.25, 0.5, 0.75]:
		var inside := a.lerp(b, fraction) - outward * 4.0
		for room in DungeonLayout.ROOMS:
			if Rect2(room - Vector2(300, 300), Vector2(600, 600)).has_point(inside):
				return true
		if Rect2(-220, -220, 440, 440).has_point(inside) or Rect2(4500, -220, 420, 440).has_point(inside):
			return true
	return false


func _add_visual(piece: IsoSprite, ground: Vector2, role: String) -> void:
	piece.position = Iso.project(ground)
	_register_visual(piece, role)


func _register_visual(piece: IsoSprite, role: String) -> void:
	piece.set_meta("cave_role", role)
	_world.add_child(piece)
	visuals.append(piece)


func _build_passages() -> void:
	var frames: Dictionary = data()["frames"]
	# The back-facing mouths carry the generated arches; front edges remain cut away.
	# 첫 가시판 바로 뒤의 장식 아치는 위험 범위와 회피 바닥을 가리므로 비운다.
	var passages: Array[Array] = []
	for index in DungeonLayout.ROOMS.size():
		var room: Vector2 = DungeonLayout.ROOMS[index]
		if index < 4:
			passages.append([room + Vector2(0, -330), "arch_positive", 200.0])
		else:
			passages.append([room + Vector2(-330, 0), "arch_negative", 220.0])
	for passage in passages:
		var frame: Dictionary = frames[passage[1]]
		var opening: Array = frame["opening"]
		var delta := Vector2(opening[1][0] - opening[0][0], opening[1][1] - opening[0][1])
		delta = Vector2(delta.x, delta.y * float(frame["gvs"]) + delta.x * float(frame["gvk"]))
		var height: float = float(passage[2]) * float(frame["height"]) / delta.length()
		var arch := IsoSprite.new().setup(frame, height)
		_add_visual(arch, passage[0], "arch")


func _build_lanterns() -> void:
	var frame: Dictionary = data()["frames"]["lantern"]
	for index in DungeonLayout.ROOMS.size():
		var room: Vector2 = DungeonLayout.ROOMS[index]
		for direction in [-1.0, 1.0]:
			# Rest on the inner wall lip, where actor-radius clearance already prevents walking.
			# A lamp behind the cliff would be hidden by its opaque rock face.
			var offset := Vector2(-280, direction * 158.0) if index in [0, 2, 4] else Vector2(direction * 148.0, -280)
			var lamp := IsoSprite.new().setup(frame, 55.0)
			_add_visual(lamp, room + offset, "lantern")
			var light := CaveLight.new()
			light.position = Vector2(0, -30)
			lamp.add_child(light)


## Lighting is an effect on the generated art, with no painted shadow layer on the floor.
class CaveLight:
	extends PointLight2D
	var phase := 0.0
	static var glow: GradientTexture2D

	func _ready() -> void:
		if glow == null:
			glow = GradientTexture2D.new()
			glow.width = 128
			glow.height = 128
			glow.fill = GradientTexture2D.FILL_RADIAL
			glow.fill_from = Vector2(0.5, 0.5)
			glow.fill_to = Vector2(1.0, 0.5)
			var ramp := Gradient.new()
			ramp.set_color(0, Color.WHITE)
			ramp.set_color(1, Color.TRANSPARENT)
			glow.gradient = ramp
		texture = glow
		texture_scale = 2.2
		color = Color(1.0, 0.66, 0.28)
		energy = 0.45
		range_z_min = -3
		range_z_max = 1

	func _process(delta: float) -> void:
		phase = 0.0 if Prefs.reduce_motion else fmod(phase + delta, TAU * 100.0)
		energy = 0.45 + sin(phase * 3.8) * 0.025 + sin(phase * 8.7) * 0.012
