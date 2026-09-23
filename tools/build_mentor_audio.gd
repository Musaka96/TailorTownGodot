extends SceneTree

## Synthesises Mr. Hemming's talk blips as .wav files — pure sample maths:
##   godot --headless --path . --script res://tools/build_mentor_audio.gd
## Then --import so Godot picks the WAVs up. Shares its maths with the other sound builders
## via tools/audio_synth.gd.
##
##   mentor_blip_1..5  one mumbled syllable each: a soft buzzing voice through two rounded
##                     resonances, gliding a little, with a breath at the end. An older man
##                     murmuring, not a beeping toy. ui/tutorial/mentor_dialog.gd picks one
##                     per letter and pitches it 0.9-1.15.
##
## Seeded, so re-running gives byte-identical files.

const RATE := 44100
const DIR := "res://assets/audio"
## How many harmonics make up the voice's pulse train (all under the resonances anyway).
const HARMONICS := 12
## Per syllable: pitch (Hz), glide across it (fraction), length (s), and the vowel — how
## much of the brighter 1400 Hz resonance is mixed over the 500 Hz one.
const SYLLABLES := [
	[165.0, 0.05, 0.078, 0.35],
	[190.0, -0.06, 0.084, 0.55],
	[150.0, 0.03, 0.072, 0.25],
	[210.0, -0.04, 0.09, 0.5],
	[178.0, 0.06, 0.08, 0.4],
]

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	for k in SYLLABLES.size():
		_rng.seed = 20260960 + k  # fixed, so re-running gives byte-identical files
		var s: Array = SYLLABLES[k]
		AudioSynth.save(_syllable(s[0], s[1], s[2], s[3]), RATE, DIR, "mentor_blip_%d" % (k + 1))
	print("build_mentor_audio: done.")
	quit(0)


func _syllable(pitch: float, glide: float, length: float, vowel: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var low := AudioSynth.poles()
	var high := AudioSynth.poles()
	var air := AudioSynth.poles()
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var p := t / length
		# A slight glide over the syllable, and a small quaver: an older voice.
		phase += TAU * pitch * (1.0 + glide * p) * (1.0 + 0.012 * sin(TAU * 9.0 * t)) / RATE
		var pulse := 0.0
		for h in range(1, HARMONICS + 1):
			pulse += cos(h * phase)
		pulse /= HARMONICS
		var voice := (
			AudioSynth.muffle(low, pulse, 500.0, RATE) * (1.0 - vowel)
			+ AudioSynth.muffle(high, pulse, 1400.0, RATE) * vowel
		)
		var q := minf(p / 0.88, 1.0)
		var shape := sin(PI * pow(q, 0.7))
		var breath := AudioSynth.muffle(air, _rng.randf_range(-1.0, 1.0), 1200.0, RATE)
		var tail := minf(1.0, (length - t) / 0.015)
		out[i] = (voice * shape + breath * p * pow(sin(PI * p), 2.0) * 0.6) * tail
	return out
