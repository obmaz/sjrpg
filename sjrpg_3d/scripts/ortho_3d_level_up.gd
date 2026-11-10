class_name Ortho3DLevelUp
extends RefCounted
## Native presentation of the real level-up RewardFx; the source owns every clock.

const MAX_ACTIVE := 2
const SPARK_COUNT := 8
const ATLAS := preload("res://assets/art/effects/reward-atlas.webp")
## Existing generated gold-star pixels, cropped from the reward atlas's first cell.
const GOLD_STAR := Rect2(110, 96, 48, 48)

var _preview: Node
var _entries := {}


func setup(presenter: Node) -> Ortho3DLevelUp:
	_preview = presenter
	return self


func sync() -> void:
	var current := {}
	var sources: Array = _preview.game.cosmetic_effects
	for index in range(sources.size() - 1, -1, -1):
		var source = sources[index]
		if not is_instance_valid(source) or source.is_queued_for_deletion() or source.kind != "reward" or not source.params.get("large", false) or source.age >= source.life:
			continue
		# Inactive forest sources retain their paused clocks during a cave visit.
		if source.get_parent() != _preview.game.world:
			continue
		var id: int = source.get_instance_id()
		current[id] = true
		if not _entries.has(id):
			_entries[id] = _create(source)
		_update(_entries[id], source)
		if current.size() >= MAX_ACTIVE:
			break
	for id in _entries.keys():
		if not current.has(id):
			var entry: Dictionary = _entries[id]
			(entry["root"] as Node3D).queue_free()
			_entries.erase(id)


func _create(source: Effect) -> Dictionary:
	var root := Node3D.new()
	root.name = "WaypointDiscovery" if source.params.has("waypoint_position") else "LevelUpCelebration"
	_preview.stage.add_child(root)
	var ring := MeshInstance3D.new()
	ring.name = "FootRing"
	var torus := TorusMesh.new()
	torus.inner_radius = NativeWaypoint3D.RADIUS+0.15 if source.params.has("waypoint_position") else 0.70
	torus.outer_radius = torus.inner_radius+0.06
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	ring.position.y = 0.035
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ink.emission_enabled = true
	ink.emission = Color(1.0, 0.64, 0.14)
	ink.emission_energy_multiplier = 1.0
	ring.material_override = ink
	root.add_child(ring)
	var sparks: Array[MeshInstance3D] = []
	for index in SPARK_COUNT:
		var spark: MeshInstance3D = _preview._new_card(ATLAS, GOLD_STAR, true)
		spark.name = "GoldSpark%d" % index
		spark.reparent(root, false)
		(spark.mesh as QuadMesh).size = Vector2.ONE * (0.20 + float(index % 3) * 0.035)
		sparks.append(spark)
	return {"root": root, "ring": ring, "sparks": sparks, "source": weakref(source)}


func _update(entry: Dictionary, source: Effect) -> void:
	var waypoint := source.params.has("waypoint_position")
	var foot := source.position + Vector2(0, 32)
	if waypoint:
		foot = source.params["waypoint_position"]
	elif is_instance_valid(source.owner_node):
		foot = source.owner_node.position
	var root: Node3D = entry["root"]
	var spatial = _preview.game.get("spatial_world")
	if is_instance_valid(source.owner_node) and is_instance_valid(spatial):
		root.position = spatial.actor_foot(source.owner_node)
	else:
		root.position = Ortho3DPreview.ground_position(foot, _preview.surface_height(foot))
	var phase := clampf(source.age / maxf(source.life, 0.001), 0.0, 1.0)
	var pose := 0.25 if Prefs.reduce_motion else phase
	var alpha := pow(1.0 - phase, 0.9) * (0.35 if Prefs.reduce_motion else 0.85)
	var ring: MeshInstance3D = entry["ring"]
	var radius := 1.0 if Prefs.reduce_motion else lerpf(0.86, 1.14, phase)
	ring.scale = Vector3(radius, 1.0, radius)
	var ring_ink := ring.material_override as StandardMaterial3D
	ring_ink.albedo_color = Color(1.0, 0.76, 0.24, alpha * 0.65)
	for index in SPARK_COUNT:
		var spark: MeshInstance3D = entry["sparks"][index]
		var angle := TAU * float(index) / SPARK_COUNT + pose * 0.22
		var spread := 0.50 + float(index % 2) * 0.12 + pose * 0.08
		if waypoint:
			spread = NativeWaypoint3D.RADIUS+0.12+pose*0.32
		var height := 0.14 + float(index % 3) * 0.16 + pose * (1.40 + float(index % 3) * 0.15)
		spark.position = Vector3(cos(angle) * spread, height, sin(angle) * spread)
		spark.basis = _preview.camera.global_transform.basis
		var ink := spark.material_override as ShaderMaterial
		ink.set_shader_parameter("tint", Color(1.0, 0.82, 0.36, alpha))
