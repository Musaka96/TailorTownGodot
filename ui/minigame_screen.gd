class_name MinigameScreen
extends Control

## The workshop chrome the craft minigames share: the scrim, the fixed WORK-skin
## panel, the title row with the job's slip pins, a swing ticket naming the piece on
## the bench, the play surface, the status line and the key prompts. Cutting and
## sewing differ only in their rules and in what they paint on that surface, so
## everything a player sees *around* the game lives here and the two screens read as
## one bench. See docs/UI_STYLE_GUIDE.md §3 (fixed frame), §4 (prompts), §5 (WORK).

const CANVAS_MIN := Vector2(600, 260)
const PIP_SIZE := Vector2(18, 18)
const SLIP_ROCK := 1.8  # degrees the bench rocks when a slip lands

var _max_mistakes := 3
var _mistakes := 0
var _built := false
var _focused := false  # this run drank from the coffee: wider bands, steadier cloth
var _panel: PanelContainer
var _canvas: MinigameCanvas
var _ticket: CraftPanel
var _job_lbl: Label
var _status_lbl: Label
var _slips_lbl: Label
var _pips_box: HBoxContainer
var _hint_slot: VBoxContainer
var _player: AudioStreamPlayer

# --- Chrome ----------------------------------------------------------------


## Build the whole screen around `painter` (the subclass's surface painter), once.
## Both _ready() and start() call this, because a host may reach either first — a
## screen built only from _ready() silently loses everything start() sets when a
## caller starts it in the same frame it is added.
func _ensure_chrome(screen_title: String, painter: Callable, frame := Style.FRAME_WIDE) -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_load_assets()
	add_child(Style.scrim())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = frame
	center.add_child(_panel)
	Style.apply_skin(_panel, Style.MenuSkin.WORK)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(box)
	box.add_child(_build_head(screen_title))
	box.add_child(_build_ticket())

	_canvas = MinigameCanvas.new()
	_canvas.custom_minimum_size = CANVAS_MIN
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.painter = painter
	box.add_child(_canvas)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", Style.bold_font())
	_status_lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(_status_lbl)

	_hint_slot = VBoxContainer.new()
	box.add_child(_hint_slot)


## Overridden by the subclass to load its sounds and optional art. Called once, from
## _ensure_chrome(), so nothing has to guess when the screen came into being.
func _load_assets() -> void:
	pass


## Title top-left (§5 keeps the top-right for the skin's tape), slips beside it as a
## word plus a row of pins — the count never rides on colour alone (§2).
func _build_head(screen_title: String) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Style.S2)
	head.add_child(Style.title_label(screen_title, Style.ACC_WORK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_slips_lbl = Label.new()
	_slips_lbl.add_theme_font_override("font", Style.bold_font())
	_slips_lbl.add_theme_font_size_override("font_size", 15)
	_slips_lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	_slips_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_slips_lbl)
	_pips_box = HBoxContainer.new()
	_pips_box.add_theme_constant_override("separation", Style.S1 + 2)
	_pips_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_pips_box)
	return head


## The job on a swing ticket, the way a real piece carries one.
func _build_ticket() -> Control:
	var row := HBoxContainer.new()
	_ticket = CraftPanel.new()
	_ticket.pad = Vector2(Style.S2, Style.S1)
	_ticket.eyelet = true
	_ticket.setup(CraftPanel.Shape.PRICE_TAG, Style.CARD, Style.WALNUT)
	_ticket.stitch_color = Style.tint(Style.WALNUT, 0.3)
	_ticket.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_job_lbl = Label.new()
	_job_lbl.add_theme_font_override("font", Style.bold_font())
	_job_lbl.add_theme_font_size_override("font_size", 16)
	_job_lbl.add_theme_color_override("font_color", Style.INK)
	_ticket.add_child(_job_lbl)
	row.add_child(_ticket)
	return row


## What is on the bench, written on the ticket.
func _set_job(text: String) -> void:
	if _job_lbl != null:
		_job_lbl.text = text


func _set_status(text: String, col: Color) -> void:
	if _status_lbl == null:
		return
	_status_lbl.text = text
	_status_lbl.add_theme_color_override("font_color", col)


## The run's key prompts (they change with the owned upgrades).
func _set_hints(pairs: Array) -> void:
	if _hint_slot == null:
		return
	for child in _hint_slot.get_children():
		_hint_slot.remove_child(child)
		child.queue_free()
	_hint_slot.add_child(Style.hint_bar(pairs))


## One pin per allowed slip, built once a run — after that they only repaint, so the
## header never resizes mid-game.
func _build_pips() -> void:
	if _pips_box == null:
		return
	for child in _pips_box.get_children():
		_pips_box.remove_child(child)
		child.queue_free()
	for i in _max_mistakes:
		var pip := Control.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.draw.connect(_paint_pip.bind(pip, i))
		_pips_box.add_child(pip)
	_refresh_pips()


func _refresh_pips() -> void:
	if _pips_box == null:
		return
	for child in _pips_box.get_children():
		child.queue_redraw()
	if _slips_lbl != null:
		_slips_lbl.text = "Slips %d/%d" % [_mistakes, _max_mistakes]


## A spent slip is a pin stuck in the board; the ones left are empty holes.
func _paint_pip(pip: Control, index: int) -> void:
	var at := pip.size * 0.5
	if index < _mistakes:
		Craft.pin(pip, at, Style.CLAY, 7.0)
	else:
		pip.draw_circle(at, 6.0, Style.tint(Style.WALNUT, 0.12))
		pip.draw_circle(at, 6.0, Style.tint(Style.WALNUT, 0.45), false, 1.5, true)


## Rock the bench — felt, not read, so it never stands in for the pin and the word.
func _slip_feedback() -> void:
	Craft.wiggle(_panel, SLIP_ROCK)
	_refresh_pips()


## Spend one job of coffee focus on this run, if there is any. Returns how much wider the
## game's timing / accuracy bands should be (1.0 when not focused).
func _take_focus() -> float:
	_focused = GameState.focus > 0
	if not _focused:
		return 1.0
	GameState.focus -= 1
	return Config.data.focus_band if Config.data != null else 1.2


func _focus_hint(pairs: Array) -> Array:
	if _focused:
		pairs.append(["Coffee", "Steady hands"])
	return pairs


func _show_panel() -> void:
	Craft.pop_in(_panel, 0.94, 0.22)


func _repaint() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


# --- Surface helpers (for the subclass painters) ---------------------------


## An X, so a slip stays visible where it happened.
func _paint_x(c: Control, pos: Vector2, col: Color, r: float) -> void:
	c.draw_line(pos - Vector2(r, r), pos + Vector2(r, r), col, 3.0)
	c.draw_line(pos - Vector2(r, -r), pos + Vector2(r, -r), col, 3.0)


## A dashed line — chalk reads as short strokes, never a solid rule.
func _dashed(c: Control, a: Vector2, b: Vector2, col: Color, width := 2.5) -> void:
	var d := a.distance_to(b)
	if d <= 0.001:
		return
	var dir := (b - a) / d
	var t := 0.0
	while t < d:
		c.draw_line(a + dir * t, a + dir * minf(t + 8.0, d), col, width)
		t += 14.0


# --- Sound & art -----------------------------------------------------------


func _play(stream: AudioStream, volume_scale: float) -> void:
	if stream == null or _player == null:
		return
	_player.stream = stream
	_player.volume_db = linear_to_db(clampf(volume_scale, 0.01, 1.0))
	_player.play()


func _load(sound_name: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % sound_name
	return load(path) if ResourceLoader.exists(path) else null


## Painted art for a surface, if it has been dropped in. Every surface paints its own
## fallback from the palette, so a missing file only costs the texture.
func _load_art(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null
