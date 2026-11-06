class_name ForestLighting
extends Node2D
## Two bounded daylight openings on textured ground. Actors, water, HUD and the
## cave retain their own materials. Tree shadows use the actual canopy casters.

const SHADE_OPACITY := 0.26
const BASE_SHADE_OPACITY := 0.11
const SHADER_CODE := GroundEdges.SHADER_CODE

var surfaces: Array[CanvasItem] = []
var openings := PackedVector2Array()
var shades: Array[CanopyShade] = []
var ground_material: ShaderMaterial
var materials: Array[ShaderMaterial] = []
var root_floor: Dictionary = {}
var enabled := true


func setup(receiver: Node2D, village: Village) -> ForestLighting:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	ground_material = ShaderMaterial.new()
	ground_material.shader = shader
	ground_material.set_shader_parameter("edge_soil", ForestArt.texture("earth"))
	# Keep feature defaults explicit for cloned materials and headless inspection.
	ground_material.set_shader_parameter("edge_enabled", false)
	ground_material.set_shader_parameter("root_enabled", false)
	materials.append(ground_material)
	# These openings stay in the world as the camera moves. The ellipse represents
	# a light footprint on the projected ground, not a perspective change to art.
	openings.append(village.chapel_steps[0] + Vector2(-40, 95))
	openings.append(village.fountain.position + Vector2(0, 35))
	ground_material.set_shader_parameter("opening_a", openings[0])
	ground_material.set_shader_parameter("opening_b", openings[1])
	root_floor = GroundEdges.root_record(receiver, village)
	_bind_surfaces(receiver)
	set_enabled(true)
	return self


func _bind_surfaces(node: Node) -> void:
	if node is CanopyShade:
		shades.append(node)
	elif node is Sprite2D or node is Polygon2D:
		var surface := node as CanvasItem
		var texture: Texture2D = node.texture
		if surface.material == null and texture in [ForestArt.texture("grass"), ForestArt.texture("paving"), ForestArt.texture("earth")]:
			var ink := ground_material
			if node is Polygon2D:
				ink = GroundEdges.material_for(node, ground_material)
			elif texture == ForestArt.texture("grass") and not root_floor.is_empty():
				ink = ground_material.duplicate() as ShaderMaterial
				ink.set_shader_parameter("root_enabled", true)
				ink.set_shader_parameter("root_mask", root_floor["texture"])
				ink.set_shader_parameter("root_origin", root_floor["origin"])
				ink.set_shader_parameter("root_extent", root_floor["extent"])
				ink.set_shader_parameter("root_inverse_basis", root_floor["inverse_basis"])
				ink.set_shader_parameter("root_inverse_origin", root_floor["inverse_origin"])
			if ink != ground_material:
				materials.append(ink)
			surface.material = ink
			surfaces.append(surface)
	for child in node.get_children():
		_bind_surfaces(child)


func set_enabled(value: bool) -> void:
	enabled = value
	for ink in materials:
		ink.set_shader_parameter("amount", 1.0 if value else 0.0)
	for shade in shades:
		if is_instance_valid(shade):
			shade.opacity = SHADE_OPACITY if value else BASE_SHADE_OPACITY
			shade.refresh()
