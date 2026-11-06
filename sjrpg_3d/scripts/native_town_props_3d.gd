class_name NativeTownProps3D
extends RefCounted
## Source adapters keep interactions/collision; shared native assets own the picture.
## Water/portal motion observes each original PlazaWater phase, including pause/reduced motion.

const FOUNTAIN := "res://assets/art/preview3d/native-fountain.glb"
const PORTAL := "res://assets/art/preview3d/native-warp-gate.glb"
const WATER_SHADER := preload("res://scripts/native_prop_water.gdshader")
const PORTAL_SHADER := preload("res://scripts/native_prop_portal.gdshader")
const MOTE_COUNT := 12
const FOUNTAIN_SIZE := Vector3(2.60, 1.94, 2.60)
const PORTAL_SIZE := Vector3(3.098, 3.065, 1.28)

var _preview: Node
var _game: Node
var _scenes := {}
var _materials := {}
var _entries := {}
var _mote_mesh: SphereMesh


func setup(presenter: Node, material_map: Dictionary = {}) -> NativeTownProps3D:
	_preview = presenter
	_game = presenter.game
	_materials = material_map.duplicate()
	for pair in [["fountain", FOUNTAIN], ["portal", PORTAL]]:
		if ResourceLoader.exists(pair[1]):
			_scenes[pair[0]] = load(pair[1])
	if not _materials.has("bronze"):
		var bronze := StandardMaterial3D.new()
		bronze.albedo_color = Color("66553e")
		bronze.metallic = 0.45
		bronze.roughness = 0.72
		_materials["bronze"] = bronze
	var mote := StandardMaterial3D.new()
	mote.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mote.vertex_color_use_as_albedo = true
	mote.albedo_color = Color(0.18, 0.61, 0.68)
	_materials["motes"] = mote
	_mote_mesh = SphereMesh.new()
	_mote_mesh.radius = 0.012
	_mote_mesh.height = 0.024
	_mote_mesh.radial_segments = 6
	_mote_mesh.rings = 3
	_mote_mesh.material = mote
	return self


## Call before building/synchronizing either source-art fallback batch.
func sync() -> void:
	var current := {}
	var cave: bool = _game.dungeon.active
	var source_world: Node = _game.world if cave else _game.village.fountain.get_parent()
	if not cave:
		_sync_source(_game.village.fountain, "fountain", current)
	for child in source_world.get_children():
		if child is IsoSprite and str(child.def.get("sheet", "")).ends_with("/remake-portal.webp"):
			_sync_source(child, "portal", current)
	for id in _entries.keys():
		if not current.has(id):
			(_entries[id]["root"] as Node3D).queue_free()
			_entries.erase(id)


func owns(source: Node) -> bool:
	return is_instance_valid(source) and _entries.has(source.get_instance_id())


func source_ids() -> Dictionary:
	var result := {}
	for id in _entries:
		result[id] = true
	return result


func _sync_source(source: IsoSprite, role: String, current: Dictionary) -> void:
	if not is_instance_valid(source) or not _scenes.has(role):
		return  # Existing art remains available until the reviewed native asset exists.
	var id := source.get_instance_id()
	var footprint: PackedVector2Array = source.atlas_polygon(_game.village.data["frames"]["pool"]["ground"]) if role == "fountain" else Village.portal_base(source)
	var centre := Vector2.ZERO
	for at in footprint:
		centre += at
	centre /= footprint.size()
	var edge := Ortho3DPreview.ground_position(footprint[1]) - Ortho3DPreview.ground_position(footprint[0])
	var side := Ortho3DPreview.ground_position(footprint[2]) - Ortho3DPreview.ground_position(footprint[1])
	var model_size := FOUNTAIN_SIZE if role == "fountain" else PORTAL_SIZE
	if model_size.x > edge.length() + 0.001 or model_size.z > side.length() + 0.001:
		return  # Never stretch one axis or silently protrude outside the existing collision.
	current[id] = true
	if not _entries.has(id):
		_entries[id] = _create(source, role)
	var entry: Dictionary = _entries[id]
	var root: Node3D = entry["root"]
	root.position = Ortho3DPreview.ground_position(centre, _preview.surface_height(centre))
	root.rotation.y = -atan2(edge.z, edge.x)
	root.visible = source.visible
	var phase := _source_phase(source)
	var motion := 0.0 if Prefs.reduce_motion else 1.0
	var fluid: ShaderMaterial = entry["fluid"]
	fluid.set_shader_parameter("phase", phase)
	fluid.set_shader_parameter("motion", motion)
	if role == "portal":
		fluid.set_shader_parameter("strength", 0.50 if Prefs.reduce_motion else 0.80)
		_sync_motes(entry["motes"], phase, motion)


func _create(source: IsoSprite, role: String) -> Dictionary:
	var scene: PackedScene = _scenes[role]
	var root := scene.instantiate() as Node3D
	root.name = "NativeFountain" if role == "fountain" else "NativeWarpGate"
	_preview.stage.add_child(root)
	var fluid := ShaderMaterial.new()
	fluid.shader = WATER_SHADER if role == "fountain" else PORTAL_SHADER
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var slot := str(mesh.name).to_lower()
		if slot == "limestone":
			mesh.material_override = _materials["stone"]
		elif slot == "timber":
			mesh.material_override = _materials["wood"]
		elif slot == "bronze":
			mesh.material_override = _materials["bronze"]
		elif slot in ["water", "portal"]:
			mesh.material_override = fluid
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.set_meta("exclude_static_batch", true)
	var motes: MultiMeshInstance3D
	if role == "portal":
		motes = MultiMeshInstance3D.new()
		motes.name = "PortalMotes"
		motes.multimesh = MultiMesh.new()
		motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		motes.multimesh.use_colors = true
		motes.multimesh.mesh = _mote_mesh
		motes.multimesh.instance_count = MOTE_COUNT
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		motes.set_meta("exclude_static_batch", true)
		root.add_child(motes)
	return {"root": root, "role": role, "source": weakref(source), "fluid": fluid, "motes": motes}


func _source_phase(source: IsoSprite) -> float:
	if Prefs.reduce_motion:
		return 0.0
	for child in source.get_children():
		if child is PlazaWater:
			return child.phase
	return 0.0


func _sync_motes(node: MultiMeshInstance3D, phase: float, motion: float) -> void:
	for index in MOTE_COUNT:
		var t := fmod(float(index) / MOTE_COUNT + phase * 0.055 * motion, 1.0)
		var angle := TAU * float(index) * 0.61803398875
		var at := Vector3(sin(angle) * 0.68, 0.30 + t * 2.05, 0.07 + cos(angle) * 0.075)
		var fade := sin(t * PI) * (0.25 if motion == 0.0 else 0.45)
		node.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
		node.multimesh.set_instance_color(index, Color(0.45, 0.82, 0.88, fade))
