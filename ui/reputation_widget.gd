extends Control

## Compact reputation badge under the HUD clock. Shows the shop's rank name, a row
## of pips (one per tier, filled up to the current rank), a thin bar for progress to
## the next rank, and the point total. A small "N · paper" hint appears once an
## edition exists, so the player knows they can reopen it. Reads the Reputation and
## News autoloads and repaints on EventBus.reputation_changed with a brief brass
## flash. Purely presentational — it never changes standing itself.

const PAPER := Color(0.96, 0.91, 0.80, 0.92)
const EDGE := Color(0.79, 0.64, 0.29)  # brass
const EDGE_HOT := Color(1.0, 0.86, 0.42)  # brass flash on a change
const INK := Color(0.29, 0.22, 0.15)
const INK_SOFT := Color(0.54, 0.45, 0.35)
const PIP_ON := Color(0.79, 0.64, 0.29)
const PIP_OFF := Color(0.82, 0.72, 0.55, 0.7)

var _flash := 0.0
var _panel: StyleBoxFlat
var _bar_bg: StyleBoxFlat
var _bar_fill: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(184, 76)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = PAPER
	_panel.set_corner_radius_all(10)
	_panel.set_border_width_all(2)
	_panel.border_color = EDGE
	_panel.shadow_color = Color(0, 0, 0, 0.25)
	_panel.shadow_size = 4
	_panel.shadow_offset = Vector2(0, 2)
	_bar_bg = StyleBoxFlat.new()
	_bar_bg.bg_color = PIP_OFF
	_bar_bg.set_corner_radius_all(3)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = PIP_ON
	_bar_fill.set_corner_radius_all(3)
	EventBus.reputation_changed.connect(_on_changed)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.2, 0.0)
		queue_redraw()


func _on_changed(_points: int, _tier: int) -> void:
	_flash = 1.0
	queue_redraw()


func _draw() -> void:
	_panel.border_color = EDGE.lerp(EDGE_HOT, _flash)
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	if font == null:
		return
	var pad := 10.0

	# Rank name (left) and point total (right).
	draw_string(font, Vector2(pad, 20.0), _rank(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	draw_string(
		font,
		Vector2(-pad, 20.0),
		"%d" % _points(),
		HORIZONTAL_ALIGNMENT_RIGHT,
		size.x,
		13,
		INK_SOFT
	)

	# Tier pips.
	var count := _tier_count()
	var filled := _tier() + 1
	var r := 4.0
	var gap := 14.0
	var y := 38.0
	for i in count:
		draw_circle(Vector2(pad + r + i * gap, y), r, PIP_ON if i < filled else PIP_OFF)

	# Progress-to-next bar.
	var bx := pad
	var bw := size.x - pad * 2.0
	var by := 52.0
	var bh := 6.0
	draw_style_box(_bar_bg, Rect2(bx, by, bw, bh))
	var frac := _progress()
	if frac > 0.0:
		draw_style_box(_bar_fill, Rect2(bx, by, maxf(bw * frac, bh), bh))

	# Reread hint once a paper exists.
	if _has_paper():
		draw_string(
			font,
			Vector2(pad, 71.0),
			"N · read the paper",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			INK_SOFT
		)


# --- Reputation/News access (safe if the autoloads are absent) -------------


func _points() -> int:
	return Reputation.points if Reputation != null else 0


func _tier() -> int:
	return Reputation.tier() if Reputation != null else 0


func _tier_count() -> int:
	return Reputation.TIERS.size() if Reputation != null else 5


func _rank() -> String:
	return Reputation.tier_name() if Reputation != null else "Unknown"


func _progress() -> float:
	return Reputation.tier_progress() if Reputation != null else 0.0


func _has_paper() -> bool:
	return News != null and not News.current_edition.is_empty()
