extends RefCounted
## 오프라인 공용 세공. 기존 재질 표면에 닫힌 부품을 합쳐 새 노드/재질을 만들지 않는다.

const FAMILY := "woodland_oak_and_forged_iron"


static func plaque(
	builder: RefCounted, frame: Transform3D, emblem: String, board := "wood", metal := "iron"
) -> void:
	# 작은 길드 방패는 문 위/성문 옆의 기존 벽 면 안에서만 쓴다.
	var outline := PackedVector2Array(
		[
			Vector2(-.27, .29),
			Vector2(.27, .29),
			Vector2(.25, -.10),
			Vector2(0, -.34),
			Vector2(-.25, -.10)
		]
	)
	builder._prism(outline, .030, frame, metal)
	var inset := PackedVector2Array()
	for point: Vector2 in outline:
		inset.append(point * .85)
	builder._prism(inset, .026, frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, .025)), board)
	var signs: Array[PackedVector2Array] = []
	match emblem:
		"smith":
			signs.append(
				PackedVector2Array(
					[
						Vector2(-.19, .12),
						Vector2(.19, .12),
						Vector2(.13, .04),
						Vector2(.06, .02),
						Vector2(.06, -.09),
						Vector2(.13, -.15),
						Vector2(-.12, -.15),
						Vector2(-.06, -.09),
						Vector2(-.06, .02),
						Vector2(-.16, .04)
					]
				)
			)
		"shop":
			signs.append(
				PackedVector2Array(
					[
						Vector2(-.025, -.16),
						Vector2(.025, -.16),
						Vector2(.025, .08),
						Vector2(.18, .08),
						Vector2(.18, .12),
						Vector2(-.18, .12),
						Vector2(-.18, .08),
						Vector2(-.025, .08)
					]
				)
			)
			for side: float in [-1.0, 1.0]:
				signs.append(
					PackedVector2Array(
						[
							Vector2(side * .13 - .07, -.015),
							Vector2(side * .13 + .07, -.015),
							Vector2(side * .13, -.10)
						]
					)
				)
		"stable":
			signs.append(
				PackedVector2Array(
					[
						Vector2(-.16, .14),
						Vector2(-.09, .14),
						Vector2(-.10, -.05),
						Vector2(-.055, -.12),
						Vector2(.055, -.12),
						Vector2(.10, -.05),
						Vector2(.09, .14),
						Vector2(.16, .14),
						Vector2(.17, -.07),
						Vector2(.10, -.20),
						Vector2(-.10, -.20),
						Vector2(-.17, -.07)
					]
				)
			)
		_:
			signs.append(
				PackedVector2Array(
					[
						Vector2(0, .19),
						Vector2(.13, .09),
						Vector2(.09, -.02),
						Vector2(.14, -.07),
						Vector2(.035, -.14),
						Vector2(0, -.20),
						Vector2(-.035, -.14),
						Vector2(-.14, -.07),
						Vector2(-.09, -.02),
						Vector2(-.13, .09)
					]
				)
			)
	for sign_shape: PackedVector2Array in signs:
		builder._prism(
			sign_shape, .012, frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, .047)), metal
		)


static func lantern(
	builder: RefCounted, frame: Transform3D, metal := "iron", inset := "stone"
) -> void:
	# 낮에는 반사면으로 읽히는 등기구. 동적 광원/투명 유리/발광 셰이더를 추가하지 않는다.
	panel(builder, Rect2(-.035, -.22, .07, .54), .018, frame, metal)
	panel(
		builder,
		Rect2(-.105, -.15, .21, .30),
		.075,
		frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, .055)),
		inset
	)
	for side: float in [-1.0, 1.0]:
		panel(
			builder,
			Rect2(side * .105 - .014, -.17, .028, .34),
			.11,
			frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, .06)),
			metal
		)
	for height: float in [-.17, .17]:
		panel(
			builder,
			Rect2(-.13, height - .018, .26, .036),
			.125,
			frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, .06)),
			metal
		)
	builder._prism(
		PackedVector2Array([Vector2(-.15, .195), Vector2(.15, .195), Vector2(0, .31)]),
		.12,
		frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, .06)),
		metal
	)


static func panel(
	builder: RefCounted, rect: Rect2, depth: float, frame: Transform3D, material: String
) -> void:
	builder._prism(
		PackedVector2Array(
			[
				rect.position,
				rect.position + Vector2(rect.size.x, 0),
				rect.end,
				rect.position + Vector2(0, rect.size.y)
			]
		),
		depth,
		frame,
		material
	)
