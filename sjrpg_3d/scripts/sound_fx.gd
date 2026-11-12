extends Node
## CC0 짧은 PCM과 원래 합성 악센트를 공유8음성으로 재생한다. 게임 RNG와 분리한다.

const RATE := 22050
const VOICE_COUNT := 8
const BANKS := "res://assets/audio/feedback/banks.json"
var _sample_banks := {}
var _sample_last := {}
var _voice_serial := 0
var played_serial := 0
var dropped_voices := 0
var last_played := {}
var _last_warning_ms := -100000

const PROFILES := {
	"warn_beast": [96.0, 54.0, 0.30, 480.0, 0.055, 0.025, "growl"],
	"warn_goblin": [180.0, 95.0, 0.22, 650.0, 0.045, 0.018, "growl"],
	# name: [pitch, endPitch, duration, noiseFreq, noiseGain, toneGain, wave]
	# Godot 전용: 실제 칼 휘두름 직전의 준비음과 살·뼈·암석 접촉 악센트.
	# 합성 PCM과 믹스 여유를 검사한다. Android 실기 청음은 별도 검수 대상이다.
	"weapon_draw": [190.0, 290.0, 0.08, 1500.0, 0.035, 0.005, "sine"],
	"hit_flesh": [125.0, 42.0, 0.095, 1100.0, 0.055, 0.04, "sine"],
	"hit_bone": [1650.0, 480.0, 0.075, 5200.0, 0.06, 0.03, "triangle"],
	"hit_stone": [80.0, 28.0, 0.14, 3600.0, 0.07, 0.045, "sine"],
	"slash": [290.0, 85.0, 0.13, 2600.0, 0.14, 0.035, "triangle"],
	"prepare": [340.0, 520.0, 0.075, 1700.0, 0.025, 0.008, "sine"],
	"fire": [180.0, 55.0, 0.25, 650.0, 0.15, 0.055, "sine"],
	"ice": [1500.0, 610.0, 0.19, 5200.0, 0.07, 0.025, "triangle"],
	"lightning": [840.0, 190.0, 0.15, 3400.0, 0.12, 0.025, "sawtooth"],
	"impact": [180.0, 48.0, 0.11, 1200.0, 0.13, 0.07, "sine"],
	"impact_heavy": [125.0, 34.0, 0.17, 1600.0, 0.15, 0.075, "sine"],
	"hurt": [95.0, 38.0, 0.19, 700.0, 0.11, 0.07, "sine"],
	"dodge": [190.0, 100.0, 0.12, 3800.0, 0.08, 0.01, "sine"],
	# 회피 시작음과 구분하는 짧고 낮은 음량의 성공 악센트. 기존 음성 풀을 재사용한다.
	"evade_confirm": [620.0, 920.0, 0.075, 3000.0, 0.025, 0.018, "sine"],
	"warcry": [135.0, 58.0, 0.36, 320.0, 0.10, 0.06, "sine"],
	"town_bell": [440.0, 438.0, 0.9, 0.0, 0.0, 0.035, "triangle"],
	"levelup": [660.0, 1320.0, 0.42, 0.0, 0.0, 0.035, "sine"],
	"loot": [880.0, 1320.0, 0.18, 0.0, 0.0, 0.025, "sine"],
	"warp": [440.0, 1040.0, 0.32, 1200.0, 0.02, 0.04, "sine"],
	# JUICE #11: not in the original audio_profile.dart. Godot-side additions so contact is not one repeated
	# thud: two light variants, a medium variant, a short high "tick" transient layered on harder hits and a
	# descending "kill" thud. Synthetic transients; Android listening is still a separate device check.
	"impact_b": [215.0, 56.0, 0.10, 1500.0, 0.13, 0.065, "sine"],
	"impact_c": [150.0, 42.0, 0.14, 1400.0, 0.14, 0.072, "sine"],
	"tick": [1900.0, 900.0, 0.04, 5200.0, 0.10, 0.02, "triangle"],
	"kill": [260.0, 62.0, 0.24, 900.0, 0.14, 0.075, "sine"],
	# JUICE #12: short elemental accents layered on elemental contact (cast sounds stay on the cast).
	"hit_fire": [230.0, 70.0, 0.12, 900.0, 0.12, 0.04, "sine"],
	"hit_lightning": [900.0, 300.0, 0.08, 3600.0, 0.10, 0.02, "sawtooth"],
	"hit_ice": [1800.0, 900.0, 0.09, 5600.0, 0.06, 0.02, "triangle"],
}
const GAIN := 5.0  # the original plays through a master gain; raw gains are very quiet

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _variation := RandomNumberGenerator.new()
var _next := 0
var _last := {}
## JUICE #11: round-robin for light variants, and a short kill streak that raises the kill pitch.
const STREAK_WINDOW_MS := 2500
const STREAK_MAX := 5
var _hit_variant := 0
var _streak := 0
var _last_kill_ms := -100000
var _last_hit_ms := -100000
var _last_hit_tier := -1


func _ready() -> void:
	for name in PROFILES:
		_streams[name] = _synth(PROFILES[name])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BANKS))
	for family: String in catalog:
		var variants: Array[AudioStreamWAV] = []
		for path: String in catalog[family]:
			variants.append(load(path) as AudioStreamWAV)
		_sample_banks[family] = variants
		_streams[family] = variants[0]
	# 준비음도 같은 석재 샘플을 낮은 피치로 읽어 중복 PCM을 만들지 않는다.
	_sample_banks["warn_skeleton"] = _sample_banks["weapon_draw"]
	_streams["warn_skeleton"] = _streams["weapon_draw"]
	_sample_banks["warn_golem"] = _sample_banks["hit_stone"]
	_streams["warn_golem"] = _streams["hit_stone"]
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _synth(p: Array) -> AudioStreamWAV:
	var n := int(RATE * float(p[2]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var phase := 0.0
	var lp := 0.0
	var alpha := clampf(TAU * float(p[3]) / (TAU * float(p[3]) + RATE), 0.02, 1.0)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(float(p[0]), float(p[1]), t)
		phase += freq / RATE
		var ph := fposmod(phase, 1.0)
		var tone := 0.0
		match p[6]:
			"sine":
				tone = sin(ph * TAU)
			"triangle":
				tone = 4.0 * absf(ph - 0.5) - 1.0
			"sawtooth":
				tone = 2.0 * ph - 1.0
			"growl":
				tone = (
					(sin(ph * TAU) + 0.35 * sin(ph * TAU * 2.0))
					* (0.7 + 0.3 * sin(float(i) / RATE * 35.0))
				)
		lp += alpha * (rng.randf_range(-1.0, 1.0) - lp)
		var env := pow(1.0 - t, 2.0) * minf(1.0, t * 40.0)
		var v := (tone * float(p[5]) + lp * 2.0 * float(p[4])) * env * GAIN
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## JUICE #11: which sounds one confirmed hit plays. Light hits alternate two variants; harder hits add a
## high transient; a killing blow adds the kill thud.
static func hit_names(tier: int, variant: int, element := 0) -> Array[String]:
	var names: Array[String] = []
	match tier:
		HitTier.LIGHT:
			names.append("impact" if variant % 2 == 0 else "impact_b")
		HitTier.MEDIUM:
			names.append_array(["impact_c", "tick"])
		HitTier.HEAVY:
			names.append_array(["impact_heavy", "tick"])
		_:
			names.append_array(["impact_heavy", "kill"])
	var accent: String = {1: "hit_fire", 2: "hit_lightning", 3: "hit_ice"}.get(element, "")
	if accent != "":
		names.append(accent)
	return names


## One semitone per consecutive kill inside the window, capped so it never turns shrill.
static func streak_pitch(count: int) -> float:
	return pow(2.0, clampi(count, 0, STREAK_MAX) / 12.0)


static func contact_volume_db(name: String) -> float:
	return -8.0 if name.begins_with("impact") else -12.0


static func material_hit_name(species: String) -> String:
	if species == "skeleton":
		return "hit_bone"
	if species == "golem":
		return "hit_stone"
	return "hit_flesh" if species in ["goblin", "wolf", "boar", "cave_crawler"] else ""


func play_hit(tier: int, element := 0, species := "") -> void:
	var kill_pitch := _next_kill_pitch() if tier == HitTier.KILL else 1.0
	var now := Time.get_ticks_msec()
	var grouped := now - _last_hit_ms < 70
	if grouped and tier <= _last_hit_tier:
		return
	if grouped:
		# 한 광역 공격 안에서도 약한 접촉음보다 강한 마무리를 우선한다.
		for voice: AudioStreamPlayer in _players:
			if voice.get_meta("contact_voice", false):
				voice.stop()
		for gate in [
			"impact", "tick", "kill", "hit_material", "hit_fire", "hit_ice", "hit_lightning"
		]:
			_last[gate] = -100000
	_last_hit_ms = now
	_last_hit_tier = tier
	var names := hit_names(tier, _hit_variant, element)
	_hit_variant += 1
	var material := material_hit_name(species)
	if not material.is_empty():
		names.append(material)
	for sound in names:
		play(sound, false, kill_pitch if sound == "kill" else 1.0)


func _next_kill_pitch() -> float:
	var now := Time.get_ticks_msec()
	_streak = mini(_streak + 1, STREAK_MAX) if now - _last_kill_ms <= STREAK_WINDOW_MS else 0
	_last_kill_ms = now
	return streak_pitch(_streak)


func play(name: String, preview := false, pitch_multiplier := 1.0) -> void:
	if not Prefs.sound_enabled or not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	# Every contact variant shares one gate so area attacks cannot layer a wall of thuds.
	var gate := (
		"impact"
		if name.begins_with("impact")
		else ("hit_material" if name in ["hit_flesh", "hit_bone", "hit_stone"] else name)
	)
	if not preview and now - int(_last.get(gate, 0)) < 70:
		return
	var priority := voice_priority(name)
	var index := _voice_index(priority)
	if index < 0:
		dropped_voices += 1
		return
	_last[gate] = now
	var player := _players[index]
	_next = (index + 1) % _players.size()
	player.stream = sample_stream(name)
	_voice_serial += 1
	player.set_meta("voice_priority", priority)
	player.set_meta("voice_serial", _voice_serial)
	player.pitch_scale = (
		(
			_variation.randf_range(0.96, 1.04)
			if (
				name
				in [
					"slash",
					"impact",
					"impact_b",
					"impact_c",
					"impact_heavy",
					"fire",
					"ice",
					"lightning",
					"hit_fire",
					"hit_ice",
					"hit_lightning"
				]
			)
			else 1.0
		)
		* pitch_multiplier
	)
	var contact := (
		name.begins_with("impact") or name.begins_with("hit_") or name in ["tick", "kill"]
	)
	player.set_meta("warning", "")
	player.set_meta("contact_voice", contact)
	player.volume_db = playback_volume_db(name)
	player.play()
	played_serial += 1
	last_played = {
		"name": name, "voice": index, "priority": priority, "variant": _sample_last.get(name, -1)
	}


## 같은 샘플을 연달아 고르지 않는다. 별도 RNG이므로 드롭/공격 난수에 영향이 없다.
func sample_stream(name: String) -> AudioStream:
	if not _sample_banks.has(name):
		return _streams[name]
	var variants: Array = _sample_banks[name]
	var previous: int = _sample_last.get(name, -1)
	var index := (
		_variation.randi_range(0, variants.size() - 2)
		if previous >= 0
		else _variation.randi_range(0, variants.size() - 1)
	)
	if previous >= 0 and index >= previous:
		index += 1
	_sample_last[name] = index
	return variants[index]


static func playback_volume_db(name: String) -> float:
	if name == "weapon_draw":
		return -13.0
	if name.begins_with("step_"):
		return -16.0
	if name in ["warn_beast", "warn_goblin"]:
		return -6.0
	if name.begins_with("warn_"):
		return -10.0
	if name.begins_with("impact") or name.begins_with("hit_") or name in ["tick", "kill"]:
		return contact_volume_db(name)
	return -4.0


static func voice_priority(name: String) -> int:
	if name == "hurt":
		return 100
	if name in ["levelup", "warp", "town_bell"]:
		return 90
	if name.begins_with("warn_") or name in ["loot", "kill", "evade_confirm"]:
		return 80
	if name.begins_with("step_"):
		return 20
	return 65 if name.begins_with("hit_") or name.begins_with("impact") or name == "tick" else 55


func _voice_index(priority: int) -> int:
	var selected := -1
	for offset: int in _players.size():
		var index := (_next + offset) % _players.size()
		var player := _players[index]
		if not player.playing:
			return index
		var lower: int = player.get_meta("voice_priority", 0)
		if lower > priority:
			continue
		if (
			selected < 0
			or lower < int(_players[selected].get_meta("voice_priority", 0))
			or (
				lower == int(_players[selected].get_meta("voice_priority", 0))
				and (
					int(player.get_meta("voice_serial", 0))
					< int(_players[selected].get_meta("voice_serial", 0))
				)
			)
		):
			selected = index
	return selected


static func warning_name(species: String) -> String:
	if species == "skeleton":
		return "warn_skeleton"
	if species == "golem":
		return "warn_golem"
	return "warn_goblin" if species == "goblin" else "warn_beast"


func play_warning(species: String, distance: float) -> bool:
	if not Prefs.sound_enabled or distance > 310.0:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_warning_ms < 180:
		return false
	var active := 0
	for player: AudioStreamPlayer in _players:
		if player.playing and str(player.get_meta("warning", "")).begins_with("warn_"):
			active += 1
	if active >= 2:
		return false
	var pitch := float(
		{"wolf": 1.10, "boar": 0.72, "cave_crawler": 1.28, "golem": 0.65, "skeleton": 0.82}.get(
			species, 1.0
		)
	)
	var before := played_serial
	play(warning_name(species), false, pitch)
	if played_serial == before:
		return false
	_last_warning_ms = now
	_players[int(last_played["voice"])].set_meta("warning", warning_name(species))
	return true
