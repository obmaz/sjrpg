extends TestCase
## Verify source-backed, ground-only shadows without pretending the billboard has 3D volume.


func run() -> void:
	var village := Village.new()
	var definition: Dictionary = village.data["sprites"]["tree-11"]
	var fixture := Node2D.new()
	add_child(fixture)
	var world := Node2D.new()
	world.position = Vector2(50, 20)
	world.rotation = 0.08
	world.scale = Vector2(1.1, 0.9)
	fixture.add_child(world)
	var ground := Node2D.new()
	ground.transform = Iso.ground_transform()
	ground.position = Vector2(-40, 80)
	fixture.add_child(ground)
	var tree := IsoSprite.new().setup(definition, float(definition["world_height"]))
	tree.position = Vector2(180, 100)
	world.add_child(tree)
	var shade := CanopyShade.attach(tree, ground)
	var raw_foot: Array = definition["foot"]
	var foot := Vector2(raw_foot[0], raw_foot[1])
	check("shade reuses the actual tree atlas cell", shade._texture == tree.texture and shade._source == Rect2(definition["source"][0], definition["source"][1], definition["source"][2], definition["source"][3]))
	var source_ink := shade.material as ShaderMaterial
	check("shade sampler binds the exact caster atlas", source_ink.get_shader_parameter("canopy_alpha") == tree.texture)
	check("shade attaches at the actual foot across projected parent coordinates", shade.projected_point(foot).is_equal_approx(tree.global_position))
	check("shade draws below actors and raised terrain", shade.z_index == -8 and not shade.z_as_relative)
	var crown := shade.projected_point(foot - Vector2(0, 100)) - tree.global_position
	check("upper-left light casts the crown down and right", crown.x > 0 and crown.y > 0)
	var revision := shade.refresh_count
	for i in 10:
		shade.refresh()
	check("static trees do not rebuild their projection", shade.refresh_count == revision)
	check("duplicate registration cannot darken the same tree twice", CanopyShade.attach(tree, ground) == shade)
	tree.position += Vector2(45, -20)
	tree.scale = Vector2(1.25, 0.8)
	tree.flip = true
	shade.refresh()
	check("movement scale and flip preserve the contact anchor", shade.projected_point(foot).is_equal_approx(tree.global_position) and shade.refresh_count == revision + 1)
	var side := shade.projected_point(foot + Vector2(80, 0)) - tree.global_position
	check("flipped source width follows the visible caster", side.dot(tree.global_transform.x) < 0)
	shade.sun_direction = Vector2(-0.7, 0.5)
	shade.refresh()
	crown = shade.projected_point(foot - Vector2(0, 100)) - tree.global_position
	check("changing the shared light updates the projection", crown.x < 0 and crown.y > 0)
	var old_low := Prefs.low_resolution
	var old_motion := Prefs.reduce_motion
	Prefs.low_resolution = true
	Prefs.reduce_motion = true
	shade.refresh()
	var ink := shade.material as ShaderMaterial
	check("economy quality uses the cheaper silhouette sampler", bool(ink.get_shader_parameter("economy")))
	var held := shade.global_transform
	revision = shade.refresh_count
	shade.refresh()
	check("reduced motion keeps a static owner-linked shade", shade.global_transform == held and shade.refresh_count == revision)
	get_tree().paused = true
	tree.position += Vector2(30, 0)
	await _frames(2)
	check("menu pause does not run projection updates", shade.refresh_count == revision)
	get_tree().paused = false
	await _frames(2)
	check("resume resynchronizes the caster contact", shade.projected_point(foot).is_equal_approx(tree.global_position))
	tree.hide()
	shade.refresh()
	check("hidden casters cannot leave floating shade", not shade.visible)
	tree.show()
	for index in CanopyShade.MAX_TOWN_CASTERS:
		var extra := IsoSprite.new().setup(definition, float(definition["world_height"]))
		world.add_child(extra)
		var added := CanopyShade.attach(extra, ground)
		check("town shade budget remains bounded %d" % index, (added != null) == (index < CanopyShade.MAX_TOWN_CASTERS - 1))
	tree.queue_free()
	await _frames(3)
	check("removing the caster also removes its shade", not is_instance_valid(shade))
	Prefs.low_resolution = old_low
	Prefs.reduce_motion = old_motion
	fixture.queue_free()
	await _frames(2)
