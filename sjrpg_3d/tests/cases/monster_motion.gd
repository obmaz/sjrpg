extends TestCase
## The authored return may finish early; the hit and next attack still obey the AI clock.


func run() -> void:
	var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/extract/monster_art_measure.json"))
	for name in Enemy.KINDS:
		var record: Dictionary = review["atlases"][name]
		check("reviewed monster pixels are unchanged: " + name, FileAccess.get_sha256("res://" + str(record["texture"])) == record["texture_sha256"] and FileAccess.get_sha256("res://" + str(record["metadata"])) == record["metadata_sha256"])
		var atlas := ActorAtlas.get_atlas(name)
		check("all eight monster directions retain their authored clips: " + name, atlas.directions == 8 and atlas.frames_per_direction == 8 and atlas.attack_frames == 8 and atlas.regions.size() == 128 and atlas.anchors.size() == 128)
	var game := await make_game()
	game.player.set_process(false)
	game.exploration.set_process(false)
	for boss in [false, true]:
		var enemy := Enemy.new()
		enemy.setup(game, "golem" if boss else "goblin", 1)
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		enemy.set_process(false)
		if boss:
			enemy.make_boss()
		enemy.position = game.player.position + Vector2(45, 0)
		enemy._state = "chase"
		game.player._invulnerable = 0.0
		game.player.hp = game.player.max_hp
		enemy._process(0.001)
		var windup := GameTempo.duration(1.0 if boss else 0.55)
		check("attack uses the accelerated preparation time %s" % boss, enemy._state == "windup" and is_equal_approx(enemy._timer, windup))
		var hp: float = game.player.hp
		enemy._process(windup - 0.01)
		check("animation cannot apply the hit early %s" % boss, game.player.hp == hp)
		var before := enemy.sprite.frame
		enemy._process(0.011)
		check("hit resolves once at the preparation boundary %s" % boss, enemy._state == "recover" and game.player.hp < hp)
		var hit_hp: float = game.player.hp
		enemy._process(0.0)
		check("recovery never replays an earlier attack pose %s" % boss, enemy.sprite.frame >= before)
		var recovery := GameTempo.duration(1.2 if boss else 0.7)
		check("recovery uses the same accelerated clock %s" % boss, is_equal_approx(enemy._timer, recovery))
		enemy._process(GameTempo.duration(0.4 if boss else 0.28) + 0.001)
		check("authored tail reaches neutral without another hit %s" % boss, enemy.sprite.frame == enemy.atlas.attack_frame(enemy.facing, 1.0) and enemy._state == "recover" and game.player.hp == hit_hp)
		enemy._process(enemy._timer - 0.01)
		check("neutral pose still waits for the full recovery %s" % boss, enemy._state == "recover")
		enemy._process(0.011)
		check("next chase only starts after the full recovery %s" % boss, enemy._state == "chase")
		game.enemies.erase(enemy)
		enemy.queue_free()
		await _frames(2)
	game.queue_free()
	await _frames(2)
