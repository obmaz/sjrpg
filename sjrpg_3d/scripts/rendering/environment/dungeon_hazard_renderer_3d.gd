class_name DungeonHazardRenderer3D
extends RefCounted


## 공유 GLB와 8개 재사용 화염 입자만 사용한다. 새 타이머/피해 판정은 만들지 않는다.
class Display:
	extends RefCounted
	var trap: DungeonTrap
	var root: Node3D
	var spikes: Node3D
	var area: MeshInstance3D
	var ink: ShaderMaterial
	var fire: MultiMeshInstance3D
	var glow: MeshInstance3D


const ROOT := "res://assets/models/environment/traps/"
var renderer: Node
var displays: Array[Display] = []
static var _scenes: Dictionary = {}


func setup(presenter: Node, parent: Node3D) -> DungeonHazardRenderer3D:
	renderer = presenter
	for trap: DungeonTrap in renderer.game.dungeon.hazards.traps:
		var id: String = "flame_vent" if trap.kind == "flame" else "spikes"
		if not _scenes.has(id):
			_scenes[id] = load(ROOT + id + "/visual.tscn")
		var scene: PackedScene = _scenes[id]
		var root := scene.instantiate() as Node3D
		root.name = "Trap_" + trap.id
		root.set_meta("exclude_static_batch", true)
		parent.add_child(root)
		root.rotation.y = atan2(trap.direction.x, trap.direction.y)
		var display := Display.new()
		display.trap = trap
		display.root = root
		display.spikes = root.find_child("Spikes", true, false) as Node3D
		display.ink = ShaderMaterial.new()
		display.ink.shader = load("res://assets/models/environment/traps/shared/warning.gdshader")
		display.area = MeshInstance3D.new()
		display.area.mesh = _area_mesh(trap)
		display.area.material_override = display.ink
		display.area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(display.area)
		if trap.kind == "flame":
			_fire_setup(display)
		displays.append(display)
	sync()
	return self


static func _area_mesh(trap: DungeonTrap) -> ArrayMesh:
	var near := DungeonTrap.NOZZLE if trap.kind == "flame" else -trap.length * .5
	var far := near + trap.length
	var first_width := .20 if trap.kind == "flame" else trap.width * .5
	var points: Array[Vector3] = [
		Vector3(-first_width, .025, near),
		Vector3(first_width, .025, near),
		Vector3(trap.width * .5, .025, far),
		Vector3(-trap.width * .5, .025, far)
	]
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(Vector3.UP)
		tool.set_uv(uvs[index])
		tool.add_vertex(points[index])
	return tool.commit()


func _fire_setup(display: Display) -> void:
	var fire := MultiMeshInstance3D.new()
	var particles := MultiMesh.new()
	particles.transform_format = MultiMesh.TRANSFORM_3D
	particles.use_colors = true
	particles.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.mesh = quad
	particles.instance_count = 8
	fire.multimesh = particles
	var ink := ShaderMaterial.new()
	ink.shader = load("res://assets/models/environment/traps/shared/flame.gdshader")
	ink.set_shader_parameter("fire_atlas", load("res://assets/effects/textures/combat-frames.webp"))
	fire.material_override = ink
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.root.add_child(fire)
	display.fire = fire
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .07
	sphere.height = .14
	sphere.radial_segments = 8
	sphere.rings = 3
	glow.mesh = sphere
	var ember := StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = Color(1, .40, .08)
	glow.material_override = ember
	glow.position = Vector3(0, .80, DungeonTrap.NOZZLE + .01)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.root.add_child(glow)
	display.glow = glow


func sync() -> void:
	var hazards: DungeonHazards = renderer.game.dungeon.hazards
	if hazards == null or not renderer.game.dungeon.active:
		return
	for display in displays:
		var trap := display.trap
		display.root.position = WorldRenderer3D.ground_position(
			trap.position, DungeonRelief.at(trap.position)
		)
		var ink := Color(.08, .07, .05, .28)
		display.area.visible = trap.kind == "flame" or trap.phase != DungeonTrap.Phase.REST
		if trap.phase == DungeonTrap.Phase.WARNING:
			var pulse := 1.0 if Prefs.reduce_motion else .7 + .3 * pow(sin(hazards.clock * 8), 2)
			ink = Color(1, .63, .16, pulse)
		elif trap.phase == DungeonTrap.Phase.ACTIVE:
			ink = Color(1, .19, .05, .9)
		elif trap.phase == DungeonTrap.Phase.RECOVER:
			ink = Color(.3, .32, .3, .5)
		display.ink.set_shader_parameter("ink", ink)
		if display.spikes != null:
			display.spikes.position.y = -1.06 * (1.0 - trap.strength())
		if display.fire != null:
			_sync_fire(display, hazards.clock)


func _sync_fire(display: Display, clock: float) -> void:
	var trap := display.trap
	var power := trap.strength()
	display.fire.visible = power > .01
	display.glow.visible = trap.phase != DungeonTrap.Phase.REST
	var size := .8 if trap.phase == DungeonTrap.Phase.WARNING else 1.4 * power
	display.glow.scale = Vector3.ONE * maxf(.1, size)
	if power <= .01:
		return
	var camera_basis: Basis = display.root.global_basis.inverse() * renderer.camera.global_basis
	for index in 8:
		var along := fmod(clock * 1.6 + index / 8.0, 1.0)
		var radius := lerpf(.18, .68, along) * power
		var bob := 0.0 if Prefs.reduce_motion else sin(clock * 7 + index) * radius * .12
		var at := Vector3(bob, .80 + bob, DungeonTrap.NOZZLE + along * trap.length * power)
		display.fire.multimesh.set_instance_transform(
			index, Transform3D(camera_basis.scaled(Vector3(radius * 2, radius * 2, 1)), at)
		)
		display.fire.multimesh.set_instance_color(index, Color(1, 1, 1, power * (1.0 - along * .4)))
		display.fire.multimesh.set_instance_custom_data(
			index, Color(fmod(floor(clock * 14 + index * .7), 4.0) / 4.0, 0, 0, 0)
		)


func snapshot() -> Array:
	var result: Array = []
	if not renderer.game.dungeon.active:
		return result
	for display in displays:
		var trap := display.trap
		result.append(
			{
				"id": trap.id,
				"kind": trap.kind,
				"phase": trap.phase,
				"age": trap.age,
				"activation": trap.activation,
				"position": [trap.position.x, trap.position.y],
				"height": display.root.position.y,
				"spike_y": display.spikes.position.y if display.spikes != null else null,
				"fire_visible": display.fire.visible if display.fire != null else false,
				"particles": display.fire.multimesh.instance_count if display.fire != null else 0
			}
		)
	return result
