extends "res://tools/assets/architecture/house_builder.gd"
## 승인된 C 원화의 실제 입체 제작. 기존 주택 메시/재질은 덮어쓰지 않는다.
const DETAIL_ATLAS := "res://assets/materials/trade_workshops/albedo.png"
var _cell := 0
var _goods := 0
var _offset := Vector3.ZERO


func make(presenter: Node, root: Node3D, id: String) -> Dictionary:
	_root = root
	_key = id
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_box_arrays = unit.surface_get_arrays(0)
	_materials = {
		"stone": presenter._materials["village_stone"],
		"wood": presenter._materials["door_shop"],
		"iron": presenter._materials["iron"],
		"glass": presenter._materials["glass"],
		"slate": BuildingSurfaceMaterials.roof_material("shop" if id == "market_shop" else "smith"),
		"wall":
		BuildingSurfaceMaterials.material(
			"shop" if id == "market_shop" else "smith", Vector3(6.8, 3.7, 4.4), -1, 1.7
		),
	}
	var details := StandardMaterial3D.new()
	details.albedo_texture = load(DETAIL_ATLAS)
	details.roughness = .92
	details.vertex_color_use_as_albedo = true
	details.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials["details"] = details
	var embers := StandardMaterial3D.new()
	embers.albedo_color = Color.WHITE
	embers.emission_enabled = true
	embers.emission = Color("e79538")
	embers.emission_texture = load(DETAIL_ATLAS)
	embers.emission_energy_multiplier = .65
	embers.albedo_texture = load(DETAIL_ATLAS)
	_materials["embers"] = embers
	if id == "market_shop":
		_shop()
	else:
		_forge()
	var meshes := _flush()
	var bounds := meshes[0].mesh.get_aabb()
	for mesh: MeshInstance3D in meshes:
		bounds = bounds.merge(mesh.mesh.get_aabb())
	return {
		"key": id,
		"triangles": _triangles,
		"surfaces": meshes.size(),
		"meshes": meshes,
		"footprint": Vector2(8, 8),
		"bounds": bounds,
		"height_max": bounds.end.y,
		"goods_count": _goods,
		"furnace_opening": Vector2(1.68, .98) if id == "open_smithy" else Vector2.ZERO,
		"eaves_height": 3.7,
		"roof_rise": 1.7,
		"materials": _materials.keys(),
		"concept": "approved C revision: projecting merchandise and large open furnace",
		"collision_note": "TownPlazaPlan3D blockers/posts; open workshop floor remains traversable"
	}


func _shop() -> void:
	_shell(Vector3(0, 0, -.8), 6.8, 4.4, 3.7, 1.7, true)
	# 상품 뒤의 실제 벽 홈이 진열대 깊이를 만든다.
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.4))
	var door := {
		"x": 2.1, "width": 1.12, "bottom": .16, "height": 2.36, "arch": true, "role": "closed_door"
	}
	var window := {
		"x": -1.05, "width": 3.7, "bottom": .85, "height": 1.82, "arch": false, "role": "display"
	}
	_wall(6.8, .16, 3.7, [door, window] as Array[Dictionary], front)
	_box(Vector3(-1.15, .40, 1.47), Vector3(4.5, .48, .22), "stone")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 3.4, .40, -.8), Vector3(.23, .48, 4.4), "stone")
	_door(door, front)
	_box(Vector3(-1.05, 1.74, 1.12), Vector3(3.7, 1.82, .10), "wood")
	for level: float in [1.04, 1.59, 2.14, 2.64]:
		_box(Vector3(-1.05, level, 1.57), Vector3(3.72, .075, .59), "wood")
	for x: float in [-2.91, -1.67, -.43, .81]:
		_box(Vector3(x, 1.82, 1.56), Vector3(.095, 1.94, .57), "wood")
	for blocker: Dictionary in TownPlazaPlan3D.blockers("market_shop").slice(1):
		_box(blocker["at"], blocker["size"], "wood")
	for x: float in [-2.82, -2.18, -1.54, -.90, -.26, .38]:
		_box(Vector3(x, .58, 3.25), Vector3(.58, .91, .055), "wood")
	# 넓은 황토색 천막, 처지는 곡선과 파도 모양 앞단.
	for strip in 16:
		var a := float(strip) / 16.0
		var b := float(strip + 1) / 16.0
		var za := lerpf(1.45, 3.23, a)
		var zb := lerpf(1.45, 3.23, b)
		var ya := lerpf(3.45, 3.00, a) - sin(a * PI) * .16
		var yb := lerpf(3.45, 3.00, b) - sin(b * PI) * .16
		_cell = 0
		_quad(
			[
				Vector3(-3.24, ya, za),
				Vector3(1.04, ya, za),
				Vector3(1.04, yb, zb),
				Vector3(-3.24, yb, zb)
			],
			Vector3(0, 1, .28).normalized(),
			"details",
			[Vector2(0, a), Vector2(1, a), Vector2(1, b), Vector2(0, b)]
		)
		_quad(
			[
				Vector3(-3.24, ya - .018, za),
				Vector3(-3.24, yb - .018, zb),
				Vector3(1.04, yb - .018, zb),
				Vector3(1.04, ya - .018, za)
			],
			Vector3(0, -1, -.28).normalized(),
			"details",
			[Vector2(0, a), Vector2(0, b), Vector2(1, b), Vector2(1, a)]
		)
	for segment in 12:
		var x := lerpf(-3.24, 1.04, float(segment) / 12.0)
		var right := x + 4.28 / 12.0
		var polygon := PackedVector2Array(
			[
				Vector2(x, 3.01),
				Vector2(right, 3.01),
				Vector2(right, 2.86),
				Vector2((x + right) * .5, 2.77),
				Vector2(x, 2.86)
			]
		)
		_cell = 0
		_prism(polygon, .025, Transform3D(Basis.IDENTITY, Vector3(0, 0, 3.23)), "details")
	for at: Vector3 in TownPlazaPlan3D.posts("market_shop"):
		_box(at, Vector3(.13, at.y * 2, .13), "wood")
		_beam(
			at + Vector3(0, 1.05, 0), at + Vector3(.35 if at.x < 0 else -.35, 1.43, 0), .09, "wood"
		)
	# 진열품은 정면 그림만 세우지 않고 병/빵/과일/천의 실제 부피를 가진다.
	for i in 8:
		_bottle(Vector3(-2.70 + i * .44, 2.18, 1.71), .105, .34, 8 + i % 3)
	for i in 7:
		_detail_box(Vector3(-2.68 + i * .45, 1.80, 1.75), Vector3(.35, .22, .34), 1 + i % 2)
	for i in 9:
		_bottle(Vector3(-2.70 + i * .39, 1.08, 1.73), .09, .32, 8 + i % 3)
	for i in 5:
		_bottle(Vector3(.62, 1.28 + i * .27, 1.98), .09, .23, 8 + i % 3)
	_crate(Vector3(-2.30, 1.17, 2.82), Vector3(1.22, .26, .70))
	_crate(Vector3(-.87, 1.17, 2.82), Vector3(1.22, .26, .70))
	for i in 18:
		var at := Vector3(-2.75 + (i % 6) * .17, 1.38 + (i / 12) * .12, 2.65 + (i / 6 % 2) * .24)
		_round(at, Vector3(.18, .17, .18), 4)
	for i in 8:
		_round(
			Vector3(-1.30 + (i % 4) * .27, 1.40, 2.69 + (i / 4) * .25), Vector3(.28, .18, .19), 5
		)
	for i in 4:
		_detail_box(Vector3(.05, 1.24 + i * .085, 2.85), Vector3(.52, .07, .52), 1 + i % 2)
	for i in 3:
		_bottle(Vector3(.47 + i * .25, 1.16, 2.87), .10, .42, 8 + i % 3)
	for at: Vector3 in [Vector3(1.3, .43, 2.5), Vector3(-3.35, .48, 2.3)]:
		_round(at, Vector3(.59, .82, .59), 3)
		_detail_box(at + Vector3(0, .36, 0), Vector3(.20, .15, .21), 3)
	_ivy(Vector3(1.05, 3.7, 1.61))
	_hanging_sign(Vector3(-3.7, 2.9, 2.0), true)
	MedievalDetails.lantern(self, Transform3D(Basis.IDENTITY, Vector3(1.04, 2.56, 1.48)))


func _forge() -> void:
	# 본채는 좁은 석조 박공, 오른쪽은 개방된 기둥/지붕 작업장.
	_shell(Vector3(0, 0, -.8), 6.8, 4.4, 3.7, 1.7, false)
	for x: float in [-3.3, -1.2]:
		_box(Vector3(x, 1.9, -.8), Vector3(.20, 3.8, 4.4), "stone")
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.42))
	var door := {
		"x": -2.35, "width": 1.1, "bottom": .16, "height": 2.32, "arch": true, "role": "closed_door"
	}
	_wall(
		2.3,
		.16,
		3.7,
		(
			[
				{
					"x": -.10,
					"width": 1.1,
					"bottom": .16,
					"height": 2.32,
					"arch": true,
					"role": "closed_door"
				}
			]
			as Array[Dictionary]
		),
		Transform3D(Basis.IDENTITY, Vector3(-2.25, 0, 1.42)),
		"stone"
	)
	_door(door, front)
	for part: Dictionary in TownPlazaPlan3D.blockers("open_smithy").slice(1, 3):
		_box(part["at"], part["size"], "wood")
	# 석조 대형 아치 아래는 실제 열린 작업장이다.
	_arch_ring(-.42, 2.32, 1.48, .23, front)
	for x: float in [-2.13, 1.29]:
		_box(Vector3(x, 1.20, 1.52), Vector3(.23, 2.4, .30), "stone")
	_lean_roof(-.95, 3.56, -3.08, 2.70, 3.95, 3.55)
	for at: Vector3 in TownPlazaPlan3D.posts("open_smithy"):
		_box(at, Vector3(.19, at.y * 2, .19), "wood")
		for dx: float in [-.52, .52]:
			_beam(at + Vector3(0, .90, 0), at + Vector3(dx, 1.40, 0), .12, "wood")
	_box(Vector3(0, .08, .1), Vector3(6.8, .16, 6.2), "stone")
	_offset = Vector3(0, 0, 1.60)
	_furnace()
	_offset = Vector3.ZERO
	# 모루의 비대칭 뿔, 목, 받침을 실제 메시로 만든다.
	_round(Vector3(.25, .43, 3.15), Vector3(.83, .83, .73), 7)
	_box(Vector3(.25, .91, 3.15), Vector3(.66, .17, .46), "iron")
	_box(Vector3(.25, 1.07, 3.15), Vector3(.28, .22, .30), "iron")
	_prism(
		PackedVector2Array(
			[Vector2(-.72, 1.13), Vector2(.63, 1.13), Vector2(.63, 1.28), Vector2(-.30, 1.30)]
		),
		.42,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, 3.15)),
		"iron"
	)
	_beam(Vector3(.73, .18, 3.47), Vector3(.54, 1.02, 3.21), .065, "wood")
	_box(Vector3(.54, 1.02, 3.21), Vector3(.30, .16, .18), "iron")
	_crate(Vector3(2.62, .43, 1.35), Vector3(.88, .86, 1.70))
	for i in 12:
		_round(
			Vector3(2.39 + (i % 3) * .21, .91 + (i / 9) * .12, .84 + (i / 3 % 3) * .43),
			Vector3(.25, .22, .27),
			13
		)
	for x: float in [-1.15, -.89, 1.71, 2.01, 2.31]:
		_beam(Vector3(x, .32, .94), Vector3(x, 1.86, .76), .035, "iron")
		_box(Vector3(x, 1.40, .81), Vector3(.22, .045, .06), "iron")
		_box(Vector3(x, 1.23, .83), Vector3(.055, .29, .07), "wood")
	_hanging_sign(Vector3(-3.64, 2.75, 1.85), false)
	MedievalDetails.lantern(self, Transform3D(Basis.IDENTITY, Vector3(-1.24, 2.31, 1.5)))


func _shell(at: Vector3, width: float, depth: float, top: float, rise: float, timber: bool) -> void:
	_box(at + Vector3(0, .08, 0), Vector3(width, .16, depth), "stone")
	var back := Transform3D(Basis(Vector3.UP, PI), at + Vector3(0, 0, -depth * .5))
	_wall(
		width,
		.16,
		top,
		[_opening(0, .75, 1.15, 1.1)] as Array[Dictionary],
		back,
		"wall" if timber else "stone"
	)
	_window(_opening(0, .75, 1.15, 1.1), back, false)
	for side: float in [-1.0, 1.0]:
		var facade := Transform3D(
			Basis(Vector3.UP, side * PI * .5), at + Vector3(side * width * .5, 0, 0)
		)
		if timber:
			var opening := _opening(0, .82, 1.15, 1.15)
			_wall(depth, .16, top, [opening] as Array[Dictionary], facade)
			_window(opening, facade, false)
			for x: float in [-depth * .48, 0, depth * .48]:
				_box(Vector3(x, 1.95, .10), Vector3(.16, 3.50, .14), "wood", facade)
			for level: float in [.44, 2.65, 3.58]:
				_box(Vector3(0, level, .11), Vector3(depth, .14, .15), "wood", facade)
			_beam(Vector3(-depth * .43, 2.74, .12), Vector3(-.2, 3.50, .12), .12, "wood", facade)
	# 앞뒤 박공과 같은 비례의 본 지붕. 기하를 변환해 옛 메시를 복제하지 않는다.
	for z: float in [-depth * .5, depth * .5]:
		_gable(
			width,
			top,
			rise,
			Transform3D(Basis.IDENTITY, at + Vector3(0, 0, z)),
			"wall" if timber else "stone",
			z > 0
		)
		for side: float in [-1.0, 1.0]:
			_beam(
				at + Vector3(side * width * .5, top, z + .13),
				at + Vector3(0, top + rise, z + .13),
				.15,
				"wood" if timber else "stone"
			)
	# _roof는 원점 기준이므로 새 표면을 만든 후 노드 변환 대신 정점에 오프셋을 굽는다.
	var previous := _offset
	_offset = at
	_roof(width, depth, top, rise)
	_offset = previous
	_chimney(width, depth, top, rise, true)
	# 보이는 쌍창: 박공의 실제 홈/유리/석조 아치.
	for x: float in [-.40, .40]:
		var face := Transform3D(Basis.IDENTITY, at + Vector3(0, 0, depth * .5 + .12))
		_window(_opening(x, .56, top + .15, .91), face, false)
		_arch_ring(x, top + .84, .28, .08, face)
	if not timber:
		return
	for x: float in [-3.24, -.85, 1.10, 3.24]:
		_box(at + Vector3(x, 1.96, depth * .5 + .10), Vector3(.16, 3.48, .16), "wood")
	_box(at + Vector3(0, 3.57, depth * .5 + .12), Vector3(width, .18, .18), "wood")


func _triangle(points: Array, uv: Array, normal: Vector3, material: String) -> void:
	var moved := []
	for point: Vector3 in points:
		moved.append(point + _offset)
	if material in ["details", "embers"]:
		var cell := 14 if material == "embers" else _cell
		var coords := []
		for p: Vector2 in uv:
			coords.append(
				(
					(
						Vector2(cell % 4, cell / 4)
						+ Vector2(.045, .045)
						+ p.clamp(Vector2.ZERO, Vector2.ONE) * .91
					)
					/ 4.0
				)
			)
		_surface(material).set_color(
			Color(.72, .62, .44) if material == "details" and _cell == 0 else Color.WHITE
		)
		super._triangle(moved, coords, normal, material)
	else:
		super._triangle(moved, uv, normal, material)


func _detail_box(at: Vector3, size: Vector3, cell: int) -> void:
	_cell = cell
	var mesh := BoxMesh.new()
	mesh.size = size
	_detail_mesh(mesh, Transform3D(Basis.IDENTITY, at))
	_goods += 1


func _detail_mesh(mesh: Mesh, transform: Transform3D, role := "details") -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var points := []
		var coords := []
		for j in 3:
			points.append(transform * vertices[indices[i + j]])
			coords.append(uv[indices[i + j]])
		_triangle(points, coords, (transform.basis * normals[indices[i]]).normalized(), role)


func _round(at: Vector3, size: Vector3, cell: int) -> void:
	_cell = cell
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 5
	_detail_mesh(sphere, Transform3D(Basis.from_scale(size), at))
	_goods += 1


func _bottle(at: Vector3, radius: float, tall: float, cell: int) -> void:
	_round(at + Vector3(0, tall * .34, 0), Vector3(radius * 2, tall * .68, radius * 2), cell)
	_cell = cell
	var neck := CylinderMesh.new()
	neck.top_radius = radius * .40
	neck.bottom_radius = radius * .50
	neck.height = tall * .40
	neck.radial_segments = 8
	_detail_mesh(neck, Transform3D(Basis.IDENTITY, at + Vector3(0, tall * .78, 0)))
	_detail_box(at + Vector3(0, tall * .98, 0), Vector3(radius * .77, .04, radius * .77), 7)


func _crate(at: Vector3, size: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		_box(at + Vector3(side * size.x * .47, 0, 0), Vector3(.07, size.y, size.z), "wood")
		_box(at + Vector3(0, 0, side * size.z * .47), Vector3(size.x, size.y, .06), "wood")
	_box(at + Vector3(0, -size.y * .45, 0), Vector3(size.x, .08, size.z), "wood")
	for x: float in [-.36, 0, .36]:
		_box(at + Vector3(size.x * x, 0, size.z * .5), Vector3(.055, size.y + .03, .035), "wood")


func _hanging_sign(at: Vector3, shop: bool) -> void:
	_beam(at + Vector3(.30, .34, -.30), at + Vector3(0, .34, .16), .07, "iron")
	_beam(at + Vector3(0, .34, .16), at + Vector3(0, -.12, .16), .035, "iron")
	if shop:
		_detail_box(at + Vector3(0, -.44, .16), Vector3(.72, .76, .075), 15)
	else:
		MedievalDetails.plaque(
			self, Transform3D(Basis.IDENTITY, at + Vector3(0, -.44, .16)), "smith"
		)


func _lean_roof(
	left: float, right: float, back: float, front: float, high: float, low: float
) -> void:
	var rows := ceili((right - left) / SLATE_PITCH)
	for row in rows:
		var a := lerpf(left, right, float(row) / rows)
		var b := lerpf(left, right, float(row + 1) / rows)
		var ya := lerpf(high, low, float(row) / rows)
		var yb := lerpf(high, low, float(row + 1) / rows)
		for col in 14:
			var z0 := lerpf(back, front, float(col) / 14.0) + .004
			var z1 := lerpf(back, front, float(col + 1) / 14.0) - .004
			_quad(
				[Vector3(a, ya, z0), Vector3(a, ya, z1), Vector3(b, yb, z1), Vector3(b, yb, z0)],
				Vector3(.12, 1, 0).normalized(),
				"slate",
				[
					Vector2(z0, a) / 2.6,
					Vector2(z1, a) / 2.6,
					Vector2(z1, b) / 2.6,
					Vector2(z0, b) / 2.6
				]
			)
	for z: float in [back, front]:
		_beam(Vector3(left, high, z), Vector3(right, low, z), .17, "wood")
	for x: float in [left, right]:
		_box(
			Vector3(x, high if x == left else low, (back + front) * .5),
			Vector3(.14, .15, front - back),
			"wood"
		)


func _furnace() -> void:
	# 공용 충돌 부피 안에 측벽/개구부/후벽/후드를 따로 조형한다.
	_detail_box(Vector3(.42, .50, .08), Vector3(2.36, 1.0, 1.4), 12)
	for x: float in [-.61, 1.45]:
		_detail_box(Vector3(x, 1.43, .08), Vector3(.30, .94, 1.4), 12)
	_detail_box(Vector3(.42, 1.44, -.53), Vector3(1.80, .94, .16), 12)
	var arch := Transform3D(Basis.IDENTITY, Vector3(0, 0, .83))
	_arch_ring(.42, 1.47, .83, .20, arch)
	_cell = 14
	_quad(
		[
			Vector3(-.40, 1.02, -.25),
			Vector3(1.25, 1.02, -.25),
			Vector3(1.25, 1.02, .74),
			Vector3(-.40, 1.02, .74)
		],
		Vector3.UP,
		"embers",
		[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	)
	for i in 5:
		_cell = 14
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.26, .10, .15)
		_detail_mesh(
			mesh,
			Transform3D(Basis(Vector3.UP, .12 * i), Vector3(-.10 + i * .25, 1.10, .43)),
			"embers"
		)
	# 금속 후드는 아래쪽이 넓고 굴뚝으로 좁아지는 사다리꼴이다.
	for side: float in [-1.0, 1.0]:
		_quad(
			[
				Vector3(.42 + side * 1.26, 2.22, .95),
				Vector3(.42 + side * 1.26, 2.22, -.70),
				Vector3(.42 + side * .30, 2.96, -.42),
				Vector3(.42 + side * .30, 2.96, .20)
			],
			Vector3(side, .7, 0).normalized(),
			"iron"
		)
	_quad(
		[
			Vector3(-.84, 2.22, .95),
			Vector3(1.68, 2.22, .95),
			Vector3(.72, 2.96, .20),
			Vector3(.12, 2.96, .20)
		],
		Vector3(0, .7, 1).normalized(),
		"iron"
	)
	_box(Vector3(.42, 3.18, -.10), Vector3(.56, .45, .54), "iron")


func _gable(
	width: float, top: float, rise: float, frame: Transform3D, role: String, windows: bool
) -> void:
	var splits: Array[float] = [-width * .5, 0, width * .5]
	if windows:
		splits.append_array([-.68, -.12, .12, .68])
	splits.sort()
	for i in splits.size() - 1:
		var a := splits[i]
		var b := splits[i + 1]
		var ya := top + rise * (1.0 - absf(a) / (width * .5))
		var yb := top + rise * (1.0 - absf(b) / (width * .5))
		var opening := windows and absf((a + b) * .5) > .12 and absf((a + b) * .5) < .68
		if opening:
			_prism(
				PackedVector2Array(
					[Vector2(a, top), Vector2(b, top), Vector2(b, top + .15), Vector2(a, top + .15)]
				),
				.20,
				frame,
				role
			)
		_prism(
			PackedVector2Array(
				[
					Vector2(a, top + 1.06 if opening else top),
					Vector2(b, top + 1.06 if opening else top),
					Vector2(b, yb),
					Vector2(a, ya)
				]
			),
			.20,
			frame,
			role
		)


func _ivy(at: Vector3) -> void:
	for i in 18:
		var point := at + Vector3(sin(i * 1.4) * .16, -i * .145, .07)
		if i > 0:
			_beam(point, point + Vector3(.02, .16, 0), .016, "wood")
		_cell = 11
		var frame := Transform3D(Basis(Vector3.UP, sin(i * 2.3) * .8), point)
		var points := [
			frame * Vector3(-.11, 0, 0),
			frame * Vector3(0, .15, .035),
			frame * Vector3(.11, 0, 0),
			frame * Vector3(0, -.08, .01)
		]
		_quad(
			points,
			Vector3.BACK,
			"details",
			[Vector2(0, .5), Vector2(.5, 0), Vector2(1, .5), Vector2(.5, 1)]
		)
		_quad(
			points,
			Vector3.FORWARD,
			"details",
			[Vector2(0, .5), Vector2(.5, 0), Vector2(1, .5), Vector2(.5, 1)]
		)


func _append_arrays(arrays: Array, transform: Transform3D, material: String) -> void:
	# 기본 박스 경로(용마루 덮개 등)도 삼각형 경로와 같은 제작 오프셋을 사용한다.
	super._append_arrays(arrays, Transform3D(Basis.IDENTITY, _offset) * transform, material)
