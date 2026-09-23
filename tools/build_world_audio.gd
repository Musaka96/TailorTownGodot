extends SceneTree

## Synthesises the shop's everyday world and UI cues as .wav files — pure sample maths, in
## place of the old library samples the owner rated harsh or flat:
##   godot --headless --path . --script res://tools/build_world_audio.gd
## Then --import so Godot picks the WAVs up. Shares its maths with the other sound builders
## via tools/audio_synth.gd.
##
## Cute, soft, rounded and quiet — a toy shop, not realistic foley. Every voice runs through a
## muffle, so next to nothing lives above ~5 kHz.
##
##   new_order_ping   a pickup day arrives: two soft mallet notes, G5 then C6
##   footstep_wood_N  a gentle wooden pat: a falling thud under a tiny muffled sole tap
##   footstep_rug     the same pat, softer and duller, no tap
##   door_open        a small cartoony hinge creak, then a soft latch knock
##   door_close       a wooden thud with a hollow body, then a small latch click
##   cloth_rustle     a fabric fold: two soft humps of cloth noise, no tone
##   error            a cartoon bonk: a buzzy note stepping down, wobbling, over a low thunk
##   happy            two mallet notes up, E5 then G5, with a faint octave shimmer
##   phone_order      a receiver clunk, a soft rotary-dial whirr, a confirming ding on A5
##   tape             a tape measure zipping out with a ratchet, then snapping back
##
## Seeded, so re-running gives byte-identical files.

const RATE := 44100
const DIR := "res://assets/audio"
const E5 := 659.25
const G5 := 783.99
const A5 := 880.0
const C6 := 1046.50
## footstep_wood_1..3: thud pitch factor and when the sole tap lands (s).
const STEPS := [[1.0, 0.004], [1.08, 0.0], [0.92, 0.009]]

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260940  # fixed, so re-running gives byte-identical files
	AudioSynth.save(_order_ping(), RATE, DIR, "new_order_ping")
	for k in STEPS.size():
		_rng.seed = 20260941 + k
		var step: Array = STEPS[k]
		AudioSynth.save(_step(step[0], step[1]), RATE, DIR, "footstep_wood_%d" % (k + 1))
	_rng.seed = 20260944
	AudioSynth.save(_rug(), RATE, DIR, "footstep_rug")
	_rng.seed = 20260945
	AudioSynth.save(_door_open(), RATE, DIR, "door_open")
	_rng.seed = 20260946
	AudioSynth.save(_door_close(), RATE, DIR, "door_close")
	_rng.seed = 20260947
	AudioSynth.save(_rustle(), RATE, DIR, "cloth_rustle")
	_rng.seed = 20260948
	AudioSynth.save(_error(), RATE, DIR, "error")
	_rng.seed = 20260949
	AudioSynth.save(_happy(), RATE, DIR, "happy")
	_rng.seed = 20260950
	AudioSynth.save(_phone(), RATE, DIR, "phone_order")
	_rng.seed = 20260951
	AudioSynth.save(_tape(), RATE, DIR, "tape")
	print("build_world_audio: done.")
	quit(0)


func _order_ping() -> PackedFloat32Array:
	var out := _silence(0.7)
	_mallet(out, 0.0, G5, 0.85)
	_mallet(out, 0.14, C6, 0.9)
	_lowpass(out, 4500.0)
	_release(out, 0.22)
	return out


## A wooden pat: the heel's thud falling in pitch, the sole's tap a hair around it.
func _step(pitch: float, tap_at: float) -> PackedFloat32Array:
	var out := _silence(0.09)
	_pat(out, 150.0 * pitch, 95.0 * pitch, 0.05, 22.0)
	_tick(out, tap_at, 1200.0, 0.012, 0.9)
	_lowpass(out, 2000.0)
	_release(out, 0.03)
	return out


## On the rug: lower, longer and duller, with a soft scuff where the tap was.
func _rug() -> PackedFloat32Array:
	var out := _silence(0.1)
	_pat(out, 130.0, 85.0, 0.06, 18.0)
	_tick(out, 0.0, 500.0, 0.05, 1.2)
	_lowpass(out, 1200.0)
	_release(out, 0.035)
	return out


func _door_open() -> PackedFloat32Array:
	var out := _silence(0.45)
	_hinge(out, 0.0, 0.16, 0.45)
	_thump(out, 0.2, 190.0, 40.0, 0.8)
	_tick(out, 0.2, 1800.0, 0.015, 0.9)
	_lowpass(out, 3500.0)
	_release(out, 0.08)
	return out


func _door_close() -> PackedFloat32Array:
	var out := _silence(0.35)
	_thump(out, 0.0, 110.0, 28.0, 1.0)
	_thump(out, 0.0, 380.0, 45.0, 0.45)
	_tick(out, 0.0, 700.0, 0.03, 0.8)
	_tick(out, 0.06, 2200.0, 0.008, 3.2)
	_lowpass(out, 3000.0)
	_release(out, 0.08)
	return out


## A fold of cloth: a mid band of noise (no hiss, no boom) swelling in two soft humps.
func _rustle() -> PackedFloat32Array:
	var out := _silence(0.35)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in out.size():
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var band := (
			AudioSynth.muffle(hi, noise, 1600.0, RATE) - AudioSynth.muffle(lo, noise, 300.0, RATE)
		)
		var env := _hump(t, 0.05, 0.05) + _hump(t, 0.2, 0.12) * 0.8
		var grain := 0.75 + 0.25 * sin(TAU * 31.0 * t + sin(TAU * 7.0 * t) * 2.0)
		out[i] = band * env * grain
	_release(out, 0.03)
	return out


## Uh-oh: a hollow buzzy note (odd harmonics, like a kazoo in a box) that steps down a
## little and wobbles, over a low thunk as it lands.
func _error() -> PackedFloat32Array:
	var length := 0.32
	var out := _silence(length)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (220.0 if t < 0.12 else 185.0) / RATE
		var buzz := sin(phase) + 0.35 * sin(3.0 * phase) + 0.15 * sin(5.0 * phase)
		var trem := 0.75 + 0.25 * sin(TAU * 22.0 * t)
		var env := _gate(t, 0.0, 0.12, 0.018, 3.0) * 0.85 + _gate(t, 0.12, length, 0.12, 5.0)
		out[i] = buzz * trem * env * 0.5
	_thump(out, 0.0, 90.0, 35.0, 0.45)
	_tick(out, 0.0, 400.0, 0.03, 0.8)
	_lowpass(out, 2500.0)
	_release(out, 0.03)
	return out


func _happy() -> PackedFloat32Array:
	var out := _silence(0.5)
	_mallet(out, 0.0, E5, 0.8)
	_mallet(out, 0.13, G5, 0.9)
	_mallet(out, 0.13, G5 * 2.0, 0.18)
	_lowpass(out, 5000.0)
	_release(out, 0.16)
	return out


## Receiver lifted with a plasticky clunk, a short number dialled (the ticks speed up a
## touch as the dial runs home), and a little ding: order placed.
func _phone() -> PackedFloat32Array:
	var out := _silence(1.0)
	_thump(out, 0.0, 240.0, 40.0, 0.5)
	_tick(out, 0.0, 2000.0, 0.015, 0.8)
	_whirr(out, 0.12, 0.35)
	var at := 0.12
	for k in 7:
		_tick(out, at, 1500.0 * _rng.randf_range(0.9, 1.1), 0.012, _rng.randf_range(0.8, 1.0))
		at += lerpf(0.066, 0.05, k / 6.0)
	_mallet(out, 0.55, A5, 0.55)
	_lowpass(out, 4500.0)
	_release(out, 0.2)
	return out


## The blade zips out over a ratchet, brightening as it goes, then snaps home.
func _tape() -> PackedFloat32Array:
	var out := _silence(0.4)
	var zip := 0.25
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in int(zip * RATE):
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var cut := lerpf(700.0, 2400.0, t / zip)
		var band := (
			AudioSynth.muffle(hi, noise, cut, RATE) - AudioSynth.muffle(lo, noise, 250.0, RATE)
		)
		var ratchet := pow(0.5 + 0.5 * sin(TAU * 38.0 * t), 2.0)
		var env := minf(1.0, t / 0.02) * minf(1.0, (zip - t) / 0.03)
		out[i] = band * (0.3 + 0.7 * ratchet) * env * 2.2
	_tick(out, 0.3, 2000.0, 0.01, 1.0)
	_thump(out, 0.3, 300.0, 60.0, 0.45)
	_lowpass(out, 4000.0)
	_release(out, 0.05)
	return out


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


## The whole sound through one more muffle, so nothing bright survives.
func _lowpass(out: PackedFloat32Array, cut: float) -> void:
	var poles := AudioSynth.poles()
	for i in out.size():
		out[i] = AudioSynth.muffle(poles, out[i], cut, RATE)


## A smooth fade over the last `seconds`, so ringing voices settle instead of being cut.
func _release(out: PackedFloat32Array, seconds: float) -> void:
	var fall := int(seconds * RATE)
	for k in fall:
		var idx := out.size() - fall + k
		if idx >= 0:
			out[idx] *= 0.5 + 0.5 * cos(PI * float(k + 1) / fall)


## One soft raised-cosine hump centred on `at`, `width` seconds either side.
func _hump(t: float, at: float, width: float) -> float:
	if absf(t - at) >= width:
		return 0.0
	return 0.5 + 0.5 * cos(PI * (t - at) / width)


## A note's envelope between `from` and `to`: quick soft attack, gentle sag, a `fall`
## second release into the next note.
func _gate(t: float, from: float, to: float, fall: float, sag: float) -> float:
	if t < from or t >= to:
		return 0.0
	return minf(1.0, (t - from) / 0.006) * minf(1.0, (to - t) / fall) * exp(-(t - from) * sag)


## A felt mallet on a wooden bar (the juice_note voice): the fundamental, a quick octave,
## and the bar's inharmonic ping that dies almost at once.
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


## A footfall's thud: a sine sliding from `f0` to `f1` over `sweep` seconds, dying at `rate`.
func _pat(out: PackedFloat32Array, f0: float, f1: float, sweep: float, rate: float) -> void:
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, minf(1.0, t / sweep)) / RATE
		out[i] += sin(phase) * minf(1.0, t / 0.002) * exp(-t * rate)


## A soft sine thump at `freq`, dying at `rate` (per second).
func _thump(out: PackedFloat32Array, at: float, freq: float, rate: float, level: float) -> void:
	var start := int(at * RATE)
	for i in out.size() - start:
		var t := float(i) / RATE
		out[start + i] += sin(TAU * freq * t) * minf(1.0, t / 0.0015) * exp(-t * rate) * level


## A muffled noise burst about `length` seconds long: a tap, a click or a scuff.
func _tick(out: PackedFloat32Array, at: float, cut: float, length: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(length * 1.5 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var click := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), cut, RATE)
		out[idx] += click * minf(1.0, t / 0.0005) * exp(-t * 4.6 / length) * level


## A small cartoony hinge creak: a rasp rising 520 -> 780 Hz with a wobble, muffled soft.
func _hinge(out: PackedFloat32Array, at: float, length: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	var phase := 0.0
	for i in int(length * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var p := float(i) / (length * RATE)
		phase += TAU * (lerpf(520.0, 780.0, p) + sin(p * 24.0) * 30.0) / RATE
		var rasp := fmod(phase, TAU) / PI - 1.0
		var grip := 0.6 + 0.4 * sin(TAU * 26.0 * p * length + sin(p * 9.0) * 2.0)
		out[idx] += AudioSynth.muffle(poles, rasp, 3000.0, RATE) * grip * sin(PI * p) * level


## The dial running home: a low, soft band of noise under the ticks.
func _whirr(out: PackedFloat32Array, at: float, length: float) -> void:
	var start := int(at * RATE)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in int(length * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var p := float(i) / (length * RATE)
		var noise := _rng.randf_range(-1.0, 1.0)
		var band := (
			AudioSynth.muffle(hi, noise, 900.0, RATE) - AudioSynth.muffle(lo, noise, 250.0, RATE)
		)
		out[idx] += band * sin(PI * p) * 0.35
