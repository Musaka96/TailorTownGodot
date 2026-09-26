class_name CustomerPortrait
extends TvFrame

## A little retro-TV portrait of a customer: a private 3D mini-scene (its own world,
## light and camera) renders a character rig framed on the face, shown inside the TV
## bezel. Call configure() to match a customer's look, set_live(true) to animate/talk.

const RIG_SCENE := preload("res://entities/character/character_rig.tscn")
const VIEW_SIZE := 260
## A straight-on, level view: the camera sits on the rig's forward axis (+Z) at CAM_AIM's
## height and looks along -Z, so the face is square to the screen with the collar and
## shoulders at the bottom of the frame.
const CAM_FOV := 34.0
const CAM_AIM := Vector3(0.0, 1.55, 0.0)
const CAM_DIST := 2.5
## Flat, even light for the paper face: a soft key from just above the camera (so no
## side shadow falls across the nose or cheeks) over a strong, cool ambient.
const KEY_EULER := Vector3(-14.0, 0.0, 0.0)
const KEY_ENERGY := 0.65
const AMBIENT_ENERGY := 1.15

var _view: SubViewport
var _rig: Node
var _cam: Camera3D


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(150, 172)
	_build_view()
	set_screen_texture(_view.get_texture())


func _build_view() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
	_view.own_world_3d = true
	_view.transparent_bg = false
	_view.msaa_3d = Viewport.MSAA_2X
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.86, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.96, 1.0)
	env.ambient_light_energy = AMBIENT_ENERGY
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = KEY_EULER
	sun.light_energy = KEY_ENERGY
	_view.add_child(sun)

	_rig = RIG_SCENE.instantiate()
	_view.add_child(_rig)
	var ap := _rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.play("idle")

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.position = CAM_AIM + Vector3(0.0, 0.0, CAM_DIST)  # level: no tilt, no yaw
	_view.add_child(_cam)
	_cam.current = true


## Match the portrait to a customer's head/hair/skin/eyes/glasses.
func configure(customer: Node) -> void:
	if _rig == null or customer == null:
		return
	_rig.set_head(int(customer.get("head_index")))
	_rig.set_hair(int(customer.get("hair_index")))
	_rig.set_palette(customer.get("skin_color"))
	_rig.set_hair_color(customer.get("hair_color"))
	_rig.set("glasses_color", str(customer.get("glasses_color")))
	_rig.set_face_look(str(customer.get("eye_color")), str(customer.get("glasses")))
	_set_face(str(customer.get("face_style")), int(customer.get("gender")))
	var dye: Variant = customer.get("street_color")
	_rig.wear_street(
		Wardrobe.street_look(int(customer.get("street_index")), int(dye) if dye != null else 0)
	)


## Match the portrait to a plain look (for characters that aren't customers, e.g. the
## tutorial mentor). Keys: head, hair (int), skin, hair_color (Color), eyes, glasses,
## face_style (String, a FaceCast preset), gender (Enums.Gender, optional: FEMALE wears the
## feminine kit), suit (MaterialType, optional — worn as jacket + trousers).
func configure_look(look: Dictionary) -> void:
	if _rig == null:
		return
	_rig.set_head(int(look.get("head", 0)))
	_rig.set_hair(int(look.get("hair", 0)))
	if look.has("skin"):
		_rig.set_palette(look["skin"])
	if look.has("hair_color"):
		_rig.set_hair_color(look["hair_color"])
	_rig.set("glasses_color", str(look.get("glasses_color", "black")))
	_rig.set_face_look(
		str(look.get("eyes", "brown")),
		str(look.get("glasses", "")),
		int(look.get("nose", -1)),
		int(look.get("mouth", -1))
	)
	_set_face(str(look.get("face_style", "")), int(look.get("gender", 0)))
	var suit: MaterialType = look.get("suit")
	if suit != null:
		_rig.set_outfit(suit, null, suit)
	else:
		_rig.wear_street()


## Animate the mouth without touching the render state (the render stays live).
func set_talking(on: bool) -> void:
	if _rig != null:
		_rig.set_talking(on)


## Pop the mouth open for one syllable (lip-sync to a talk blip).
func syllable() -> void:
	if _rig != null:
		_rig.syllable()


## Start/stop the live render (and the talking mouth) — off when the bubble is hidden.
func set_live(on: bool) -> void:
	if _rig != null:
		_rig.set_talking(on)
	if _view != null:
		_view.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		)


## React on the portrait too (used later at the mirror): true = pleased, false = not.
func react(liked: bool) -> void:
	if _rig != null and _rig.has_method("express_once"):
		_rig.express_once(liked)


## The cut-paper face (a FaceCast preset name; empty or unknown = left as it is), with the
## feminine kit for a woman (FaceCast.style()).
func _set_face(preset: String, gender: int) -> void:
	if FaceCast.exists(preset):
		_rig.set("face_style", FaceCast.style(preset, gender))
