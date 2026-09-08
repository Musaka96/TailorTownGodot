extends Control

## Always-on heads-up display: the interaction prompt (bottom) and what the
## player is currently carrying (top-left). Driven entirely by EventBus signals.

var _prompt_bar: PanelContainer
var _prompt_verb: Label
var _money_panel: PanelContainer
var _money_value: Label
var _money_style: StyleBoxFlat
var _money_current := 0  # target balance
var _money_shown := 0  # what the rolling counter currently reads
var _money_started := false
var _count_tween: Tween

@onready var _prompt: Label = $Prompt
@onready var _held: Label = $Held
@onready var _money: Label = $Money


func _ready() -> void:
	_build_prompt_bar()
	_build_money_panel()
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.item_picked_up.connect(func(item): _show_held(item))
	EventBus.item_taken.connect(func(item, _station): _show_held(item))
	EventBus.item_stored.connect(func(_item, _station): _show_held(null))
	EventBus.money_changed.connect(_show_money)
	_show_held(null)
	_show_money(GameState.money)
	_on_prompt_changed("")


## A brass-trimmed cash tag (coin badge + amount) top-right. The original scene
## label is hidden and this is built in code, so the .tscn never needs regenerating.
func _build_money_panel() -> void:
	_money.visible = false
	_money_panel = PanelContainer.new()
	_money_style = StyleBoxFlat.new()
	_money_style.bg_color = Style.CREAM
	_money_style.set_corner_radius_all(10)
	_money_style.set_border_width_all(2)
	_money_style.border_color = Style.BRASS
	_money_style.content_margin_left = Style.S2
	_money_style.content_margin_right = Style.S3
	_money_style.content_margin_top = Style.S1 + 1
	_money_style.content_margin_bottom = Style.S1 + 1
	_money_style.shadow_color = Style.SHADOW
	_money_style.shadow_size = 6
	_money_style.shadow_offset = Vector2(0, 3)
	_money_panel.add_theme_stylebox_override("panel", _money_style)
	_money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pin to the top-right corner and grow leftward to fit the content.
	_money_panel.anchor_left = 1.0
	_money_panel.anchor_right = 1.0
	_money_panel.anchor_top = 0.0
	_money_panel.anchor_bottom = 0.0
	_money_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_money_panel.grow_vertical = Control.GROW_DIRECTION_END
	_money_panel.offset_left = -16.0
	_money_panel.offset_right = -16.0
	_money_panel.offset_top = 14.0
	_money_panel.offset_bottom = 14.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	_money_panel.add_child(row)
	row.add_child(_coin_badge())
	_money_value = Label.new()
	_money_value.add_theme_font_override("font", Style.bold_font())
	_money_value.add_theme_font_size_override("font_size", 18)
	_money_value.add_theme_color_override("font_color", Style.INK)
	_money_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money_value)
	add_child(_money_panel)


## A little round brass coin with a "$" struck on it.
func _coin_badge() -> Control:
	var badge := PanelContainer.new()
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.BRASS
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "$"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Style.bold_font())
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Style.CHALK)
	badge.add_child(lbl)
	return badge


## Update the purse: the first time snaps into place, later changes roll the counter
## and play a bump, an edge flash and a rising +/- delta (green for gain, clay loss).
func _show_money(balance: int) -> void:
	if _money_value == null:
		return
	if not _money_started:
		_money_started = true
		_money_current = balance
		_money_shown = balance
		_money_value.text = str(balance)
		return
	var delta := balance - _money_current
	_money_current = balance
	_roll_to(balance)
	if delta != 0:
		_bump_money()
		_flash_money(delta > 0)
		_spawn_delta(delta)


func _roll_to(target: int) -> void:
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_count_tween.tween_method(_set_money_display, float(_money_shown), float(target), 0.4)


func _set_money_display(value: float) -> void:
	_money_shown = int(round(value))
	_money_value.text = str(_money_shown)


func _bump_money() -> void:
	_money_panel.pivot_offset = _money_panel.size * 0.5
	var t := create_tween()
	t.tween_property(_money_panel, "scale", Vector2(1.08, 1.08), 0.09).set_ease(Tween.EASE_OUT)
	t.tween_property(_money_panel, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_IN)


func _flash_money(gain: bool) -> void:
	var col: Color = Style.FOREST if gain else Style.CLAY
	var t := create_tween()
	t.tween_property(_money_style, "border_color", col, 0.08)
	t.tween_property(_money_style, "border_color", Style.BRASS, 0.35)


## A floating "+$50" / "-$20" that rises above the purse and fades out.
func _spawn_delta(delta: int) -> void:
	var lbl := Label.new()
	lbl.text = ("+$%d" if delta > 0 else "-$%d") % absi(delta)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_override("font", Style.bold_font())
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Style.FOREST if delta > 0 else Style.CLAY)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.anchor_left = 1.0
	lbl.anchor_right = 1.0
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.offset_left = -150.0
	lbl.offset_right = -18.0
	lbl.offset_top = 52.0
	add_child(lbl)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "offset_top", 34.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	t.tween_property(lbl, "modulate:a", 0.0, 0.8)
	t.chain().tween_callback(lbl.queue_free)


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
	# Anchor to the bottom-centre as a point and let the panel size to its content:
	# equal top/bottom offsets give a zero-height base rect that grows upward to the
	# key-cap + text (grow BEGIN), instead of being pinned to a fixed 92 px box.
	_prompt_bar.anchor_left = 0.5
	_prompt_bar.anchor_right = 0.5
	_prompt_bar.anchor_top = 1.0
	_prompt_bar.anchor_bottom = 1.0
	_prompt_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_bar.offset_left = 0.0
	_prompt_bar.offset_right = 0.0
	_prompt_bar.offset_top = -48.0
	_prompt_bar.offset_bottom = -48.0
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
