class_name PostFxProfile
extends Resource

## An editable look for the retro post-process filter. Every field maps to a uniform
## in assets/shaders/retro_postfx.gdshader; the PostFX autoload pushes them to the
## screen shader each frame, so editing this resource (in the inspector, or by
## swapping to another .tres in data/postfx/) changes the whole look live. Each
## screen effect has its own 0..1 strength — set it to 0 to turn that effect off.
##
## Presets are built by tools/build_postfx.gd from the make_* factories below.

enum FilmPreset {
	NONE,
	KODACHROME,  ## warm, rich, deep primaries (classic 70s film)
	VHS,  ## desaturated, cool shadows, chroma bleed
	SEPIA,  ## old-TV brown monochrome
	TECHNICOLOR,  ## punchy, exaggerated colour separation
	BLACK_WHITE,  ## luma only
	GREEN_PHOSPHOR,  ## old green CRT monitor
	AMBER,  ## amber monochrome monitor
}

## Master switch and how strongly the whole filter blends over the raw image.
@export var enabled: bool = true
@export_range(0.0, 1.0) var master_strength: float = 1.0

@export_group("Colour Grade")
## Warm (+) toward orange, cool (-) toward blue.
@export_range(-1.0, 1.0) var temperature: float = 0.0
## Green (+) / magenta (-).
@export_range(-1.0, 1.0) var tint: float = 0.0
@export_range(-1.0, 1.0) var brightness: float = 0.0
@export_range(0.0, 2.0) var contrast: float = 1.0
@export_range(0.0, 2.0) var saturation: float = 1.0

@export_group("Film Emulation")
@export var film_preset: FilmPreset = FilmPreset.NONE
@export_range(0.0, 1.0) var film_strength: float = 0.0

@export_group("Screen Effects")
@export_range(0.0, 1.0) var scanline_strength: float = 0.0
@export_range(0.0, 2000.0) var scanline_count: float = 480.0
@export_range(0.0, 1.0) var vignette_strength: float = 0.0
@export_range(0.0, 1.0) var grain_strength: float = 0.0
@export_range(0.0, 1.0) var chromatic_aberration: float = 0.0
@export_range(0.0, 1.0) var bloom_strength: float = 0.0
@export_range(0.0, 1.0) var barrel_distortion: float = 0.0
@export_range(0.0, 1.0) var vhs_wobble: float = 0.0
@export_range(0.0, 1.0) var flicker_strength: float = 0.0


## Default look shipped as data/postfx/retro_70s.tres.
static func make_default() -> PostFxProfile:
	return make_70s()


## Warm Kodachrome film look: gentle CRT, soft glow, sun-faded colour.
static func make_70s() -> PostFxProfile:
	var p := PostFxProfile.new()
	p.temperature = 0.15
	p.tint = 0.03
	p.brightness = -0.02
	p.contrast = 1.08
	p.saturation = 1.12
	p.film_preset = FilmPreset.KODACHROME
	p.film_strength = 0.5
	p.scanline_strength = 0.12
	p.scanline_count = 500.0
	p.vignette_strength = 0.35
	p.grain_strength = 0.06
	p.chromatic_aberration = 0.12
	p.bloom_strength = 0.15
	p.barrel_distortion = 0.10
	p.flicker_strength = 0.05
	return p


## 80s VHS tape: wobble, chroma bleed, heavier grain and scanlines.
static func make_vhs() -> PostFxProfile:
	var p := PostFxProfile.new()
	p.temperature = -0.05
	p.contrast = 1.05
	p.saturation = 0.90
	p.film_preset = FilmPreset.VHS
	p.film_strength = 0.7
	p.scanline_strength = 0.18
	p.scanline_count = 480.0
	p.vignette_strength = 0.30
	p.grain_strength = 0.15
	p.chromatic_aberration = 0.35
	p.bloom_strength = 0.10
	p.barrel_distortion = 0.12
	p.vhs_wobble = 0.40
	p.flicker_strength = 0.08
	return p


## Green-phosphor CRT monitor: heavy tube, strong scanlines, monochrome glow.
static func make_crt_green() -> PostFxProfile:
	var p := PostFxProfile.new()
	p.contrast = 1.10
	p.saturation = 0.0
	p.film_preset = FilmPreset.GREEN_PHOSPHOR
	p.film_strength = 1.0
	p.scanline_strength = 0.30
	p.scanline_count = 400.0
	p.vignette_strength = 0.45
	p.grain_strength = 0.08
	p.chromatic_aberration = 0.05
	p.bloom_strength = 0.25
	p.barrel_distortion = 0.20
	p.flicker_strength = 0.10
	return p
