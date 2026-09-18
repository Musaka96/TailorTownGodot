class_name AudioSynth

## Shared sample maths for the headless sound builders (build_curtain_audio.gd,
## build_sewing_audio.gd). Everything here is static and deterministic: a builder seeds its
## own RandomNumberGenerator, writes a PackedFloat32Array of mono samples in -1..1, and
## hands it to save() — so re-running a builder produces byte-identical .wav files and the
## committed audio never drifts.

## Normalise to this, leaving a little headroom.
const PEAK := 0.85
## Fades at the very ends, so nothing pops on or off. The attack has to stay tiny: fade a
## percussive sound in over even a few milliseconds and you smear away the transient that
## makes it read as a click at all.
const FADE_IN := 0.001
const FADE_OUT := 0.006


## Three one-pole low passes in series (-18 dB/oct), which is the difference between cloth
## and hiss. `cut` is the corner frequency in Hz; `state` holds the three poles and is
## updated in place, so keep one array per voice.
static func muffle(state: PackedFloat32Array, sample: float, cut: float, rate: int) -> float:
	var a := 1.0 - exp(-TAU * cut / rate)
	state[0] += (sample - state[0]) * a
	state[1] += (state[0] - state[1]) * a
	state[2] += (state[1] - state[2]) * a
	return state[2]


## A fresh, silent filter state for muffle().
static func poles() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0, 0.0])


## Add `voice` into `out` starting at `at` seconds, ignoring anything past the end.
static func mix(out: PackedFloat32Array, voice: PackedFloat32Array, at: float, rate: int) -> void:
	var start := int(at * rate)
	for i in voice.size():
		var idx := start + i
		if idx >= 0 and idx < out.size():
			out[idx] += voice[i]


## Normalise to PEAK, fade the very ends, and write a 16-bit mono WAV under `dir`. A
## `seamless` loop skips the end fades — they would click every time it wraps.
static func save(
	samples: PackedFloat32Array, rate: int, dir: String, sound_name: String, seamless := false
) -> void:
	var loudest := 0.0
	for s in samples:
		loudest = maxf(loudest, absf(s))
	var gain := PEAK / loudest if loudest > 0.0 else 1.0
	var rise := maxf(FADE_IN * rate, 1.0)
	var fall := maxf(FADE_OUT * rate, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var fade := minf(minf(1.0, i / rise), minf(1.0, (samples.size() - 1 - i) / fall))
		if seamless:
			fade = 1.0
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain * fade, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	var path := "%s/%s.wav" % [dir, sound_name]
	if wav.save_to_wav(path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote %s (%.2fs, peak x%.2f)" % [path, float(samples.size()) / rate, gain])
