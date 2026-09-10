@tool
extends VBoxContainer

## The Tool Runner dock. Scans res://tools/ for command-line tool scripts (those that
## `extends SceneTree`) and shows a Run button for each; clicking it launches a fresh
## headless Godot process running that tool and prints its output here. After a run the
## editor FileSystem is rescanned so regenerated assets (.tres, sliced PNGs, …) refresh.

const TOOLS_DIR := "res://tools"

var _list: VBoxContainer
var _log: TextEdit
var _running := false


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	add_theme_constant_override("separation", 6)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Tool Runner"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(_refresh)
	header.add_child(refresh)
	add_child(header)

	var hint := Label.new()
	hint.text = "Runs a tool headless in a separate process."
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	add_child(scroll)

	var log_label := Label.new()
	log_label.text = "Output"
	add_child(log_label)
	_log = TextEdit.new()
	_log.editable = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 180)
	_log.placeholder_text = "Run a tool to see its output here."
	add_child(_log)


## Rebuild the button list from the tools folder.
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var dir := DirAccess.open(TOOLS_DIR)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.get_extension() != "gd":
			continue
		var path := "%s/%s" % [TOOLS_DIR, f]
		if not _is_runnable(path):
			continue
		var btn := Button.new()
		btn.text = "  ▶  %s" % f.get_basename()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = _doc(path)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_run.bind(f))
		_list.add_child(btn)


## A tool script is one that drives its own loop via SceneTree (run with --script).
func _is_runnable(path: String) -> bool:
	var txt := FileAccess.get_file_as_string(path)
	return txt.find("extends SceneTree") != -1


## The leading `##` doc block of a script, for the button tooltip.
func _doc(path: String) -> String:
	var txt := FileAccess.get_file_as_string(path)
	var lines := txt.split("\n")
	var out: Array[String] = []
	for line in lines:
		var t := line.strip_edges()
		if t.begins_with("##"):
			out.append(t.substr(2).strip_edges())
		elif not out.is_empty():
			break
	return "\n".join(out) if not out.is_empty() else path


func _run(file_name: String) -> void:
	if _running:
		return
	_running = true
	_set_buttons_disabled(true)
	_log.text = "Running %s …\n" % file_name
	await get_tree().process_frame  # let the label paint before we block
	var args := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tools/%s" % file_name,
	]
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	_log.text += "\n".join(out)
	_log.text += "\n\n[exit code %d]" % code
	_log.scroll_vertical = _log.get_line_count()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_set_buttons_disabled(false)
	_running = false


func _set_buttons_disabled(disabled: bool) -> void:
	for b in _list.get_children():
		if b is Button:
			(b as Button).disabled = disabled
