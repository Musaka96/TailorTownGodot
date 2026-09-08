extends Node

## Autoloaded as "DayNight". Plays one work shift as an accelerated day: it begins at
## midday and advances to night over `shift_real_seconds`, driving the current
## scene's Sun (DirectionalLight3D) and WorldEnvironment sky. The light sweeps down
## through a warm sunset, then a soft blue "moon" rises and the world settles into a
## cartoonish blue night — kept bright by lifting the ambient, never black. When the
## end hour is reached it rings a closing bell and emits EventBus.shift_ended.
##
## It locates the sun + environment in whatever scene is current (by type), so it
## needs no scene edits and won't touch the map on disk. The HUD clock reads `hour`
## and the shift window from here. Call start_shift() to run another day.

const DEFAULT_START_HOUR := 12.0
const DEFAULT_END_HOUR := 22.0
const DEFAULT_SHIFT_SECONDS := 300.0

# Light / sky palette keyframes (day → dusk → night).
const DAY_SUN := Color(1.0, 0.96, 0.88)
const DUSK_SUN := Color(1.0, 0.55, 0.30)
const NIGHT_SUN := Color(0.55, 0.66, 1.0)
const DAY_TOP := Color(0.35, 0.58, 0.98)
const DAY_HORIZON := Color(0.72, 0.83, 0.98)
const DUSK_HORIZON := Color(0.98, 0.55, 0.32)
const NIGHT_TOP := Color(0.05, 0.09, 0.30)
const NIGHT_HORIZON := Color(0.16, 0.20, 0.46)
const DAY_GROUND := Color(0.42, 0.40, 0.37)
const NIGHT_GROUND := Color(0.10, 0.12, 0.28)

## Current in-game hour (24h), read by the clock.
var hour := DEFAULT_START_HOUR
var running := false

var _elapsed := 0.0
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
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


## Find the sun + environment in the current scene (re-finds when the scene changes,
## detected by the cached sun going invalid).
func _locate() -> void:
	if _sun != null and is_instance_valid(_sun):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var lights := scene.find_children("*", "DirectionalLight3D", true, false)
	_sun = lights[0] if not lights.is_empty() else null
	_env = null
	_sky = null
	var envs := scene.find_children("*", "WorldEnvironment", true, false)
	if not envs.is_empty():
		_env = (envs[0] as WorldEnvironment).environment
		if _env != null and _env.sky != null:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial


## Apply the current hour to the sun direction/colour and the sky palette.
func _drive() -> void:
	var dusk := smoothstep(15.5, 18.5, hour)
	var night := smoothstep(16.5, 21.0, hour)
	var deep := smoothstep(19.0, 21.5, hour)

	if _sun != null and is_instance_valid(_sun):
		# Sun arcs down to the horizon by dusk; then a soft moon rises for the night.
		var sun_elev := 90.0 * cos((hour - 12.0) / 12.0 * PI)
		var elevation := lerpf(sun_elev, 50.0, deep)
		var yaw := -30.0 + (hour - 12.0) / 10.0 * 90.0
		_sun.rotation_degrees = Vector3(-elevation, yaw, 0.0)
		_sun.light_color = DAY_SUN.lerp(DUSK_SUN, dusk).lerp(NIGHT_SUN, night)
		var energy := lerpf(1.05, 0.9, dusk)
		_sun.light_energy = lerpf(energy, 0.4, night)

	if _sky != null:
		_sky.sky_top_color = DAY_TOP.lerp(NIGHT_TOP, night)
		var horizon := DAY_HORIZON.lerp(DUSK_HORIZON, dusk * (1.0 - night))
		horizon = horizon.lerp(NIGHT_HORIZON, night)
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sky.ground_bottom_color = DAY_GROUND.lerp(NIGHT_GROUND, night)

	if _env != null:
		# Lift ambient at night so it reads as a bright cartoon night, not darkness.
		_env.ambient_light_energy = lerpf(1.0, 1.4, night)


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
