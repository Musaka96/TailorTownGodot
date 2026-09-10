extends Node

## Autoloaded as "Settings". Global player options (audio volumes, display, the retro
## filter), persisted to user://settings.cfg — SEPARATE from save slots, so they apply to
## every game. Loaded and applied once at boot (this autoload sits after Sfx and PostFX so
## their buses/filter exist), and each setter applies live + re-saves. The Settings screen
## (ui/settings_ui.gd) reads/writes through here; nothing else needs to know the storage.

const PATH := "user://settings.cfg"

## Retro-filter choices for the Settings dropdown: [label, value]. "off" disables PostFX;
## anything else is a PostFxProfile resource path (see data/postfx/).
const FILTERS := [
	["Off", "off"],
	["Chew", "res://data/postfx/chew.tres"],
	["Cozy Diorama", "res://data/postfx/cozy_diorama.tres"],
	["Storybook", "res://data/postfx/storybook.tres"],
	["Pixel Toy", "res://data/postfx/pixel_toy.tres"],
	["CRT Green", "res://data/postfx/crt_green.tres"],
	["VHS 80s", "res://data/postfx/vhs_80s.tres"],
	["Retro 70s", "res://data/postfx/retro_70s.tres"],
]

var master := 1.0
var music := 1.0
var sfx := 1.0
var fullscreen := false
var vsync := true
var filter := "res://data/postfx/chew.tres"


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
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	filter = str(cfg.get_value("video", "filter", filter))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("video", "filter", filter)
	cfg.save(PATH)


func apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_filter()


# --- Setters (apply live + persist) ----------------------------------------


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


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_display()
	save()


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_display()
	save()


func set_filter(value: String) -> void:
	filter = value
	_apply_filter()
	save()


## Index of the current filter within FILTERS (0 if unknown).
func filter_index() -> int:
	for i in FILTERS.size():
		if FILTERS[i][1] == filter:
			return i
	return 0


# --- Apply -----------------------------------------------------------------


func _apply_audio() -> void:
	_bus_db("Master", master)
	_bus_db("Music", music)
	_bus_db("SFX", sfx)


func _bus_db(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, -80.0 if v <= 0.001 else linear_to_db(v))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)
	var vs := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vs)


func _apply_filter() -> void:
	if PostFX == null:
		return
	if filter == "off":
		PostFX.set_enabled(false)
		return
	if ResourceLoader.exists(filter):
		PostFX.set_profile_path(filter)
		PostFX.set_enabled(true)
