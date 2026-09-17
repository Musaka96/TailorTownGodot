extends SceneTree

## Synthesises the sewing machine's per-tap sounds as .wav files — pure sample maths, no
## recordings and nothing to generate on a GPU:
##   godot --headless --path . --script res://tools/build_sewing_audio.gd
## Then --import so Godot picks the WAVs up.
##
## The machine's own running loop is a real recording (sew_machine_loop.wav); these are the
## short cues that have to land the instant you press, which the shipped stitch.wav could
## not do — it is two seconds long and all but silent, so every tap felt dead. Three cues,
## so the seam answers differently depending on how well you caught it:
##   sew_stitch_good     a needle punching cloth
##   sew_stitch_perfect  the same punch with a bright little ring on top
##   sew_tap             a dry click for a press that lands on nothing
##
## Shares its maths with build_curtain_audio.gd via tools/audio_synth.gd, and is seeded, so
## re-running gives byte-identical files.

const RATE := 44100
const DIR := "res://assets/audio"

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260918
	AudioSynth.save(_punch(false), RATE, DIR, "sew_stitch_good")
	_rng.seed = 20260919
	AudioSynth.save(_punch(true), RATE, DIR, "sew_stitch_perfect")
	_rng.seed = 20260920
	AudioSynth.save(_tap(), RATE, DIR, "sew_tap")
	print("build_sewing_audio: done.")
	quit(0)


## The needle going through: a click as it pierces, a short body as the bar drives down, and
## the thread being drawn after it. `bright` adds the ring that says the stitch was perfect.
func _punch(bright: bool) -> PackedFloat32Array:
	var n := int((0.17 if bright else 0.09) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var pierce := AudioSynth.poles()
	var thread := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var click := AudioSynth.muffle(pierce, _rng.randf_range(-1.0, 1.0), 2800.0, RATE)
		var pull := AudioSynth.muffle(thread, _rng.randf_range(-1.0, 1.0), 4200.0, RATE)
		var bar := sin(TAU * 185.0 * t) * exp(-t * 70.0) * 0.5  # the bar driving down
		var point := click * exp(-t * 240.0) * 2.2  # the needle going through
		var draw := pull * exp(-t * 90.0) * 0.5  # thread drawn after it
		out[i] = bar + point + draw
	if bright:
		_ring(out)
	return out


## A small bell over the punch — two partials a fifth-ish apart, ringing out gently.
func _ring(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var bell := sin(TAU * 2640.0 * t) * 0.6 + sin(TAU * 3960.0 * t) * 0.4
		out[i] += bell * exp(-t * 21.0) * 0.32


## A press that lands on nothing: the treadle answering, dry and quiet, so the button is
## never silent without being mistaken for a stitch.
func _tap() -> PackedFloat32Array:
	var n := int(0.05 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var poles := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var click := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 2000.0, RATE)
		out[i] = click * exp(-t * 300.0) * 2.0 + sin(TAU * 900.0 * t) * exp(-t * 200.0) * 0.25
	return out
