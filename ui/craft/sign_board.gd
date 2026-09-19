class_name SignBoard
extends Control

## Dresses a PanelContainer as a hanging shop sign: a walnut board with wood grain,
## brass-screwed cream plate with a running stitch, and two chains rising to the top of
## the screen. The board sways gently. Drawn as a backdrop child behind the panel's
## content (the panel's own stylebox becomes empty), so any existing menu layout works.
##   SignBoard.dress(panel)

const BORDER := 14.0  # walnut showing around the cream plate
const SWAY_DEG := 0.6

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
	var board := Craft.rounded(full, 18.0)
	Craft.card(self, board, Style.WALNUT, Style.BROWN, 3.0)
	# Wood grain.
	var y := full.position.y + 9.0
	var grain := Color(Style.BROWN, 0.55)
	while y < full.end.y - 6.0:
		var wob := sin(y * 0.37) * 3.0
		draw_line(
			Vector2(full.position.x + 8.0, y + wob), Vector2(full.end.x - 8.0, y - wob), grain, 1.0
		)
		y += 11.0
	var plate_rect := full.grow(-BORDER)
	var inner := Craft.rounded(plate_rect, 10.0)
	if plate:
		draw_colored_polygon(inner, Style.CREAM)
		Craft.stitch(self, inner, Style.CREAM_DARK, 6.0)
	Craft.outline(self, inner, Style.BRASS, 2.0)
	for c in [
		plate_rect.position,
		Vector2(plate_rect.end.x, plate_rect.position.y),
		plate_rect.end,
		Vector2(plate_rect.position.x, plate_rect.end.y),
	]:
		var at: Vector2 = c + (plate_rect.get_center() - c).normalized() * -2.0
		draw_circle(at, 4.0, Style.BRASS)
		draw_line(at - Vector2(2.5, 0), at + Vector2(2.5, 0), Style.WALNUT, 1.2)


func _draw_chains(full: Rect2) -> void:
	var top := -global_position.y - 40.0  # well above the screen top
	for fx in [0.22, 0.78]:
		var x: float = full.position.x + full.size.x * fx
		var y := full.position.y + 4.0
		draw_circle(Vector2(x, y), 5.0, Style.BRASS)
		var link := 0
		while y > top:
			var r := Rect2(Vector2(x - 3.5, y - 12.0), Vector2(7.0, 11.0))
			if link % 2 == 0:
				draw_rect(r, Style.RIM_DARK, false, 2.0)
			else:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Style.RIM_DARK, 2.5)
			y -= 9.0
			link += 1
