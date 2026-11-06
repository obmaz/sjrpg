extends TestCase
## The flash is an alpha-mask body layer; the original actor and its ground shadow retain their material/tint.

func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var sprite := ActorSprite.new()
	var atlas := ActorAtlas.get_atlas("goblin")
	add_child(sprite)
	sprite.set_frame(atlas, 0)
	check("unhit actors do not allocate flash materials", sprite._flash_overlay == null)
	var body_tint := sprite.tint
	sprite.trigger_flash(SkillDefs.COLD)
	var overlay := sprite._flash_overlay
	check("confirmed flash uses a separate alpha silhouette layer", overlay != null and overlay.material is ShaderMaterial and sprite.material == null and sprite.tint == body_tint)
	var skin := overlay.material as ShaderMaterial
	check("flash paints the actual frame texture at a bounded strength", overlay.texture == atlas.texture and overlay.region == atlas.regions[0] and is_equal_approx(float(skin.get_shader_parameter("flash_strength")), 0.65))
	check("flash remains inside its actor hierarchy for death fade inheritance", overlay.get_parent() == sprite and not overlay.top_level and overlay.modulate == Color.WHITE)
	var frame := mini(1, atlas.regions.size() - 1)
	sprite.set_frame(atlas, frame)
	var factor := sprite.body_height / atlas.ref_height
	check("flash follows changed frame and feet anchor", overlay.region == atlas.regions[frame] and overlay.destination == Rect2(-atlas.anchors[frame] * factor, atlas.regions[frame].size * factor))
	Prefs.reduce_motion = true
	sprite._process(0.0)
	check("reduced motion immediately dims an existing bright flash", float(skin.get_shader_parameter("flash_strength")) <= 0.65 * 0.35 + 0.0001)
	sprite.clear_flash()
	check("clear or revive removes the overlay immediately", not overlay.visible)
	sprite.trigger_flash(SkillDefs.FIRE)
	sprite.set_frame(null, 0)
	check("missing atlas never leaves the previous body silhouette behind", not overlay.visible)
	sprite.queue_free()
	await _frames(2)
	Prefs.reduce_motion = old_reduce
