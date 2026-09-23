extends SceneTree

## Synthesises the room-renovation minigame's sounds as .wav files — pure sample maths, no
## recordings and nothing to generate on a GPU:
##   godot --headless --path . --script res://tools/build_renovation_audio.gd
## Then --import so Godot picks the WAVs up. Shares its maths with the other sound builders
## via tools/audio_synth.gd.
##
## Kept cute, soft, rounded and quiet — a toy-shop clatter, not realistic foley (the owner
## turned that down flat).
##
##   reno_scoop    a soft, papery-gravelly scoop through a rubble/dust pile
##   reno_tumble   rubble dropped into a sack: a few tiny pebble ticks over a muffled thump
##   reno_whip     a dust sheet yanked off furniture: an airy whoosh, a cloth flap at the end
##   reno_creak    a nail prising out of old wood: a cartoony squeaky creak, then a tiny pop
##   reno_clatter  a plank landing on floorboards: a hollow woody knock, then a smaller bounce
##   reno_tick     the payoff sparkle: one warm marimba tock (pitched per play in code)
##   reno_done     project finished: three ascending glockenspiel notes with an octave shimmer
##   reno_open     a room opens up: a four-note mallet run over a soft chord swell
##
## Seeded, so re-running gives byte-identical files.

const RATE := 44100
const DIR := "res://assets/audio"
const C4 := 261.63
const E4 := 329.63
const G4 := 392.00
const C5 := 523.25
const E5 := 659.25
const G5 := 783.99
const C6 := 1046.50

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20260929  # fixed, so re-running gives byte-identical files
	AudioSynth.save(_scoop(), RATE, DIR, "reno_scoop")
	_rng.seed = 20260930
	AudioSynth.save(_tumble(), RATE, DIR, "reno_tumble")
	_rng.seed = 20260931
	AudioSynth.save(_whip(), RATE, DIR, "reno_whip")
	_rng.seed = 20260932
	AudioSynth.save(_creak(), RATE, DIR, "reno_creak")
	_rng.seed = 20260933
	AudioSynth.save(_clatter(), RATE, DIR, "reno_clatter")
	_rng.seed = 20260934
	AudioSynth.save(_tick(), RATE, DIR, "reno_tick")
	_rng.seed = 20260935
	AudioSynth.save(_done(), RATE, DIR, "reno_done")
	_rng.seed = 20260936
	AudioSynth.save(_open(), RATE, DIR, "reno_open")
	print("build_renovation_audio: done.")
	quit(0)


## A soft scoop through rubble/dust: a band-passed noise swell (papery, not hissy) with a
## small woody tick right at the start, as the scoop bites in.
func _scoop() -> PackedFloat32Array:
	var n := int(0.35 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hi := AudioSynth.poles()
	var lo := AudioSynth.poles()
	var tick_poles := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var p := t / (float(n) / RATE)
		var noise := _rng.randf_range(-1.0, 1.0)
		var band := (
			AudioSynth.muffle(hi, noise, 3200.0, RATE) - AudioSynth.muffle(lo, noise, 700.0, RATE)
		)
		var swell := sin(PI * p)
		var grit := 0.7 + 0.3 * sin(TAU * 14.0 * t)
		var tick := AudioSynth.muffle(tick_poles, _rng.randf_range(-1.0, 1.0), 1800.0, RATE)
		var woody := sin(TAU * 260.0 * t) * exp(-t * 90.0) * 0.5
		out[i] = band * swell * grit * 0.8 + tick * exp(-t * 200.0) * 1.1 + woody
	return out


## Rubble dropped in a sack: a muffled thump under a handful of tiny, soft pebble ticks.
func _tumble() -> PackedFloat32Array:
	var length := 0.42
	var out := _silence(length)
	_thump_soft(out, 0.0, 0.55)
	var count := _rng.randi_range(4, 6)
	for _k in count:
		var at: float = _rng.randf_range(0.05, length - 0.05)
		_pebble(out, at, _rng.randf_range(0.3, 0.6))
	return out


## A dust sheet yanked clear: a quick rising-then-falling airy whoosh, a soft cloth flap
## as it comes free at the end.
func _whip() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var poles := AudioSynth.poles()
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := t / (float(n) / RATE)
		var sweep := sin(PI * p)
		var cut := lerpf(900.0, 4200.0, sweep)
		var lp := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), cut, RATE)
		hp = lp - prev + hp * 0.98
		prev = lp
		out[i] = hp * sweep * 0.9
	_flap(out, 0.4, 0.45)
	return out


## A nail prising out of old wood: a short cartoony squeaky creak that rises and wobbles,
## then a tiny pop as it lets go.
func _creak() -> PackedFloat32Array:
	var creak_len := 0.27
	var out := _silence(creak_len + 0.06)
	var poles := AudioSynth.poles()
	var phase := 0.0
	for i in int(creak_len * RATE):
		var t := float(i) / RATE
		var p := t / creak_len
		var freq := lerpf(320.0, 900.0, p) + sin(p * 26.0) * 40.0
		phase += TAU * freq / RATE
		var rasp := fmod(phase, TAU) / PI - 1.0
		var body := AudioSynth.muffle(poles, rasp, 2600.0, RATE)
		out[i] = body * sin(PI * p) * 0.8
	_pop(out, creak_len + 0.01, 0.6)
	return out


## A plank landing on floorboards: a hollow woody knock, then a smaller bounce knock 80ms
## later as it settles.
func _clatter() -> PackedFloat32Array:
	var out := _silence(0.38)
	_plank_knock(out, 0.0, 1.0)
	_plank_knock(out, 0.08, 0.45)
	return out


## The payoff sparkle: one warm marimba tock: the fundamental with a short 4th partial,
## muffled, over a tiny wood knock so it is never a bare bell. Played pitched (up or down a
## little) per call in code, so this is the canonical pitch.
func _tick() -> PackedFloat32Array:
	var n := int(0.35 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bar := AudioSynth.poles()
	var wood := AudioSynth.poles()
	for i in n:
		var t := float(i) / RATE
		var tone := (
			sin(TAU * C6 * t) * exp(-t * 17.0) + sin(TAU * C6 * 4.0 * t) * exp(-t * 90.0) * 0.3
		)
		tone = AudioSynth.muffle(bar, tone * minf(1.0, t * 1500.0), 4000.0, RATE)
		var knock := AudioSynth.muffle(wood, _rng.randf_range(-1.0, 1.0), 1200.0, RATE)
		knock = knock * exp(-t * 160.0) * 0.9 + sin(TAU * 340.0 * t) * exp(-t * 70.0) * 0.18
		out[i] = tone + knock
	return out


## Project finished: three soft ascending glockenspiel notes, with a little octave shimmer
## laid over the last one.
func _done() -> PackedFloat32Array:
	var out := _silence(0.9)
	_glock(out, 0.0, C5, 0.6)
	_glock(out, 0.22, E5, 0.65)
	_glock(out, 0.44, G5, 0.7)
	_glock(out, 0.46, G5 * 2.0, 0.22)
	return out


## A room opens up: a four-note mallet run up C5 E5 G5 C6 with an octave shimmer on the
## top note, over the warm chord swell (kept quiet underneath).
func _open() -> PackedFloat32Array:
	var n := int(1.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var attack := 0.25
	var chord: Array[float] = [C4, E4, G4, C5]
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * exp(-t * 3.2)
		var pad := 0.0
		for f: float in chord:
			pad += sin(TAU * f * t)
		pad /= chord.size()
		out[i] = pad * env * 0.35
	var notes: Array[float] = [C5, E5, G5, C6]
	for k in notes.size():
		_mallet(out, 0.06 * k, notes[k], 0.8 + 0.05 * k)
	_mallet(out, 0.2, C6 * 2.0, 0.25)
	var poles := AudioSynth.poles()
	for i in n:
		out[i] = AudioSynth.muffle(poles, out[i], 4500.0, RATE)
	return out


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


## A soft low thump: a sine body under a little muffled noise, much gentler than the plank
## knock below — this is rubble settling, not wood hitting wood.
func _thump_soft(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(0.3 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var soft := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 500.0, RATE)
		out[idx] += (sin(TAU * 85.0 * t) * exp(-t * 20.0) + soft * exp(-t * 30.0) * 0.5) * level


## One tiny pebble tick: a short bandpassed click, no tonal body.
func _pebble(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(0.02 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var click := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 3400.0, RATE)
		out[idx] += click * exp(-t * 260.0) * level


## A soft cloth flap as the sheet comes free.
func _flap(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(0.1 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var cloth := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 2000.0, RATE)
		out[idx] += cloth * exp(-t * 35.0) * level


## A tiny pop as the nail lets go.
func _pop(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(0.04 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var click := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 2400.0, RATE)
		out[idx] += (sin(TAU * 700.0 * t) * exp(-t * 180.0) + click * exp(-t * 220.0) * 0.6) * level


## One woody knock: two resonant modes (a hollow plank body) plus a soft slap, fast decay.
func _plank_knock(out: PackedFloat32Array, at: float, level: float) -> void:
	var start := int(at * RATE)
	var poles := AudioSynth.poles()
	for i in int(0.28 * RATE):
		var idx := start + i
		if idx < 0 or idx >= out.size():
			continue
		var t := float(i) / RATE
		var slap := AudioSynth.muffle(poles, _rng.randf_range(-1.0, 1.0), 1400.0, RATE)
		var body := (
			sin(TAU * 180.0 * t) * exp(-t * 24.0) + sin(TAU * 420.0 * t) * exp(-t * 40.0) * 0.6
		)
		out[idx] += (body * 0.6 + slap * exp(-t * 60.0) * 0.6) * level


## One glockenspiel note: the fundamental plus two soft inharmonic partials, ringing gently.
func _glock(out: PackedFloat32Array, at: float, freq: float, level: float) -> void:
	var start := int(at * RATE)
	for i in out.size() - start:
		var t := float(i) / RATE
		var tone := (
			sin(TAU * freq * t) * exp(-t * 9.0)
			+ sin(TAU * freq * 2.4 * t) * exp(-t * 16.0) * 0.3
			+ sin(TAU * freq * 3.8 * t) * exp(-t * 24.0) * 0.16
		)
		out[start + i] += tone * level * minf(1.0, t * 700.0)


## A felt mallet on a wooden bar (the voice from build_juice_audio.gd): the fundamental, a
## quick octave, and the bar's bright inharmonic ping that dies almost at once.
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
