class_name MaterialSwatch
extends Control

## A rounded, layered preview of one material: cloth colour + fabric weave +
## pattern (via a shader), with a fabric-type badge in the corner and a fill bar
## for how much cloth is left. Reusable anywhere a material needs to be shown.
##
## Build in code (no .tscn) so it stays a single drop-in component:
##   var s := MaterialSwatch.new(); parent.add_child(s); s.setup(material, remaining)

const SHADER := preload("res://ui/material_swatch.gdshader")

# Indexed by Enums.Fabric / Enums.Pattern.
const FABRIC_TEX := ["worsted", "flannel", "tweed", "mohair", "linen"]
const FABRIC_LETTER := ["W", "F", "T", "M", "L"]
const FABRIC_BADGE := [
	Color("55668c"),
	Color("6d7075"),
	Color("7a5a38"),
	Color("7a4b57"),
	Color("a99a5e"),
]
const PATTERN_TEX := [
	"solid",
	"pinstripe",
	"herringbone",
	"houndstooth",
	"windowpane",
	"glen_check",
	"birdseye",
	"sharkskin",
	"nailhead",
]

@export var swatch_size := 84

var _rect: ColorRect
var _shader_mat: ShaderMaterial
var _fill_fg: Panel
var _badge: Panel
var _badge_label: Label


func _ready() -> void:
	_build()


func _build() -> void:
	if _rect != null:
		return
	custom_minimum_size = Vector2(swatch_size, swatch_size)
	# Sit above the menu's pattern overlay so the real cloth preview stays clean.
	z_index = 1

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _shader_mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	resized.connect(_update_size)

	# Fill bar along the bottom.
	var fill_bg := Panel.new()
	fill_bg.add_theme_stylebox_override("panel", Style.bar(Color(0, 0, 0, 0.35), 5))
	fill_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fill_bg.offset_left = 8
	fill_bg.offset_right = -8
	fill_bg.offset_top = -15
	fill_bg.offset_bottom = -7
	fill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill_bg)

	_fill_fg = Panel.new()
	_fill_fg.add_theme_stylebox_override("panel", Style.bar(Style.LEAF, 5))
	_fill_fg.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_fill_fg.offset_right = 0
	_fill_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_bg.add_child(_fill_fg)

	# Fabric-type badge, top-left.
	_badge = Panel.new()
	_badge.add_theme_stylebox_override("panel", Style.bar(Color("55668c"), 11))
	_badge.position = Vector2(6, 6)
	_badge.size = Vector2(22, 22)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)

	_badge_label = Label.new()
	_badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	_badge_label.add_theme_font_size_override("font_size", 13)
	_badge.add_child(_badge_label)

	_update_size()


func setup(mat: MaterialType, remaining: float) -> void:
	_build()
	if mat == null:
		return
	_shader_mat.set_shader_parameter("cloth_color", mat.cloth_color)
	_shader_mat.set_shader_parameter("pattern_color", mat.pattern_color)
	_shader_mat.set_shader_parameter("fabric_tex", _tex("fabrics", FABRIC_TEX[mat.fabric]))
	_shader_mat.set_shader_parameter("pattern_tex", _tex("patterns", PATTERN_TEX[mat.pattern]))

	var frac := clampf(remaining / maxf(mat.roll_length_m, 0.001), 0.0, 1.0)
	_fill_fg.anchor_right = frac
	_fill_fg.add_theme_stylebox_override("panel", Style.bar(Style.fill_color(frac), 5))

	_badge_label.text = FABRIC_LETTER[mat.fabric]
	_badge.add_theme_stylebox_override("panel", Style.bar(FABRIC_BADGE[mat.fabric], 11))


func _update_size() -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("rect_size", size)


func _tex(kind: String, name: String) -> Texture2D:
	return load("res://assets/textures/%s/%s.png" % [kind, name])
