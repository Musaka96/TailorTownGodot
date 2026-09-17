extends Control

## Always-on heads-up display: the interaction prompt (bottom) and what the
## player is currently carrying (top-left). Driven entirely by EventBus signals.

const MONEY_TILT := -3.0  # the purse tag hangs slightly askew

var _prompt_bar: CraftPanel
var _booked_badge: CraftPanel
var _prompt_verb: Label
var _money_panel: CraftPanel
var _money_value: Label
var _money_current := 0  # target balance
var _money_shown := 0  # what the rolling counter currently reads
var _money_started := false
var _count_tween: Tween

@onready var _prompt: Label = $Prompt
@onready var _held: Label = $Held
@onready var _money: Label = $Money


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # prompt visibility tracks menus, even paused
	_build_prompt_bar()
	_build_money_panel()
	_build_booked_badge()
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.item_picked_up.connect(func(item): _show_held(item))
	EventBus.item_taken.connect(func(item, _station): _show_held(item))
	EventBus.item_stored.connect(func(_item, _station): _show_held(null))
	EventBus.money_changed.connect(_show_money)
	_show_held(null)
	_show_money(GameState.money)
	_on_prompt_changed("")


## The purse: a cream price tag hanging on a string top-right (coin badge + amount).
## The original scene label is hidden and this is built in code, so the .tscn never
## needs regenerating. It swings when the balance changes.
func _build_money_panel() -> void:
	_money.visible = false
	_money_panel = CraftPanel.new().setup(CraftPanel.Shape.PRICE_TAG, Style.CREAM)
	_money_panel.eyelet = true
	_money_panel.string_len = 20.0
	_money_panel.stitch_color = Style.CREAM_DARK
	_money_panel.pad = Vector2(Style.S3, Style.S1 + 2)
	_money_panel.rotation_degrees = MONEY_TILT
	# Pin to the top-right corner and grow leftward to fit the content.
	_money_panel.anchor_left = 1.0
	_money_panel.anchor_right = 1.0
	_money_panel.anchor_top = 0.0
	_money_panel.anchor_bottom = 0.0
	_money_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_money_panel.grow_vertical = Control.GROW_DIRECTION_END
	_money_panel.offset_left = -20.0
	_money_panel.offset_right = -20.0
	_money_panel.offset_top = 22.0
	_money_panel.offset_bottom = 22.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	_money_panel.add_child(row)
	row.add_child(_coin_badge())
	_money_value = Label.new()
	_money_value.add_theme_font_override("font", Style.bold_font())
	_money_value.add_theme_font_size_override("font_size", 20)
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


## The tag swings on its string (and the string sways with it).
func _bump_money() -> void:
	Craft.wiggle(_money_panel, 6.0, MONEY_TILT)
	var t := create_tween()
	for s in [8.0, -6.0, 3.0, 0.0]:
		t.tween_property(_money_panel, "sway", s, 0.08)


func _flash_money(gain: bool) -> void:
	var col: Color = Style.FOREST if gain else Style.CLAY
	var t := create_tween()
	t.tween_property(_money_panel, "line", col, 0.08)
	t.tween_property(_money_panel, "line", Style.WALNUT, 0.35)


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
	lbl.offset_top = 66.0
	add_child(lbl)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "offset_top", 48.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	t.tween_property(lbl, "modulate:a", 0.0, 0.8)
	t.chain().tween_callback(lbl.queue_free)


## The interaction prompt as a brass pill ("[E] Order fabric") — the same button
## language as the menus' key hints — that pops whenever its text changes.
func _build_prompt_bar() -> void:
	_prompt.visible = false
	_prompt_bar = CraftPanel.new().setup(CraftPanel.Shape.ROUNDED, Style.BRASS)
	_prompt_bar.radius = 18.0
	_prompt_bar.pad = Vector2(Style.S3, Style.S1 + 2)
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
	_prompt_verb.add_theme_color_override("font_color", Style.WALNUT)
	_prompt_verb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_verb)
	add_child(_prompt_bar)
	_prompt_bar.visible = false


func _process(_delta: float) -> void:
	# The "E …" prompt refers to the world; hide it while a menu covers the world.
	_prompt_bar.visible = _prompt_verb.text != "" and not UI.any_menu_open()
	if _booked_badge != null:
		_booked_badge.visible = FrontDesk.booked


## A small burgundy "FULLY BOOKED" tag under the reputation patch while the sign is up.
func _build_booked_badge() -> void:
	# A plain rounded plate (no stitching or notches crossing the small lettering).
	_booked_badge = CraftPanel.new()
	_booked_badge.pad = Vector2(Style.S2 + 2, Style.S1)
	_booked_badge.radius = 9.0
	_booked_badge.setup(CraftPanel.Shape.ROUNDED, Style.BURGUNDY, Style.WALNUT)
	_booked_badge.position = Vector2(26, 206)
	var lbl := Label.new()
	lbl.text = "Fully booked"
	lbl.add_theme_font_override("font", Style.bold_font())
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Style.CHALK)
	_booked_badge.add_child(lbl)
	add_child(_booked_badge)
	_booked_badge.visible = false


func _on_prompt_changed(text: String) -> void:
	var changed := text != _prompt_verb.text
	_prompt_verb.text = text
	_prompt_bar.visible = text != ""
	if changed and text != "":
		Craft.pop_in.call_deferred(_prompt_bar, 0.8, 0.2)


func _show_held(item) -> void:
	if item == null:
		_held.text = ""
		return
	_held.text = "Carrying: %s" % _held_desc(item)


## A readable label for whatever is in hand — each carryable type reports different
## things (rolls/pieces have length, garments have type/size, a suit has quality).
func _held_desc(item) -> String:
	if item is MaterialRoll:
		return "%s  (%.1f m left)" % [_mat_name(item), item.remaining_length_m]
	if item is FabricPiece:
		return "%s  (%.1f m piece)" % [_mat_name(item), item.length_m]
	if item is GarmentPiece:
		var kind := Enums.garment_type_name(item.garment_type)
		return "%s  (%s, %s)" % [kind, Enums.size_name(item.size), _mat_name(item)]
	if item is Suit:
		return "finished suit  (Q %d%%)" % roundi(item.quality * 100.0)
	return "item"


func _mat_name(item) -> String:
	return item.material.display_name if item.material != null else "cloth"
