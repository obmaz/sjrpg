extends TestCase
## Exercise the real skill callbacks: authored sprites must never become another hitbox.


class ContactProbe:
	extends Enemy
	var contacts := 0
	var contact_stop_seen := false
	var dodge_on_first := false

	func take_damage(amount: float, source: Node2D, visual_source: Node2D = null) -> void:
		var before := hp
		super.take_damage(amount, source, visual_source)
		if hp < before:
			contacts += 1
			if source is Player:
				contact_stop_seen = contact_stop_seen or source._hitstop.remaining > 0.0
				if dodge_on_first and contacts == 1:
					source.try_roll()


func run() -> void:
	var previous := Prefs.reduce_motion
	Prefs.reduce_motion = false
	_check_art_contract()
	_check_frost_caster_gap()
	await _check_warrior_contacts()
	await _check_frost_and_cosmetic_clocks()
	await _check_meteor_transition()
	Prefs.reduce_motion = previous


func _check_art_contract() -> void:
	var data := ReferenceFxArt.data()
	for source: Dictionary in data["sources"]:
		check("authored skill source matches reviewed pixels", FileAccess.get_sha256("res://" + str(source["path"])) == str(source["sha256"]))
	for key in ["reference", "generation"]:
		var record: Dictionary = data[key]
		check("authored skill %s provenance matches reviewed inputs" % key, FileAccess.get_sha256("res://" + str(record["path"])) == str(record["sha256"]))
	var atlas: Dictionary = data["atlas"]
	var path := "res://" + str(atlas["path"])
	check("runtime authored skill atlas matches reviewed pixels", FileAccess.get_sha256(path) == str(atlas["sha256"]))
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	var cell := int(atlas["cell"])
	check("six authored effects retain four temporal frames", int(atlas["columns"]) == 4 and int(atlas["rows"]) == 6 and data["effects"].size() == 6 and str(atlas["blend"]) == "add")
	check("authored atlas dimensions match every cell", image.get_size() == Vector2i(cell * 4, cell * 6))
	for name in ["slash", "spin", "slam", "bolt", "frost", "meteor"]:
		var effect: Dictionary = data["effects"][name]
		var effect_image := ReferenceFxArt.texture(name).get_image()
		if effect.has("override"):
			var replacement: Dictionary = effect["override"]
			check("adopted replacement pixels match the runtime override", FileAccess.get_sha256("res://" + str(replacement["path"])) == str(replacement["sha256"]))
		var padding_clear := true
		var energies: Array[float] = []
		for column in 4:
			var origin := Vector2i(ReferenceFxArt.frame(name, column).position)
			for along in range(cell):
				for inset in 3:
					for offset in [Vector2i(along, inset), Vector2i(along, cell - 1 - inset), Vector2i(inset, along), Vector2i(cell - 1 - inset, along)]:
						var pixel := effect_image.get_pixelv(origin + offset)
						padding_clear = padding_clear and maxf(pixel.r, maxf(pixel.g, pixel.b)) <= 0.04
			var energy := 0.0
			for y in range(0, cell, 8):
				for x in range(0, cell, 8):
					var pixel := effect_image.get_pixelv(origin + Vector2i(x, y))
					energy += pixel.r + pixel.g + pixel.b
			energies.append(energy)
		check("authored %s frames keep black ADD padding" % name, padding_clear)
		check("authored %s tail loses energy after its peak" % name, energies[1] > 1.0 and energies[3] < energies[1])
		if name == "frost":
			check("frost shatter ends in a sparse quiet tail", energies[3] < energies[1] * 0.2)
	var frost_peak: Array = data["effects"]["frost"]["frame_bounds"][1]
	var crown_ratio := float(frost_peak[3] - frost_peak[1]) / float(frost_peak[2] - frost_peak[0])
	check("frost keeps the reviewed low broad silhouette", crown_ratio > 0.55 and crown_ratio < 0.9)


## Sample the actual standing torso area in world draw units, not just an empty
## atlas corner. A new central crystal pillar must fail this readability guard.
func _check_frost_caster_gap() -> void:
	var image := ReferenceFxArt.texture("frost").get_image()
	var target := ReferenceFxArt.rect("frost", 280.0)
	for column in 4:
		var frame := ReferenceFxArt.frame("frost", column)
		var energy := 0.0
		var bright := 0
		var samples := 0
		for y in range(-95, -29, 3):
			for x in range(-18, 19, 3):
				var uv := (Vector2(x, y) - target.position) / target.size
				var pixel := image.get_pixelv(Vector2i(frame.position + uv * frame.size))
				var luminance := pixel.get_luminance()
				energy += luminance
				bright += 1 if luminance > 0.18 else 0
				samples += 1
		check("frost phase %d leaves the caster torso readable" % column, energy / samples < 0.04 and float(bright) / samples < 0.08)


func _target(game: Node, at: Vector2) -> ContactProbe:
	var enemy := ContactProbe.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = at
	enemy.max_hp = 100000.0
	enemy.hp = enemy.max_hp
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	return enemy


func _authored(game: Node, key: String) -> Array:
	return game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "skill_fx" and effect.params.get("visual", "") == key)


func _check_warrior_contacts() -> void:
	var game := await make_game()
	var hero: Player = game.player
	hero.set_process(false)
	hero.facing = 0.0
	var enemy := _target(game, hero.position + Vector2(45, 0))
	var before := enemy.hp
	check("weapon reference attack starts through the real slot", hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.44)
	check("crescent does not precede the actual weapon contact", enemy.hp == before and not game.cosmetic_effects.any(func(effect) -> bool: return effect.kind == "slash"))
	seed(22017)
	var expected := hero.damage_for("cleave", SkillDefs.scaled(1.0, 0.06, GameState.effective_rank("cleave")))
	seed(22017)
	hero._process(hero._attack_duration * 0.02)
	var slashes: Array = game.cosmetic_effects.filter(func(effect) -> bool: return effect.kind == "slash")
	check("weapon contact emits exactly one authored crescent", slashes.size() == 1 and enemy.contacts == 1)
	check("crescent preserves the resolved weapon damage", is_equal_approx(before - enemy.hp, expected))
	if not slashes.is_empty():
		var slash: Effect = slashes[0]
		var profile := hero.weapon_melee()
		check("crescent uses the equipped weapon reach and half-angle", is_equal_approx(slash.radius, float(profile["range"])) and is_equal_approx(float(slash.params["arc"]), float(profile["arc"])))
		var hp_after_contact := enemy.hp
		slash._process(0.6)
		check("slow first frame still presents the crescent without damage", not slash.is_queued_for_deletion() and slash.age < slash.life and enemy.hp == hp_after_contact)
		slash._process(0.6)
		check("crescent expires after its bounded first update", slash.is_queued_for_deletion())

	hero._cancel_actions()
	enemy.contacts = 0
	enemy.contact_stop_seen = false
	enemy.dodge_on_first = true
	var spin := hero._prepare("whirlwind", SkillDefs.get_def("whirlwind"), 1)
	spin.call()
	var spins := _authored(game, "spin")
	check("one native whirlwind creates one continuous authored sweep", spins.size() == 1)
	var sweep: Effect = spins[0] if not spins.is_empty() else null
	await get_tree().create_timer(0.35, false).timeout
	check("actual whirlwind contact gives the attacker a contact stop", enemy.contact_stop_seen)
	check("dodge after the first contact cancels remaining whirlwind ticks", enemy.contacts == 1 and hero._roll_time > 0.0)
	check("cancelled whirlwind cannot leave its sweep behind", not is_instance_valid(sweep) or sweep.is_queued_for_deletion())

	hero._cancel_actions()
	hero._roll_cooldown = 0.0
	enemy.contacts = 0
	enemy.dodge_on_first = false
	spin = hero._prepare("whirlwind", SkillDefs.get_def("whirlwind"), 1)
	spin.call()
	await get_tree().create_timer(0.35, false).timeout
	check("uninterrupted whirlwind retains its three native damage ticks", enemy.contacts == int(SkillDefs.get_def("whirlwind")["ticks"]))
	hero._cancel_actions()
	enemy.contacts = 0
	enemy.contact_stop_seen = false
	var landing := hero._prepare("leapAttack", SkillDefs.get_def("leapAttack"), 1)
	check("targeted leap prepares without a premature landing plume", landing.is_valid() and _authored(game, "slam").is_empty())
	before = enemy.hp
	seed(94013)
	expected = hero.damage_for("leapAttack", float(SkillDefs.get_def("leapAttack")["mult"]))
	seed(94013)
	landing.call()
	var slams := _authored(game, "slam")
	check("actual targeted landing emits one grounded slam and one hit", slams.size() == 1 and enemy.contacts == 1 and is_equal_approx(before - enemy.hp, expected))
	check("damaging landing gives its attacker a contact stop", enemy.contact_stop_seen)
	if not slams.is_empty():
		var slam: Effect = slams[0]
		check("landing plume keeps the real landing contact", slam.position.is_equal_approx(hero.position))
		before = enemy.hp
		slam._process(0.1)
		check("landing artwork never repeats its resolved damage", enemy.hp == before and enemy.contacts == 1 and slam.damage == 0.0)
	game.queue_free()
	await _frames(2)


func _check_frost_and_cosmetic_clocks() -> void:
	var game := await make_game("mage")
	var hero: Player = game.player
	hero.set_process(false)
	var enemy := _target(game, hero.position + Vector2(70, 0))
	var definition := SkillDefs.get_def("frostNova")
	var frost := hero._prepare("frostNova", definition, 1)
	var before := enemy.hp
	seed(7721)
	var expected := hero.damage_for("frostNova", float(definition["mult"]))
	seed(7721)
	frost.call()
	var bursts := _authored(game, "frost")
	check("native frost nova creates one shard burst for the cast", bursts.size() == 1 and enemy.contacts == 1)
	check("frost artwork preserves native damage and slow", is_equal_approx(before - enemy.hp, expected) and is_equal_approx(enemy._slow_time, float(definition["slow"])))
	if not bursts.is_empty():
		var burst: Effect = bursts[0]
		var blend := burst.material as CanvasItemMaterial
		check("authored raised frost uses ADD without a black plate", blend != null and blend.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
		var hp_after_contact := enemy.hp
		burst._process(0.01)
		var first_phase := burst.visual_phase()
		burst._process(0.04)
		check("authored skill frames advance on the cosmetic clock only", burst.visual_phase() > first_phase and enemy.hp == hp_after_contact and burst.damage == 0.0)
		game.hud.open_settings()
		var paused_age := burst.age
		await _frames(3)
		check("menu pause freezes the authored skill lifetime", burst.age == paused_age)
		game.hud.close_panel()
		Prefs.reduce_motion = true
		var still_phase := burst.visual_phase()
		burst._process(0.03)
		check("reduced motion holds one authored pose while its lifetime advances", burst.visual_phase() == still_phase and burst.age > paused_age)
		burst._process(burst.life + 0.2)
		check("authored frost expires without extra damage", burst.is_queued_for_deletion() and enemy.hp == hp_after_contact)
		Prefs.reduce_motion = false
	var bolt := hero._prepare("iceBolt", SkillDefs.get_def("iceBolt"), 1)
	seed(4832)
	expected = hero.damage_for("iceBolt", float(SkillDefs.get_def("iceBolt")["mult"]))
	seed(4832)
	bolt.call()
	var shots: Array = game.world.get_children().filter(func(node: Node) -> bool: return node is Effect and node.kind == "proj")
	check("native cold spell uses the authored blue missile", shots.size() == 1 and shots[0].params.get("visual", "") == "bolt")
	if not shots.is_empty():
		var shot: Effect = shots[0]
		shot.set_process(false)
		check("blue missile keeps its chest pivot and native travel speed", shot._ground().is_equal_approx(hero.position + Vector2.from_angle(hero.facing) * 8.0) and is_equal_approx(shot.velocity.length(), GameTempo.speed(float(SkillDefs.get_def("iceBolt")["speed"]))))
		before = enemy.hp
		shot._process(0.12)
		check("blue missile preserves swept contact and native damage", shot.is_queued_for_deletion() and is_equal_approx(before - enemy.hp, expected))
	var fire := hero._prepare("firebolt", SkillDefs.get_def("firebolt"), 1)
	fire.call()
	var thrown := hero._prepare("doubleThrow", SkillDefs.get_def("doubleThrow"), 1)
	thrown.call()
	var fire_count := 0
	var throw_count := 0
	for child in game.world.get_children():
		if not child is Effect or child.kind != "proj" or child.is_queued_for_deletion():
			continue
		var effect := child as Effect
		if effect.params.get("throw", false):
			throw_count += 1
			check("physical thrown projectiles keep their solid material", effect.material == null and effect.params.get("visual", "") == "")
		elif effect.color.is_equal_approx(SkillDefs.FIRE):
			fire_count += 1
			check("firebolts retain their fire artwork and elemental color", effect.params.get("visual", "") == "")
	check("cold artwork does not replace fire or throwing routes", fire_count == 1 and throw_count == 2)
	var held: Effect = game.spawn_reference_fx("slam", hero.position, 90.0, hero)
	held._process(0.8)
	check("slow first frame retains the authored landing burst", not held.is_queued_for_deletion() and held.age < held.life)
	held._process(0.8)
	check("unrendered landing burst still expires normally", held.is_queued_for_deletion())
	for index in 80:
		game.spawn_reference_fx("frost", hero.position, 100.0, hero)
	check("authored skill spam shares the existing cosmetic budget", game.cosmetic_effects.size() <= 64)
	game.queue_free()
	await _frames(2)


func _check_meteor_transition() -> void:
	var game := await make_game("mage")
	var hero: Player = game.player
	hero.set_process(false)
	var at := hero.position + Vector2(180, 0)
	var enemy := _target(game, at)
	var action := hero._prepare("meteor", SkillDefs.get_def("meteor"), 1)
	check("meteor targeting creates no premature impact art", _authored(game, "meteor").is_empty())
	action.call()
	var zones: Array = game.world.get_children().filter(func(node: Node) -> bool: return node is Effect and node.kind == "zone")
	check("native meteor cast creates one gameplay zone", zones.size() == 1)
	if not zones.is_empty():
		var zone: Effect = zones[0]
		zone.set_process(false)
		var before := enemy.hp
		var delay: float = zone.params["delay"]
		zone._process(delay - 0.01)
		check("meteor warning cannot deal damage or emit a plume before impact", enemy.hp == before and _authored(game, "meteor").is_empty())
		var impact: float = zone.params["impact"]
		var continuing := zone.damage
		zone._process(0.02)
		check("crossing the native delay emits exactly one authored meteor impact", bool(zone.params.get("impacted", false)) and _authored(game, "meteor").size() == 1)
		check("meteor preserves its native impact plus first zone tick", is_equal_approx(before - enemy.hp, impact + continuing))
		var after := enemy.hp
		zone._process(0.01)
		check("meteor plume does not repeat on later zone updates", _authored(game, "meteor").size() == 1 and enemy.hp == after)
	game.queue_free()
	await _frames(2)
