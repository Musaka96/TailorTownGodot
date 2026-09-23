extends SceneTree

## Synthesises the main menu's hanging-sign sounds as .wav files — pure sample maths:
##   godot --headless --path . --script res://tools/build_menu_audio.gd
## Then --import so Godot picks the WAVs up. The sample maths is shared with the other
## sound builders in tools/audio_synth.gd.
##
##   sign_drop   the board lowered on its chains: links run out, the wood settles with a
##               soft knock and a last creak. Timed to MainMenu._hang_sign (DOWN seconds).
##   sign_hoist  hauled back up: a quicker run of links, brightening as it goes.
##   sign_sew    one soft pull of thread through the board, played per stitch as the
##               wordmark's underline is sewn in (ui/craft/wordmark.gd).

const RATE := 44100
const DIR := "res://assets/audio"
const DOWN := 0.55  # MainMenu: seconds the sign takes to drop
const UP := 0.35  # ... and to be hoisted clear

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260920  # fixed, so re-running gives byte-identical files
	AudioSynth.save(_drop(), RATE, DIR, "sign_drop")
	_rng.seed = 20260921
	AudioSynth.save(_hoist(), RATE, DIR, "sign_hoist")
	_rng.seed = 20260922
	AudioSynth.save(_sew(), RATE, DIR, "sign_sew")
	print("build_menu_audio: done.")
	quit(0)


func _drop() -> PackedFloat32Array:
	var out := _silence(DOWN + 0.75)
	_links(out, 0.0, DOWN * 0.9, 16, 1.4, 0.5, 2600.0)
	_knock(out, DOWN * 0.82, 1.0)
	_knock(out, DOWN + 0.13, 0.35)  # the overshoot swinging back
	_creak(out, DOWN + 0.05, 0.5, 210.0, 150.0)
	return _muffled(out)


func _hoist() -> PackedFloat32Array:
	var out := _silence(UP + 0.3)
	_creak(out, 0.0, 0.22, 170.0, 260.0)
	_links(out, 0.03, UP + 0.1, 14, 0.8, 0.45, 3000.0)
	return _muffled(out)


## Thread drawn through: a short bright hiss that darkens, under a tiny needle tick.
func _sew() -> PackedFloat32Array:
	var out := _silence(0.11)
	var poles := AudioSynth.poles()
	var prev := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var lp := AudioSynth.muffle(
			poles, _rng.randf_range(-1.0, 1.0), lerpf(5200.0, 1400.0, t / 0.11), RATE
		)
		var hp := lp - prev
		prev = lp
		out[i] = hp * sin(PI * minf(t / 0.09, 1.0)) * exp(-t * 22.0) * 2.4
	_link(out, 0.0, 3100.0, 0.5)
	return out


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


## Chain links running between `from` and `to`; `crowd` above 1 bunches them at the start.
## Each link is a soft noise tick centred near `pitch`, with its own spacing and level.
func _links(
	out: PackedFloat32Array,
	from: float,
	to: float,
	count: int,
	crowd: float,
	gain: float,
	pitch: float
) -> void:
	for _k in count:
		var at := lerpf(from, to, pow(_rng.randf(), crowd))
		var centre := pitch * _rng.randf_range(0.85, 1.25)
		_soft_link(out, at, centre, gain * _rng.randf_range(0.3, 0.7))


## One chain link for the sign: a short muffled noise burst in a band around `centre` —
## metallic, but soft, with none of a pure tone's ping.
func _soft_link(out: PackedFloat32Array, at: float, centre: float, level: float) -> void:
	var start := int(at * RATE)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	for i in int(0.05 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var band := AudioSynth.muffle(hi, noise, centre, RATE)
		band -= AudioSynth.muffle(lo, noise, centre * 0.5, RATE)
		out[idx] += band * exp(-t * 110.0) * minf(1.0, t * 1500.0) * level * 1.6


## One link: three inharmonic partials with a quick iron decay (duller than curtain brass).
func _link(out: PackedFloat32Array, at: float, base: float, level: float) -> void:
	var start := int(at * RATE)
	for i in int(0.07 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var ring := (
			sin(TAU * base * t) * 0.5
			+ sin(TAU * base * 1.47 * t) * 0.3
			+ sin(TAU * base * 2.09 * t) * 0.2
		)
		out[idx] += ring * exp(-t * 70.0) * level * 0.2


## The board settling against its chains: a woody knock with a hollow body and the board's
## own resonance ringing briefly under it.
func _knock(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(0.35 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var slap := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 1100.0, RATE)
		var body := sin(TAU * 118.0 * t) * exp(-t * 18.0) + sin(TAU * 236.0 * t) * exp(-t * 30.0)
		var board := sin(TAU * 380.0 * t) * exp(-t * 38.0) * minf(1.0, t * 800.0)
		out[idx] += (body * 0.4 + board * 0.3 + slap * exp(-t * 40.0) * 0.8) * level


## Wood and iron taking the weight: a gritty tone sliding from `f0` to `f1`, its pitch and
## grip wandering on slow random noise so it grinds unevenly rather than wobbling cleanly.
func _creak(out: PackedFloat32Array, at: float, length: float, f0: float, f1: float) -> void:
	var start := int(at * RATE)
	var phase := 0.0
	var drift := AudioSynth.poles()
	var target := 0.0
	var hold := int(RATE / 40.0)
	for i in int(length * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		if i % hold == 0:
			target = _rng.randf_range(-1.0, 1.0)
		var wobble := AudioSynth.muffle(drift, target, 30.0, RATE)
		var p := float(i) / (length * RATE)
		phase += TAU * lerpf(f0, f1, p) * (1.0 + wobble * 0.08) / RATE
		# A sawtooth-ish rasp, gated by the wandering stick-slip so it grinds, not hums.
		var rasp := fmod(phase, TAU) / PI - 1.0
		var grip := clampf(0.55 + wobble * 0.9, 0.0, 1.0)
		out[idx] += rasp * grip * sin(PI * p) * 0.07


## The whole sound through a gentle low pass, so nothing bright pokes out of it.
func _muffled(out: PackedFloat32Array) -> PackedFloat32Array:
	var poles := AudioSynth.poles()
	for i in out.size():
		out[i] = AudioSynth.muffle(poles, out[i], 5000.0, RATE)
	return out
