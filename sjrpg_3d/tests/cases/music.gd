extends TestCase
## 지역 음악은 반복·포커스·설정을 따르며 전환 중에도 한 곡만 재생한다.


func run() -> void:
	var old_music := Prefs.music_enabled
	Prefs.music_enabled = true
	for name in ["town", "field", "dungeon"]:
		var stream: AudioStreamOggVorbis = MusicDirector.TRACKS[name]
		check("%s track is a 30-90 second loop" % name, stream.get_length() >= 30.0 and stream.get_length() <= 90.0)
	var game := await make_game()
	var music: MusicDirector = game.music
	var town_position: Vector2 = game.player.position
	check("the game owns a music director", music != null)
	for player: AudioStreamPlayer in music._players.values():
		check("long music always streams instead of duplicating Web Audio samples",
			player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
	for name in ["town", "field", "dungeon"]:
		var looping: AudioStreamOggVorbis = MusicDirector.TRACKS[name]
		check("%s track loops" % name, looping.loop)
	check("the hero starts in town on the town track", MusicDirector.context_for(game) == "town")
	music._process(MusicDirector.CHECK_INTERVAL)
	check("town music begins fading in", music.current == "town" and music.is_playing("town") and music.level_of("town") > 0.0)
	music.step(MusicDirector.FADE_SECONDS)
	check("town music reaches full level and others stay silent", is_equal_approx(music.level_of("town"), 1.0) and not music.is_playing("field") and not music.is_playing("dungeon"))
	var pause_writes := music.focus_pause_updates
	var town_player: AudioStreamPlayer = music._players["town"]
	var town_playback: AudioStreamPlayback = town_player.get_stream_playback()
	var town_playback_id := town_playback.get_instance_id()
	town_playback = null
	for frame in 120:
		music.step(1.0 / 60.0)
	town_playback = town_player.get_stream_playback()
	check("120 normal render steps never issue another unpause or replace the music decoder",
		music.focus_pause_updates == pause_writes and town_playback.get_instance_id() == town_playback_id)
	town_playback = null

	game.player.position = Iso.project(Vector2(-2800, -2800))
	check("outside the village the field track is chosen", MusicDirector.context_for(game) == "field")
	music._next_check = 0.0
	music._process(0.1)
	check("walking out fades town before starting field", music.current == "field" and not music.is_playing("field") and music.is_playing("town") and music.level_of("town") < 1.0)
	for frame in 120:
		music.step(1.0 / 60.0)
		check("town to field never overlaps actual decoders", _playing_count(music) <= 1)
	check("the transition finishes with only the field track playing", not music.is_playing("town") and music.is_playing("field") and is_equal_approx(music.level_of("field"), 1.0))
	# Boundary reversals and a cave entry can interrupt a fade before it completes.
	for cycle in 6:
		for context: String in ["town", "field", "dungeon", "field"]:
			music.current = context
			music.step(0.1)
			check("rapid context changes never layer songs", _playing_count(music) <= 1)
	music.current = "field"
	music.step(MusicDirector.FADE_SECONDS)

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
	# Exercise a real interrupted transition before exit, not merely silent players.
	var exits: Array[Dictionary] = []
	music.tree_exited.connect(_observe_exit.bind(music, exits))
	_interrupt_transition(game, music, town_position)
	check("an interrupted three-context transition retains only one real playback", _playing_count(music) == 1)
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for player: AudioStreamPlayer in music._players.values():
		check("focus loss pauses every active audio player", not player.has_stream_playback() or player.stream_paused)
	pause_writes = music.focus_pause_updates
	music._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	for frame in 120:
		music.step(0.0)
	check("duplicate focus-loss notifications and paused steps never repeat the pause bridge",
		music.focus_pause_updates == pause_writes)
	var players: Dictionary = music._players.duplicate()
	game.remove_child(music)
	check("detaching stops voices, releases streams and resets fade state", exits.size() == 1 and bool(exits[0]["released"]) and bool(exits[0]["reset"]))
	game.dungeon.active = false
	game.player.position = Iso.project(Vector2(-2800, -2800))
	game.add_child(music)
	check("re-entering reuses exactly the original three players", music._players.size() == 3 and music.get_child_count() == 3)
	for name: String in MusicDirector.TRACKS:
		var player: AudioStreamPlayer = music._players[name]
		check("re-entering restores the original track without duplicate players", player == players[name] and player.stream == MusicDirector.TRACKS[name])
	music._process(0.1)
	var paused_field: AudioStreamPlayer = music._players["field"]
	check("re-entering begins the paused context fade", music.current == "field" and paused_field.has_stream_playback() and paused_field.stream_paused and music.level_of("field") > 0.0 and music.level_of("field") < 1.0)
	for name: String in ["town", "dungeon"]:
		var inactive: AudioStreamPlayer = music._players[name]
		check("inactive tracks retain no decoder after re-entry", not inactive.has_stream_playback())
	if paused_field.has_stream_playback():
		var playback: AudioStreamPlayback = paused_field.get_stream_playback()
		var playback_id: int = playback.get_instance_id()
		playback = null
		music.step(0.1)
		check("stepping preserves the same paused decoder", paused_field.has_stream_playback() and paused_field.stream_paused)
		if paused_field.has_stream_playback():
			playback = paused_field.get_stream_playback()
			check("paused playback is not restarted every step", playback.get_instance_id() == playback_id)
			playback = null
	Prefs.music_enabled = false
	music._next_check = 0.0
	music._process(0.0)
	music.step(MusicDirector.FADE_SECONDS)
	for player: AudioStreamPlayer in music._players.values():
		check("music off releases every playback while unfocused", not player.has_stream_playback())
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	music._process(0.1)
	for player: AudioStreamPlayer in music._players.values():
		check("focus return cannot resume music while the setting is off", not player.has_stream_playback())
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Prefs.music_enabled = true
	music._next_check = 0.0
	music._process(0.1)
	check("re-enabling while unfocused preserves paused field playback", paused_field.has_stream_playback() and paused_field.stream_paused)
	pause_writes = music.focus_pause_updates
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check("focus return sends one resume for the one paused field voice",
		music.focus_pause_updates == pause_writes + 1)
	pause_writes = music.focus_pause_updates
	music._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	for frame in 120:
		music.step(0.0)
	check("duplicate focus-return notifications and active steps never repeat unpause",
		music.focus_pause_updates == pause_writes)
	music.step(MusicDirector.FADE_SECONDS)
	var field_player: AudioStreamPlayer = music._players["field"]
	check("focus return resumes the actual field playback and normal fade", not field_player.stream_paused and field_player.playing and is_equal_approx(music.level_of("field"), 1.0))
	_interrupt_transition(game, music, town_position)
	check("game shutdown interrupts one active song without layering tracks", _playing_count(music) == 1)
	var director_ref: WeakRef = weakref(music)
	var player_refs: Array[WeakRef] = []
	for player: AudioStreamPlayer in music._players.values():
		player_refs.append(weakref(player))
	game.queue_free()
	await _frames(2)
	check("freeing the actual game invokes the same stream-release contract", exits.size() == 2 and bool(exits[1]["released"]) and bool(exits[1]["reset"]))
	check("game destruction releases its director node", director_ref.get_ref() == null)
	for reference: WeakRef in player_refs:
		check("game destruction releases every owned player node", reference.get_ref() == null)
	Prefs.music_enabled = old_music


func _interrupt_transition(game: Node, director: MusicDirector, town_position: Vector2) -> void:
	var previous_scope: bool = game.dungeon.active
	game.dungeon.active = false
	game.player.position = town_position
	director._next_check = 0.0
	director._process(MusicDirector.FADE_SECONDS)
	game.player.position = Iso.project(Vector2(-2800, -2800))
	director._next_check = 0.0
	director._process(0.1)
	game.dungeon.active = true
	director._next_check = 0.0
	director._process(0.01)
	game.dungeon.active = previous_scope


func _playing_count(director: MusicDirector) -> int:
	var count := 0
	for name: String in MusicDirector.TRACKS:
		var player: AudioStreamPlayer = director._players[name]
		if player.has_stream_playback():
			count += 1
	return count


func _observe_exit(director: MusicDirector, events: Array[Dictionary]) -> void:
	var released: bool = director._players.size() == MusicDirector.TRACKS.size()
	var reset: bool = director.current.is_empty() and is_zero_approx(director._next_check)
	for name: String in director._players:
		var player: AudioStreamPlayer = director._players[name]
		released = released and is_instance_valid(player) and not player.playing and not player.has_stream_playback() and player.stream == null
		reset = reset and is_zero_approx(director.level_of(name))
	events.append({"released": released, "reset": reset})

