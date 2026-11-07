extends TestCase
## Native actors need animation bounds, not decoded legacy sprite sheets.


func run() -> void:
	var atlas := ActorAtlas.new()
	atlas._load("wolf")
	check("animation metadata is available without loading its large texture",
		not atlas.is_texture_loaded() and atlas.regions.size() > 0 and atlas.anchors.size() == atlas.regions.size()
		and atlas.ref_height > 0.0 and atlas.walk_frame(0.0, 0.4) >= 0)
	var parent := Node2D.new()
	parent.visible = false
	add_child(parent)
	var sprite := ActorSprite.new()
	parent.add_child(sprite)
	sprite.set_frame(atlas, atlas.walk_frame(0.0, 0.0))
	sprite.trigger_flash(SkillDefs.COLD)
	sprite.trigger_squash(0.08)
	await _frames(3)
	sprite.set_frame(atlas, atlas.walk_frame(1.0, 0.6))
	sprite.trigger_flash(SkillDefs.FIRE)
	await _frames(2)
	check("hidden frame changes and real hit feedback do not decode the legacy sheet",
		not atlas.is_texture_loaded() and sprite._flash_overlay == null)
	var region: Rect2 = atlas.regions[sprite.frame]
	var anchor: Vector2 = atlas.anchors[sprite.frame]
	parent.show()
	sprite.trigger_flash(SkillDefs.COLD)
	check("a visible fallback still acquires its original texture and alpha silhouette",
		atlas.is_texture_loaded() and atlas.texture != null
		and sprite._flash_overlay != null and sprite._flash_overlay.texture == atlas.texture
		and sprite._flash_overlay.region == region)
	var factor: float = sprite.body_height / atlas.ref_height
	check("lazy fallback keeps the original frame and foot alignment",
		sprite._flash_overlay.destination == Rect2(-anchor * factor, region.size * factor))
	var original_texture: Texture2D = atlas.texture
	check("repeated explicit consumers share one actual fallback texture", atlas.texture == original_texture)
	atlas.texture = null
	check("an explicit null assignment does not silently reacquire the original sheet", atlas.texture == null and not atlas.is_texture_loaded())
	atlas.texture = original_texture
	parent.hide()
	sprite.trigger_flash(SkillDefs.FIRE)
	check("hiding an already displayed fallback hides its flash without breaking its texture",
		not sprite._flash_overlay.visible and atlas.texture == original_texture)
	parent.queue_free()
	await _frames(2)
	# Check the actual native game path without forcing any new texture getter.
	var before: Dictionary = ActorAtlas.texture_snapshot()
	var game: Node = await make_game()
	for enemy: Enemy in game.enemies:
		enemy.sprite.trigger_flash(SkillDefs.COLD)
	game.player.sprite.trigger_flash(SkillDefs.FIRE)
	await _frames(3)
	var after: Dictionary = ActorAtlas.texture_snapshot()
	check("native hero and monsters retain metadata without allocating hidden atlas textures",
		int(after["metadata_atlases"]) >= int(before["metadata_atlases"])
		and int(after["loaded_textures"]) == int(before["loaded_textures"]))
	game.queue_free()
	await _frames(2)
