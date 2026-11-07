extends Node
## 전투 효과음 (원본 audio_profile.dart의 SoundProfile을 그대로 합성): 피치 스윕 + 필터링한 노이즈.

const RATE := 22050
const PROFILES := {
	# name: [pitch, endPitch, duration, noiseFreq, noiseGain, toneGain, wave]
	"slash": [290.0, 85.0, 0.13, 2600.0, 0.14, 0.035, "triangle"],
	"prepare": [340.0, 520.0, 0.075, 1700.0, 0.025, 0.008, "sine"],
	"fire": [180.0, 55.0, 0.25, 650.0, 0.15, 0.055, "sine"],
	"ice": [1500.0, 610.0, 0.19, 5200.0, 0.07, 0.025, "triangle"],
	"lightning": [840.0, 190.0, 0.15, 3400.0, 0.12, 0.025, "sawtooth"],
	"impact": [180.0, 48.0, 0.11, 1200.0, 0.13, 0.07, "sine"],
	"impact_heavy": [125.0, 34.0, 0.17, 1600.0, 0.15, 0.075, "sine"],
	"hurt": [95.0, 38.0, 0.19, 700.0, 0.11, 0.07, "sine"],
	"dodge": [190.0, 100.0, 0.12, 3800.0, 0.08, 0.01, "sine"],
	"warcry": [135.0, 58.0, 0.36, 320.0, 0.10, 0.06, "sine"],
	"levelup": [660.0, 1320.0, 0.42, 0.0, 0.0, 0.035, "sine"],
	"loot": [880.0, 1320.0, 0.18, 0.0, 0.0, 0.025, "sine"],
	"warp": [440.0, 1040.0, 0.32, 1200.0, 0.02, 0.04, "sine"],
	# JUICE #11: not in the original audio_profile.dart. Godot-side additions so contact is not one repeated
	# thud: two light variants, a medium variant, a short high "tick" transient layered on harder hits and a
	# descending "kill" thud. Values are first guesses tuned by ear, not measured.
	"impact_b": [215.0, 56.0, 0.10, 1500.0, 0.13, 0.065, "sine"],
	"impact_c": [150.0, 42.0, 0.14, 1400.0, 0.14, 0.072, "sine"],
	"tick": [1900.0, 900.0, 0.04, 5200.0, 0.10, 0.02, "triangle"],
	"kill": [260.0, 62.0, 0.24, 900.0, 0.14, 0.075, "sine"],
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


func _ready() -> void:
	for name in PROFILES:
		_streams[name] = _synth(PROFILES[name])
	for i in 8:
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
static func hit_names(tier: int, variant: int) -> Array[String]:
	match tier:
		HitTier.LIGHT:
			return ["impact" if variant % 2 == 0 else "impact_b"]
		HitTier.MEDIUM:
			return ["impact_c", "tick"]
		HitTier.HEAVY:
			return ["impact_heavy", "tick"]
	return ["impact_heavy", "kill"]


## One semitone per consecutive kill inside the window, capped so it never turns shrill.
static func streak_pitch(count: int) -> float:
	return pow(2.0, clampi(count, 0, STREAK_MAX) / 12.0)


func play_hit(tier: int) -> void:
	var names := hit_names(tier, _hit_variant)
	_hit_variant += 1
	for sound in names:
		if sound == "kill":
			play(sound, false, _next_kill_pitch())
		else:
			play(sound)


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
	var gate := "impact" if name.begins_with("impact") else name
	if not preview and now - int(_last.get(gate, 0)) < 70:
		return
	_last[gate] = now
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[name]
	player.pitch_scale = (_variation.randf_range(0.96, 1.04) if name in ["slash", "impact", "impact_b", "impact_c", "impact_heavy", "fire", "ice", "lightning"] else 1.0) * pitch_multiplier
	player.volume_db = -4.0
	player.play()
