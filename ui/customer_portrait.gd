class_name CustomerPortrait
extends TvFrame

## A little retro-TV portrait of a customer: a private 3D mini-scene (its own world,
## light and camera) renders a character rig framed on the face, shown inside the TV
## bezel. Call configure() to match a customer's look, set_live(true) to animate/talk.

const RIG_SCENE := preload("res://entities/character/character_rig.tscn")
const VIEW_SIZE := 260

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
	env.ambient_light_energy = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -32, 0)
	sun.light_energy = 1.1
	_view.add_child(sun)

	_rig = RIG_SCENE.instantiate()
	_view.add_child(_rig)
	var ap := _rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.play("idle")

	_cam = Camera3D.new()
	_cam.fov = 34
	# Framed on the head + the top half of the torso.
	_cam.position = Vector3(0.0, 1, 2.35)
	_cam.look_at_from_position(_cam.position, Vector3(0, 1.6, 0.4), Vector3.UP)
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
	_rig.set_face_look(str(customer.get("eye_color")), str(customer.get("glasses")))
	_rig.wear_street()


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
