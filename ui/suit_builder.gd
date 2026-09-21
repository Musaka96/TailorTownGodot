extends Control

## The mirror's suit builder. A side panel (keeps the customer visible) where you
## design each part of the suit. Selecting a part glides the camera to zoom onto
## it; "Overview" frames the whole customer. E confirms the design.

enum Row { PART, FABRIC, COLOR, PATTERN, STYLE }
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
}
# Display order of the parts.
const PARTS := [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]
# The design fields a row edits (the tutorial checks them against its recipe).
const ROW_KEY := {Row.FABRIC: "fabric", Row.COLOR: "color", Row.PATTERN: "pattern"}
# Camera framing. The subject (whole customer, or the selected part) is placed EXACTLY
# at the centre of the free screen area left of the fitting panel, solved from the live
# camera FOV, viewport aspect and panel width — so it can't drift on other resolutions.
# FILL = fraction of the screen height the subject's span takes up.
const OVERVIEW_FILL := 0.8
const PITCH_DEG := 8.0  # camera looks slightly down at the subject
# Part shots: (centre height, visible screen-height span), both as fractions of the
# customer's height (measured from their meshes, so every body frames the same).
const PART_FRAME := {
	Enums.GarmentType.JACKET: Vector2(0.42, 0.72),
	Enums.GarmentType.SHIRT: Vector2(0.48, 0.56),
	Enums.GarmentType.PANTS: Vector2(0.22, 0.72),
}
const DEFAULT_BODY_HEIGHT := 2.25
## Asking the customer: the camera eases out to head and shoulders (centre, span as
## fractions of their height) so you see their face as they answer, holds for
## REACTION_HOLD seconds (or until you change something), then eases back to the part.
const REACTION_FRAME := Vector2(0.62, 1.0)
const REACTION_HOLD := 2.6
const HEAD_AT := 0.9  # the bubble points at this fraction of the customer's height
const REACTION_LINES := 3  # most complaints the bubble lists at once
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
var _reaction_t := 0.0  # > 0 while the camera is out on the customer's face
var _bubble: ReactionBubble
var _rig = null
var _part_sel := -1  # -1 = overview, else index into PARTS
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

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _preview: HBoxContainer = $Panel/Margin/Box/Preview
@onready var _rows: VBoxContainer = $Panel/Margin/Box/Rows
@onready var _hint: Label = $Panel/Margin/Box/Hint


func _ready() -> void:
	_build_preview()


func _process(delta: float) -> void:
	# Re-solve every frame: the panel's layout settles after opening and the window can
	# be resized, and the target must track both to stay exactly centred.
	if visible:
		if _reaction_t > 0.0:
			_reaction_t -= delta
			if _reaction_t <= 0.0:
				_end_reaction()
		_update_camera()


func open(mirror, actor) -> void:
	_mirror = mirror
	_actor = actor
	_customer = mirror.customer
	_pref = _customer.get("preference") if _customer != null else null
	_awaiting = false
	_rig = get_tree().get_first_node_in_group("camera_rig")
	_part_sel = -1
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
	_apply_to_customer()
	_height = _body_height() if _customer != null else DEFAULT_BODY_HEIGHT
	_update_camera()
	_refresh()


func close() -> void:
	_end_reaction()
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
## tutorial reserves on the left and the panel.
func tutorial_busy_rects() -> Array[Rect2]:
	var vp := get_viewport_rect().size
	var left := _left_reserve()
	return [Rect2(left, 0, _panel.get_global_rect().position.x - left, vp.y)]


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


## W/S to reach the part tabs, then A/D across to the tab for part `t`.
func _coach_tab(t: int) -> Dictionary:
	for child in _rows.get_children():
		var tabs := child as PartTabs
		if tabs == null or tabs.is_queued_for_deletion():
			continue
		var on_tabs: bool = _active_rows()[_row] == Row.PART
		var nm := Enums.garment_type_name(t)
		var text := ("A/D: pick %s" % nm) if on_tabs else "W/S: go to the tabs"
		return {"rect": tabs.tab_rect(PARTS.find(t)), "text": text, "beside": true}
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
	return Enums.pattern_name(value)


## Whether `row` already matches the tutorial's recipe (a Part row: the whole part does).
func _row_on_target(row: int) -> bool:
	if Tutorial == null or _part_sel < 0:
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
	if _part_sel < 0 or not (row == Row.FABRIC or row == Row.PATTERN):
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


## Width kept free at the left edge (the tutorial's goal tag), so the customer is centred
## in the space that is actually visible.
func _left_reserve() -> float:
	return Tutorial.side_reserve() if Tutorial != null else 0.0


# --- State -----------------------------------------------------------------


func _type() -> int:
	return PARTS[_part_sel] if _part_sel >= 0 else -1


func _cfg() -> Dictionary:
	return _design[_type()] if _part_sel >= 0 else {}


func _active_rows() -> Array:
	if _part_sel < 0:
		return [Row.PART]
	return [Row.PART, Row.FABRIC, Row.COLOR, Row.PATTERN, Row.STYLE]


func _material() -> MaterialType:
	var t := _type() if _part_sel >= 0 else int(Enums.GarmentType.JACKET)
	var c: Dictionary = _design[t]
	return MaterialFactory.make(c["fabric"], c["pattern"], c["color"], 1.0)


func _value_text(row: int) -> String:
	if row == Row.PART:
		return "Overview" if _part_sel < 0 else Enums.garment_type_name(_type())
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
	var height := _height
	var centre := 0.5
	var span := height / OVERVIEW_FILL
	if _reaction_t > 0.0:
		centre = REACTION_FRAME.x
		span = height * REACTION_FRAME.y
	elif _part_sel >= 0:
		var pf: Vector2 = PART_FRAME.get(_type(), Vector2(0.5, 0.5))
		centre = pf.x
		span = height * pf.y
	var subject := base + Vector3(0.0, height * centre, 0.0)
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
	if _part_sel < 0:
		_name_label.text = "Whole suit"
		_sub_label.text = "Pick a part to design and zoom in."
	else:
		_name_label.text = mat.display_name
		_sub_label.text = (
			"%s  ·  %s" % [mat.summary(), Enums.styles_for(_type())[_cfg()["style_idx"]]]
		)
	if _pref != null:
		# Live price readout: cloth + craft = quote, against the customer's budget.
		var q := Pricing.quote_breakdown(_design)
		var over: bool = int(q["total"]) > _pref.budget
		var rush := ""
		if _pref.rush:
			rush = "  + rush $%d" % _rush_extra(int(q["total"]))
		_brief_label.text = (
			"For: %s   ·   Budget $%d%s" % [_pref.describe(), _pref.budget, _status]
		)
		var working := "Cloth $%d + Craft $%d%s" % [q["cloth"], q["craft"], rush]
		_show_total(working, int(q["total"]), over)
	else:
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
		_rows.add_child(_make_row(rows[i], i == _row))
	_keep_row_in_view.call_deferred()


func _keep_row_in_view() -> void:
	if _scroll != null and _row < _rows.get_child_count():
		_scroll.ensure_control_visible(_rows.get_child(_row) as Control)


func _clear_total() -> void:
	for child in _total_slot.get_children():
		_total_slot.remove_child(child)  # gone now, so it can't count toward this frame's layout
		child.queue_free()


## The live quote as the panel's footer: working on the left, the total large and bold.
func _show_total(working: String, total: int, over: bool) -> void:
	_clear_total()
	var col := Style.CLAY if over else Style.INK
	var note := "Over budget" if over else ""
	_total_slot.add_child(Style.total_bar(working, "Quote", total, col, note))


## Rebuild the key-cap bar — the confirm verb and the debug auto-fit key vary.
func _rebuild_hint_bar() -> void:
	for child in _hint_bar.get_children():
		_hint_bar.remove_child(child)  # gone now, so the tutorial finds only the live keys
		child.queue_free()
	var pairs := [["W/S", "Select"], ["A/D", "Change"]]
	pairs.append(["E", "Ask / confirm"] if _pref != null else ["E", "Confirm"])
	pairs.append([_key_name("handbook"), "Handbook"])
	if OS.is_debug_build():
		pairs.append(["F2", "Auto-fit"])
	pairs.append(["Esc", "Close"])
	_hint_bar.add_child(Style.hint_bar(pairs))


## The key the Handbook is bound to, for the hint bar — the player may have rebound it.
func _key_name(action: String) -> String:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).as_text_physical_keycode()
	return action.to_upper()


func _make_row(row: int, selected: bool) -> Control:
	if row == Row.PART:
		# Not one more value row: the part switcher is its own strip of drawn tabs.
		return PartTabs.make(PARTS, _part_sel, selected, _parts_on_target())
	var card := CraftPanel.option(selected, Style.ACC_MIRROR)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	Style.field_row(hbox, ROW_NAME[row], _value_text(row), selected)
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
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


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
		_part_sel = wrapi(_part_sel + dir, -1, PARTS.size())
		_update_camera()
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
	var c: Dictionary = _design[_type()] if _part_sel >= 0 else _design[Enums.GarmentType.JACKET]
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
	# Free-design mode (no customer): just announce the design.
	if _pref == null:
		EventBus.design_confirmed.emit(_design.duplicate(true))
		_status = "     Design saved!"
		_refresh()
		return
	# First E asks the customer for their reaction — they light up or shake their head
	# for a moment, then settle back to their normal face.
	if not _awaiting:
		var reaction: Dictionary = _pref.evaluate(_design)
		var suitable: bool = reaction.get("suitable", false)
		if _customer != null and _customer.has_method("react"):
			_customer.react(Customer.REACT_LIKE if suitable else Customer.REACT_DISLIKE)
		var verdict := "happy: E to take the order" if suitable else "not quite"
		_status = "     %s is %s" % [_pref.display_name, verdict]
		_awaiting = suitable
		_start_reaction(suitable, reaction.get("reasons", []))
		_refresh()
		return
	# Second E finalises: create the order and send the customer on their way.
	_finalize()


## Ease the camera out to the customer's face and let them answer in a bubble.
func _start_reaction(suitable: bool, reasons: Array) -> void:
	_end_reaction()
	if _customer == null or not is_instance_valid(_customer):
		return
	var lines := PackedStringArray()
	if suitable:
		lines.append("Perfect. I'll take it!")
		lines.append("Press E to agree the order.")
	else:
		lines.append("Not quite.")
		for r: String in reasons.slice(0, REACTION_LINES):
			lines.append(r.substr(0, 1).to_upper() + r.substr(1))
	_reaction_t = REACTION_HOLD
	_bubble = ReactionBubble.show_for(self, _customer, _height * HEAD_AT, suitable, lines)
	var vp := get_viewport_rect()
	_bubble.bounds = Rect2(
		Vector2(_left_reserve(), 0.0),
		Vector2(_panel.get_global_rect().position.x - _left_reserve(), vp.size.y)
	)
	Sfx.play("menu_open", -8.0)


## Back to the part being edited (the rig eases the camera there).
func _end_reaction() -> void:
	_reaction_t = 0.0
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.dismiss()
	_bubble = null


## Create the order for the current design and send the customer off happy.
func _finalize() -> void:
	var quote: int = Pricing.suit_quote(_design)
	if _pref.rush:
		quote += _rush_extra(quote)  # the rush premium is agreed up front
	var skin: Color = _customer.skin_color if _customer != null else _SKIN_FALLBACK
	var hair: int = _customer.hair_index if _customer != null else 0
	var hair_col: Color = _customer.hair_color if _customer != null else _HAIR_FALLBACK
	var flags := {"rush": _pref.rush, "picky": _pref.picky, "occasion": int(_pref.occasion)}
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
			color = int(rule.allowed_colors[0])
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
		# The brief only judges the jacket, so give the shirt a sensible shirting
		# default rather than forcing a suiting fabric/colour onto it.
		if t == Enums.GarmentType.SHIRT:
			design[t] = {
				"fabric": _available_fabrics(t)[0],
				"color": MaterialFactory.colors_for(t)[0],
				"pattern": Enums.patterns_for(t)[0],
				"style_idx": 0,
			}
		else:
			design[t] = {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	return design


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
