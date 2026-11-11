class_name NativeBridgeBuilder
extends RefCounted
## 발판·난간은 기존 경계, 강바닥 기초는 NativeBridgePlan의 실제 부피를 사용한다.
static func _arch(tool: SurfaceTool, centre: Vector3, width: float, rise: float, thickness: float, depth: float) -> void:
	var radius := width * 0.5
	for segment: int in 10:
		var a := PI * segment / 10.0 + 0.008
		var b := PI * (segment + 1) / 10.0 - 0.008
		var p := centre + Vector3(cos(a) * radius, sin(a) * rise, 0)
		var q := centre + Vector3(cos(b) * radius, sin(b) * rise, 0)
		var r := centre + Vector3(cos(a) * (radius + thickness), sin(a) * (rise + thickness), 0)
		var s := centre + Vector3(cos(b) * (radius + thickness), sin(b) * (rise + thickness), 0)
		var front := Vector3(0, 0, depth * 0.5)
		var back := -front
		var middle := (p + q + r + s) * 0.25
		NativeSceneryProps3D._face(tool, p + front, q + front, s + front, r + front, middle)
		NativeSceneryProps3D._face(tool, q + back, p + back, r + back, s + back, middle)
		NativeSceneryProps3D._face(tool, p + back, q + back, q + front, p + front, middle)
		NativeSceneryProps3D._face(tool, s + back, r + back, r + front, s + front, middle)
		NativeSceneryProps3D._face(tool, p + back, p + front, r + front, r + back, middle)
		NativeSceneryProps3D._face(tool, q + front, q + back, s + back, s + front, middle)

static func _box(tool: SurfaceTool, at: Vector3, size: Vector3) -> void:
	NativeSceneryProps3D._box(tool, at, size)

static func build(preview: Node, parent: Node3D) -> Node3D:
	var bridge: Bridge = preview.game.village.bridge
	var deck := bridge.deck_polygon()
	var a := Ortho3DPreview.ground_position(deck[0])
	var b := Ortho3DPreview.ground_position(deck[1])
	var c := Ortho3DPreview.ground_position(deck[3])
	var length := a.distance_to(b)
	var width := a.distance_to(c)
	var root := Node3D.new()
	root.name = "NativeDetailedBridge"
	NativePlayerOcclusion.mark_object(root)
	root.transform = NativeBridgePlan.frame(bridge)
	parent.add_child(root)
	var masonry := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps := SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bays := maxi(2, ceili(length / 1.45))
	var pitch := length / bays
	var arches := 0
	for side: float in [0.0, width]:
		# 기단은 기존 난간 폭 안에 두고 덮개돌을 단차와 줄눈으로 나눈다.
		_box(masonry, Vector3(length * 0.5, 0.18, side), Vector3(length, 0.28, 0.22))
		# 얕은 아케이드 뒤에도 석재를 남겨 기존의 연속 난간 충돌과 일치시킨다.
		_box(caps, Vector3(length * 0.5, 0.59, side), Vector3(length, 0.61, 0.07))
		for bay: int in bays:
			var x := (bay + 0.5) * pitch
			_arch(masonry, Vector3(x, 0.39, side), pitch - 0.28, 0.39, 0.10, 0.18)
			arches += 1
			_box(caps, Vector3(x, 0.96, side), Vector3(pitch - 0.018, 0.10, 0.24))
			_box(caps, Vector3(x, 0.885, side), Vector3(pitch - 0.02, 0.055, 0.205))
			for bar: int in 3:
				_box(iron, Vector3(x + (bar - 1) * (pitch - 0.36) / 4.0, 0.55, side + (0.10 if side == 0.0 else -0.10)), Vector3(0.022, 0.43, 0.025))
		for pier: int in bays + 1:
			var x := pier * pitch
			_box(masonry, Vector3(x, 0.52, side), Vector3(0.22, 0.97, 0.22))
			_box(caps, Vector3(x, 1.04, side), Vector3(0.25, 0.095, 0.25))
			_box(caps, Vector3(x, 1.105, side), Vector3(0.19, 0.035, 0.19))
			# 작은 철제 고정 장식은 실제 입체 부품이다.
			_box(iron, Vector3(x, 0.72, side + (0.12 if side == 0.0 else -0.12)), Vector3(0.075, 0.10, 0.02))
	# 낮은 강바닥까지 내려가는 실제 하부 아치. 보행면은 원래 지면에 접속한다.
	_box(masonry,Vector3(length*0.5,-0.14,width*0.5),Vector3(length,0.28,width))
	for span: int in 2:
		_arch(masonry,Vector3((span+0.5)*length*0.5,-1.70,width*0.5),length*0.5-0.42,1.33,0.28,width-0.06)
	for pier: int in 3:
		_box(masonry,Vector3(pier*length*0.5,-0.85,width*0.5),Vector3(0.46,1.70,width+0.03))
	for part: Dictionary in NativeBridgePlan.foundations(bridge):
		var faces := NativeBridgePlan.faces(part)
		for index in range(0, faces.size(), 3):
			var normal := (faces[index + 2] - faces[index]).cross(faces[index + 1] - faces[index]).normalized()
			NativeLandmarks3D._tri(masonry, faces[index], faces[index + 1], faces[index + 2], normal)
	# 보행면의 높이와 끝점은 공유 충돌의 원래 값에서 바꾸지 않는다.
	for index: int in bays * 2:
		var x := (index + 0.5) * length / (bays * 2)
		_box(paving, Vector3(x, 0.035, width * 0.5), Vector3(length / (bays * 2) - 0.012, 0.03, width - 0.25))
	var metal := (preview._materials["iron"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	metal.metallic = 0.55
	metal.roughness = 0.68
	var triangles := 0
	var index := 0
	for tool: SurfaceTool in [masonry, caps, iron, paving]:
		var mesh := tool.commit()
		var material: Material = [NativeAssetSurface.material("bridge", Vector3.ONE, 0), NativeVillageSurfaces.masonry(1), metal, NativeAssetSurface.material("bridge", Vector3.ONE, 2)][index]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.name = ["PierAndArchStone", "JointedCoping", "IronGrille", "JointedPaving"][index]
		root.add_child(node)
		triangles += mesh.surface_get_array_len(0) / 3
		index += 1
	root.set_meta("bridge_detail", {"deck": deck, "length_m": length, "width_m": width, "bays": bays, "arches": arches, "triangles": triangles, "surfaces": 4, "solid_arcade_backing": true, "deck_height": 0.045, "collision_changes": 1, "opening_guards": true, "foundation_parts": 9})
	return root
