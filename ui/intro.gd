extends Control
## Boot scene: the studio clip, then the main menu switching on like a CRT. Any key,
## click or pad button skips the clip. The clip's last second is black; it is cut at
## END_AT so the tube comes on without a dead pause.

const MENU := "res://scenes/menu/main_menu.tscn"
const CLIP := preload("res://assets/video/felt_intro.ogv")
const END_AT := 9.2  # seconds; the clip goes fully black at 8.9

var _done := false

@onready var _video: VideoStreamPlayer = $Video


func _ready() -> void:
	# Sfx boots on the menu theme and the HUD autoload draws above every scene; both
	# wait for the menu so the clip plays alone.
	Sfx.stop_music()
	UI.visible = false
	if DisplayServer.get_name() == "headless":
		_finish.call_deferred()
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_video.stream = CLIP
	_video.finished.connect(_finish)
	_video.play()


func _process(_delta: float) -> void:
	if not _done and _video.is_playing() and _video.stream_position >= END_AT:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
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
	get_tree().root.add_child(CrtPowerOn.new())
	Sfx.fade_music_in(Sfx.MENU_THEME, CrtPowerOn.HOLD + CrtPowerOn.DURATION)
	get_tree().change_scene_to_file(MENU)
