class_name ResidentModelBuilder
extends RefCounted
## 주민 여섯 역할의 오프라인 형상 제작. 게임 중에는 GLB를 읽는다.
const IDS := ["merchant", "smith", "stable", "elder", "mira", "elin", "noah", "rowen"]
const AUTHORED_IDS := ["smith", "stable", "elder", "elin", "noah", "rowen"]
const COATS := ["74634c", "59605b", "68684c", "626e7a", "607b79", "677687", "637452", "526d7c"]
static var _meshes: Dictionary = {}


static func _part(
	buckets: Dictionary,
	key: String,
	mesh: Mesh,
	at: Vector3,
	stretch: Vector3 = Vector3.ONE,
	angle: float = 0.0,
	lean: float = 0.0
) -> void:
	var palette: Dictionary = {
		"leather": Color("8b7051"),
		"trouser": Color("555d59"),
		"skin": Color("f0c7a1"),
		"hair": Color("514539"),
		"greyhair": Color("c1baa3"),
		"bronze": Color("c6a66d"),
		"iron": Color("a4b3b0"),
		"ivory": Color("d8d4be"),
		"wood": Color("9d7d53"),
		"olive": Color("8da361"),
		"eye": Color("b2ad94"),
		"pupil": Color("282d2a")
	}
	var color: Color = palette.get(key, Color.WHITE)
	if key.begins_with("cloth"):
		color = Color(COATS[int(key.trim_prefix("cloth"))])
	var group: String = (
		"iron"
		if key in ["bronze", "iron"]
		else (
			"skin"
			if key in ["skin", "hair", "greyhair", "eye", "pupil"]
			else "cloth" if key.begins_with("cloth") or key in ["ivory", "olive"] else "leather"
		)
	)
	if not buckets.has(group):
		var fresh: SurfaceTool = SurfaceTool.new()
		fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
		buckets[group] = fresh
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var colored: ArrayMesh = ArrayMesh.new()
	colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool: SurfaceTool = buckets[group]
	var basis: Basis = Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, lean)
	tool.append_from(colored, 0, Transform3D(basis.scaled(stretch), at))


static func _box(
	b: Dictionary, key: String, at: Vector3, size: Vector3, angle: float = 0.0
) -> void:
	var mesh: PrimitiveMesh = BoxMesh.new()
	mesh.size = size
	_part(b, key, mesh, at, Vector3.ONE, angle)


static func _round(b: Dictionary, key: String, at: Vector3, size: Vector3) -> void:
	var mesh: PrimitiveMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_part(b, key, mesh, at, size)


static func _loft(
	b: Dictionary,
	key: String,
	rings: Array[Vector4],
	at: Vector3 = Vector3.ZERO,
	folds: float = 0.0,
	segments: int = 16,
	start: float = 0.0,
	span: float = TAU,
	thickness: float = 0.0
) -> void:
	_part(b, key, ActorShapeBuilder.loft(rings, segments, folds, start, span, thickness), at)


static func _face(b: Dictionary, base: float, female: bool, older: bool, identity: String) -> void:
	var scale: Vector3 = Vector3(0.90 if female else 1.0, 1, 1)
	_part(b, "skin", ActorShapeBuilder.head(), Vector3(0, base, 0.015), scale)
	# Eye whites, pupils and brows sit outside the actual cheek/temple section.
	for side: float in [-1.0, 1.0]:
		_round(b, "eye", Vector3(side * 0.046, base + 0.167, 0.119), Vector3(0.040, 0.017, 0.023))
		_round(b, "pupil", Vector3(side * 0.046, base + 0.166, 0.131), Vector3(0.016, 0.015, 0.007))
		_box(
			b,
			"greyhair" if older else "hair",
			Vector3(side * 0.046, base + 0.189, 0.120),
			Vector3(0.051, 0.014, 0.018),
			side * 0.08
		)
	_loft(
		b,
		"skin",
		[
			Vector4(0, 0.027, 0.016, 0),
			Vector4(0.027, 0.024, 0.041, 0.010),
			Vector4(0.079, 0.014, 0.015, -0.007)
		],
		Vector3(0, base + 0.105, 0.116),
		0,
		8
	)
	_box(b, "leather", Vector3(0, base + 0.058, 0.101), Vector3(0.047, 0.007, 0.006))
	var hair: String = "greyhair" if older else "hair"
	# The cap follows the skull sides and back; individually tapered locks
	# break its edge instead of presenting a flat circular disk.
	_loft(
		b,
		hair,
		[
			Vector4(base + 0.085, 0.108, 0.103, -0.012),
			Vector4(base + 0.20, 0.116, 0.108, -0.014),
			Vector4(base + 0.268, 0.085, 0.080, -0.01),
			Vector4(base + 0.29, 0.015, 0.020, -0.01)
		],
		Vector3.ZERO,
		0.006,
		16,
		PI * 0.80,
		PI * 1.40,
		0.012
	)
	for index: int in 6:
		var x: float = (float(index) - 2.5) * 0.031
		_loft(
			b,
			hair,
			[
				Vector4(0, 0.009, 0.012, 0.022),
				Vector4(0.038, 0.023, 0.022, 0.007),
				Vector4(0.087, 0.019, 0.022, -0.015),
				Vector4(0.108, 0.004, 0.006, -0.025)
			],
			Vector3(x, base + 0.168 + absf(x) * 0.12, 0.091),
			0,
			8
		)
	if female:
		_loft(
			b,
			hair,
			[
				Vector4(0, 0.025, 0.025, 0),
				Vector4(0.12, 0.040, 0.034, -0.01),
				Vector4(0.28, 0.052, 0.050, 0)
			],
			Vector3(0.07, base - 0.14, -0.11),
			0.005,
			10
		)
	if older or identity == "smith":
		_loft(
			b,
			hair,
			[
				Vector4(0, 0.014, 0.018, 0.025),
				Vector4(0.07, 0.055, 0.040, 0.016),
				Vector4(0.15, 0.083, 0.035, 0)
			],
			Vector3(0, base - (0.11 if older else 0.025), 0.095),
			0.004,
			12
		)


static func build(identity: String) -> ArrayMesh:
	if not AUTHORED_IDS.has(identity):
		return null
	if _meshes.has(identity):
		return _meshes[identity]
	var index: int = IDS.find(identity)
	if index < 0:
		return null
	var b: Dictionary = {}
	var cloth: String = "cloth" + str(index)
	var female: bool = identity == "elin"
	var elder: bool = identity == "elder"
	var smith: bool = identity == "smith"
	var width: float = 1.15 if smith else 0.90 if female else 1.0
	var shift: float = -0.065 if elder else -0.025 if female else 0.0
	for side: float in [-1.0, 1.0]:
		_part(b, "leather", ActorShapeBuilder.boot(), Vector3(side * 0.115, 0, 0))
		_loft(
			b,
			"trouser",
			[
				Vector4(0.25, 0.068, 0.076, 0),
				Vector4(0.47, 0.078, 0.083, 0),
				Vector4(0.56, 0.072, 0.080, 0.02),
				Vector4(0.82, 0.10, 0.10, 0)
			],
			Vector3(side * 0.11, 0, 0),
			0.003,
			12
		)
		var arm_key: String = "skin" if smith or identity == "stable" else cloth
		_part(
			b,
			arm_key,
			ActorShapeBuilder.sleeve(0.49, 0.095 if smith else 0.076),
			Vector3(side * 0.273 * width, 1.34 + shift, 0),
			Vector3.ONE,
			side * -0.10,
			-0.10 if identity == "rowen" else 0.04
		)
		_loft(
			b,
			"leather" if smith else cloth,
			[Vector4(0, 0.060, 0.065, 0), Vector4(0.055, 0.065, 0.068, 0)],
			Vector3(side * 0.276 * width, 0.87 + shift, 0.047),
			0.003,
			12
		)
		_round(
			b,
			"skin",
			Vector3(side * 0.276 * width, 0.79 + shift, 0.070),
			Vector3(0.104, 0.15, 0.091)
		)
	_part(
		b,
		cloth if not smith else "leather",
		ActorShapeBuilder.chest(),
		Vector3(0, shift, 0.045 if elder else 0),
		Vector3(width, 1, 1.0)
	)
	var long_robe: bool = identity in ["elder", "elin", "noah"]
	var hem: float = 0.14 if long_robe else 0.69
	_loft(
		b,
		cloth,
		[
			Vector4(hem, 0.29 if long_robe else 0.24 * width, 0.195, 0),
			Vector4(0.78, 0.225 * width, 0.15, 0),
			Vector4(0.99, 0.177 * width, 0.13, 0)
		],
		Vector3.ZERO,
		0.014 if long_robe else 0.009,
		24
	)
	_loft(
		b,
		"leather",
		[Vector4(0.94, 0.19 * width, 0.153, 0), Vector4(1.01, 0.19 * width, 0.153, 0)],
		Vector3.ZERO,
		0,
		16
	)
	_box(b, "bronze", Vector3(0, 0.974, 0.169), Vector3(0.069, 0.059, 0.020))
	# Open collar and two lapels, not a peg below a detached head.
	_loft(
		b,
		"ivory" if female else "leather",
		[Vector4(1.32 + shift, 0.106, 0.085, 0), Vector4(1.43 + shift, 0.079, 0.071, 0)],
		Vector3(0, 0, 0.015),
		0,
		16,
		PI * 0.03,
		PI * 0.94,
		0.016
	)
	_loft(
		b,
		"skin",
		[Vector4(1.36 + shift, 0.063, 0.058, 0.02), Vector4(1.54 + shift, 0.064, 0.059, 0.025)],
		Vector3.ZERO,
		0,
		12
	)
	var face_base: float = 1.49 + shift
	_face(b, face_base, female, elder, identity)
	match identity:
		"smith":
			_loft(
				b,
				"leather",
				[
					Vector4(0.43, 0.20, 0.025, 0.23),
					Vector4(0.65, 0.20, 0.025, 0.23),
					Vector4(0.98, 0.17, 0.025, 0.19),
					Vector4(1.28, 0.14, 0.025, 0.18)
				],
				Vector3.ZERO,
				0.006,
				16
			)
			for side: float in [-1.0, 1.0]:
				_box(b, "leather", Vector3(side * 0.09, 1.31, 0.15), Vector3(0.028, 0.20, 0.025))
			_box(b, "wood", Vector3(0.32, 0.77, 0.13), Vector3(0.030, 0.39, 0.035))
			_box(b, "iron", Vector3(0.32, 0.99, 0.13), Vector3(0.19, 0.085, 0.085))
		"stable":
			_loft(
				b,
				"leather",
				[
					Vector4(1.02, 0.21, 0.16, 0),
					Vector4(1.29, 0.257, 0.17, 0),
					Vector4(1.38, 0.17, 0.10, 0)
				],
				Vector3.ZERO,
				0,
				16,
				PI * 0.14,
				PI * 1.72,
				0.016
			)
			_round(b, "leather", Vector3(-0.22, 0.91, -0.06), Vector3(0.20, 0.29, 0.15))
		"elder":
			_part(b, "wood", ActorShapeBuilder.sleeve(1.62, 0.023), Vector3(0.35, 1.64, 0.12))
			_round(b, "bronze", Vector3(0.35, 1.65, 0.12), Vector3(0.10, 0.11, 0.10))
		"elin":
			_loft(
				b,
				"ivory",
				[
					Vector4(1.39, 0.18, 0.15, -0.025),
					Vector4(1.60, 0.17, 0.14, -0.025),
					Vector4(1.72, 0.145, 0.13, -0.02),
					Vector4(1.81, 0.065, 0.06, -0.02)
				],
				Vector3.ZERO,
				0.004,
				20,
				PI * 0.80,
				PI * 1.40,
				0.018
			)
			_loft(
				b,
				"ivory",
				[Vector4(0.28, 0.083, 0.022, 0.20), Vector4(1.20, 0.090, 0.025, 0.18)],
				Vector3.ZERO,
				0.006,
				12
			)
		"noah":
			_loft(
				b,
				cloth,
				[Vector4(1.21, 0.28, 0.21, 0), Vector4(1.42, 0.17, 0.13, 0)],
				Vector3.ZERO,
				0.008,
				20,
				PI * 0.1,
				PI * 1.8,
				0.025
			)
			_round(b, "wood", Vector3(0.21, 0.82, 0.20), Vector3(0.19, 0.23, 0.18))
			for side: float in [-1.0, 1.0]:
				_loft(
					b,
					"olive",
					[
						Vector4(0, 0.01, 0.01, 0),
						Vector4(0.08, 0.03, 0.018, 0.02),
						Vector4(0.18, 0.003, 0.004, 0.06)
					],
					Vector3(0.21 + side * 0.04, 0.92, 0.20),
					0,
					8
				)
		"rowen":
			_loft(
				b,
				cloth,
				[Vector4(0.78, 0.24, 0.18, -0.03), Vector4(1.35, 0.24, 0.19, 0)],
				Vector3.ZERO,
				0.012,
				18,
				PI * 1.04,
				PI * 0.96,
				0.020
			)
			_box(b, "leather", Vector3(0.27, 0.82, 0.13), Vector3(0.12, 0.20, 0.075))
			_box(b, "ivory", Vector3(0.27, 0.82, 0.17), Vector3(0.10, 0.17, 0.016))
			_loft(
				b,
				"iron",
				[
					Vector4(1.30, 0.11, 0.12, 0),
					Vector4(1.37, 0.135, 0.15, 0),
					Vector4(1.43, 0.06, 0.09, 0)
				],
				Vector3(-0.22, 0, 0),
				0,
				12
			)
	var result: ArrayMesh = ArrayMesh.new()
	for group: String in b:
		var tool: SurfaceTool = b[group]
		tool.commit(result)
		result.surface_set_material(
			result.get_surface_count() - 1, ActorSurfaceMaterials.material(group)
		)
	_meshes[identity] = result
	return result
