extends TestCase
## 실제 공격 콜백→3D 접촉 자세·피격 리그·숫자·파편·초점까지 한 경로로 검증한다.
func run() -> void:
	var old_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("warrior")
	var preview: Ortho3DPreview = game.ortho_preview
	var hero: Player = game.player
	hero.set_process(false)
	var native := preview.actor as NativeWarrior3D
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.hp = 1000.0
	foe.max_hp = 1000.0
	foe.position = hero.position + Vector2(65, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	check("actual basic attack starts", hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.20)
	native.sync(hero)
	var windup := native.arms[1].rotation
	var health := foe.hp
	hero._process(hero._attack_duration * 0.32)
	native.sync(hero)
	check("confirmed contact installs the strike pose before hit-stop", foe.hp < health and hero.contact_serial > 0 and hero._hitstop.remaining > 0.0 and is_equal_approx(native.last_pose["attack_progress"], Player.CONTACT_PROGRESS) and windup.distance_to(native.arms[1].rotation) > 1.0)
	var contact := native.arms[1].rotation
	native.sync(hero)
	check("subsequent frozen samples retain the actual strike", native.arms[1].rotation.is_equal_approx(contact))
	var clock := hero._attack_time
	hero._process(0.15)
	check("local hold does not freeze the whole game or extend damage callbacks", Engine.time_scale == 1.0 and hero._attack_time < clock and hero.contact_serial == 1)
	var at := foe.position
	foe.take_damage(350.0, hero)
	preview._enemy_models.sync()
	var model: Dictionary = preview._enemy_models.entries[foe.get_instance_id()]
	var torso: Node3D = model["torso"]
	var first_lean := Vector2(torso.rotation.x, torso.rotation.z)
	check("confirmed hit tilts real chest and head while keeping the collision foot", first_lean.length() > 0.15 and foe.position == at and float(model["hit_lean"]) > 0.2)
	var shoulder: Node3D = model["arms"][0]
	var shoulder_anchor: Vector3 = model["arm_origins"][0] - model["torso_origin"]
	check("shoulder anchors stay attached to the recoiling ribcage", (torso.transform.affine_inverse() * shoulder.position).distance_to(shoulder_anchor) < 0.001)
	var hit_age := foe.hit_reaction_age
	foe._process(0.01)
	check("victim flinch shares its bounded local hit-stop", foe.hit_reaction_age == hit_age)
	var projectile := Effect.new()
	projectile.position = foe.position + Vector2(100, 0)
	projectile.velocity = Vector2(-300, 0)
	projectile.owner_node = hero
	foe.take_damage(350.0, projectile)
	preview._enemy_models.sync()
	var reverse := Vector2(torso.rotation.x, torso.rotation.z)
	check("opposite travel reverses the body's hit response", first_lean.dot(reverse) < 0.0)
	projectile.free()
	preview._sync_cards()
	var numbers: Array = game.cosmetic_effects.filter(func(effect: Effect): return effect.kind == "text" and effect.font_size == HitTier.number_size(HitTier.HEAVY))
	check("heavy hits generate tiered numbers", not numbers.is_empty())
	var number: Effect = numbers.back()
	check("simultaneous follow-up number waits before its native pop", number.age < 0.0 and not preview._labels.has(number.get_instance_id()))
	number._process(-number.age)
	preview._sync_cards()
	var label: Label3D = preview._labels[number.get_instance_id()]["node"]
	check("actual 3D text honors heavy font size and initial pop", label.font_size == HitTier.number_size(HitTier.HEAVY) and label.scale.x > 1.3)
	number.age = 0.12
	preview._sync_cards()
	check("the 3D number pop settles without changing the damage value", is_equal_approx(label.scale.x, 1.0))
	var fx := preview._hit_feel
	fx.sync(0.0)
	check("real confirmed impacts create directional depth-tested streaks and a short focus pulse", fx.entries.size() > 0 and float(fx.snapshot()["pulse"]) > 0.0 and not "depth_test_disabled" in NativeHitFeel3D.SPARK_CODE)
	for entry: Dictionary in fx.entries.values():
		var effect: Effect = entry["source"].get_ref()
		check("streaks sit on the actual 3D struck chest", (entry["node"] as Node3D).position.is_equal_approx(effect.params["contact_position"]))
	var pulse: float = fx.snapshot()["pulse"]
	get_tree().paused = true
	fx.sync(0.0)
	check("pause preserves the focus pulse and source particle clock", is_equal_approx(fx.snapshot()["pulse"], pulse))
	get_tree().paused = false
	for index in 30:
		var effect := Effect.spawn_impact(game, hero.position, hero, true)
		effect.params["contact_position"] = preview.actor_foot(hero) + Vector3.UP
		effect.params["tier"] = HitTier.HEAVY
	fx.sync(0.0)
	check("large area hits obey a fixed renderer budget", fx.entries.size() <= NativeHitFeel3D.MAX_BURSTS and fx.builds <= NativeHitFeel3D.MAX_BURSTS)
	for effect: Effect in Effect.in_world(game.world):
		if effect.kind == "impact":
			effect.age = effect.life
	fx.sync(0.4)
	var builds := fx.builds
	var next := Effect.spawn_impact(game, hero.position, hero, true)
	next.params["contact_position"] = preview.actor_foot(hero) + Vector3.UP
	next.params["tier"] = HitTier.HEAVY
	fx.sync(0.0)
	check("new impacts reuse expired streak batches", fx.entries.size() == 1 and fx.builds == builds)
	Prefs.reduce_motion = true
	foe.take_damage(1.0, hero)
	preview._enemy_models.sync()
	preview._sync_cards()
	fx.sync(0.0)
	check("reduced motion removes the extra flinch, sparks and focus", float(model["hit_lean"]) == 0.0 and fx.entries.is_empty() and float(fx.snapshot()["pulse"]) == 0.0 and label.scale == Vector3.ONE)
	Prefs.reduce_motion = old_motion
	game.queue_free()
	await _frames(3)
	_check_audio()
	await _check_mage_contact()

func _check_audio() -> void:
	check("flesh, bone and stone receive distinct contact accents", SoundFx.material_hit_name("wolf") != SoundFx.material_hit_name("skeleton") and SoundFx.material_hit_name("skeleton") != SoundFx.material_hit_name("golem"))
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
	print("ART_AUDIT contact_audio " + JSON.stringify({"mix_peak": peak, "voices": SoundFx._players.size(), "device_listening": false}))

func _check_mage_contact() -> void:
	var game := await make_game("mage")
	var hero: Player = game.player
	hero.set_process(false)
	var foe := Enemy.new()
	foe.setup(game, "skeleton", 1)
	foe.hp = 1000.0
	foe.max_hp = 1000.0
	foe.position = hero.position + Vector2(65, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	GameState.slots[0] = "sorceressAttack"
	check("actual mage melee starter attack starts", hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.52)
	var motion: Ortho3DHeroMotion = game.ortho_preview._hero_motion
	motion.sync(hero, 0.0)
	var clip: Animation = game.ortho_preview.animation.get_animation(motion.active_clip)
	check("GLB first confirmed contact seeks the contact key before holding", hero.contact_serial > 0 and motion.active_clip.to_lower().contains("cast") and is_equal_approx(motion.sample_time, Player.CONTACT_PROGRESS * clip.length))
	var updates := motion.pose_updates
	motion.sync(hero, 0.05)
	check("held GLB contact performs no second seek", motion.pose_updates == updates)
	game.queue_free()
	await _frames(3)
