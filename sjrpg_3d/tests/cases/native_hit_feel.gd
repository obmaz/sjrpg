extends TestCase


## 실제 공격 콜백→3D 접촉 자세·피격 리그·숫자·파편·초점까지 한 경로로 검증한다.
func run() -> void:
	var old_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	_check_contact_stop()
	var game := await make_game("warrior")
	var renderer: WorldRenderer3D = game.world_renderer
	var hero: Player = game.player
	hero.set_process(false)
	var native := renderer.actor as WarriorRenderer3D
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.hp = 1000.0
	foe.max_hp = 1000.0
	foe.position = hero.position + Vector2(65, 0)
	hero.facing = 0.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	check("actual basic attack starts", hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.20)
	native.sync(hero)
	var windup := native.joint_rotation("upperarm_r")
	var health := foe.hp
	hero._process(hero._attack_duration * 0.32)
	native.sync(hero)
	check(
		"confirmed contact installs the strike pose before hit-stop",
		(
			foe.hp < health
			and hero.contact_serial > 0
			and hero._hitstop.remaining > 0.0
			and is_equal_approx(native.last_pose["attack_progress"], Player.CONTACT_PROGRESS)
			and windup.angle_to(native.joint_rotation("upperarm_r")) > 0.5
		)
	)
	var contact := native.joint_rotation("upperarm_r")
	native.sync(hero)
	check(
		"subsequent frozen samples retain the actual strike",
		native.joint_rotation("upperarm_r").is_equal_approx(contact)
	)
	var clock := hero._attack_time
	hero._process(0.15)
	check(
		"local hold does not freeze the whole game or extend damage callbacks",
		Engine.time_scale == 1.0 and hero._attack_time < clock and hero.contact_serial == 1
	)
	var at := foe.position
	foe.take_damage(350.0, hero)
	renderer._enemy_renderer.sync()
	var model: Dictionary = renderer._enemy_renderer.entries[foe.get_instance_id()]
	var torso: Node3D = model["torso"]
	_check_hit_flash(model)
	var first_lean := Vector2(torso.rotation.x, torso.rotation.z)
	check(
		"confirmed hit tilts real chest and head while keeping the collision foot",
		first_lean.length() > 0.15 and foe.position == at and float(model["hit_lean"]) > 0.2
	)
	var visual: EnemyVisual = model["visual"]
	EnemyRenderer3D.pose(model, foe.facing, 0.0, 0.0)
	visual.skeleton.force_update_all_bone_transforms()
	var bone := visual.skeleton.find_bone("shoulder_R")
	var bone_pose := visual.skeleton.get_bone_global_pose(bone).origin
	var resting := visual.skeleton.global_transform * bone_pose
	var local_anchor := torso.global_transform.affine_inverse() * resting
	EnemyRenderer3D.hit_reaction(model, foe)
	var recoiling := visual.skeleton.global_transform * bone_pose
	check(
		"skinned shoulder stays attached to the actual recoil pivot",
		(
			resting.distance_to(recoiling) > .001
			and (
				(torso.global_transform.affine_inverse() * recoiling).distance_to(local_anchor)
				< .001
			)
		)
	)
	var hit_age := foe.hit_reaction_age
	foe._process(0.01)
	check("victim flinch shares its bounded local hit-stop", foe.hit_reaction_age == hit_age)
	var projectile := Effect.new()
	projectile.position = foe.position + Vector2(100, 0)
	projectile.velocity = Vector2(-300, 0)
	projectile.owner_node = hero
	foe.take_damage(350.0, projectile)
	renderer._enemy_renderer.sync()
	var reverse := Vector2(torso.rotation.x, torso.rotation.z)
	check("opposite travel reverses the body's hit response", first_lean.dot(reverse) < 0.0)
	projectile.free()
	renderer._sync_cards()
	var numbers: Array = game.cosmetic_effects.filter(
		func(effect: Effect):
			return effect.kind == "text" and effect.font_size == HitTier.number_size(HitTier.HEAVY)
	)
	check("heavy hits generate tiered numbers", not numbers.is_empty())
	var number: Effect = numbers.back()
	check(
		"simultaneous follow-up number waits before its native pop",
		number.age < 0.0 and not renderer._labels.has(number.get_instance_id())
	)
	number._process(-number.age)
	renderer._sync_cards()
	var label: Label3D = renderer._labels[number.get_instance_id()]["node"]
	check(
		"actual 3D text honors heavy font size and initial pop",
		label.font_size == HitTier.number_size(HitTier.HEAVY) and label.scale.x > 1.3
	)
	number.age = 0.12
	renderer._sync_cards()
	check(
		"the 3D number pop settles without changing the damage value",
		is_equal_approx(label.scale.x, 1.0)
	)
	var fx := renderer._hit_feel
	game.contact_rhythm.tick(game, 0.12)
	fx.sync(0.0)
	check(
		"real confirmed impacts create directional depth-tested streaks and a short focus pulse",
		(
			fx.entries.size() > 0
			and float(fx.snapshot()["pulse"]) > 0.0
			and not "depth_test_disabled" in HitFeedback3D.SPARK_CODE
		)
	)
	for entry: Dictionary in fx.entries.values():
		var effect: Effect = entry["source"].get_ref()
		check(
			"streaks sit on the actual 3D struck chest",
			(entry["node"] as Node3D).position.is_equal_approx(effect.params["contact_position"])
		)
	var pulse: float = fx.snapshot()["pulse"]
	get_tree().paused = true
	fx.sync(0.0)
	check(
		"pause preserves the focus pulse and source particle clock",
		is_equal_approx(fx.snapshot()["pulse"], pulse)
	)
	get_tree().paused = false
	for index in 30:
		var effect := Effect.spawn_impact(game, hero.position, hero, true)
		effect.params["contact_position"] = renderer.actor_foot(hero) + Vector3.UP
		effect.params["tier"] = HitTier.HEAVY
	fx.sync(0.0)
	check(
		"large area hits obey a fixed renderer budget",
		fx.entries.size() <= HitFeedback3D.MAX_BURSTS and fx.builds <= HitFeedback3D.MAX_BURSTS
	)
	for effect: Effect in Effect.in_world(game.world):
		if effect.kind == "impact":
			effect.age = effect.life
	fx.sync(0.4)
	var builds := fx.builds
	var next := Effect.spawn_impact(game, hero.position, hero, true)
	next.params["contact_position"] = renderer.actor_foot(hero) + Vector3.UP
	next.params["tier"] = HitTier.HEAVY
	fx.sync(0.0)
	check(
		"new impacts reuse expired streak batches", fx.entries.size() == 1 and fx.builds == builds
	)
	Prefs.reduce_motion = true
	foe.take_damage(1.0, hero)
	renderer._enemy_renderer.sync()
	renderer._sync_cards()
	fx.sync(0.0)
	check(
		"reduced motion removes the extra flinch, sparks and focus",
		(
			float(model["hit_lean"]) == 0.0
			and fx.entries.is_empty()
			and float(fx.snapshot()["pulse"]) == 0.0
			and label.scale == Vector3.ONE
		)
	)
	Prefs.reduce_motion = old_motion
	game.queue_free()
	await _frames(3)
	_check_audio()
	await _check_mage_contact()
	await _check_live_review_contact()


func _check_live_review_contact() -> void:
	var game := await make_game("warrior")
	game.player.facing = PI
	game.inspection = AdventureInspection.create(game, "inspection=1&hitfeel_preview=1")
	game.inspection.apply()
	await get_tree().create_timer(3.5).timeout
	check(
		"live review fixture turns toward its actual target and confirms damage",
		game.player.contact_serial > 0
	)
	game.queue_free()
	await _frames(3)


func _check_contact_stop() -> void:
	var stop := GameTempo.ContactStop.new()
	stop.trigger(HitTier.HEAVY_VICTIM_STOP, HitTier.HEAVY_STOP_LIMIT)
	check("heavy victim contact holds for65ms", is_equal_approx(stop.remaining, 0.065))
	check("local stop consumes only its remaining time", is_equal_approx(stop.consume(0.1), 0.035))
	stop.trigger(HitTier.HEAVY_VICTIM_STOP, HitTier.HEAVY_STOP_LIMIT)
	check("rapid repeated contacts cannot keep pinning the victim", stop.remaining == 0.0)
	stop.consume(0.05)
	stop.trigger(HitTier.HEAVY_ATTACKER_STOP, HitTier.HEAVY_STOP_LIMIT)
	check("fresh heavy contact holds the attacker for60ms", is_equal_approx(stop.remaining, 0.060))
	stop.clear()
	Prefs.reduce_motion = true
	stop.trigger(HitTier.HEAVY_VICTIM_STOP, HitTier.HEAVY_STOP_LIMIT)
	check("reduced motion still suppresses contact stop", stop.remaining == 0.0)
	Prefs.reduce_motion = false


func _check_hit_flash(model: Dictionary) -> void:
	var ink: StandardMaterial3D = model["materials"][0]
	var other := EnemyRenderer3D.build("goblin")
	var other_ink: StandardMaterial3D = other["materials"][0]
	check(
		"contact brightness uses an already enabled per-actor material",
		(
			ink.emission_enabled
			and ink.emission.r > 0.5
			and other_ink != ink
			and other_ink.emission == Color.BLACK
		)
	)
	var albedo := ink.albedo_texture
	EnemyRenderer3D.tint(model, Color.WHITE, 0.7, Color.WHITE, 1.0)
	check(
		"contact brightness quickly decays while preserving the original texture",
		ink.emission.r > 0.0 and ink.emission.r < 0.2 and ink.albedo_texture == albedo
	)
	EnemyRenderer3D.tint(model, Color.WHITE, 0.55, Enemy.TELEGRAPH_COLOR, 1.0)
	check("attack warning does not get a white contact accent", is_zero_approx(ink.emission.r))
	EnemyRenderer3D.tint(model, Color.WHITE, 0.0, Color.WHITE, 1.0)
	check(
		"expired contact leaves no brightness on a live model or corpse",
		is_zero_approx(ink.emission.r)
	)
	Prefs.reduce_motion = true
	EnemyRenderer3D.tint(model, Color.WHITE, 1.0, Color.WHITE, 1.0)
	check("enabling reduced motion immediately removes brightness", ink.emission == Color.BLACK)
	Prefs.reduce_motion = false
	(other["root"] as Node3D).free()


func _check_audio() -> void:
	check(
		"flesh, bone and stone receive distinct contact accents",
		(
			SoundFx.material_hit_name("wolf") != SoundFx.material_hit_name("skeleton")
			and SoundFx.material_hit_name("skeleton") != SoundFx.material_hit_name("golem")
		)
	)
	var peak := 0.0
	for tier in [HitTier.LIGHT, HitTier.MEDIUM, HitTier.HEAVY, HitTier.KILL]:
		for species: String in ["wolf", "skeleton", "golem"]:
			var names := SoundFx.hit_names(tier, 0, 1)
			names.append(SoundFx.material_hit_name(species))
			var frames := 0
			for name: String in names:
				frames = maxi(frames, (SoundFx._streams[name] as AudioStreamWAV).data.size() / 2)
			for frame in frames:
				var sample := 0.0
				for name: String in names:
					var data: PackedByteArray = (SoundFx._streams[name] as AudioStreamWAV).data
					if frame * 2 < data.size():
						var gain := db_to_linear(SoundFx.contact_volume_db(name))
						sample += float(data.decode_s16(frame * 2)) / 32768.0 * gain
				peak = maxf(peak, absf(sample))
	check("layered contact PCM has headroom instead of clipping", peak > 0.1 and peak < 0.95)
	print(
		(
			"ART_AUDIT contact_audio "
			+ JSON.stringify(
				{"mix_peak": peak, "voices": SoundFx._players.size(), "device_listening": false}
			)
		)
	)


func _check_mage_contact() -> void:
	var game := await make_game("mage")
	var hero: Player = game.player
	hero.set_process(false)
	var foe := Enemy.new()
	foe.setup(game, "skeleton", 1)
	foe.hp = 1000.0
	foe.max_hp = 1000.0
	foe.position = hero.position + Vector2(65, 0)
	hero.facing = 0.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	GameState.slots[0] = "sorceressAttack"
	check("actual mage melee starter attack starts", hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.52)
	var motion: HeroAnimation3D = game.world_renderer._hero_animation
	motion.sync(hero, 0.0)
	var clip: Animation = game.world_renderer.animation.get_animation(motion.active_clip)
	check(
		"GLB first confirmed contact seeks the contact key before holding",
		(
			hero.contact_serial > 0
			and motion.active_clip.to_lower().contains("cast")
			and is_equal_approx(motion.sample_time, Player.CONTACT_PROGRESS * clip.length)
		)
	)
	var updates := motion.pose_updates
	motion.sync(hero, 0.05)
	check("held GLB contact performs no second seek", motion.pose_updates == updates)
	game.queue_free()
	await _frames(3)
