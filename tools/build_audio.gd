extends SceneTree

## Generates temporary SFX for the cutting minigame as .wav files. Pure sample
## synthesis (no rendering), runs headless:
##   godot --headless --path . --script res://tools/build_audio.gd
## Then --import so Godot imports the WAVs.

const RATE := 22050
const DIR := "res://assets/audio"


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	_save(_snip(), "snip")
	_save(_slip(), "slip")
	_save(_complete(), "complete")
	_save(_ruined(), "ruined")
	_save(_stitch(), "stitch")
	print("build_audio: done.")
	quit(0)


func _stitch() -> PackedFloat32Array:
	# Soft pluck for a stitch.
	var s := PackedFloat32Array()
	var n := int(0.07 * RATE)
	for i in n:
		var t := float(i) / RATE
		var env: float = exp(-t * 45.0)
		var tone := sin(TAU * 720.0 * t)
		var click := (randf() * 2.0 - 1.0) * exp(-t * 160.0) * 0.3
		s.append((tone * 0.5 + click) * env * 0.5)
	return s


func _snip() -> PackedFloat32Array:
	# Short noisy click.
	var s := PackedFloat32Array()
	var n := int(0.05 * RATE)
	for i in n:
		var t := float(i) / RATE
		var env: float = exp(-t * 75.0)
		s.append((randf() * 2.0 - 1.0) * env * 0.6)
	return s


func _slip() -> PackedFloat32Array:
	# Descending buzzy saw — a bad snip.
	var s := PackedFloat32Array()
	var dur := 0.18
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq: float = lerpf(320.0, 150.0, t / dur)
		phase += freq / RATE
		var saw: float = 2.0 * (phase - floor(phase)) - 1.0
		var env: float = exp(-t * 7.0)
		s.append(saw * env * 0.35 + (randf() * 2.0 - 1.0) * env * 0.08)
	return s


func _complete() -> PackedFloat32Array:
	# Two rising notes (C5 → G5).
	var s := PackedFloat32Array()
	var n := int(0.34 * RATE)
	var half := n / 2
	for i in n:
		var first := i < half
		var lt := float(i) / RATE if first else float(i - half) / RATE
		var freq := 523.25 if first else 784.0
		var env: float = minf(lt * 60.0, 1.0) * exp(-lt * 5.0)
		s.append(sin(TAU * freq * lt) * env * 0.4)
	return s


func _ruined() -> PackedFloat32Array:
	# Descending sad tone.
	var s := PackedFloat32Array()
	var dur := 0.5
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq: float = lerpf(300.0, 90.0, t / dur)
		phase += freq / RATE
		var env: float = exp(-t * 3.0) * minf(t * 30.0, 1.0)
		s.append(sin(TAU * phase) * env * 0.4)
	return s


func _save(samples: PackedFloat32Array, name: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var path := "%s/%s.wav" % [DIR, name]
	if wav.save_to_wav(path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote ", path)
