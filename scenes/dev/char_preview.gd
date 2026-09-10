extends Node3D

## Dev harness for the character body-part system. Open this scene and press F6 to
## cycle heads / hair / suit tops / bottoms / skin / hair colour live, or roll a full
## random look (gender-aware). Everything is read from the wardrobe, so any GLB you add
## to assets/characters/parts/ (then rerun tools/build_wardrobe.gd) shows up here.
##
## Keys:  Q/A head   W/S hair   E/D top   R/F bottom   T skin   Y hair colour
##        G cycle gender filter   SPACE random look   ←/→ turn   ESC quit

const SKINS := [
	Color(0.9, 0.76, 0.66), Color(0.8, 0.62, 0.48), Color(0.66, 0.48, 0.35), Color(0.55, 0.38, 0.27)
]
const HAIR_COLORS := [
	Color(0.12, 0.09, 0.07),
	Color(0.35, 0.22, 0.12),
	Color(0.72, 0.55, 0.30),
	Color(0.55, 0.20, 0.10),
	Color(0.6, 0.6, 0.62),
]
const GENDERS := [Enums.Gender.ANY, Enums.Gender.MALE, Enums.Gender.FEMALE]

var _rig: Node3D
var _label: Label
var _rng := RandomNumberGenerator.new()
var _head := 0
var _hair := 0
var _top := 0
var _bottom := 0
var _skin_i := 0
var _hair_i := 0
var _gender_i := 0
var _mat: Resource


func _ready() -> void:
	_rng.randomize()
	_mat = load("res://data/materials/navy_worsted_pinstripe.tres")
	_build_world()
	_rig = load("res://entities/character/character_rig.tscn").instantiate()
	add_child(_rig)
	var ap: AnimationPlayer = _rig.get_node("AnimationPlayer")
	ap.play("idle")
	_apply()


func _process(_dt: float) -> void:
	# Keep the auto-opening newspaper out of the preview.
	var ui := get_node_or_null("/root/UI")
	if ui is CanvasLayer:
		(ui as CanvasLayer).visible = false


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_Q:
			_head = _wrap(_head - 1, Wardrobe.head_count())
		KEY_A:
			_head = _wrap(_head + 1, Wardrobe.head_count())
		KEY_W:
			_hair = _wrap(_hair - 1, Wardrobe.hair_count())
		KEY_S:
			_hair = _wrap(_hair + 1, Wardrobe.hair_count())
		KEY_E:
			_top = _wrap(_top - 1, Wardrobe.library().tops.size())
		KEY_D:
			_top = _wrap(_top + 1, Wardrobe.library().tops.size())
		KEY_R:
			_bottom = _wrap(_bottom - 1, Wardrobe.library().bottoms.size())
		KEY_F:
			_bottom = _wrap(_bottom + 1, Wardrobe.library().bottoms.size())
		KEY_T:
			_skin_i = _wrap(_skin_i + 1, SKINS.size())
		KEY_Y:
			_hair_i = _wrap(_hair_i + 1, HAIR_COLORS.size())
		KEY_G:
			_gender_i = _wrap(_gender_i + 1, GENDERS.size())
		KEY_SPACE:
			_randomize()
		KEY_LEFT:
			_rig.rotate_y(0.3)
		KEY_RIGHT:
			_rig.rotate_y(-0.3)
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	_apply()


func _randomize() -> void:
	var g: int = GENDERS[_gender_i]
	_head = maxi(0, Wardrobe.random_head_index(g, _rng))
	_hair = maxi(0, Wardrobe.random_hair_index(g, _rng))
	_skin_i = _rng.randi() % SKINS.size()
	_hair_i = _rng.randi() % HAIR_COLORS.size()


func _apply() -> void:
	_rig.set_head(_head)
	_rig.set_hair(_hair)
	_rig.set_palette(SKINS[_skin_i])
	_rig.set_hair_color(HAIR_COLORS[_hair_i])
	_rig.set_outfit(_mat, null, _mat, _top, _bottom)
	_rig.set_face_look("brown", "")
	_refresh_label()


func _refresh_label() -> void:
	var lib := Wardrobe.library()
	_label.text = (
		"HEAD %d/%d  %s\nHAIR %d/%d  %s\nTOP %d/%d   BOTTOM %d/%d\ngender filter: %s\n\n%s"
		% [
			_head + 1,
			Wardrobe.head_count(),
			_name(Wardrobe.head(_head)),
			_hair + 1,
			Wardrobe.hair_count(),
			_name(Wardrobe.hair(_hair)),
			_top + 1,
			lib.tops.size(),
			_bottom + 1,
			lib.bottoms.size(),
			Enums.gender_name(GENDERS[_gender_i]),
			"Q/A head  W/S hair  E/D top  R/F bottom  T skin  Y hair  G gender  SPACE random  ←→ turn",
		]
	)


func _name(part) -> String:
	if part != null and not part.display_name.is_empty():
		return "%s [%s]" % [part.display_name, Enums.gender_name(part.gender)]
	return "-"


func _wrap(v: int, n: int) -> int:
	if n <= 0:
		return 0
	return (v % n + n) % n


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 3.0)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0), Vector3.UP)
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)
