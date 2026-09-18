extends SceneTree

## Synthesises the workshop furniture's sounds as .wav files — pure sample maths:
##   godot --headless --path . --script res://tools/build_shop_audio.gd
## Then --import so Godot picks them up.
##
##   steam_hiss   the iron pressed down: a soft burst of steam that swells and sighs out,
##                under a little wooden knock of the iron on the board
##   coffee_pour  a cup filled from the pot: a warm trickle with small bubbles on it and
##                a gentle clink of the cup at the end
##
## Kept quiet and rounded (cute, not foley) — see the audio notes in docs/SFX_LIST.md.
## Seeded, so re-running gives byte-identical files (maths shared via audio_synth.gd).

const RATE := 44100
const DIR := "res://assets/audio"

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260922
	AudioSynth.save(_steam(), RATE, DIR, "steam_hiss")
	_rng.seed = 20260923
	AudioSynth.save(_pour(), RATE, DIR, "coffee_pour")
	print("build_shop_audio: done.")
	quit(0)


func _steam() -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var hiss := AudioSynth.muffle(hi, noise, 5200.0, RATE)
		hiss -= AudioSynth.muffle(lo, noise, 900.0, RATE)
		var swell := smoothstep(0.0, 0.12, t) * exp(-maxf(t - 0.12, 0.0) * 4.5)
		var knock := sin(TAU * 140.0 * t) * exp(-t * 60.0) * 0.6
		out[i] = hiss * swell + knock
	return out


func _pour() -> PackedFloat32Array:
	var n := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var body := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var flow := AudioSynth.muffle(body, _rng.randf_range(-1.0, 1.0), 1400.0, RATE)
		var level := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.75, 0.9, t))
		out[i] = flow * level * 0.8
	# Bubbles: little rising blips as the cup fills.
	var at := 0.05
	while at < 0.85:
		AudioSynth.mix(out, _bubble(_rng.randf_range(500.0, 900.0) + at * 500.0), at, RATE)
		at += _rng.randf_range(0.035, 0.09)
	AudioSynth.mix(out, _clink(), 0.93, RATE)
	return out


func _bubble(freq: float) -> PackedFloat32Array:
	var n := int(0.04 * RATE)
	var v := PackedFloat32Array()
	v.resize(n)
	for i in n:
		var t := float(i) / RATE
		v[i] = sin(TAU * freq * (1.0 + t * 12.0) * t) * sin(PI * t / 0.04) * 0.35
	return v


func _clink() -> PackedFloat32Array:
	var n := int(0.16 * RATE)
	var v := PackedFloat32Array()
	v.resize(n)
	for i in n:
		var t := float(i) / RATE
		v[i] = (sin(TAU * 2350.0 * t) + sin(TAU * 3470.0 * t) * 0.5) * exp(-t * 32.0) * 0.4
	return v
