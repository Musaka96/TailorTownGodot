class_name MinigameScreen
extends Control

## The workshop chrome the craft minigames share: the scrim, the fixed WORK-skin
## panel, the title row with the job's slip pins, a swing ticket naming the piece on
## the bench, the play surface, the status line and the key prompts. Cutting and
## sewing differ only in their rules and in what they paint on that surface, so
## everything a player sees *around* the game lives here and the two screens read as
## one bench. See docs/UI_STYLE_GUIDE.md §3 (fixed frame), §4 (prompts), §5 (WORK).
##
## It also owns how a bench *celebrates* (docs/MINIGAME_JUICE.md, tier 1), so every game
## does it the same way: _perfect_beat() for each perfect stitch / stroke / stretch — a
## note that climbs a scale as the streak grows, sparks off the tool, a streak chip by the
## slip pins; _break_streak() when the run of perfects ends; _stamp_verdict() to thump
## the result onto the finished piece. _good_feedback() is the twin of _slip_feedback().

const CANVAS_MIN := Vector2(600, 260)
const PIP_SIZE := Vector2(18, 18)
const SLIP_ROCK := 1.8  # degrees the bench rocks when a slip lands
## One word for how a piece came out, best first: [quality at or above, word].
## "Flawless" means exactly that — a piece that shows as 100%. Just short of it is still
## something to be proud of, and says so.
const FLAWLESS_AT := 0.995
const FINE_AT := 0.85
const VERDICTS := [
	[FLAWLESS_AT, "Flawless"],
	[0.93, "Exquisite"],
	[FINE_AT, "Fine work"],
	[0.7, "Good enough"],
	[0.0, "Rough"],
]
const FANFARE_NOTES := [0, 4, 7, 12, 16]  # semitones: up the major chord
const FLAWLESS_HOLD := 2.2  # seconds a flawless finish lingers (others: STAMP_HOLD)
## The streak's tune: the first beats climb these notes (semitones over the base, a
## major pentatonic kept in the middle register). After that single beats go quiet and the
## streak is marked by ranks instead, so a long clean run never turns into a siren.
const STREAK_SCALE := [0, 2, 4, 7, 9]
const STREAK_SHOWN := 2  # the chip appears once a streak is this long
## Every RANK_EVERY beats the streak earns the next rank: a name on the chip, its own
## colour, a low chord and a bigger burst. Past the last rank it stays there, chiming again
## every RANK_EVERY beats.
const RANK_EVERY := 5
const RANKS := ["Steady", "In the zone", "Master's hand"]
const RANK_CHORD := [0, 4, 7]  # a plain major triad on the base note: warm, never shrill
const QUIET_SPARKS := 3  # the small puff for a beat past the tune
const STREAK_MOURNED := 4  # breaking a streak this long gets the soft falling note
const CHIP_SIZE := Vector2(150, 24)  # wide enough for the longest rank
const STAMP_HOLD := 1.3  # seconds a finished game lingers so the stamp can be read

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
var _streak := 0
var _best_streak := 0
var _juice: JuiceLayer
var _chip: Control

# --- Chrome ----------------------------------------------------------------


## Build the whole screen around `painter` (the subclass's surface painter), once.
## Both _ready() and start() call this, because a host may reach either first — a
## screen built only from _ready() silently loses everything start() sets when a
## caller starts it in the same frame it is added.
## What the player has done so far, for the tutorial's checklist to tick off live — e.g.
## {"started": true}. Each game reports what it can; the default reports nothing, and the
## tutorial treats a missing flag as not done yet.
func coach_flags() -> Dictionary:
	return {}


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
	UiScale.attach(_panel, UiScale.MENUS)
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
	_juice = JuiceLayer.new()
	_canvas.add_child(_juice)  # over the play surface, in its coordinates

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", Style.bold_font())
	_status_lbl.add_theme_font_size_override("font_size", Style.T_BODY)
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
	var head := TitleBlock.make(screen_title, "The bench", Style.ACC_WORK)
	# The streak chip keeps its place even when empty, so the header never jumps.
	_chip = Control.new()
	_chip.custom_minimum_size = CHIP_SIZE
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.draw.connect(_paint_chip)
	head.right.add_child(_chip)
	_slips_lbl = Label.new()
	_slips_lbl.add_theme_font_override("font", Style.font_bold())
	_slips_lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_slips_lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	_slips_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.right.add_child(_slips_lbl)
	_pips_box = HBoxContainer.new()
	_pips_box.add_theme_constant_override("separation", Style.S1 + 2)
	_pips_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.right.add_child(_pips_box)
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
	_job_lbl.add_theme_font_size_override("font_size", Style.T_BODY)
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
	_reset_juice()  # pins are laid out once a run, so this is "a new run starts"


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
	_break_streak()  # a slip always ends the run of perfects


# --- Celebration -----------------------------------------------------------


func _reset_juice() -> void:
	_streak = 0
	_best_streak = 0
	if _juice != null:
		_juice.reset()
	if _chip != null:
		_chip.queue_redraw()


## The twin of _slip_feedback(): the bench takes a little breath. `level` 0..1.
func _good_feedback(level := 0.5) -> void:
	Craft.bump(_panel, lerpf(1.004, 1.014, clampf(level, 0.0, 1.0)))


## One perfect stitch / stroke / stretch of line, made at `at` (play-surface pixels).
## The first few climb a short tune; after that a beat is just a small puff of sparks,
## and every RANK_EVERY beats the streak moves up a rank (see _rank_up).
func _perfect_beat(at: Vector2, col: Color = Style.BRASS_LIGHT) -> void:
	_streak += 1
	_best_streak = maxi(_best_streak, _streak)
	if _streak % RANK_EVERY == 0:
		_rank_up(at)
	elif _streak <= STREAK_SCALE.size():
		var pitch := pow(2.0, float(STREAK_SCALE[_streak - 1]) / 12.0)
		Sfx.play("juice_note", -10.0, pitch, pitch)
		if _juice != null:
			_juice.burst(at, col, 5)
	elif _juice != null:
		_juice.burst(at, col, QUIET_SPARKS)
	if _chip != null:
		_chip.queue_redraw()
		if _streak == STREAK_SHOWN:
			Craft.bump(_chip, 1.12)


## Which rank a streak of `n` holds: -1 below the first, else an index into RANKS.
func _rank_of(n: int) -> int:
	return mini(floori(float(n) / RANK_EVERY), RANKS.size()) - 1


## A new rank: the chip changes, the bench breathes, a low chord and a proper burst.
func _rank_up(at: Vector2) -> void:
	for i in RANK_CHORD.size():
		var pitch := pow(2.0, float(RANK_CHORD[i]) / 12.0)
		get_tree().create_timer(0.07 * i).timeout.connect(
			func() -> void: Sfx.play("juice_note", -8.0, pitch, pitch)
		)
	_good_feedback(1.0)
	if _juice != null:
		_juice.burst(at, _rank_color(_rank_of(_streak)), 14)
	if _chip != null:
		Craft.bump(_chip, 1.2)


func _rank_color(rank: int) -> Color:
	match rank:
		0:
			return Style.BRASS
		1:
			return Style.FOREST
	return Style.BRASS_LIGHT


## The run of perfects ended. Quiet on purpose: losing the tune is the penalty.
func _break_streak() -> void:
	if _streak >= STREAK_MOURNED:
		Sfx.play("juice_drop", -12.0)
	_streak = 0
	if _chip != null:
		_chip.queue_redraw()


func _verdict(quality: float) -> String:
	for v: Array in VERDICTS:
		if quality >= float(v[0]):
			return v[1]
	return VERDICTS[VERDICTS.size() - 1][1]


## Thump the result onto the finished piece: the word for `quality`, or `word` if the
## game has its own ("Perfect cup"). The better the work, the bigger the moment: plain ink
## below fine work, a ring of thread snippets for fine work and better, and for a truly
## flawless piece — 100%, nothing less — gold foil, rays, confetti and a little fanfare.
func _stamp_verdict(quality: float, word := "") -> void:
	if _juice == null:
		return
	var text := word if word != "" else _verdict(quality)
	var fine: bool = quality >= FINE_AT
	Sfx.play("juice_stamp", -3.0, 0.95, 1.05)
	if quality >= FLAWLESS_AT:
		_juice.stamp(text, Style.RIM_DARK, JuiceLayer.Fanfare.GRAND)
		Craft.wiggle(_panel, 1.4)
		Craft.bump(_panel, 1.03)
		_fanfare()
		return
	var weight: int = JuiceLayer.Fanfare.FINE if fine else JuiceLayer.Fanfare.PLAIN
	_juice.stamp(text, Style.FOREST if fine else Style.WALNUT, weight)
	Craft.wiggle(_panel, 0.7)
	if fine:
		_good_feedback(1.0)
		Sfx.play("juice_top", -10.0, 1.0, 1.0)


## How long a finished game lingers so the stamp can be enjoyed.
func _stamp_hold(quality: float) -> float:
	return FLAWLESS_HOLD if quality >= FLAWLESS_AT else STAMP_HOLD


## A quick run up the chord, ending on the shimmer — only ever for a flawless piece.
func _fanfare() -> void:
	for i in FANFARE_NOTES.size():
		var pitch := pow(2.0, float(FANFARE_NOTES[i]) / 12.0)
		var last := i == FANFARE_NOTES.size() - 1
		var key := "juice_top" if last else "juice_note"
		get_tree().create_timer(0.1 + 0.09 * i).timeout.connect(
			func() -> void: Sfx.play(key, -6.0, pitch, pitch)
		)


func _paint_chip() -> void:
	if _streak < STREAK_SHOWN:
		return
	var rank := _rank_of(_streak)
	var fill := Style.CARD
	var ink := Style.INK
	if rank >= 0:
		fill = _rank_color(rank)
		ink = Style.CHALK if rank == 1 else Style.WALNUT
	var poly := Craft.rounded(Rect2(Vector2.ZERO, _chip.size), 11.0)
	Craft.card(_chip, poly, fill, Style.WALNUT, 2.0)
	Craft.stitch(_chip, poly, Style.tint(ink, 0.45), 3.5, 1.0)
	var font := Style.font_bold()
	var word := "Perfect" if rank < 0 else str(RANKS[rank])
	var text := "×%d %s" % [_streak, word]
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO).x
	var left := (_chip.size.x - text_w) * 0.5
	if rank >= RANKS.size() - 1:
		left += 7.0  # room for the star
		_chip_star(Vector2(left - 9.0, _chip.size.y * 0.5), ink)
	var base := Vector2(left, _chip.size.y * 0.5 + 4.5)
	_chip.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO, ink)


func _chip_star(at: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := 6.0 if i % 2 == 0 else 2.7
		pts.append(at + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * r)
	_chip.draw_colored_polygon(pts, col)


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
