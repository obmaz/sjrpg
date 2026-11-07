extends TestCase
## Background music: area tracks loop gapless, follow the hero, crossfade, and respect the setting.


func run() -> void:
	var old_music := Prefs.music_enabled
	Prefs.music_enabled = true
	for name in ["town", "field", "dungeon"]:
		var stream: AudioStreamOggVorbis = MusicDirector.TRACKS[name]
		check("%s track is a 30-90 second loop" % name, stream.get_length() >= 30.0 and stream.get_length() <= 90.0)
	var game := await make_game()
	var music: MusicDirector = game.music
	check("the game owns a music director", music != null)
	for name in ["town", "field", "dungeon"]:
		var looping: AudioStreamOggVorbis = MusicDirector.TRACKS[name]
		check("%s track loops" % name, looping.loop)
	check("the hero starts in town on the town track", MusicDirector.context_for(game) == "town")
	music._process(MusicDirector.CHECK_INTERVAL)
	check("town music begins fading in", music.current == "town" and music.is_playing("town") and music.level_of("town") > 0.0)
	music.step(MusicDirector.FADE_SECONDS)
	check("town music reaches full level and others stay silent", is_equal_approx(music.level_of("town"), 1.0) and not music.is_playing("field") and not music.is_playing("dungeon"))

	game.player.position = Iso.project(Vector2(-2800, -2800))
	check("outside the village the field track is chosen", MusicDirector.context_for(game) == "field")
	music._next_check = 0.0
	music._process(0.1)
	check("walking out starts a crossfade", music.current == "field" and music.is_playing("field") and music.is_playing("town") and music.level_of("town") < 1.0 and music.level_of("field") > 0.0)
	music.step(MusicDirector.FADE_SECONDS)
	check("the crossfade finishes with only the field track playing", not music.is_playing("town") and is_equal_approx(music.level_of("field"), 1.0))

	Prefs.music_enabled = false
	music._next_check = 0.0
	music._process(0.0)
	music.step(MusicDirector.FADE_SECONDS)
	check("turning the setting off fades everything out", not music.is_playing("field") and not music.is_playing("town") and not music.is_playing("dungeon"))
	Prefs.music_enabled = true
	music._next_check = 0.0
	music._process(0.1)
	check("turning it back on resumes the area track", music.current == "field" and music.is_playing("field"))

	game.hud.open_settings()
	await _frames(2)
	check("music keeps fading while a menu pauses the game", get_tree().paused and music.process_mode == Node.PROCESS_MODE_ALWAYS)
	game.hud.close_panel()
	check("music setting is saved with the device settings", Prefs.music_enabled == true)
	Prefs.music_enabled = old_music
	game.queue_free()
	await _frames(2)
