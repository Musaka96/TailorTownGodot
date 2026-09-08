extends Control

## Always-on heads-up display: the interaction prompt (bottom) and what the
## player is currently carrying (top-left). Driven entirely by EventBus signals.

var _prompt_bar: PanelContainer
var _prompt_verb: Label

@onready var _prompt: Label = $Prompt
@onready var _held: Label = $Held
@onready var _money: Label = $Money


func _ready() -> void:
	_build_prompt_bar()
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.item_picked_up.connect(func(item): _show_held(item))
	EventBus.item_taken.connect(func(item, _station): _show_held(item))
	EventBus.item_stored.connect(func(_item, _station): _show_held(null))
	EventBus.money_changed.connect(_show_money)
	_show_held(null)
	_show_money(GameState.money)
	_on_prompt_changed("")


func _show_money(balance: int) -> void:
	_money.text = "$ %d" % balance


## The interaction prompt as an atelier key-cap bar ("[E] Order fabric") on a
## translucent rounded panel, so it reads cleanly over the 3D scene (guide §4).
func _build_prompt_bar() -> void:
	_prompt.visible = false
	_prompt_bar = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.09, 0.82)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = Style.S3
	sb.content_margin_right = Style.S3
	sb.content_margin_top = Style.S1 + 2
	sb.content_margin_bottom = Style.S1 + 2
	_prompt_bar.add_theme_stylebox_override("panel", sb)
	_prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_bar.anchor_left = 0.5
	_prompt_bar.anchor_right = 0.5
	_prompt_bar.anchor_top = 1.0
	_prompt_bar.anchor_bottom = 1.0
	_prompt_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_bar.offset_top = -92.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	_prompt_bar.add_child(row)
	row.add_child(Style.keycap("E"))
	_prompt_verb = Label.new()
	_prompt_verb.add_theme_font_override("font", Style.bold_font())
	_prompt_verb.add_theme_font_size_override("font_size", 15)
	_prompt_verb.add_theme_color_override("font_color", Style.CHALK)
	_prompt_verb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_verb)
	add_child(_prompt_bar)
	_prompt_bar.visible = false


func _on_prompt_changed(text: String) -> void:
	_prompt_verb.text = text
	_prompt_bar.visible = text != ""


func _show_held(item) -> void:
	if item == null:
		_held.text = ""
		return
	# Rolls report remaining_length_m; cut pieces report length_m.
	var meters = item.get("remaining_length_m")
	var noun := "left"
	if meters == null:
		meters = item.get("length_m")
		noun = "piece"
	var mat_name: String = item.material.display_name if item.material else "cloth"
	_held.text = "Carrying: %s   (%.1f m %s)" % [mat_name, float(meters), noun]
