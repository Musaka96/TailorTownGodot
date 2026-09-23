class_name SignBoard
extends Control

## Dresses a PanelContainer as a hanging shop sign: a walnut board with wood grain,
## brass-screwed cream plate with a running stitch, and two chains rising to the top of
## the screen. The board sways gently. Drawn as a backdrop child behind the panel's
## content (the panel's own stylebox becomes empty), so any existing menu layout works.
##   SignBoard.dress(panel)

const BORDER := 14.0  # walnut showing around the cream plate
const SWAY_DEG := 0.6
const SHADOW_DROP := Vector2(0, 9)
const CHAIN_AT := [0.22, 0.78]  # where the two chains meet the board, across its width

var chains := true
## false = a bare walnut fascia with a brass inlay line (for gold lettering); true = the
## cream plate that menu content sits on.
var plate := true
var _time := 0.0


## Turn `panel` into a hanging sign; returns the backdrop.
static func dress(panel: PanelContainer, with_chains := true) -> SignBoard:
	var existing := panel.get_node_or_null("SignBoard") as SignBoard
	if existing != null:
		return existing
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(BORDER + Style.S3)
	panel.add_theme_stylebox_override("panel", sb)
	var board := SignBoard.new()
	board.name = "SignBoard"
	board.chains = with_chains
	panel.add_child(board)
	panel.move_child(board, 0)
	return board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	var panel := get_parent() as Control
	if panel == null or not panel.is_visible_in_tree():
		return
	_time += delta
	if not UiScale.is_attached(panel):  # a scaled board keeps the pivot it shrinks on
		panel.pivot_offset = Vector2(panel.size.x * 0.5, 0.0)
	panel.rotation_degrees = sin(_time * 0.9) * SWAY_DEG
	queue_redraw()


func _draw() -> void:
	var panel := get_parent() as Control
	if panel == null:
		return
	# This node fills the panel's content rect; draw over the whole panel instead.
	var full := Rect2(-position, panel.size)
	if chains:
		_draw_chains(full)
	# A soft shadow on whatever is behind, so the board hangs proud of the street.
	draw_colored_polygon(
		Craft.rounded(Rect2(full.position + SHADOW_DROP, full.size).grow(2.0), 20.0), Style.SHADOW
	)
	var board := Craft.rounded(full, 18.0)
	Craft.card(self, board, Style.WALNUT, Style.BROWN, 3.0)
	_draw_grain(full)
	if chains:
		_draw_mounts(full)
	var plate_rect := full.grow(-BORDER)
	var inner := Craft.rounded(plate_rect, 10.0)
	if plate:
		draw_colored_polygon(inner, Style.CREAM)
		Craft.stitch(self, inner, Style.CREAM_DARK, 6.0)
	else:
		# The carved field the gold lettering sits in: a shade darker, with a fine inlay.
		draw_colored_polygon(inner, Style.tint(Style.SHADOW, 0.45))
		Craft.outline(
			self, Craft.rounded(plate_rect.grow(-7.0), 6.0), Style.tint(Style.BRASS, 0.6), 1.0
		)
	# A bevelled brass frame: dark foot, brass face, a lit upper edge.
	Craft.outline(self, inner, Style.RIM_DARK, 5.0)
	Craft.outline(self, inner, Style.BRASS, 3.0)
	var glint := Style.tint(Style.BRASS_LIGHT, 0.8)
	Craft.outline(self, Craft.rounded(plate_rect.grow(1.0), 11.0), glint, 1.0)
	for c in [
		plate_rect.position,
		Vector2(plate_rect.end.x, plate_rect.position.y),
		plate_rect.end,
		Vector2(plate_rect.position.x, plate_rect.end.y),
	]:
		_draw_rivet(c + (plate_rect.get_center() - c).normalized() * -2.0)


## Wood grain: long wavering lines of uneven weight, and a lit top edge.
func _draw_grain(full: Rect2) -> void:
	var y := full.position.y + 9.0
	while y < full.end.y - 6.0:
		var wob := sin(y * 0.37) * 3.0
		var grain := Color(Style.BROWN, 0.35 + 0.3 * absf(sin(y * 1.7)))
		draw_line(
			Vector2(full.position.x + 8.0, y + wob), Vector2(full.end.x - 8.0, y - wob), grain, 1.0
		)
		y += 11.0 if int(y) % 3 != 0 else 7.0
	var lit := Style.tint(Style.BRASS_LIGHT, 0.22)
	var top := full.position.y + 3.5
	draw_line(Vector2(full.position.x + 16.0, top), Vector2(full.end.x - 16.0, top), lit, 1.5)


## A domed brass screw: dark foot, brass dome, a glint, and the slot.
func _draw_rivet(at: Vector2) -> void:
	draw_circle(at + Vector2(0.5, 1.0), 5.5, Style.RIM_DARK)
	draw_circle(at, 4.5, Style.BRASS)
	draw_circle(at + Vector2(-1.3, -1.3), 1.6, Style.BRASS_LIGHT)
	draw_line(at - Vector2(2.4, -0.4), at + Vector2(2.4, -0.4), Style.WALNUT, 1.2)


## Brass mounting plates screwed to the board's top edge, each with the eye it hangs by.
func _draw_mounts(full: Rect2) -> void:
	for fx in CHAIN_AT:
		var x: float = full.position.x + full.size.x * fx
		var y := full.position.y + 4.0
		var mount := Rect2(Vector2(x - 13.0, y - 3.0), Vector2(26.0, 9.0))
		draw_colored_polygon(Craft.rounded(mount.grow(1.0), 4.0), Style.RIM_DARK)
		draw_colored_polygon(Craft.rounded(mount, 3.5), Style.BRASS)
		draw_line(
			mount.position + Vector2(3, 2), mount.position + Vector2(23, 2), Style.BRASS_LIGHT, 1.0
		)
		draw_circle(Vector2(x, y - 3.0), 5.0, Style.RIM_DARK)
		draw_circle(Vector2(x, y - 3.0), 3.4, Style.BRASS_LIGHT)


func _draw_chains(full: Rect2) -> void:
	# Well above the screen top, in this node's (possibly scaled) space.
	var top := (get_global_transform().affine_inverse() * Vector2(0.0, -40.0)).y
	for fx in CHAIN_AT:
		var x: float = full.position.x + full.size.x * fx
		var y := full.position.y + 4.0
		var link := 0
		while y > top:
			var r := Rect2(Vector2(x - 3.5, y - 12.0), Vector2(7.0, 11.0))
			if link % 2 == 0:
				draw_rect(r, Style.RIM_DARK, false, 2.0)
			else:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Style.RIM_DARK, 2.5)
			y -= 9.0
			link += 1
