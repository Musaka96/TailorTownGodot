extends Node

## Autoloaded as "Settings". Global player options — audio, display (mode / resolution /
## vsync) and key bindings — persisted to user://settings.cfg, SEPARATE from save slots so
## they apply to every game. Loaded and applied once at boot, and each setter applies live +
## re-saves. The Settings screen (ui/settings_ui.gd + ui/rebind_button.gd) reads/writes
## through here; nothing else needs to know the storage.

const PATH := "user://settings.cfg"

## Window modes for the dropdown (index = stored value).
const MODES := ["Windowed", "Fullscreen", "Borderless"]
## Selectable windowed resolutions.
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
## Rebindable gameplay actions: [InputMap action, label]. Order = display order.
const REBINDS := [
	["move_forward", "Move up"],
	["move_back", "Move down"],
	["move_left", "Move left"],
	["move_right", "Move right"],
	["interact", "Interact"],
	["sprint", "Sprint / fast"],
	["cut", "Cut"],
	["orders", "Orders board"],
	["newspaper", "Newspaper"],
	["pause", "Pause / menu"],
]

var master := 1.0
var music := 1.0
var sfx := 1.0
var mode := 0  # index into MODES
var resolution := Vector2i(1280, 720)
var vsync := true

var _bindings := {}  # action -> encoded event dict (only actions the player changed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master = float(cfg.get_value("audio", "master", master))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
	mode = int(cfg.get_value("display", "mode", mode))
	resolution = cfg.get_value("display", "resolution", resolution)
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	_bindings = {}
	if cfg.has_section("controls"):
		for action in cfg.get_section_keys("controls"):
			_bindings[action] = cfg.get_value("controls", action)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("display", "mode", mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	for action: String in _bindings:
		cfg.set_value("controls", action, _bindings[action])
	cfg.save(PATH)


func apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_bindings()


# --- Audio -----------------------------------------------------------------


func set_master(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	_bus_db("Master", master)
	save()


func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	_bus_db("Music", music)
	save()


func set_sfx(v: float) -> void:
	sfx = clampf(v, 0.0, 1.0)
	_bus_db("SFX", sfx)
	save()


func _apply_audio() -> void:
	_bus_db("Master", master)
	_bus_db("Music", music)
	_bus_db("SFX", sfx)


func _bus_db(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, -80.0 if v <= 0.001 else linear_to_db(v))


# --- Display ---------------------------------------------------------------


func set_mode(m: int) -> void:
	mode = clampi(m, 0, MODES.size() - 1)
	_apply_display()
	save()


func set_resolution(res: Vector2i) -> void:
	resolution = res
	_apply_display()
	save()


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_display()
	save()


## Index of the current resolution within RESOLUTIONS (0 if unknown).
func resolution_index() -> int:
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == resolution:
			return i
	return 0


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vs := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vs)
	match mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(DisplayServer.screen_get_size())
			DisplayServer.window_set_position(Vector2i.ZERO)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(resolution)
			_center_window()


func _center_window() -> void:
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen - DisplayServer.window_get_size()) / 2)


# --- Key bindings ----------------------------------------------------------


## Human-readable label for an action's current primary binding (e.g. "W", "Space").
func binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
		if ev is InputEventMouseButton:
			return "Mouse %d" % (ev as InputEventMouseButton).button_index
		if ev is InputEventJoypadButton:
			return "Pad %d" % (ev as InputEventJoypadButton).button_index
	return "—"


## Rebind an action to a single captured event (replacing its keyboard/mouse/pad events).
func set_binding(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_bindings[action] = _encode(event)
	save()


## Restore every action to the project defaults and forget saved bindings.
func reset_controls() -> void:
	InputMap.load_from_project_settings()
	_bindings.clear()
	save()


func _apply_bindings() -> void:
	for action: String in _bindings:
		if not InputMap.has_action(action):
			continue
		var ev := _decode(_bindings[action])
		if ev != null:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)


func _encode(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "key", "c": (ev as InputEventKey).physical_keycode}
	if ev is InputEventMouseButton:
		return {"t": "mb", "c": (ev as InputEventMouseButton).button_index}
	if ev is InputEventJoypadButton:
		return {"t": "jb", "c": (ev as InputEventJoypadButton).button_index}
	return {}


func _decode(d: Dictionary) -> InputEvent:
	match str(d.get("t", "")):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d["c"])
			return e
		"mb":
			var e := InputEventMouseButton.new()
			e.button_index = int(d["c"])
			return e
		"jb":
			var e := InputEventJoypadButton.new()
			e.button_index = int(d["c"])
			return e
	return null
