extends SceneTree

## Synthesises the stage curtain's two sounds as .wav files — pure sample maths, no
## recordings and nothing to generate on a GPU:
##   godot --headless --path . --script res://tools/build_curtain_audio.gd
## Then --import so Godot picks the WAVs up.
##
## Separate from build_audio.gd because that one rewrites the whole cutting-minigame set at
## 22 kHz every run; these want 44.1 kHz for the brush of the velvet and the chatter of the
## brass rings. Both are timed to ui/loading_curtain.gd, which plays them as it starts each
## move: the close lands its thump exactly as the fabric reaches the floor (DROP_SECONDS),
## and the open's sweep peaks halfway through the pull (PART_SECONDS). Keep them in step if
## those durations change.

const RATE := 44100
const DIR := "res://assets/audio"
const DROP := 0.5  # LoadingCurtain.DROP_SECONDS
const PART := 0.75  # LoadingCurtain.PART_SECONDS
const PEAK := 0.85  # normalise to this, leaving a little headroom
const EDGE := 0.006  # seconds of fade at each end, so nothing clicks

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260918  # fixed, so re-running gives byte-identical files
	_save(_close(), "curtain_close")
	_rng.seed = 20260919
	_save(_open(), "curtain_open")
	print("build_curtain_audio: done.")
	quit(0)


## Velvet dropping: the rings chatter along the rail, the cloth brushes past itself and
## darkens as it slows, and the weight lands with a soft thump on the floor.
func _close() -> PackedFloat32Array:
	var n := int((DROP + 0.45) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var poles := PackedFloat32Array([0.0, 0.0, 0.0])
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var fall := clampf(t / DROP, 0.0, 1.0)
		var lp := _muffle(poles, _rng.randf_range(-1.0, 1.0), lerpf(2200.0, 350.0, fall))
		hp = lp - prev + hp * 0.985  # drop the rumble; keep the brush
		prev = lp
		var swell := pow(sin(PI * minf(t / (DROP * 1.06), 1.0)), 0.7)
		out[i] = hp * swell * exp(-maxf(t - DROP, 0.0) * 6.0) * 0.9
	_rings(out, 0.0, DROP, 18, 1.6, 0.55)
	_thump(out, DROP - 0.03)
	return out


## Velvet drawn aside: the rings run the whole length of the rail and the cloth sweeps off,
## brightest in the middle of the pull where it moves fastest, then a rustle as it settles.
func _open() -> PackedFloat32Array:
	var n := int((PART + 0.3) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var poles := PackedFloat32Array([0.0, 0.0, 0.0])
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := clampf(t / PART, 0.0, 1.0)
		var speed := 4.0 * p * (1.0 - p)  # the pull eases in and out again
		var lp := _muffle(poles, _rng.randf_range(-1.0, 1.0), lerpf(800.0, 2600.0, speed))
		hp = lp - prev + hp * 0.985
		prev = lp
		var tail := exp(-maxf(t - PART, 0.0) * 7.0)
		out[i] = hp * (0.15 + speed * 0.85) * tail * 0.4
	_rings(out, 0.02, PART, 22, 1.0, 0.42)
	return out


## Three one-pole low passes in series (-18 dB/oct), which is the difference between cloth
## and hiss. `cut` is the corner frequency in Hz; `state` holds the poles and is updated in
## place.
func _muffle(state: PackedFloat32Array, sample: float, cut: float) -> float:
	var a := 1.0 - exp(-TAU * cut / RATE)
	state[0] += (sample - state[0]) * a
	state[1] += (state[0] - state[1]) * a
	state[2] += (state[1] - state[2]) * a
	return state[2]


## Brass rings chattering along the rail between `from` and `to`. `crowd` above 1 bunches
## them toward the start (the moment the curtain is let go); 1 spreads them evenly.
func _rings(
	out: PackedFloat32Array, from: float, to: float, count: int, crowd: float, gain: float
) -> void:
	for _k in count:
		var at := lerpf(from, to, pow(_rng.randf(), crowd))
		_tick(out, at, _rng.randf_range(1700.0, 2600.0), gain * _rng.randf_range(0.25, 0.6))


## One ring: two inharmonic partials with a fast metallic decay.
func _tick(out: PackedFloat32Array, at: float, base: float, level: float) -> void:
	var start := int(at * RATE)
	for i in int(0.055 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var ring := sin(TAU * base * t) * 0.6 + sin(TAU * base * 1.51 * t) * 0.4
		out[idx] += ring * exp(-t * 90.0) * level * 0.18


## The weight of the fabric reaching the floor: a low body under a dull cloth slap.
func _thump(out: PackedFloat32Array, at: float) -> void:
	var start := int(at * RATE)
	var poles := PackedFloat32Array([0.0, 0.0, 0.0])
	for i in int(0.5 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var slap := _muffle(poles, _rng.randf_range(-1.0, 1.0), 700.0)
		out[idx] += sin(TAU * 62.0 * t) * exp(-t * 13.0) * 0.34 + slap * exp(-t * 24.0) * 0.75


## Normalise to PEAK and fade the very ends, then write a 16-bit mono WAV.
func _save(samples: PackedFloat32Array, sound_name: String) -> void:
	var loudest := 0.0
	for s in samples:
		loudest = maxf(loudest, absf(s))
	var gain := PEAK / loudest if loudest > 0.0 else 1.0
	var edge := int(EDGE * RATE)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var fade := minf(1.0, minf(float(i), float(samples.size() - 1 - i)) / edge)
		var v := clampf(samples[i] * gain * fade, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var path := "%s/%s.wav" % [DIR, sound_name]
	if wav.save_to_wav(path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote %s (%.2fs, peak x%.2f)" % [path, float(samples.size()) / RATE, gain])
