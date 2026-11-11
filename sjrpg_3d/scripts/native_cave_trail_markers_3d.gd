class_name NativeCaveTrailMarkers3D
extends RefCounted
## 표지의 방향·발치는 길 계획과 공유한다. 이동 충돌은 SpatialWorld3D가 만든다.


static func build(preview: Node, parent: Node3D) -> void:
	var wood := NativeVillageSurfaces.oak(true)
	var index := 0
	for plan: Dictionary in NativeCaveTrail.signs(preview.game.village):
		var root := Node3D.new()
		root.name = "CaveTrailSign_%d" % index
		index += 1
		parent.add_child(root)
		root.position = Ortho3DPreview.ground_position(
			plan["point"], preview.surface_height(plan["point"])
		)
		NativePlayerOcclusion.mark_object(root)
		var direction: Vector3 = plan["direction"]
		var rotation := Basis(Vector3.UP, atan2(-direction.z, direction.x))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Dictionary in [
			{"at": Vector3(0, .75, 0), "size": Vector3(.16, 1.5, .16)},
			{"at": Vector3(0, 1.32, 0), "size": Vector3(1.6, .40, .14)}
		]:
			var box := BoxMesh.new()
			box.size = part["size"]
			tool.append_from(box, 0, Transform3D(rotation, part["at"]))
		var mesh := MeshInstance3D.new()
		mesh.mesh = tool.commit()
		mesh.material_override = wood
		root.add_child(mesh)
		var label := Label3D.new()
		label.text = "바람 동굴"
		label.font = UiKit.BOLD_FONT
		label.font_size = 19
		label.outline_size = 4
		label.modulate = Color("e6d6b4")
		label.pixel_size = .012
		label.position = Vector3(0, 1.65, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(label)
