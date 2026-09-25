extends Control
## Boot scene: the studio clip, then the main menu switching on like a CRT. Any key,
## click or pad button skips the clip. The menu and grandpa's shop behind it load on a
## thread while the clip plays, so the swap doesn't stall. Sfx holds the menu theme
## back while this scene is up (CrtPowerOn starts it); the HUD autoload is hidden here.

const MENU := "res://scenes/menu/main_menu.tscn"
const BACKDROP := "res://scenes/world/grandpa/grandpa_shop_room.tscn"
const CLIP := preload("res://assets/video/felt_intro.ogv")

var _done := false

@onready var _video: VideoStreamPlayer = $Video


func _ready() -> void:
	Sfx.stop_music()
	UI.visible = false
	ResourceLoader.load_threaded_request(MENU)
	ResourceLoader.load_threaded_request(BACKDROP)
	if DisplayServer.get_name() == "headless":
		_finish.call_deferred()
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_video.stream = CLIP
	_video.finished.connect(_finish)
	_video.play()


## _input, not _unhandled_input: the full-screen root and the HUD/debug autoloads would
## otherwise swallow clicks and keys before they reach the skip.
func _input(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_video.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var crt := CrtPowerOn.new()
	get_tree().root.add_child(crt)  # black from the first frame, so the swap is hidden
	var menu := ResourceLoader.load_threaded_get(MENU) as PackedScene
	# The overlay holds the shop so the menu's own load() of it hits the cache.
	crt.keep = [menu, ResourceLoader.load_threaded_get(BACKDROP)]
	get_tree().change_scene_to_packed(menu)
