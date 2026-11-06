class_name Ortho3DStaticBatch
extends RefCounted
## Optional comparison-only batching. Call after constructing static village geometry,
## before adding actors. A material group is culled as one AABB, trading fine object
## culling for fewer draw submissions; this alone makes no frame-rate claim.


static func apply(stage: Node3D) -> Dictionary:
	var groups := {}
	var sources: Array[Dictionary] = []
	var skipped := 0
	var to_stage := stage.global_transform.affine_inverse()
	for candidate in stage.find_children("*", "MeshInstance3D", true, false):
		var node := candidate as MeshInstance3D
		var box := node.mesh as BoxMesh
		if box == null:
			continue
		# Only the presenter's simple, visible, static leaf boxes are eligible.
		# Preserve unusual mesh/render behavior by leaving those instances alone.
		if node.get_child_count() != 0 or node.is_queued_for_deletion() or not node.is_visible_in_tree() or node.material_overlay != null or node.transparency != 0.0 or node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0 or box.subdivide_width != 0 or box.subdivide_height != 0 or box.subdivide_depth != 0 or box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
			skipped += 1
			continue
		var material: Material = node.material_override
		if material == null:
			material = box.surface_get_material(0)
		var material_id := material.get_instance_id() if material != null else 0
		# Layers and flipped winding also affect rendering, so never merge across them.
		var key := "%s:%s:%s:%s" % [material_id, node.cast_shadow, node.layers, box.flip_faces]
		if not groups.has(key):
			groups[key] = {"material": material, "shadow": node.cast_shadow, "layers": node.layers, "flip": box.flip_faces, "instances": [], "margin": 0.0}
		var world := node.global_transform
		var local := to_stage * world * Transform3D(Basis.from_scale(box.size), Vector3.ZERO)
		var entries: Array = groups[key]["instances"]
		var index := entries.size()
		entries.append(local)
		groups[key]["margin"] = maxf(groups[key]["margin"], node.extra_cull_margin)
		# A test can compare all eight unit-box corners after this size transform
		# against the original world transform applied to size/2 corners.
		sources.append({"group": key, "index": index, "world_transform": world, "size": box.size, "batch_transform": local})
		node.hide()
		node.queue_free()
	var batches := {}
	for key: String in groups:
		var group: Dictionary = groups[key]
		var unit := BoxMesh.new()
		unit.size = Vector3.ONE
		unit.flip_faces = group["flip"]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = unit
		var entries: Array = group["instances"]
		multimesh.instance_count = entries.size()
		for index in entries.size():
			multimesh.set_instance_transform(index, entries[index])
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticBoxBatch%d" % batches.size()
		batch.multimesh = multimesh
		batch.material_override = group["material"]
		batch.cast_shadow = group["shadow"]
		batch.layers = group["layers"]
		batch.extra_cull_margin = group["margin"]
		stage.add_child(batch)
		batches[key] = batch
	return {"boxes": sources.size(), "groups": batches.size(), "skipped": skipped, "sources": sources, "batches": batches}


## Dummy's instance setter is a no-op and its getter always returns identity.
## Use the CPU plan there; browser probes verify the actual installed GPU data.
static func corner_error(report: Dictionary, installed := true) -> float:
	var maximum := 0.0
	for source: Dictionary in report["sources"]:
		var batch: MultiMeshInstance3D = report["batches"][source["group"]]
		var local: Transform3D = batch.multimesh.get_instance_transform(int(source["index"])) if installed else source["batch_transform"]
		var actual := batch.global_transform * local
		var original: Transform3D = source["world_transform"]
		var size: Vector3 = source["size"]
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					var corner := Vector3(x, y, z)
					maximum = maxf(maximum, (actual * corner).distance_to(original * (corner * size)))
	return maximum
