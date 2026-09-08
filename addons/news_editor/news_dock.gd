@tool
extends VBoxContainer

## The News Editor dock. Lists every newspaper event under data/news/ and edits the
## selected one through a form — day/reputation gates, kind, and the fashion/event
## parameters — then saves it back as a .tres. Enum fields are driven from Enums so
## authoring can't produce an invalid pattern/fabric/occasion/style. Editor-only.

const NEWS_DIR := "res://data/news"
const KIND_STORY := 0
const KIND_FASHION := 1
const KIND_EVENT := 2

var _paths: Array[String] = []
var _current_path: String = ""

var _list: ItemList
var _id: LineEdit
var _headline: LineEdit
var _body: TextEdit
var _kind: OptionButton
var _exact_day: SpinBox
var _min_day: SpinBox
var _max_day: SpinBox
var _min_rep: SpinBox
var _max_rep: SpinBox
var _repeatable: CheckBox
var _priority: SpinBox
var _weight: SpinBox
var _fashion_box: VBoxContainer
var _fashion_pattern: OptionButton
var _fashion_fabric: OptionButton
var _fashion_bonus: SpinBox
var _event_box: VBoxContainer
var _event_day: SpinBox
var _event_occasion: OptionButton
var _event_style: OptionButton
var _bias_days: SpinBox
var _bias_chance: SpinBox
var _status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	add_theme_constant_override("separation", 6)
	_build_list_section()
	_build_form_section()
	_refresh_list()
	_load_event(NewsEvent.new(), "")


# --- Layout ----------------------------------------------------------------


func _build_list_section() -> void:
	var head := HBoxContainer.new()
	add_child(head)
	var title := Label.new()
	title.text = "Newspaper events"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Reload", _refresh_list))

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 150)
	_list.item_selected.connect(_on_list_selected)
	add_child(_list)

	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_button("New", _on_new))
	row.add_child(_button("Duplicate", _on_duplicate))
	row.add_child(_button("Delete", _on_delete))
	add_child(HSeparator.new())


func _build_form_section() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 4)
	scroll.add_child(form)

	_id = LineEdit.new()
	_field(form, "Id (filename)", _id)
	_headline = LineEdit.new()
	_field(form, "Headline", _headline)
	_body = TextEdit.new()
	_body.custom_minimum_size = Vector2(0, 84)
	_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_field(form, "Body", _body)

	_kind = _enum_option(["Story", "Fashion", "Event"])
	_kind.item_selected.connect(func(_i: int) -> void: _sync_kind())
	_field(form, "Kind", _kind)

	_exact_day = _spin(0, 999, 1)
	_field(form, "Exact day (0 = ignore)", _exact_day)
	_min_day = _spin(0, 999, 1)
	_field(form, "Min day", _min_day)
	_max_day = _spin(0, 999, 1)
	_field(form, "Max day (0 = none)", _max_day)
	_min_rep = _spin(0, 9999, 5)
	_field(form, "Min reputation", _min_rep)
	_max_rep = _spin(0, 9999, 5)
	_field(form, "Max reputation (0 = none)", _max_rep)
	_repeatable = CheckBox.new()
	_repeatable.text = "Repeatable"
	form.add_child(_repeatable)
	_priority = _spin(0, 99, 1)
	_field(form, "Priority (lead story)", _priority)
	_weight = _spin(1, 99, 1)
	_field(form, "Weight", _weight)

	_build_fashion_group(form)
	_build_event_group(form)

	add_child(_button("Save", _on_save))
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(_status)


func _build_fashion_group(form: VBoxContainer) -> void:
	_fashion_box = VBoxContainer.new()
	form.add_child(_fashion_box)
	_fashion_box.add_child(_heading("Fashion trend"))
	_fashion_pattern = _enum_option(_names_of(Enums.Pattern.size(), Enums.pattern_name), "— none —")
	_field(_fashion_box, "Pattern in favour", _fashion_pattern)
	_fashion_fabric = _enum_option(_names_of(Enums.Fabric.size(), Enums.fabric_name), "— none —")
	_field(_fashion_box, "Fabric in favour", _fashion_fabric)
	_fashion_bonus = _spin(0, 99, 1)
	_field(_fashion_box, "Reputation bonus", _fashion_bonus)


func _build_event_group(form: VBoxContainer) -> void:
	_event_box = VBoxContainer.new()
	form.add_child(_event_box)
	_event_box.add_child(_heading("City event"))
	_event_day = _spin(0, 999, 1)
	_field(_event_box, "Event day", _event_day)
	_event_occasion = _enum_option(_names_of(Enums.Occasion.size(), Enums.occasion_name))
	_field(_event_box, "Occasion", _event_occasion)
	_event_style = _enum_option(_names_of(Enums.Style.size(), Enums.style_name), "— any —")
	_field(_event_box, "Style", _event_style)
	_bias_days = _spin(0, 30, 1)
	_field(_event_box, "Bias days before", _bias_days)
	_bias_chance = _spin(0.0, 1.0, 0.05)
	_field(_event_box, "Bias chance", _bias_chance)


# --- Small builders --------------------------------------------------------


func _field(parent: VBoxContainer, label: String, control: Control) -> void:
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)


func _heading(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.79, 0.64, 0.29))
	return lbl


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	return s


func _enum_option(names: Array, lead: String = "") -> OptionButton:
	var ob := OptionButton.new()
	if lead != "":
		ob.add_item(lead)
	for n: String in names:
		ob.add_item(n)
	return ob


## Display names for enum values 0..count-1 via a name function.
func _names_of(count: int, name_fn: Callable) -> Array:
	var out: Array = []
	for i in count:
		out.append(name_fn.call(i))
	return out


# --- List ------------------------------------------------------------------


func _refresh_list() -> void:
	_paths.clear()
	_list.clear()
	var dir := DirAccess.open(NEWS_DIR)
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				_paths.append(NEWS_DIR.path_join(file))
	_paths.sort()
	for path in _paths:
		var ev := load(path) as NewsEvent
		var kind := _kind_label(ev.kind) if ev != null else "?"
		_list.add_item("[%s] %s" % [kind, path.get_file().trim_suffix(".tres")])


func _on_list_selected(index: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	var path := _paths[index]
	var ev := load(path) as NewsEvent
	if ev != null:
		_load_event(ev, path)


func _kind_label(kind: int) -> String:
	match kind:
		KIND_FASHION:
			return "Fashion"
		KIND_EVENT:
			return "Event"
	return "Story"


# --- Form <-> resource -----------------------------------------------------


func _load_event(ev: NewsEvent, path: String) -> void:
	_current_path = path
	_id.text = ev.id
	_headline.text = ev.headline
	_body.text = ev.body
	_kind.select(ev.kind)
	_exact_day.value = ev.exact_day
	_min_day.value = ev.min_day
	_max_day.value = ev.max_day
	_min_rep.value = ev.min_reputation
	_max_rep.value = ev.max_reputation
	_repeatable.button_pressed = ev.repeatable
	_priority.value = ev.priority
	_weight.value = ev.weight
	_fashion_pattern.select(ev.fashion_pattern + 1)
	_fashion_fabric.select(ev.fashion_fabric + 1)
	_fashion_bonus.value = ev.fashion_bonus
	_event_day.value = ev.event_day
	_event_occasion.select(ev.event_occasion)
	_event_style.select(ev.event_style + 1)
	_bias_days.value = ev.bias_days
	_bias_chance.value = ev.bias_chance
	_sync_kind()


func _collect() -> NewsEvent:
	var ev := NewsEvent.new()
	ev.id = _id.text.strip_edges()
	ev.headline = _headline.text
	ev.body = _body.text
	ev.kind = _kind.selected
	ev.exact_day = int(_exact_day.value)
	ev.min_day = int(_min_day.value)
	ev.max_day = int(_max_day.value)
	ev.min_reputation = int(_min_rep.value)
	ev.max_reputation = int(_max_rep.value)
	ev.repeatable = _repeatable.button_pressed
	ev.priority = int(_priority.value)
	ev.weight = int(_weight.value)
	ev.fashion_pattern = _fashion_pattern.selected - 1
	ev.fashion_fabric = _fashion_fabric.selected - 1
	ev.fashion_bonus = int(_fashion_bonus.value)
	ev.event_day = int(_event_day.value)
	ev.event_occasion = _event_occasion.selected
	ev.event_style = _event_style.selected - 1
	ev.bias_days = int(_bias_days.value)
	ev.bias_chance = _bias_chance.value
	return ev


func _sync_kind() -> void:
	_fashion_box.visible = _kind.selected == KIND_FASHION
	_event_box.visible = _kind.selected == KIND_EVENT


# --- Actions ---------------------------------------------------------------


func _on_new() -> void:
	_load_event(NewsEvent.new(), "")
	_status.text = "New event — set an id and Save."


func _on_duplicate() -> void:
	var ev := _collect()
	ev.id = (ev.id if ev.id != "" else "event") + "_copy"
	_load_event(ev, "")
	_status.text = "Duplicated — Save to write it."


func _on_delete() -> void:
	if _current_path == "" or not FileAccess.file_exists(_current_path):
		_status.text = "Nothing saved to delete."
		return
	DirAccess.remove_absolute(_current_path)
	_current_path = ""
	_refresh_list()
	_scan_filesystem()
	_load_event(NewsEvent.new(), "")
	_status.text = "Deleted."


func _on_save() -> void:
	var ev := _collect()
	if ev.id == "":
		_status.text = "Give it an id first."
		return
	_ensure_dir()
	var path := "%s/%s.tres" % [NEWS_DIR, ev.id]
	var err := ResourceSaver.save(ev, path)
	if err != OK:
		_status.text = "Save failed (%d)." % err
		return
	_current_path = path
	_refresh_list()
	_scan_filesystem()
	_status.text = "Saved %s.tres" % ev.id


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(NEWS_DIR):
		DirAccess.make_dir_recursive_absolute(NEWS_DIR)


func _scan_filesystem() -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
