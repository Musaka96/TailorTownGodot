class_name FloraElement
extends Resource

## One scatter layer of a FloraPatch — a grass tuft or a flower sprite, with its own
## textures, spawn count, size range and wind sway. Add several to a patch for variety;
## each is scattered independently so you control every kind on its own.

## Just a label for the inspector.
@export var element_name: String = "Element"
## The sprite's colour (RGB). Swap this in the editor to change the plant.
@export var color_texture: Texture2D
## The sprite's silhouette — its red channel is the alpha (what's solid vs cut away).
@export var mask_texture: Texture2D
## How many to scatter across the patch — this element's spawn rate.
@export var count: int = 180
## Card size in metres before random scaling.
@export var width: float = 0.35
@export var height: float = 0.45
## Each instance is scaled randomly between these (1.0 = the size above).
@export_range(0.2, 4.0) var size_min: float = 0.8
@export_range(0.2, 4.0) var size_max: float = 1.3
## How much this element sways in the wind (0 = stiff).
@export_range(0.0, 1.0) var sway: float = 0.15
## Colour multiplier over the sprite.
@export var tint: Color = Color(1, 1, 1, 1)
