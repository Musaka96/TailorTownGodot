class_name FaceLayout
extends Resource

## Placement of the 2D face elements on a character's head — the single source the
## rig reads at runtime and the Face Editor dock writes. All distances are in metres
## in the head's local space (y is up, relative to the head centre; x is offset from
## the midline). "gap" is the centre-to-centre distance between the paired left/right
## elements, so it directly controls how far apart the eyes / brows sit. "px" is the
## sprite's pixel_size (metres per texture pixel), i.e. how big that element draws.
## Stored at res://data/face_layout.tres.

const PATH := "res://data/face_layout.tres"

## How far the whole face sits in front of the head, and the head-centre height.
@export var face_z := 0.47
@export var head_y := 1.64

@export_group("Eyes")
@export var eye_y := 0.09
@export var eye_gap := 0.16
@export var eye_px := 0.0060

@export_group("Brows")
@export var brow_y := 0.155
@export var brow_gap := 0.17
@export var brow_px := 0.0060

@export_group("Nose")
@export var nose_y := -0.03
@export var nose_px := 0.0050

@export_group("Mouth")
@export var mouth_y := -0.13
@export var mouth_px := 0.0060


## The saved layout, or a fresh one with the defaults above if none exists yet.
static func load_or_default() -> FaceLayout:
	if ResourceLoader.exists(PATH):
		var r := load(PATH) as FaceLayout
		if r != null:
			return r
	return FaceLayout.new()
