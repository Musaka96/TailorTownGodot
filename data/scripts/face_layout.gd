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
## Deeper head meshes need the face pushed further out, so face_z can be overridden
## per head index in head_face_z (falling back to face_z when a head has no entry).
@export var face_z := 0.47
@export var head_y := 1.64
## head index -> face_z override. Tune per head in the char preview (edit face_z),
## which writes the current head's entry here.
@export var head_face_z: Dictionary = {}

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

@export_group("Glasses")
## Glasses sit centred over the eyes; a single wide sprite (not paired).
@export var glasses_y := 0.085
@export var glasses_px := 0.0036


## The face depth for a given head index (its override, else the shared face_z).
func face_z_for(head_index: int) -> float:
	return float(head_face_z.get(head_index, face_z))


## Set the per-head face depth for a head index (used by the char preview's editor).
func set_face_z_for(head_index: int, value: float) -> void:
	head_face_z[head_index] = value


## The saved layout, or a fresh one with the defaults above if none exists yet.
static func load_or_default() -> FaceLayout:
	if ResourceLoader.exists(PATH):
		var r := load(PATH) as FaceLayout
		if r != null:
			return r
	return FaceLayout.new()
