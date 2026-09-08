extends Node

## Autoloaded as "DayNight". Runs one work shift across the day: it advances the
## in-game clock from the start hour to the end hour over `shift_real_seconds` and
## sweeps the scene's Sun (DirectionalLight3D) across the sky at a pleasant daytime
## angle — never straight overhead, never down to night. The light comes in low and
## warm at the open, lifts toward midday, and eases back down by closing, with the
## direction rotating so shadows travel across the shop through the day. At the end
## hour it rings a closing bell and emits EventBus.shift_ended.
##
## It finds the sun in whatever scene is current (by type), so it needs no scene
## edits. The HUD clock reads `hour` and the shift window from here. It intentionally
## leaves the sky/ambient alone — the shift is a daytime window, not a night cycle.

const DEFAULT_START_HOUR := 8.0
const DEFAULT_END_HOUR := 17.0
const DEFAULT_SHIFT_SECONDS := 300.0

# Sun look across the shift (ends = warm/low, midday = neutral/higher — never zenith).
const SUN_MID := Color(1.0, 0.97, 0.90)
const SUN_GOLDEN := Color(1.0, 0.87, 0.70)
const ELEV_LOW := 38.0  # degrees above horizon at the open/close
const ELEV_HIGH := 56.0  # degrees at midday (angled, not overhead)
const YAW_START := -55.0
const YAW_END := 55.0

## Current in-game hour (24h), read by the clock.
var hour := DEFAULT_START_HOUR
var running := false

var _elapsed := 0.0
var _sun: DirectionalLight3D
var _bell: AudioStreamPlayer


func _ready() -> void:
	_bell = AudioStreamPlayer.new()
	_bell.stream = _make_bell()
	add_child(_bell)
	start_shift()


func _process(delta: float) -> void:
	if running:
		_elapsed += delta
		var p := clampf(_elapsed / _shift_seconds(), 0.0, 1.0)
		hour = lerpf(start_hour(), end_hour(), p)
		if p >= 1.0:
			running = false
			EventBus.shift_ended.emit()
			_ring()
	_locate()
	_drive()


# --- Public API ------------------------------------------------------------


## Begin (or restart) the shift from the start hour.
func start_shift() -> void:
	_elapsed = 0.0
	hour = start_hour()
	running = true
	EventBus.shift_started.emit(hour)


## 0..1 across the whole shift.
func progress() -> float:
	return clampf(_elapsed / _shift_seconds(), 0.0, 1.0)


func start_hour() -> float:
	var c := _cfg()
	return c.shift_start_hour if c != null else DEFAULT_START_HOUR


func end_hour() -> float:
	var c := _cfg()
	return c.shift_end_hour if c != null else DEFAULT_END_HOUR


## "HH:MM" for the current time.
func time_string() -> String:
	var h := int(floor(hour)) % 24
	var m := int(floor(fmod(hour, 1.0) * 60.0))
	return "%02d:%02d" % [h, m]


# --- Internals -------------------------------------------------------------


func _cfg() -> GameConfig:
	return Config.data if Config != null else null


func _shift_seconds() -> float:
	var c := _cfg()
	return maxf(c.shift_real_seconds if c != null else DEFAULT_SHIFT_SECONDS, 1.0)


## Find the sun in the current scene (re-finds when the scene changes, detected by
## the cached sun going invalid).
func _locate() -> void:
	if _sun != null and is_instance_valid(_sun):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var lights := scene.find_children("*", "DirectionalLight3D", true, false)
	_sun = lights[0] if not lights.is_empty() else null


## Sweep the sun across the sky over the shift: a gentle elevation arc (low → midday
## → low) with the direction rotating east→west, and a warm tint near the ends.
func _drive() -> void:
	if _sun == null or not is_instance_valid(_sun):
		return
	var p := progress()
	var arc := sin(p * PI)  # 0 at the ends of the day, 1 at midday
	var elevation := lerpf(ELEV_LOW, ELEV_HIGH, arc)
	var yaw := lerpf(YAW_START, YAW_END, p)
	_sun.rotation_degrees = Vector3(-elevation, yaw, 0.0)
	var golden := 1.0 - arc
	_sun.light_color = SUN_MID.lerp(SUN_GOLDEN, golden * 0.6)
	_sun.light_energy = lerpf(1.15, 1.0, golden)


func _ring() -> void:
	if _bell == null:
		return
	_bell.play()
	get_tree().create_timer(0.55).timeout.connect(_bell.play)


## Synthesise a short bell "ding" (bell partials with exponential decay) so no audio
## asset is needed. Played twice for a ding-dong at closing time.
func _make_bell() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 1.3)
	var partials := [1.0, 2.0, 2.76, 5.4]
	var amps := [1.0, 0.6, 0.4, 0.22]
	var base := 620.0
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var env := exp(-3.2 * t)
		var s := 0.0
		for k in partials.size():
			s += amps[k] * sin(TAU * base * partials[k] * t)
		var sample := clampf(s * env * 0.2, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
