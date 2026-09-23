extends Control

## The mirror's suit builder. A side panel (keeps the customer visible) where you
## design each part of the suit. The camera holds one portrait of the customer, head to
## shin, the whole time: every part stays in view while you work. E confirms the design.

enum Row { PART, FABRIC, COLOR, PATTERN, STYLE, TROUSERS }
const KICKER := "Fitting room"
# The mark for "in fashion" — the same glyph on the header line and on the rows, so the
# thing you're told to look for is the thing you see when you land on it.
const TREND_MARK := "★"
const ROW_NAME := {
	Row.PART: "Part",
	Row.FABRIC: "Fabric",
	Row.COLOR: "Colour",
	Row.PATTERN: "Pattern",
	Row.STYLE: "Style",
	Row.TROUSERS: "Trousers",
}
# Every part of the design, in display order. While the trousers are linked to the jacket
# (the usual suit) the tabs show only the suit and the shirt: see _parts().
const PARTS := [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]
const LINKED_PARTS := [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT]
# The design fields the linked trousers copy from the jacket (the cut stays their own).
const LINK_KEYS := ["fabric", "color", "pattern"]
# The design fields a row edits (the tutorial checks them against its recipe).
const ROW_KEY := {Row.FABRIC: "fabric", Row.COLOR: "color", Row.PATTERN: "pattern"}
# Camera framing. The subject is placed EXACTLY at the centre of the free screen area
# between the fitting notepad and the panel, solved from the live camera FOV, viewport
# aspect and panel width — so it can't drift on other resolutions.
const PITCH_DEG := 8.0  # camera looks slightly down at the subject
## The one shot, for every tab and for the customer's answer: (centre height, visible
## screen-height span), both as fractions of the customer's height (measured from their
## meshes, so every body frames the same). Air above the head down to mid-shin.
const PORTRAIT := Vector2(0.65, 1.37)
const DEFAULT_BODY_HEIGHT := 2.25
const HEAD_AT := 0.9  # the bubble points at this fraction of the customer's height
## After an ask, E / a click does nothing for this long, so a double tap can't sell.
const ASK_LOCK := 0.5
const PAD_GAP := 16.0  # between the fitting notepad and the band the customer is framed in
const CAMERA_BLOCK_MASK := 1  # world geometry (walls, furniture)
const CAMERA_WALL_MARGIN := 0.3
# Yaw offsets (degrees) tried in order when the straight-on view is blocked.
const ORBIT_TRIES := [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 80.0, -80.0]
# Data fallbacks when there's no seated customer (not UI styling).
const _SKIN_FALLBACK := Color(0.87, 0.72, 0.60)  # ui-check-ignore: skin data
const _HAIR_FALLBACK := Color(0.14, 0.11, 0.09)  # ui-check-ignore: hair data

var _mirror = null
var _actor = null
var _customer = null
var _pref = null  # CustomerPreference when fitting a real customer, else null
var _awaiting := false  # customer loved it; next E finalises the order
var _ask_lock := 0.0  # > 0 just after an ask: E and clicks wait (see ASK_LOCK)
var _linked := true  # the trousers follow the jacket's cloth (one "Suit" tab)
var _bubble: ReactionBubble  # the customer's answer, up until the design changes
var _rig = null
var _part_sel := 0  # index into _parts()
var _row := 0
var _status := ""
var _design := {}  # GarmentType -> { fabric, color, pattern, style_idx }
var _swatch: MaterialSwatch
var _name_label: Label
var _sub_label: Label
var _brief_label: Label
var _trend_label: Label
var _hint_bar: HBoxContainer
var _total_slot: VBoxContainer
var _scroll: ScrollContainer
var _stock_badge: HBoxContainer
var _stock_dot: Panel
var _stock_label: Label
var _decor_built := false
var _head: TitleBlock
var _badges: ClientBadges
var _height := DEFAULT_BODY_HEIGHT  # customer's measured height, cached on open
var _pad: FittingNotepad

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _preview: HBoxContainer = $Panel/Margin/Box/Preview
@onready var _rows: VBoxContainer = $Panel/Margin/Box/Rows
@onready var _hint: Label = $Panel/Margin/Box/Hint


func _ready() -> void:
	_build_preview()
	# The fitting notes: the builder's own child (not the panel's), bottom-left of the screen.
	_pad = FittingNotepad.new()
	add_child(_pad)


func _process(delta: float) -> void:
	# Re-solve every frame: the panel's layout settles after opening and the window can
	# be resized, and the target must track both to stay exactly centred.
	if visible:
		_ask_lock = maxf(_ask_lock - delta, 0.0)
		_update_camera()


func open(mirror, actor) -> void:
	_mirror = mirror
	_actor = actor
	_customer = mirror.customer
	_pref = _customer.get("preference") if _customer != null else null
	_awaiting = false
	_ask_lock = 0.0
	_linked = true
	_rig = get_tree().get_first_node_in_group("camera_rig")
	_part_sel = 0  # the Suit tab
	_row = 0
	_status = ""
	_design = {}
	for t in PARTS:
		_design[t] = {
			"fabric": _available_fabrics(t)[0],
			"color": MaterialFactory.colors_for(t)[0],
			"pattern": Enums.patterns_for(t)[0],
			"style_idx": 0,
		}
	# Hide the player avatar so it doesn't block the view of the customer being fitted.
	if _actor != null:
		_actor.visible = false
	GameState.input_locked = true
	visible = true
	# The fitting is framed from inside the shop: no see-through or missing walls.
	WallCutaway.hold_solid(true)
	RoofManager.hold_walls(true)
	_style()
	_sync_pants()
	_apply_to_customer()
	_height = _body_height() if _customer != null else DEFAULT_BODY_HEIGHT
	_update_camera()
	if _pref != null:
		_pad.show_for(_pref, _she())
		UI.key_pills_hidden = true
	else:
		_pad.hide_pad()
	_refresh()


func close() -> void:
	_end_reaction()
	_pad.hide_pad()
	UI.key_pills_hidden = false
	WallCutaway.hold_solid(false)
	RoofManager.hold_walls(false)
	visible = false
	GameState.input_locked = false
	if _actor != null:
		_actor.visible = true
	if _rig != null:
		_rig.unfocus()
	if _customer != null and _customer.has_method("react"):
		_customer.react(Customer.REACT_NEUTRAL)
	_mirror = null


func _build_preview() -> void:
	_swatch = MaterialSwatch.new()
	_swatch.swatch_size = 96
	_preview.add_child(_swatch)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview.add_child(info)
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", Style.font_medium())
	_name_label.add_theme_font_size_override("font_size", Style.T_NAME)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_name_label)
	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.max_lines_visible = 2
	info.add_child(_sub_label)
	# A small "do I already have this cloth?" badge (dot + word) under the sub-line.
	_stock_badge = HBoxContainer.new()
	_stock_badge.add_theme_constant_override("separation", Style.S1 + 2)
	_stock_dot = Panel.new()
	_stock_dot.custom_minimum_size = Vector2(12, 12)
	_stock_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stock_badge.add_child(_stock_dot)
	_stock_label = Label.new()
	_stock_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_stock_badge.add_child(_stock_label)
	info.add_child(_stock_badge)


func _style() -> void:
	# Fitting-room skin (arched, brass). Side panel — the customer stays visible.
	_panel.custom_minimum_size = Vector2(440, 560)
	Style.apply_skin(_panel, Style.MenuSkin.MIRROR)
	_preview.add_theme_constant_override("separation", Style.S3)
	_name_label.add_theme_color_override("font_color", Style.INK)
	_sub_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)
	_build_decor_once()


## The scene Hint label is retired for an informational brief/quote line plus a
## rebuilt key-cap bar (the keys change with mode/debug). Skin applied in _style().
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	_hint.visible = false
	var box := _hint.get_parent()
	_head = TitleBlock.adopt(_title, KICKER, Style.ACC_MIRROR)
	_badges = ClientBadges.make(null)
	_badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.meta.add_child(_badges)
	_brief_label = Label.new()
	_brief_label.add_theme_font_override("font", Style.font_body())
	_brief_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_brief_label.add_theme_color_override("font_color", Style.INK)
	_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_brief_label)
	box.move_child(_brief_label, _head.get_index() + 1)
	# Under the brief: what the paper says is in fashion, marked with the same star the
	# rows wear, so you know what to hunt for instead of cycling every fabric blind.
	_trend_label = Label.new()
	_trend_label.add_theme_font_override("font", Style.font_bold())
	_trend_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_trend_label.add_theme_color_override("font_color", Style.BRASS)
	_trend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_trend_label)
	box.move_child(_trend_label, _brief_label.get_index() + 1)
	# The panel is the one fixed thing (docked right, full height): the rows fill what is
	# left and scroll, so the quote and the key prompts stay pinned to the bottom and no
	# content — a long cloth name, an extra badge line — can push the panel around.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, Style.S1 + 2)
	var at := _rows.get_index()
	box.remove_child(_rows)
	box.add_child(_scroll)
	box.move_child(_scroll, at)
	_scroll.add_child(pad)
	pad.add_child(_rows)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total_slot = VBoxContainer.new()
	box.add_child(_total_slot)
	_hint_bar = HBoxContainer.new()
	box.add_child(_hint_bar)


# --- Tutorial hooks ----------------------------------------------------------


## The part-by-part design being edited (GarmentType -> {fabric, color, pattern, ...}).
func current_design() -> Dictionary:
	return _design


## Screen areas the tutorial must keep clear: the customer, framed between the strip the
## tutorial reserves on the left and the panel, and the fitting notepad.
func tutorial_busy_rects() -> Array[Rect2]:
	var vp := get_viewport_rect().size
	var left := _left_reserve()
	var out: Array[Rect2] = [Rect2(left, 0, _panel.get_global_rect().position.x - left, vp.y)]
	if _pad != null and _pad.visible:
		out.append(_pad.get_global_rect())
	return out


## The tutorial's coach mark (see Tutorial._update_pointers): the first part, in panel
## order, not yet made to the recipe — the Part row until that part is shown, then its
## first wrong row — with the value to pick. {} once it all matches (Tutorial then points
## at E to confirm).
func tutorial_coach(goal: Dictionary) -> Dictionary:
	if str(goal.get("step", "")) != "design":
		return {}
	var recipe: Dictionary = goal.get("recipe", {})
	for t: int in PARTS:
		var want: Dictionary = recipe.get(t, {})
		var wrong := _first_wrong_row(t, want)
		if wrong < 0:
			continue
		if _type() != t:
			return _coach_tab(t)
		return _coach_row(wrong, _field_name(wrong, int(want[ROW_KEY[wrong]])))
	return {}


## The first design row of part `t` that differs from `want`, or -1 if it all matches.
func _first_wrong_row(t: int, want: Dictionary) -> int:
	if want.is_empty():
		return -1
	for row: int in [Row.FABRIC, Row.COLOR, Row.PATTERN]:
		var k: String = ROW_KEY[row]
		if int(_design[t][k]) != int(want.get(k, -1)):
			return row
	return -1


## W/S to reach the part tabs, then A/D across to the tab for part `t` (linked trousers
## live on the Suit tab).
func _coach_tab(t: int) -> Dictionary:
	var at := _parts().find(t)
	if at < 0:
		at = _parts().find(Enums.GarmentType.JACKET)
	for child in _rows.get_children():
		var tabs := child as PartTabs
		if tabs == null or tabs.is_queued_for_deletion():
			continue
		var on_tabs: bool = _active_rows()[_row] == Row.PART
		var nm := _part_name(int(_parts()[at]))
		var text := ("A/D: pick %s" % nm) if on_tabs else "W/S: go to the tabs"
		return {"rect": tabs.tab_rect(at), "text": text, "beside": true}
	return {}


## The parts already made to the tutorial's recipe — each earns a tick on its tab.
func _parts_on_target() -> Array:
	var out: Array = []
	if Tutorial == null:
		return out
	for t: int in PARTS:
		var want: Dictionary = Tutorial.design_target(t)
		if not want.is_empty() and _first_wrong_row(t, want) < 0:
			out.append(t)
	return out


## W/S to reach `row`, then A/D to set it to `value`.
func _coach_row(row: int, value: String) -> Dictionary:
	var i := _active_rows().find(row)
	var n := 0
	for child in _rows.get_children():
		if child.is_queued_for_deletion():
			continue
		if n == i:
			var text := ("A/D: pick %s" % value) if _row == i else ("W/S: go to %s" % ROW_NAME[row])
			return {"rect": (child as Control).get_global_rect(), "text": text, "beside": true}
		n += 1
	return {}


func _field_name(row: int, value: int) -> String:
	match row:
		Row.FABRIC:
			return Enums.fabric_name(value)
		Row.COLOR:
			return MaterialFactory.color_name(value)
		Row.TROUSERS:
			return _link_text(value != 0)
	return Enums.pattern_name(value)


## Whether `row` already matches the tutorial's recipe (a Part row: the whole part does).
func _row_on_target(row: int) -> bool:
	if Tutorial == null:
		return false
	var want: Dictionary = Tutorial.design_target(_type())
	if want.is_empty():
		return false
	if row == Row.PART:
		return _first_wrong_row(_type(), want) < 0
	if not ROW_KEY.has(row):
		return false
	var k: String = ROW_KEY[row]
	return int(_cfg()[k]) == int(want.get(k, -1))


# --- What's in fashion -------------------------------------------------------


## The running trend as {fabric, pattern} enum values, -1 where the paper named none.
func _trend() -> Dictionary:
	var ev: NewsEvent = News.current_fashion if News != null else null
	if ev == null:
		return {"fabric": -1, "pattern": -1}
	return {"fabric": ev.fashion_fabric, "pattern": ev.fashion_pattern}


## Whether `row`'s current value is the one the paper says is in fashion. Only the
## Fabric and Pattern rows can be: the trend never names a colour or a cut.
func _in_style(row: int) -> bool:
	if not (row == Row.FABRIC or row == Row.PATTERN):
		return false
	var want: int = _trend()[ROW_KEY[row]]
	return want >= 0 and int(_cfg()[ROW_KEY[row]]) == want


## The header's fashion line — "★ In style: Pinstripe or Tweed (+8 standing)", and
## "★ In style — this suit follows it" once any part does. "" when nothing is in fashion.
func _trend_text() -> String:
	var t := _trend()
	var bits: Array[String] = []
	if int(t["pattern"]) >= 0:
		bits.append(Enums.pattern_name(int(t["pattern"])))
	if int(t["fabric"]) >= 0:
		bits.append(Enums.fabric_name(int(t["fabric"])))
	if bits.is_empty():
		return ""
	var bonus: int = News.current_fashion.fashion_bonus
	var tail := " — this suit follows it" if News.fashion_matches(_design) else ""
	return "%s In style: %s (+%d standing)%s" % [TREND_MARK, " or ".join(bits), bonus, tail]


## Width kept free at the left edge (the tutorial's goal tag, then the fitting notepad and
## a gap past it), so the customer is centred in the space that is actually visible. The
## pad places itself from Tutorial.side_reserve(), never from this.
func _left_reserve() -> float:
	var side: float = Tutorial.side_reserve() if Tutorial != null else 0.0
	if _pad != null and _pad.visible:
		var pad_w := FittingNotepad.WIDTH * UiScale.target_scale(_pad).x
		side += FittingNotepad.EDGE + pad_w + PAD_GAP
	return side


# --- State -----------------------------------------------------------------


## The parts with a tab of their own: the suit and the shirt while the trousers are linked
## to the jacket, all three once they have their own cloth.
func _parts() -> Array:
	return LINKED_PARTS if _linked else PARTS


func _type() -> int:
	return _parts()[clampi(_part_sel, 0, _parts().size() - 1)]


## A part's name on the page: the jacket is "Suit" while the trousers come with it.
func _part_name(t: int) -> String:
	if _linked and (t == Enums.GarmentType.JACKET or t == Enums.GarmentType.PANTS):
		return "Suit"
	return Enums.garment_type_name(t)


func _link_text(linked: bool) -> String:
	return "Match the jacket" if linked else "Own choice"


## Linked trousers take the jacket's cloth, colour and pattern (the cut stays their own).
func _sync_pants() -> void:
	if not _linked or _design.is_empty():
		return
	for k: String in LINK_KEYS:
		_design[Enums.GarmentType.PANTS][k] = _design[Enums.GarmentType.JACKET][k]


func _cfg() -> Dictionary:
	return _design[_type()]


func _active_rows() -> Array:
	if _type() == Enums.GarmentType.JACKET:
		return [Row.PART, Row.FABRIC, Row.COLOR, Row.PATTERN, Row.STYLE, Row.TROUSERS]
	return [Row.PART, Row.FABRIC, Row.COLOR, Row.PATTERN, Row.STYLE]


func _material() -> MaterialType:
	var c := _cfg()
	return MaterialFactory.make(c["fabric"], c["pattern"], c["color"], 1.0)


func _value_text(row: int) -> String:
	if row == Row.PART:
		return _part_name(_type())
	if row == Row.TROUSERS:
		return _link_text(_linked)
	var c := _cfg()
	if row == Row.FABRIC:
		return Enums.fabric_name(c["fabric"])
	if row == Row.COLOR:
		return MaterialFactory.color_name(c["color"])
	if row == Row.PATTERN:
		return Enums.pattern_name(c["pattern"])
	return Enums.styles_for(_type())[c["style_idx"]]


# --- Camera ----------------------------------------------------------------


func _update_camera() -> void:
	if _rig == null or _customer == null or not is_instance_valid(_customer):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var front: Vector3 = _customer.facing()
	front.y = 0.0
	if front.length() < 0.01:
		return
	front = front.normalized()
	var base: Vector3 = _customer.global_position
	var span := _height * PORTRAIT.y
	var subject := base + Vector3(0.0, _height * PORTRAIT.x, 0.0)
	# Prefer straight-on; if a wall is in the way, orbit to the nearest clear angle.
	var pose := _frame_pose(cam, subject, front, span)
	for deg: float in ORBIT_TRIES:
		var tryp := _frame_pose(cam, subject, front.rotated(Vector3.UP, deg_to_rad(deg)), span)
		if _blocked_at(subject, tryp.origin) < 0.0:
			pose = tryp
			break
	var hit := _blocked_at(subject, pose.origin)
	if hit >= 0.0:
		# Nowhere clear: slide in along the same line (subject stays on its spot).
		var dist := subject.distance_to(pose.origin)
		var keep := maxf(hit - CAMERA_WALL_MARGIN, dist * 0.5) / dist
		pose.origin = subject + (pose.origin - subject) * keep
	_rig.focus(pose.origin, pose.origin - pose.basis.z)


## Camera pose that projects `subject` onto the centre of the free screen area (left of
## the panel, vertically centred) with `span` metres of world height visible at the
## subject's depth. Solved in camera space from the real FOV/aspect, so it is exact.
func _frame_pose(cam: Camera3D, subject: Vector3, front: Vector3, span: float) -> Transform3D:
	var vp := get_viewport_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var tan_half := tan(deg_to_rad(cam.fov) * 0.5)
	var tan_v := tan_half if cam.keep_aspect == Camera3D.KEEP_HEIGHT else tan_half / aspect
	var tan_h := tan_v * aspect
	# Free area is [left reserve, panel_left]; its centre in NDC x is left + right - 1
	# (both as fractions of the width).
	var right := clampf(_panel.get_global_rect().position.x / maxf(vp.x, 1.0), 0.3, 1.0)
	var left := clampf(_left_reserve() / maxf(vp.x, 1.0), 0.0, right - 0.2)
	var ndc := Vector2(left + right - 1.0, 0.0)
	var pitch := deg_to_rad(PITCH_DEG)
	var dir := (-front * cos(pitch) + Vector3.DOWN * sin(pitch)).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP)
	var depth := span / (2.0 * tan_v)
	var ray := Vector3(ndc.x * tan_h, ndc.y * tan_v, -1.0) * depth
	return Transform3D(basis, subject - basis * ray)


## Distance from `subject` to the first wall/prop on the way to `eye`, or -1 if the
## line is clear. The customer's own collision is ignored.
func _blocked_at(subject: Vector3, eye: Vector3) -> float:
	var space := get_viewport().find_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(subject, eye, CAMERA_BLOCK_MASK)
	var skip: Array[RID] = []
	for body in _customer.find_children("*", "CollisionObject3D", true, false):
		skip.append((body as CollisionObject3D).get_rid())
	query.exclude = skip
	var hit := space.intersect_ray(query)
	return -1.0 if hit.is_empty() else subject.distance_to(hit["position"])


## The customer's height from their visible meshes (feet to top of hair), so the
## framing adapts to different heads/hair. Falls back to the stock rig's height.
func _body_height() -> float:
	var base_y: float = _customer.global_position.y
	var top := base_y
	for node in _customer.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree():
			top = maxf(top, (mesh.global_transform * mesh.get_aabb()).end.y)
	var h := top - base_y
	return h if h > 0.5 and h < 6.0 else DEFAULT_BODY_HEIGHT


# --- Rendering -------------------------------------------------------------


func _refresh() -> void:
	_title.text = _pref.display_name if _pref != null else "Suit Builder"
	_badges.show_for(_pref)
	var mat := _material()
	_swatch.setup(mat, mat.roll_length_m)
	_name_label.text = mat.display_name
	var cut: String = Enums.styles_for(_type())[_cfg()["style_idx"]]
	_sub_label.text = "%s  ·  %s" % [mat.summary(), cut]
	if _pref != null:
		# Live price readout: cloth + craft = quote, against the customer's budget.
		var q := Pricing.quote_breakdown(_design)
		var over: bool = int(q["total"]) > _pref.budget
		var rush := ""
		if _pref.rush:
			rush = "  + rush $%d" % _rush_extra(int(q["total"]))
		# The brief and the verdict are on the fitting notepad now; the panel keeps the quote.
		_brief_label.visible = false
		var working := "Cloth $%d + Craft $%d%s" % [q["cloth"], q["craft"], rush]
		_show_total(working, int(q["total"]), over)
	else:
		_brief_label.visible = true
		_brief_label.text = _status.strip_edges()
		_clear_total()
	_trend_label.text = _trend_text()
	_trend_label.visible = _trend_label.text != ""
	_update_stock()
	_rebuild_hint_bar()

	var rows := _active_rows()
	_row = clampi(_row, 0, rows.size() - 1)
	for child in _rows.get_children():
		_rows.remove_child(child)  # gone now — old + new rows together would jolt the layout
		child.queue_free()
	for i in rows.size():
		_rows.add_child(_make_row(rows[i], i == _row, i))
	_wire_total()
	MousePick.release(self)  # a right click on the panel reaches _unhandled_input as Esc
	_keep_row_in_view.call_deferred()


func _keep_row_in_view() -> void:
	# A frame later: the rebuilt rows have their sizes by then (the suit tab's sixth row,
	# Trousers, sits below the fold at 720p).
	await get_tree().process_frame
	if _scroll != null and visible and _row < _rows.get_child_count():
		_scroll.ensure_control_visible(_rows.get_child(_row) as Control)


func _clear_total() -> void:
	for child in _total_slot.get_children():
		_total_slot.remove_child(child)  # gone now, so it can't count toward this frame's layout
		child.queue_free()


## The live quote as the panel's footer: working on the left, the total large and bold.
## Once the customer has said yes, the note under the working says so, in green.
func _show_total(working: String, total: int, over: bool) -> void:
	_clear_total()
	var col := Style.INK
	var note := ""
	if over:
		col = Style.CLAY
		note = "Over budget"
	elif _awaiting:
		col = Style.FOREST
		note = "%s take it" % ("She'll" if _she() else "He'll")
	_total_slot.add_child(Style.total_bar(working, "Quote", total, col, note))


## Whether the customer at the mirror is a woman (for "She'll take it").
func _she() -> bool:
	if _customer == null or not is_instance_valid(_customer):
		return false
	var gender: Variant = _customer.get("gender")
	return gender != null and int(gender) == Enums.Gender.FEMALE


## Rebuild the key-cap bar — the confirm verb and the debug auto-fit key vary.
func _rebuild_hint_bar() -> void:
	for child in _hint_bar.get_children():
		_hint_bar.remove_child(child)  # gone now, so the tutorial finds only the live keys
		child.queue_free()
	var pairs := [["W/S", "Select"], ["A/D", "Change"]]
	if _pref == null:
		pairs.append(["E", "Confirm"])
	elif _awaiting:
		pairs.append(["E", "Sell · $%d" % _final_quote()])
	else:
		pairs.append(["E", "Ask"])
	pairs.append([_key_name("handbook"), "Handbook"])
	pairs.append(["Esc", "Close"])
	var bar := Style.hint_bar(pairs)
	_hint_bar.add_child(bar)
	# The one-shot keys double as buttons: confirm, the handbook, close.
	MousePick.wire_hint(bar, 2, _click_confirm)
	MousePick.wire_hint(bar, 3, _click_handbook)
	MousePick.wire_hint(bar, -1, _click_close)


## The key the Handbook is bound to, for the hint bar — the player may have rebound it.
func _key_name(action: String) -> String:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).as_text_physical_keycode()
	return action.to_upper()


## A design row. E asks the customer from any row, so a click here only selects it (the
## footer's quote is what a click asks from); a click on the "‹ value ›" steps it like
## A/D, and a click on one of the part tabs turns to that part.
func _make_row(row: int, selected: bool, index: int) -> Control:
	if row == Row.PART:
		# Not one more value row: the part switcher is its own strip of drawn tabs.
		var strip := PartTabs.make(_parts(), _part_sel, selected, _parts_on_target(), _linked)
		MousePick.wire(strip, _pick_row.bind(index))
		strip.gui_input.connect(_on_tabs_input.bind(strip, index))
		return strip
	var card := CraftPanel.option(selected, Style.ACC_MIRROR)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var value := Style.field_row(hbox, ROW_NAME[row], _value_text(row), selected)
	MousePick.wire(card, _pick_row.bind(index))
	MousePick.wire_stepper(value, _step_row.bind(index))
	if _row_on_target(row):
		# The tutorial's "that's right": a tick on every row already set to the recipe.
		var tick := Label.new()
		tick.text = "✓"
		tick.add_theme_color_override("font_color", Style.FOREST)
		tick.add_theme_font_size_override("font_size", Style.T_VALUE)
		hbox.add_child(tick)
	if _in_style(row):
		# The paper's star: this cloth or pattern is what the city is wearing this week.
		var star := Label.new()
		star.text = TREND_MARK
		star.tooltip_text = "In style — the paper is calling for this"
		star.add_theme_color_override("font_color", Style.BRASS)
		star.add_theme_font_size_override("font_size", Style.T_VALUE)
		hbox.add_child(star)
	return card


# --- Input -----------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	Sfx.ui(event)
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_move_row(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_move_row(-1)
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("handbook"):
		# Look the dress code up without losing the fitting: the book opens over the
		# mirror, pauses the shop, and puts the input lock back as it found it.
		UI.open_handbook(_actor)
	elif OS.is_debug_build() and event.is_action_pressed("debug"):
		_debug_autocomplete()
	elif (
		event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or MousePick.is_back(event)
	):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## A row pointed at: the same step as W/S landing on it.
func _pick_row(index: int) -> void:
	if not visible or index == _row or index >= _active_rows().size():
		return
	Sfx.ui_move()
	_move_row(index - _row)


## A click on the left (dir -1) / right (dir 1) of row `index`'s value: select it, then A / D.
## (`dir` comes first: the stepper passes it, the row index is bound after.)
func _step_row(dir: int, index: int) -> void:
	if not visible:
		return
	_pick_row(index)
	Sfx.ui_move()
	_adjust(dir)


## A click on a part tab: select the strip and turn to that part; a click out on its
## ‹ › chevrons steps it, as A/D would.
func _on_tabs_input(event: InputEvent, strip: PartTabs, index: int) -> void:
	if not MousePick.is_left_press(event):
		return
	var at := (event as InputEventMouseButton).position
	var part := strip.part_at(at)
	if part >= 0:
		_pick_part.call_deferred(index, part)
	elif strip.chevron_at(at) != 0:
		_step_row.call_deferred(strip.chevron_at(at), index)


func _pick_part(index: int, part: int) -> void:
	if not visible or part == _part_sel:
		return
	_pick_row(index)
	Sfx.ui_move()
	_adjust(part - _part_sel)


## The footer's quote asks the customer (and then confirms) when clicked, like E.
func _wire_total() -> void:
	for bar in _total_slot.get_children():
		MousePick.wire(bar, Callable(), _click_confirm)


func _click_confirm() -> void:
	if not visible:
		return
	Sfx.ui_confirm()
	_confirm()


func _click_handbook() -> void:
	if visible:
		UI.open_handbook(_actor)  # the same as the key: the book opens over the mirror


func _click_close() -> void:
	if visible:
		Sfx.ui_cancel()
		close()


func _move_row(delta: int) -> void:
	_end_reaction()
	_status = ""
	var n := _active_rows().size()
	_row = (_row + delta + n) % n
	_refresh()


func _adjust(dir: int) -> void:
	_end_reaction()
	_status = ""
	_awaiting = false
	var row: int = _active_rows()[_row]
	if row == Row.PART:
		_part_sel = wrapi(_part_sel + dir, 0, _parts().size())
	elif row == Row.TROUSERS:
		# Unlinking leaves the trousers as they are (their own tab appears); relinking
		# puts them back in the jacket's cloth.
		_linked = not _linked
	else:
		var c := _cfg()
		match row:
			Row.FABRIC:
				c["fabric"] = _cycle(_available_fabrics(_type()), int(c["fabric"]), dir)
			Row.COLOR:
				c["color"] = _cycle(MaterialFactory.colors_for(_type()), int(c["color"]), dir)
			Row.PATTERN:
				c["pattern"] = _cycle(Enums.patterns_for(_type()), int(c["pattern"]), dir)
			Row.STYLE:
				c["style_idx"] = wrapi(c["style_idx"] + dir, 0, Enums.styles_for(_type()).size())
	_sync_pants()
	_apply_to_customer()
	_refresh()


## Dress the seated customer in the current design so they change live as you edit.
func _apply_to_customer() -> void:
	if _customer == null or not _customer.has_method("wear_suit"):
		return
	(
		_customer
		. wear_suit(
			_part_material(Enums.GarmentType.JACKET),
			_part_material(Enums.GarmentType.SHIRT),
			_part_material(Enums.GarmentType.PANTS),
			int(_design[Enums.GarmentType.JACKET]["style_idx"]),
			int(_design[Enums.GarmentType.PANTS]["style_idx"]),
		)
	)


func _part_material(garment_type: int) -> MaterialType:
	var c: Dictionary = _design[garment_type]
	return MaterialFactory.make(c["fabric"], c["pattern"], c["color"], 1.0)


## Step `current` to the next/previous value within a part's allowed option list
## (wrapping), so a shirt only ever cycles shirt fabrics/colours/patterns.
func _cycle(options: PackedInt32Array, current: int, dir: int) -> int:
	if options.is_empty():
		return current
	var idx := options.find(current)
	if idx < 0:
		idx = 0
	return options[(idx + dir + options.size()) % options.size()]


# --- Stock indicator -------------------------------------------------------


## Flag whether the shop already holds cloth matching the shown part's design, so
## the player knows a fitting fabric is on hand (vs. one they'd have to order).
func _update_stock() -> void:
	if _stock_dot == null:
		return
	var c := _cfg()
	var have := _cloth_in_stock(int(c["fabric"]), int(c["pattern"]), int(c["color"]))
	# Missing cloth is news, not an error: the designer only offers what a supplier on the
	# phone sells, so it can always be ordered — say so, in the brass "note" tone.
	var tint: Color = Style.FOREST if have else Style.BRASS
	_stock_dot.add_theme_stylebox_override("panel", Style.bar(tint, 6))
	_stock_label.text = "In stock" if have else "Not in stock · order it by phone"
	_stock_label.add_theme_color_override("font_color", Style.text_accent(tint))


## True if any bolt or cut length in the shop is this cloth (see ClothStock).
func _cloth_in_stock(fabric: int, pattern: int, color_index: int) -> bool:
	return ClothStock.has_cloth(get_tree().current_scene, fabric, pattern, color_index)


func _confirm() -> void:
	if _ask_lock > 0.0:
		return  # the answer is still coming: a double tap can't sell by accident
	# Free-design mode (no customer): just announce the design.
	if _pref == null:
		EventBus.design_confirmed.emit(_design.duplicate(true))
		_status = "     Design saved!"
		_refresh()
		return
	# First E asks the customer for their reaction — they light up or shake their head
	# for a moment, then settle back to their normal face.
	if not _awaiting:
		_ask()
		return
	# Second E finalises: create the order and send the customer on their way.
	_finalize()


## Ask the customer: they answer in a bubble (the biggest complaint, or yes) and the
## fitting notepad takes down everything still wrong.
func _ask() -> void:
	_ask_lock = ASK_LOCK
	var reaction: Dictionary = _pref.evaluate(_design)
	var lesson: Array[String] = Tutorial.recipe_reasons(_design) if Tutorial != null else []
	if not lesson.is_empty():
		# Mr. Hemming's customer came for the suit he's teaching, and takes no other.
		reaction["suitable"] = false
		reaction["reasons"] = lesson
		reaction["notes"] = FittingNotepad.fallback_notes(lesson)
	var suitable: bool = reaction.get("suitable", false)
	if suitable and str(reaction.get("said_happy", "")) == "" and reaction.get("liked", false):
		reaction["said_happy"] = (
			"%s! Just as I asked." % MaterialFactory.color_name(_pref.likes_color)
		)
	var objections: Array = reaction.get("reasons", [])
	EventBus.design_judged.emit(suitable, str(objections[0]) if not objections.is_empty() else "")
	if _customer != null and _customer.has_method("react"):
		_customer.react(Customer.REACT_LIKE if suitable else Customer.REACT_DISLIKE)
	_awaiting = suitable
	_pad.note(reaction)
	_start_reaction(suitable, FittingNotepad.said_of(reaction))
	_refresh()


## The customer answers in a bubble by their head. The camera stays put; the bubble stays
## until the design or the tab changes, the next ask, or the fitting closes.
func _start_reaction(suitable: bool, said: String) -> void:
	_end_reaction()
	if _customer == null or not is_instance_valid(_customer) or said == "":
		return
	var lines := PackedStringArray([said])
	_bubble = ReactionBubble.show_for(self, _customer, _height * HEAD_AT, suitable, lines)
	var vp := get_viewport_rect()
	_bubble.bounds = Rect2(
		Vector2(_left_reserve(), 0.0),
		Vector2(_panel.get_global_rect().position.x - _left_reserve(), vp.size.y)
	)
	Sfx.play("menu_open", -8.0)


## Put the answer away (the design moved on, or the fitting closed).
func _end_reaction() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.dismiss()
	_bubble = null


## Create the order for the current design and send the customer off happy.
func _finalize() -> void:
	var quote := _final_quote()
	var skin: Color = _customer.skin_color if _customer != null else _SKIN_FALLBACK
	var hair: int = _customer.hair_index if _customer != null else 0
	var hair_col: Color = _customer.hair_color if _customer != null else _HAIR_FALLBACK
	var flags := {"rush": _pref.rush, "picky": _pref.picky, "occasion": int(_pref.occasion)}
	flags["liked"] = _pref.likes_met(_design)
	if _customer != null:
		flags["coffee"] = float(_customer.get("coffee"))  # welcomed with a cup
	var order := Orders.create_order(
		_pref.display_name, _design, quote, skin, hair, hair_col, flags
	)
	if order.event_id != "":
		var title := News.event_title(order.event_id)
		UI.toast("For %s on day %d: make it the best in the room" % [title, order.due_day])
	if Clientele != null and _customer != null:
		Clientele.note_customer(_customer)  # remember their face so they can return
	EventBus.design_confirmed.emit(_design.duplicate(true))
	var cust = _customer
	close()
	if cust != null:
		if cust.has_method("react"):
			cust.react(Customer.REACT_ACCEPT)  # keep a happy face as they leave
		cust.finish_and_leave()


## What the customer pays for this design: the quote, plus the rush premium (agreed up
## front) when they need it tomorrow.
func _final_quote() -> int:
	var quote: int = Pricing.suit_quote(_design)
	if _pref != null and _pref.rush:
		quote += _rush_extra(quote)
	return quote


func _rush_extra(quote: int) -> int:
	return int(round(quote * FrontDesk.RUSH_BONUS))


# --- Debug (F2, debug builds only) -----------------------------------------


## Instantly design a suit this customer would accept, then confirm the order.
func _debug_autocomplete() -> void:
	if _pref == null:
		EventBus.design_confirmed.emit(_design.duplicate(true))
		_status = "     Design saved! (debug)"
		_refresh()
		return
	_design = _acceptable_design()
	_apply_to_customer()
	_finalize()


## A design that satisfies this customer's dress-code brief and budget: allowed
## colour, the required/allowed pattern, and the cheapest allowed cloth.
func _acceptable_design() -> Dictionary:
	var color := 0
	var pattern := 0
	var fabric := 0
	var rule: DressRule = null
	if Catalog.dress_code != null:
		rule = Catalog.dress_code.rule_for(_pref.occasion, _pref.style)
	if rule != null:
		if not rule.allowed_colors.is_empty():
			color = _taste_pick(rule.allowed_colors, color)
		fabric = _cheapest_fabric(rule.allowed_fabrics)
		if rule.require_pattern:
			for p in rule.allowed_patterns:
				if int(p) != Enums.Pattern.SOLID:
					pattern = int(p)
					break
		elif not rule.allowed_patterns.is_empty():
			pattern = int(rule.allowed_patterns[0])
	var design := {}
	for t in PARTS:
		# The shirt from its own row of the dress code, never a suiting cloth or colour.
		if t == Enums.GarmentType.SHIRT:
			var cols := DressCode.shirt_colors(_pref.occasion, _pref.style)
			var pats := DressCode.shirt_patterns(_pref.occasion, _pref.style)
			if cols.is_empty():
				cols = Array(MaterialFactory.colors_for(t))
			design[t] = {
				"fabric": _available_fabrics(t)[0],
				"color": _taste_pick(cols, int(cols[0])),
				"pattern": int(pats[0]) if not pats.is_empty() else Enums.patterns_for(t)[0],
				"style_idx": 0,
			}
		else:
			design[t] = {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	return design


## From `allowed`: the colour the customer asked for if it's there, else the first one
## they haven't turned down.
func _taste_pick(allowed: Array, fallback: int) -> int:
	if _pref.likes_color in allowed:
		return _pref.likes_color
	var told: Dictionary = _pref.quiet_dislike if _pref.quiet_known else {}
	for c in allowed:
		var quiet_no: bool = (
			told.get("kind", "") == "color" and int(told.get("value", -1)) == int(c)
		)
		if int(c) != _pref.dislikes_color and not quiet_no:
			return int(c)
	return fallback


## Cheapest fabric among `allowed` (or all fabrics if unrestricted), restricted to what
## the shop's unlocked suppliers can actually provide, to stay in budget.
func _cheapest_fabric(allowed: Array) -> int:
	var prices: Array = Config.data.fabric_price_per_m if Config.data != null else []
	var supplied := _supplied_fabrics()
	var pool: Array = []
	if allowed != null and not allowed.is_empty():
		for f in allowed:
			if supplied.is_empty() or int(f) in supplied:
				pool.append(int(f))
	if pool.is_empty():  # nothing allowed is stocked (or no restriction) — fall back to all supplied
		for i in prices.size():
			if supplied.is_empty() or i in supplied:
				pool.append(i)
	if pool.is_empty():
		return 0
	var best: int = pool[0]
	for f in pool:
		if f < prices.size() and best < prices.size() and prices[f] < prices[best]:
			best = f
	return best


## The set of fabric ids (Enums.Fabric) the shop's currently-unlocked suppliers offer.
## Empty only if the Upgrades autoload is missing.
func _supplied_fabrics() -> Dictionary:
	var out := {}
	if Upgrades != null:
		for v in Upgrades.unlocked_vendors():
			for f in v.get("fabrics", []):
				out[int(f)] = true
	return out


## Fabrics offered for `garment_type` by the suppliers the shop has unlocked — so the
## designer only ever shows cloth you could actually order. Unlock more vendors → more
## fabrics appear here. Never returns empty (falls back to the full type list).
func _available_fabrics(garment_type: int) -> PackedInt32Array:
	var supplied := _supplied_fabrics()
	var out := PackedInt32Array()
	for f in Enums.fabrics_for(garment_type):
		if supplied.is_empty() or int(f) in supplied:
			out.append(int(f))
	if out.is_empty():
		out = Enums.fabrics_for(garment_type)
	return out
