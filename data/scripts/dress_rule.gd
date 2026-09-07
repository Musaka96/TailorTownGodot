class_name DressRule
extends Resource

## One dress-code entry: for a given occasion + aesthetic style, which jacket
## colours / patterns / fabrics are acceptable, whether a bold (non-solid) pattern
## is required, and a plain-language hint shown to the player.
##
## Colour indices match MaterialFactory.COLORS (0 Navy, 1 Charcoal, 2 Light Grey,
## 3 Black, 4 Tan, 5 Brown, 6 Blue, 7 Burgundy, 8 Olive, 9 Forest). Pattern and
## fabric indices match Enums.Pattern / Enums.Fabric. Empty array = "anything goes".

@export var occasion: Enums.Occasion = Enums.Occasion.BUSINESS
@export var style: Enums.Style = Enums.Style.CLASSIC
@export var allowed_colors: Array[int] = []
@export var allowed_patterns: Array[int] = []
@export var allowed_fabrics: Array[int] = []
## Require a non-solid pattern (e.g. Fashion looks that must make a statement).
@export var require_pattern: bool = false
## One-line brief shown to the player at the mirror.
@export var hint: String = ""
