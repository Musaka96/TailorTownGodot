extends SceneTree

## Synthesises the cutting table's glide loop as a .wav — pure sample maths:
##   godot --headless --path . --script res://tools/build_cut_audio.gd
## Then --import so Godot picks it up.
##
##   scissors_glide_loop  the shears held half-open and pushed along a straight run: a
##                        soft, steady hiss of cloth parting on the blade, a faint steel
##                        shimmer, and a gentle flutter as the threads give. Seamless.
##
## Seeded, so re-running gives a byte-identical file (maths shared via audio_synth.gd).

const RATE := 44100
const DIR := "res://assets/audio"
const LENGTH := 1.2  # seconds; the flutter below repeats a whole number of times in it
const FLUTTER_HZ := 7.5
const XFADE := 0.12  # the tail is folded back over the head so the loop point is silent

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260921
	AudioSynth.save(_glide(), RATE, DIR, "scissors_glide_loop", true)
	print("build_cut_audio: done.")
	quit(0)


func _glide() -> PackedFloat32Array:
	var n := int(LENGTH * RATE)
	var f := int(XFADE * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + f)
	var body := AudioSynth.poles()
	var edge := AudioSynth.poles()
	var low := AudioSynth.poles()
	for i in n + f:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		# Cloth parting: noise with most of its lows taken out (bright minus dull = a soft
		# band). A share of the lows is left in as the blade's body, under the hiss.
		var hiss := AudioSynth.muffle(body, noise, 1700.0, RATE)
		hiss -= AudioSynth.muffle(low, noise, 500.0, RATE) * 0.7
		var fine := AudioSynth.muffle(edge, _rng.randf_range(-1.0, 1.0), 3800.0, RATE)
		var flutter := 0.75 + 0.25 * sin(TAU * FLUTTER_HZ * t)
		var shimmer := sin(TAU * 3150.0 * t) * (0.5 + 0.5 * sin(TAU * FLUTTER_HZ * 2.0 * t))
		buf[i] = hiss * flutter + fine * 0.18 + shimmer * 0.035
	# Fold the extra tail over the start: sample n-1 flows straight into sample 0.
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = buf[i]
	for i in f:
		var w := float(i) / f
		out[i] = buf[i] * w + buf[n + i] * (1.0 - w)
	return out
