extends SceneTree

## Synthesises the pressing and coffee minigames' sounds as .wav files — pure sample maths:
##   godot --headless --path . --script res://tools/build_comfort_audio.gd
## Then --import so Godot picks them up.
##
##   iron_glide_loop  the iron pushed along the cloth: a low, soft, steamy rub (loops)
##   scorch           held too long: a short dry sizzle with a dull thump under it
##   grinder_loop     the espresso grinder: a rattly motor hum with beans in it (loops)
##   tamp             the tamper pressed home: a soft, woody thud
##   pour_loop        coffee running into a cup: a warm trickle with small bubbles (loops)
##
## Kept quiet and rounded (cute, not foley) — see the audio notes in docs/SFX_LIST.md.
## Seeded, so re-running gives byte-identical files (maths shared via audio_synth.gd).

const RATE := 44100
const DIR := "res://assets/audio"
const XFADE := 0.12  # a loop's tail is folded back over its head so the loop point is silent

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260924
	AudioSynth.save(_seamless(_glide, 1.2), RATE, DIR, "iron_glide_loop", true)
	_rng.seed = 20260925
	AudioSynth.save(_scorch(), RATE, DIR, "scorch")
	_rng.seed = 20260926
	AudioSynth.save(_seamless(_grinder, 1.0), RATE, DIR, "grinder_loop", true)
	_rng.seed = 20260927
	AudioSynth.save(_tamp(), RATE, DIR, "tamp")
	_rng.seed = 20260928
	AudioSynth.save(_seamless(_trickle, 1.2), RATE, DIR, "pour_loop", true)
	print("build_comfort_audio: done.")
	quit(0)


## Render `voice` a little long and fold the extra tail over the start, so the last sample
## flows straight into the first.
func _seamless(voice: Callable, length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var f := int(XFADE * RATE)
	var buf: PackedFloat32Array = voice.call(n + f)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = buf[i]
	for i in f:
		var w := float(i) / f
		out[i] = buf[i] * w + buf[n + i] * (1.0 - w)
	return out


func _glide(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var body := AudioSynth.poles()
	var low := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var rub := AudioSynth.muffle(body, noise, 1500.0, RATE)
		rub -= AudioSynth.muffle(low, noise, 300.0, RATE)
		out[i] = rub * (0.8 + 0.2 * sin(TAU * 5.0 * t))
	return out


func _scorch() -> PackedFloat32Array:
	var n := int(0.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var sizzle := AudioSynth.muffle(hi, noise, 7000.0, RATE)
		sizzle -= AudioSynth.muffle(lo, noise, 2200.0, RATE)
		var crackle := 1.0 if _rng.randf() < 0.04 else 0.35
		var thump := sin(TAU * 95.0 * t) * exp(-t * 28.0) * 0.8
		out[i] = sizzle * crackle * exp(-t * 6.0) + thump
	return out


func _grinder(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var grit := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var hum := sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 220.0 * t) * 0.25
		var beans := AudioSynth.muffle(grit, _rng.randf_range(-1.0, 1.0), 3200.0, RATE)
		var rattle := 0.6 + 0.4 * absf(sin(TAU * 12.0 * t))
		out[i] = hum * 0.5 + beans * rattle * 0.7
	return out


func _tamp() -> PackedFloat32Array:
	var n := int(0.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var puff := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var thud := sin(TAU * (120.0 - t * 140.0) * t) * exp(-t * 26.0)
		var soft := AudioSynth.muffle(puff, _rng.randf_range(-1.0, 1.0), 900.0, RATE)
		out[i] = thud + soft * exp(-t * 40.0) * 0.4
	return out


## Coffee running into the cup: a muffled, steady flow with a few small bubbles rising on
## it. The bubbles sit clear of the folded tail so each one plays whole on every loop.
func _trickle(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var body := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var flow := AudioSynth.muffle(body, _rng.randf_range(-1.0, 1.0), 900.0, RATE)
		out[i] = flow * (0.9 + 0.1 * sin(TAU * 2.5 * t))
	var first := XFADE + 0.02
	var span := float(n) / RATE - XFADE - first - 0.06
	var count := 5
	for k in count:
		var at := first + span * (float(k) + _rng.randf_range(0.1, 0.9)) / count
		AudioSynth.mix(out, _bubble(_rng.randf_range(0.05, 0.08)), at, RATE)
	return out


## One soft bubble: a short sine chirp rising 300 -> 600 Hz under a rounded window.
func _bubble(level: float) -> PackedFloat32Array:
	var length := 0.04
	var v := PackedFloat32Array()
	v.resize(int(length * RATE))
	for i in v.size():
		var t := float(i) / RATE
		var phase := TAU * (300.0 * t + 300.0 * t * t / (2.0 * length))
		v[i] = sin(phase) * sin(PI * t / length) * level
	return v
