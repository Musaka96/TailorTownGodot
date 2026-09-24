class_name OutlineProfile
extends Resource

## Settings for the screen-space object outline (materials/outline_postfx.gdshader).
## The Outline autoload pushes these to the shader every frame, so editing this resource
## — in the inspector while the game runs, or by swapping to another .tres — changes the
## look live. Toggle `enabled` to turn outlines off entirely.

## Master switch. Off = the post-process quad is hidden (costs nothing).
@export var enabled: bool = true

@export_group("Outline")
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Line width in pixels.
@export_range(0.2, 8.0, 0.1) var thickness: float = 1.6
## Overall strength: 0 = invisible, 1 = solid.
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0

@export_group("Detection")
## How big a depth jump counts as an edge. LOWER = more lines (more sensitive).
@export_range(0.001, 0.5, 0.001) var depth_threshold: float = 0.02
## Softness of the line's edge. 0 = hard/aliased, higher = smoother.
@export_range(0.0, 2.0, 0.01) var edge_softness: float = 0.6
## Suppresses false lines across floors/walls seen at a steep angle. 0 = off.
@export_range(0.0, 1.0, 0.01) var grazing_guard: float = 0.75
## Interior creases (folds, corners). Keep 0 for pure silhouettes.
@export_range(0.0, 1.0, 0.01) var crease_strength: float = 0.0
@export_range(0.0, 1.0, 0.01) var crease_threshold: float = 0.35

@export_group("Distance")
## Lines fade out between these distances (metres) so the far background stays clean.
@export_range(0.0, 200.0, 0.5) var fade_start: float = 30.0
@export_range(0.0, 400.0, 0.5) var fade_end: float = 80.0


## A clean, readable default: thin solid black silhouettes, no interior creases.
static func make_default() -> OutlineProfile:
	return OutlineProfile.new()


## Chunkier, storybook-ish lines.
static func make_bold() -> OutlineProfile:
	var p := OutlineProfile.new()
	p.thickness = 2.6
	p.depth_threshold = 0.015
	p.edge_softness = 0.35
	return p
