extends SceneTree

## Synthesises the stage curtain's two sounds as .wav files — pure sample maths, no
## recordings and nothing to generate on a GPU:
##   godot --headless --path . --script res://tools/build_curtain_audio.gd
## Then --import so Godot picks the WAVs up.
##
## Separate from build_audio.gd because that one rewrites the whole cutting-minigame set at
## 22 kHz every run; these want 44.1 kHz for the brush of the velvet and the chatter of the
## brass rings. The sample maths is shared with the other sound builders in
## tools/audio_synth.gd. Both are timed to ui/loading_curtain.gd, which plays them as it
## starts each
## move: the close lands its thump exactly as the fabric reaches the floor (DROP_SECONDS),
## and the open's sweep peaks halfway through the pull (PART_SECONDS). Keep them in step if
## those durations change.

const RATE := 44100
const DIR := "res://assets/audio"
const DROP := 0.5  # LoadingCurtain.DROP_SECONDS
const PART := 0.75  # LoadingCurtain.PART_SECONDS

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260918  # fixed, so re-running gives byte-identical files
	AudioSynth.save(_close(), RATE, DIR, "curtain_close")
	_rng.seed = 20260919
	AudioSynth.save(_open(), RATE, DIR, "curtain_open")
	print("build_curtain_audio: done.")
	quit(0)


## Velvet dropping: the rings chatter along the rail, the cloth brushes past itself and
## darkens as it slows, and the weight lands with a soft thud on the floor.
func _close() -> PackedFloat32Array:
	var n := int((DROP + 0.45) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var poles := AudioSynth.poles()
	var hp := 0.0
	var prev := 0.0
	var fab_hi := AudioSynth.poles()
	var fab_lo := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var fall := clampf(t / DROP, 0.0, 1.0)
		var noise := _rng.randf_range(-1.0, 1.0)
		var lp := AudioSynth.muffle(poles, noise, lerpf(1400.0, 300.0, fall), RATE)
		hp = lp - prev + hp * 0.985  # drop the rumble; keep the brush
		prev = lp
		var swell := pow(sin(PI * minf(t / (DROP * 1.06), 1.0)), 0.7)
		var fade := exp(-maxf(t - DROP, 0.0) * 6.0)
		out[i] = (hp * 0.7 + _band(fab_hi, fab_lo, noise) * 1.6) * swell * fade
	_rings(out, 0.0, DROP, 9, 1.6, 0.3)
	_thump(out, DROP - 0.03)
	return out


## Velvet drawn aside: a light muffled whoosh as it starts to move, the rings run the whole
## length of the rail and the cloth sweeps off, fullest in the middle of the pull where it
## moves fastest, then a rustle as it settles.
func _open() -> PackedFloat32Array:
	var n := int((PART + 0.3) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var poles := AudioSynth.poles()
	var rush := AudioSynth.poles()
	var hp := 0.0
	var prev := 0.0
	var fab_hi := AudioSynth.poles()
	var fab_lo := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var p := clampf(t / PART, 0.0, 1.0)
		var speed := 4.0 * p * (1.0 - p)  # the pull eases in and out again
		var noise := _rng.randf_range(-1.0, 1.0)
		var lp := AudioSynth.muffle(poles, noise, lerpf(600.0, 1700.0, speed), RATE)
		hp = lp - prev + hp * 0.985
		prev = lp
		var tail := exp(-maxf(t - PART, 0.0) * 7.0)
		var body := hp * 0.3 + _band(fab_hi, fab_lo, noise) * 1.2
		# The whoosh-up: dull air opening out over the first moment of the pull.
		var up := smoothstep(0.0, 0.14, t) * exp(-maxf(t - 0.14, 0.0) * 9.0)
		var whoosh := AudioSynth.muffle(
			rush, noise, lerpf(300.0, 1200.0, minf(t / 0.14, 1.0)), RATE
		)
		out[i] = body * (0.15 + speed * 0.85) * tail + whoosh * up * 0.9
	_rings(out, 0.02, PART, 10, 1.0, 0.25)
	return out


## Brass rings chattering along the rail between `from` and `to`. `crowd` above 1 bunches
## them toward the start (the moment the curtain is let go); 1 spreads them evenly.
func _rings(
	out: PackedFloat32Array, from: float, to: float, count: int, crowd: float, gain: float
) -> void:
	for _k in count:
		var at := lerpf(from, to, pow(_rng.randf(), crowd))
		_tick(out, at, gain * _rng.randf_range(0.25, 0.6))


## One ring: a short, dull noise tick (muffled well below the brass's own ring), so the rail
## chatters softly instead of chiming.
func _tick(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in int(0.04 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var click := (
			AudioSynth.muffle(hi, noise, 2500.0, RATE) - AudioSynth.muffle(lo, noise, 900.0, RATE)
		)
		out[idx] += click * exp(-t * 130.0) * minf(1.0, t * 2000.0) * level


## The weight of the fabric reaching the floor: a low, round body under a dull cloth slap.
func _thump(out: PackedFloat32Array, at: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	var phase := 0.0
	for i in int(0.5 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		phase += TAU * lerpf(85.0, 55.0, minf(t / 0.1, 1.0)) / RATE
		var body := sin(phase) * exp(-t * 12.0) * minf(1.0, t * 400.0)
		var slap := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 500.0, RATE)
		out[idx] += body * 0.6 + slap * exp(-t * 24.0) * 0.8


## The cloth's own body: noise band-passed to roughly 250-600 Hz, under the brush. `hi` and
## `lo` are the voice's own filter states.
func _band(hi: PackedFloat32Array, lo: PackedFloat32Array, sample: float) -> float:
	return AudioSynth.muffle(hi, sample, 600.0, RATE) - AudioSynth.muffle(lo, sample, 250.0, RATE)
