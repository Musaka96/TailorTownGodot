extends SceneTree

## Synthesises the bench games' reward sounds as .wav files — pure sample maths:
##   godot --headless --path . --script res://tools/build_juice_audio.gd
## Then --import so Godot picks the WAVs up. Shares tools/audio_synth.gd with the other
## sound builders.
##
##   juice_note   one soft mallet note (C5). MinigameScreen plays it per perfect, pitched
##                up a pentatonic scale as the streak grows — so a clean run is a tune.
##   juice_top    the same note with a bright shimmer: the streak has reached the top.
##   juice_drop   a gentle two-note fall when a long streak breaks — an "aw", not a buzzer.
##   juice_stamp  the verdict stamp coming down: a low thump under a woody thunk and a
##                little ink-pad slap.

const RATE := 44100
const DIR := "res://assets/audio"
const C5 := 523.25

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260923  # fixed, so re-running gives byte-identical files
	AudioSynth.save(_note(false), RATE, DIR, "juice_note")
	AudioSynth.save(_note(true), RATE, DIR, "juice_top")
	AudioSynth.save(_drop(), RATE, DIR, "juice_drop")
	AudioSynth.save(_stamp(), RATE, DIR, "juice_stamp")
	print("build_juice_audio: done.")
	quit(0)


## A felt mallet on a wooden bar: the fundamental, a quick octave, and the bar's bright
## inharmonic ping that dies almost at once.
func _note(shimmer: bool) -> PackedFloat32Array:
	var out := _silence(0.75 if shimmer else 0.5)
	_mallet(out, 0.0, C5, 1.0)
	if shimmer:
		_mallet(out, 0.0, C5 * 2.0, 0.45)
		_mallet(out, 0.07, C5 * 3.0, 0.3)
		_mallet(out, 0.14, C5 * 4.0, 0.2)
	return out


func _drop() -> PackedFloat32Array:
	var out := _silence(0.55)
	_mallet(out, 0.0, C5 * 0.75, 0.6)  # G4
	_mallet(out, 0.13, C5 * 0.5946, 0.5)  # ~E♭4
	return out


func _stamp() -> PackedFloat32Array:
	var out := _silence(0.4)
	var poles := AudioSynth.poles()
	var drum := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var slap := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 1600.0, RATE)
		var body := (
			sin(TAU * 92.0 * t) * exp(-t * 16.0) + sin(TAU * 184.0 * t) * exp(-t * 34.0) * 0.5
		)
		# The weight landing: a low thump sweeping 75 -> 45 Hz, and a soft wooden knock.
		drum += TAU * lerpf(75.0, 45.0, minf(t / 0.12, 1.0)) / RATE
		var thump := sin(drum) * exp(-t * 14.0) * minf(1.0, t * 600.0)
		var knock := sin(TAU * 200.0 * t) * exp(-t * 55.0) * minf(1.0, t * 900.0)
		out[i] = body * 0.5 + slap * exp(-t * 55.0) * 0.7 + thump * 1.1 + knock * 0.3
	return out


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


func _mallet(out: PackedFloat32Array, at: float, freq: float, level: float) -> void:
	var start := int(at * RATE)
	for i in out.size() - start:
		var t := float(i) / RATE
		var tone := (
			sin(TAU * freq * t) * exp(-t * 7.0)
			+ sin(TAU * freq * 2.0 * t) * exp(-t * 14.0) * 0.25
			+ sin(TAU * freq * 3.93 * t) * exp(-t * 38.0) * 0.18
		)
		out[start + i] += tone * level * minf(1.0, t * 900.0) * 0.5
