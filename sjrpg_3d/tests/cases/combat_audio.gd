extends TestCase
## 확정 접촉음과 지역 음악의 실제 연결·수명·음소거 경계를 확인한다.


func run() -> void:
	var old_sound := Prefs.sound_enabled
	var old_music := Prefs.music_enabled
	var old_motion := Prefs.reduce_motion
	Prefs.sound_enabled = true
	Prefs.music_enabled = true
	Prefs.reduce_motion = false
	var listeners := SoundFx.contact_played.get_connections().size()
	var game := await make_game()
	var music: MusicDirector = game.music
	music.set_process(false)
	music._next_check = 0.0
	music._process(MusicDirector.FADE_SECONDS)
	music.step(MusicDirector.FADE_SECONDS)
	var track: AudioStreamPlayer = music._players[music.current]
	var voices := SoundFx._players.size()
	_reset_sounds()
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = game.player.position + Vector2(60, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	var before := SoundFx.played_serial
	var health := foe.hp
	foe.take_damage(1.0, game.player)
	check(
		"actual enemy contact plays sound and ducks its owned music",
		(
			SoundFx.played_serial > before
			and is_equal_approx(
				track.volume_db, MusicDirector.BASE_DB + MusicDirector.CONTACT_DUCK_DB
			)
		)
	)
	check("audio feedback never changes confirmed damage", is_equal_approx(foe.hp, health - 1.0))
	music.step(0.10)
	var expected := (
		MusicDirector.CONTACT_DUCK_DB * (1.0 - 0.02 / MusicDirector.CONTACT_DUCK_RELEASE)
	)
	check(
		"large steps consume hold before releasing only the remainder",
		is_equal_approx(music._contact_duck_db, expected)
	)
	music.step(MusicDirector.CONTACT_DUCK_RELEASE)
	check(
		"contact music returns to its original level in finite time",
		(
			is_zero_approx(music._contact_duck_db)
			and is_equal_approx(track.volume_db, MusicDirector.BASE_DB)
		)
	)
	_reset_sounds()
	SoundFx.play("slash", true)
	check("a swing without contact never ducks music", is_zero_approx(music._contact_duck_db))
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY, 0, "goblin")
	for hit in 12:
		_reset_sounds()
		SoundFx.play_hit(HitTier.HEAVY, 0, "goblin")
		check(
			"repeated hits never stack music attenuation",
			is_equal_approx(music._contact_duck_db, MusicDirector.CONTACT_DUCK_DB)
		)
	check(
		"combat mixing retains the original bounded voices and one music track",
		(
			SoundFx._players.size() == voices
			and voices == SoundFx.VOICE_COUNT
			and _playing_count(music) == 1
		)
	)
	music.step(0.3)
	_reset_sounds()
	var now := Time.get_ticks_msec()
	for gate in ["impact", "tick", "kill", "hit_material"]:
		SoundFx._last[gate] = now
	before = SoundFx.played_serial
	SoundFx.play_hit(HitTier.HEAVY, 0, "goblin")
	check(
		"throttled contact with no actual voice never ducks",
		SoundFx.played_serial == before and is_zero_approx(music._contact_duck_db)
	)
	_reset_sounds()
	for player: AudioStreamPlayer in SoundFx._players:
		player.stream = SoundFx._streams["hurt"]
		player.set_meta("voice_priority", 100)
		player.play()
	before = SoundFx.played_serial
	SoundFx.play_hit(HitTier.LIGHT, 0, "goblin")
	check(
		"rejected contact voices never duck music",
		SoundFx.played_serial == before and is_zero_approx(music._contact_duck_db)
	)
	_reset_sounds()
	Prefs.sound_enabled = false
	before = SoundFx.played_serial
	SoundFx.play_hit(HitTier.HEAVY)
	check(
		"muted effects neither play nor duck",
		SoundFx.played_serial == before and is_zero_approx(music._contact_duck_db)
	)
	Prefs.sound_enabled = true
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	Prefs.sound_enabled = false
	music.step(0.0)
	check(
		"muting effects immediately restores the music mix", is_zero_approx(music._contact_duck_db)
	)
	Prefs.sound_enabled = true
	Prefs.reduce_motion = true
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	check(
		"reduce motion keeps contact audio without music pumping",
		is_zero_approx(music._contact_duck_db)
	)
	Prefs.reduce_motion = false
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	game.hud.open_settings()
	music.step(0.0)
	check(
		"opening a paused menu clears a pending contact duck",
		get_tree().paused and is_zero_approx(music._contact_duck_db)
	)
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	check("paused menus cannot schedule another music duck", is_zero_approx(music._contact_duck_db))
	game.hud.close_panel(false)
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(
		"focus loss clears the attenuation while pausing the existing decoder",
		is_zero_approx(music._contact_duck_db) and track.stream_paused
	)
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	check("unfocused contacts cannot duck the paused music", is_zero_approx(music._contact_duck_db))
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	Prefs.music_enabled = false
	music._next_check = 0.0
	music._process(MusicDirector.FADE_SECONDS)
	check(
		"music off clears the contact envelope and releases the song",
		is_zero_approx(music._contact_duck_db) and _playing_count(music) == 0
	)
	Prefs.music_enabled = true
	music._next_check = 0.0
	music._process(MusicDirector.FADE_SECONDS)
	_reset_sounds()
	SoundFx.play_hit(HitTier.HEAVY)
	game.player.position = Iso.project(Vector2(-2800, -2800))
	music._next_check = 0.0
	music._process(0.0)
	check(
		"region changes clear the previous contact envelope without layering songs",
		(
			music.current == "field"
			and is_zero_approx(music._contact_duck_db)
			and _playing_count(music) <= 1
		)
	)
	game.remove_child(music)
	check(
		"detaching disconnects the global contact signal",
		(
			SoundFx.contact_played.get_connections().size() == listeners
			and is_zero_approx(music._contact_duck_db)
		)
	)
	game.add_child(music)
	check(
		"re-entry reconnects once and reuses existing music players",
		(
			SoundFx.contact_played.get_connections().size() == listeners + 1
			and music.get_child_count() == MusicDirector.TRACKS.size()
		)
	)
	game.queue_free()
	await _frames(2)
	check(
		"game shutdown releases its contact listener",
		SoundFx.contact_played.get_connections().size() == listeners
	)
	_reset_sounds()
	Prefs.sound_enabled = old_sound
	Prefs.music_enabled = old_music
	Prefs.reduce_motion = old_motion


func _reset_sounds() -> void:
	for player: AudioStreamPlayer in SoundFx._players:
		player.stop()
	SoundFx._last.clear()
	SoundFx._last_hit_ms = -100000
	SoundFx._last_hit_tier = -1
	SoundFx._last_contact_tap_ms = -100000


func _playing_count(music: MusicDirector) -> int:
	var count := 0
	for player: AudioStreamPlayer in music._players.values():
		if player.has_stream_playback():
			count += 1
	return count
