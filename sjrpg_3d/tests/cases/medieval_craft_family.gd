extends TestCase
## 실제 가져온 건물의 세공과 가림·재질 예산 계약을 함께 검증한다.


func run() -> void:
	var family := "woodland_oak_and_forged_iron"
	for id: String in ["shop", "smith", "stable", "home"]:
		var model := ArchitectureSceneLibrary.create(id)
		add_child(model)
		var report: Dictionary = model.report
		check(
			"town houses share a restrained craft family " + id,
			report.get("craft_family", "") == family
		)
		check(
			"houses retain a role-specific guild emblem " + id, report.get("guild_emblem", "") == id
		)
		check("all four eaves have structural knee braces " + id, report.get("knee_braces", 0) == 8)
		check(
			"one wall-mounted lantern uses existing merged material slots " + id,
			report.get("lanterns", 0) == 1 and int(report["surfaces"]) == 6
		)
		var shutters: Array = report.get("shutters", [])
		var usable := not shutters.is_empty()
		var timber: TriangleMesh
		for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if str(node.name).ends_with("_wood"):
				timber = node.mesh.generate_triangle_mesh()
		var physical_panels := timber != null
		for shutter: Dictionary in shutters:
			usable = (
				usable
				and is_equal_approx(
					float(shutter["panel_width"]) * 2.0, float(shutter["window_width"])
				)
				and int(shutter["planks"]) == 3
			)
			var frame: Transform3D = shutter["transform"]
			var width := float(shutter["window_width"])
			var panel := float(shutter["panel_width"])
			for side: float in [-1.0, 1.0]:
				var hinge := (
					frame
					* Transform3D(
						Basis(Vector3.UP, -side * float(shutter["hinge_angle"])),
						Vector3(
							float(shutter["x"]) + side * (width * .5 + .075),
							float(shutter["bottom"]) + float(shutter["height"]) * .5,
							float(shutter["hinge_depth"])
						)
					)
				)
				for plank: int in 3:
					var x := side * panel * .5 + (plank - 1) * panel / 3.0
					var origin := hinge * Vector3(x, float(shutter["height"]) * .12, 1.0)
					var hit: Dictionary = (
						timber.intersect_ray(origin, -hinge.basis.z) if timber != null else {}
					)
					var local_hit: Vector3 = (
						hinge.affine_inverse() * (hit.get("position", Vector3.ZERO) as Vector3)
					)
					physical_panels = (
						physical_panels and not hit.is_empty() and absf(local_hit.z - .0275) < .003
					)
		check("paired plank shutters can close their measured window " + id, usable)
		check(
			"every shutter plank has a real outward face beside its window " + id, physical_panels
		)
		check(
			"decorative iron and wood do not add a renderer per small part " + id,
			model.find_children("*", "MeshInstance3D", true, false).size() == 6
		)
		model.free()
	var chapel := ArchitectureSceneLibrary.create("chapel")
	add_child(chapel)
	check(
		"chapel fixtures belong to the surrounding town",
		(
			chapel.report.get("craft_family", "") == family
			and chapel.report.get("lanterns", 0) == 2
			and chapel.report["surfaces"] == 5
		)
	)
	chapel.free()
	var fortress := ArchitectureSceneLibrary.create("fortress")
	add_child(fortress)
	check(
		"gate heraldry ties the enclosure to its village",
		(
			fortress.report.get("craft_family", "") == family
			and fortress.report.get("heraldic_plaques", 0) == 8
		)
	)
	check(
		"heraldry preserves the existing four opaque material groups and 38k budget",
		fortress.report["static_surfaces"] == 4 and fortress.report["triangles"] < 38000
	)
	var shells: Array[TriangleMesh] = []
	for node: MeshInstance3D in fortress.report["static_meshes"]:
		shells.append(node.mesh.generate_triangle_mesh())
	var heraldry_visible := true
	for frame: Transform3D in fortress.report.get("heraldic_frames", []):
		var origin := frame * Vector3(0, 0, 1.0)
		var nearest := INF
		for shell: TriangleMesh in shells:
			var hit := shell.intersect_ray(origin, -frame.basis.z)
			if not hit.is_empty():
				nearest = minf(nearest, origin.distance_to(hit["position"]))
		heraldry_visible = heraldry_visible and absf(nearest - .947) < .01
	check("gate shields sit on the exterior rather than being buried in towers", heraldry_visible)
	check(
		"lived-in detail adds no point lights or transparent overlays",
		fortress.find_children("*", "Light3D", true, false).is_empty()
	)
	fortress.free()
