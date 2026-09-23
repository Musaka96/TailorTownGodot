extends Node

## Autoloaded as "Settings". Global player options — audio, display (mode / resolution /
## vsync / anti-aliasing), interface sizes and key bindings — persisted to
## user://settings.cfg, SEPARATE from save slots so they apply to every game. Loaded and
## applied once at boot, and each setter applies live + re-saves. The Settings screen
## (ui/settings_ui.gd + ui/rebind_button.gd) reads/writes through here; nothing else
## needs to know the storage.

## A key binding changed (rebind or reset) — on-screen key caps refresh on this.
signal bindings_changed
## One interface size changed (see UiScale): every control of category `cat` rescales.
signal ui_scale_changed(cat: String, value: float)

const PATH := "user://settings.cfg"
## The interface size sliders' range (1.0 = as designed).
const UI_SCALE_MIN := 0.6
const UI_SCALE_MAX := 1.3

## Window modes for the dropdown (index = stored value).
const MODES := ["Windowed", "Fullscreen", "Borderless"]
## Selectable resolutions: the window's size when windowed, the 3D render size when the
## game fills the screen (the UI always stays at the screen's own sharpness).
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
## Edge smoothing levels for the dropdown (index = stored value): [label, MSAA, screen AA].
## SMAA also softens the drawn outlines, which MSAA alone can't reach.
const ANTIALIASING := [
	["Off", Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED],
	["Low", Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_SMAA],
	["Medium", Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_SMAA],
	["High", Viewport.MSAA_4X, Viewport.SCREEN_SPACE_AA_SMAA],
]
## Controller button names by JoyButton index (Xbox layout).
const PAD_BUTTONS := [
	"A",
	"B",
	"X",
	"Y",
	"Back",
	"Guide",
	"Start",
	"L3",
	"R3",
	"LB",
	"RB",
	"D-pad Up",
	"D-pad Down",
	"D-pad Left",
	"D-pad Right",
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
	["handbook", "Handbook"],
	["pause", "Pause / menu"],
]

var master := 1.0
var music := 1.0
var sfx := 1.0
var mode := 0  # index into MODES
var resolution := Vector2i(1280, 720)
var vsync := true
var antialiasing := 3  # index into ANTIALIASING
## Interface size per UiScale category (menus / hud / prompts / dialogue).
## The owner's pick after playing with the sliders: 80% across the board.
const UI_SCALE_DEFAULT := 0.8
var ui_scale := {
	"menus": UI_SCALE_DEFAULT,
	"hud": UI_SCALE_DEFAULT,
	"prompts": UI_SCALE_DEFAULT,
	"dialogue": UI_SCALE_DEFAULT,
}

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
	antialiasing = int(cfg.get_value("display", "antialiasing", antialiasing))
	for cat: String in ui_scale:
		var v := float(cfg.get_value("ui", cat, ui_scale[cat]))
		ui_scale[cat] = clampf(v, UI_SCALE_MIN, UI_SCALE_MAX)
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
	cfg.set_value("display", "antialiasing", antialiasing)
	for cat: String in ui_scale:
		cfg.set_value("ui", cat, ui_scale[cat])
	for action: String in _bindings:
		cfg.set_value("controls", action, _bindings[action])
	cfg.save(PATH)


func apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_bindings()


# --- Interface size ----------------------------------------------------------


## Set one UiScale category's size (clamped to the slider range); every attached control
## of that category rescales live.
func set_ui_scale(cat: String, value: float) -> void:
	if not ui_scale.has(cat):
		return
	ui_scale[cat] = clampf(value, UI_SCALE_MIN, UI_SCALE_MAX)
	ui_scale_changed.emit(cat, ui_scale[cat])
	save()


## The size for a UiScale category (the default for an unknown one).
func ui_scale_of(cat: String) -> float:
	return float(ui_scale.get(cat, UI_SCALE_DEFAULT))


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
	_apply_vsync()
	_rebuild_swapchain()
	save()


func set_antialiasing(level: int) -> void:
	antialiasing = clampi(level, 0, ANTIALIASING.size() - 1)
	_apply_antialiasing()
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
	_apply_vsync()
	_apply_antialiasing()
	var screen := DisplayServer.screen_get_size()
	match mode:
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			_render_at(screen)
		2:
			# Godot's plain FULLSCREEN is a borderless window over the whole screen.
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_render_at(screen)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			get_window().scaling_3d_scale = 1.0
			# A window can't outgrow the desktop; leaving fullscreen settles a frame late,
			# so the size is set once the mode change has landed.
			var usable := DisplayServer.screen_get_usable_rect().size
			_size_window.call_deferred(resolution.min(usable))


func _apply_antialiasing() -> void:
	var level: Array = ANTIALIASING[clampi(antialiasing, 0, ANTIALIASING.size() - 1)]
	get_window().msaa_3d = level[1]
	get_window().screen_space_aa = level[2]


## On its own, so flipping VSync never resizes or re-centres the window.
func _apply_vsync() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vs := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vs)


## The D3D12 driver only picks a new VSync mode up when the swapchain is rebuilt, which
## a bare window_set_vsync_mode() doesn't do — so a live toggle nudges the window a pixel
## and back (or, when it fills the screen and its size is fixed, steps out to a window and back).
func _rebuild_swapchain() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if mode != 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(DisplayServer.screen_get_size() / 2)
	else:
		DisplayServer.window_set_size(DisplayServer.window_get_size() - Vector2i(0, 1))
	for i in 3:
		await get_tree().process_frame
	_apply_display()


## Filling the screen, the window is always the screen's size — so the chosen resolution
## becomes the 3D render size instead, scaled up to fit. Never above native.
func _render_at(screen: Vector2i) -> void:
	var scale := float(resolution.y) / float(maxi(screen.y, 1))
	get_window().scaling_3d_scale = clampf(scale, 0.25, 1.0)


func _size_window(to: Vector2i) -> void:
	if mode != 0:
		return
	DisplayServer.window_set_size(to)
	_center_window()


func _center_window() -> void:
	var area := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(
		area.position + (area.size - DisplayServer.window_get_size()) / 2
	)


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
			return pad_button_text((ev as InputEventJoypadButton).button_index)
	return "—"


## The pad button an action is bound to (e.g. "X", "RB"), or "" when it has none.
func pad_text(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return pad_button_text((ev as InputEventJoypadButton).button_index)
	return ""


## A controller button's everyday name (Xbox layout), e.g. 2 -> "X".
func pad_button_text(index: int) -> String:
	if index >= 0 and index < PAD_BUTTONS.size():
		return PAD_BUTTONS[index]
	return "Pad %d" % index


## Rebind an action to a single captured event (replacing its keyboard/mouse/pad events).
func set_binding(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_bindings[action] = _encode(event)
	save()
	bindings_changed.emit()


## Restore every action to the project defaults and forget saved bindings.
func reset_controls() -> void:
	InputMap.load_from_project_settings()
	_bindings.clear()
	save()
	bindings_changed.emit()


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
