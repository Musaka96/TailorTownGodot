class_name ControlsScreen
extends Control

## The controls sheet: a drawn keyboard and a drawn controller with the keys that matter
## lit up in three colours (moving / doing / looking things up), a legend under each, and
## the bench controls along the bottom. Everything is read live from the InputMap, so a
## rebind in Settings shows up here. Self-contained overlay — the pause menu and the main
## menu both open it with ControlsScreen.open(parent).

signal closed

enum Group { MOVE, ACT, INFO }

const PANEL_SIZE := Vector2(1080, 640)
const MOVES := ["move_forward", "move_left", "move_back", "move_right"]
## [action, what it does, colour group]. "move" stands for the four move actions.
const ROWS := [
	["move", "Move", Group.MOVE],
	["sprint", "Run  ·  fast gear at the bench", Group.ACT],
	["jump", "Jump  ·  hold / pedal at the bench", Group.ACT],
	["interact", "Use  ·  pick up  ·  drop  ·  confirm", Group.ACT],
	["cut", "Cut cloth", Group.ACT],
	["orders", "Orders board", Group.INFO],
	["newspaper", "Newspaper", Group.INFO],
	["handbook", "Handbook", Group.INFO],
	["pause", "Pause  ·  back", Group.INFO],
]
const BENCH := [
	["Cutting", [["Space / F", "Hold to cut"], ["A / D", "Steer"]]],
	["Sewing", [["Space / RT", "Pedal"], ["A / D", "Aim"], ["S", "Backstitch"], ["E", "Pins"]]],
	["Pressing & coffee", [["Space", "Hold"], ["A / D", "Slide the iron"]]],
	["Once upgraded", [["Shift / RB", "Fast gear"]]],
]

var _panel: PanelContainer


static func open(parent: Node) -> ControlsScreen:
	var screen := ControlsScreen.new()
	parent.add_child(screen)
	return screen


static func group_color(group: int) -> Color:
	match group:
		Group.MOVE:
			return Style.FOREST
		Group.ACT:
			return Style.BRASS
	return Style.BURGUNDY


static func group_ink(group: int) -> Color:
	return Style.WALNUT if group == Group.ACT else Style.CHALK


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sfx.play("menu_open")
	Craft.pop_in.call_deferred(_panel, 0.92, 0.26)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	for action in ["pause", "ui_cancel", "interact", "ui_accept"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			close()
			return
	# Swallow everything else so the menu underneath doesn't move while this is up.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


# --- Layout ------------------------------------------------------------------------


func _build() -> void:
	add_child(Style.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_SIZE
	center.add_child(_panel)
	Style.apply_skin(_panel, Style.MenuSkin.WORK)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(outer)
	outer.add_child(TitleBlock.make("Controls", "How to play", Style.ACC_WORK))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", Style.S2)
	scroll.add_child(body)

	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", Style.S4)
	body.add_child(sides)
	sides.add_child(_side("Keyboard", _KeysPic.new(), false))
	sides.add_child(_side("Controller", _PadPic.new(), true))

	body.add_child(Style.header("At the bench", Style.ACC_WORK))
	var bench := HBoxContainer.new()
	bench.add_theme_constant_override("separation", Style.S3)
	body.add_child(bench)
	for entry: Array in BENCH:
		bench.add_child(_bench_column(entry[0], entry[1]))

	outer.add_child(Style.hint_bar([["Esc", "Back"]]))


func _side(title: String, pic: Control, pad: bool) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", Style.S1)
	col.add_child(Style.header(title, Style.ACC_WORK))
	col.add_child(pic)
	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", Style.S3)
	legend.add_theme_constant_override("v_separation", Style.S1)
	col.add_child(legend)
	for row: Array in _pad_rows() if pad else _key_rows():
		legend.add_child(_legend_row(row[0], row[1], row[2]))
	return col


func _key_rows() -> Array:
	var rows := []
	for r: Array in ROWS:
		var key := ""
		if r[0] == "move":
			var parts := []
			for m: String in MOVES:
				parts.append(Settings.binding_text(m))
			key = " ".join(parts)
		else:
			key = Settings.binding_text(r[0]).replace("Escape", "Esc")
		rows.append([key, r[1], r[2]])
	return rows


func _pad_rows() -> Array:
	var rows := []
	for r: Array in ROWS:
		var key: String = "Left stick" if r[0] == "move" else Settings.pad_text(r[0])
		if key != "":
			rows.append([key, r[1], r[2]])
	rows.append(["RT", "Sewing pedal", Group.ACT])
	rows.append([Settings.pad_text("ui_cancel"), "Back", Group.INFO])
	rows.append(["D-pad", "Move through menus", Group.MOVE])
	return rows


func _legend_row(key: String, verb: String, group: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	row.add_child(_cap(key, group))
	var lbl := Label.new()
	lbl.text = verb
	lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
	lbl.add_theme_color_override("font_color", Style.INK)
	row.add_child(lbl)
	return row


func _cap(key: String, group: int) -> Control:
	var cap := PanelContainer.new()
	var sb := Style.bar(group_color(group), 6)
	sb.content_margin_left = Style.S1 + 3
	sb.content_margin_right = Style.S1 + 3
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", sb)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.text = key
	lbl.add_theme_font_override("font", Style.font_bold())
	lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
	lbl.add_theme_color_override("font_color", group_ink(group))
	cap.add_child(lbl)
	return cap


func _bench_column(title: String, pairs: Array) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", Style.S1)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_override("font", Style.font_medium())
	lbl.add_theme_font_size_override("font_size", Style.T_BODY)
	lbl.add_theme_color_override("font_color", Style.INK)
	col.add_child(lbl)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Style.S1)
	flow.add_theme_constant_override("v_separation", Style.S1)
	col.add_child(flow)
	for pair: Array in pairs:
		flow.add_child(Style.key_pill(pair[0], pair[1]))
	return col


# --- The drawn keyboard --------------------------------------------------------------


class _KeysPic:
	extends Control

	const U := 34.0
	const GAP := 4.0
	## Rows of [label, keycode string it lights up for, width in key units].
	const KEYS := [
		[["Esc", "Escape", 1.0]],
		[
			["Tab", "Tab", 1.5],
			["Q", "Q", 1.0],
			["W", "W", 1.0],
			["E", "E", 1.0],
			["R", "R", 1.0],
			["T", "T", 1.0],
			["Y", "Y", 1.0],
			["U", "U", 1.0],
		],
		[
			["Caps", "CapsLock", 1.8],
			["A", "A", 1.0],
			["S", "S", 1.0],
			["D", "D", 1.0],
			["F", "F", 1.0],
			["G", "G", 1.0],
			["H", "H", 1.0],
			["J", "J", 1.0],
		],
		[
			["Shift", "Shift", 2.3],
			["Z", "Z", 1.0],
			["X", "X", 1.0],
			["C", "C", 1.0],
			["V", "V", 1.0],
			["B", "B", 1.0],
			["N", "N", 1.0],
			["M", "M", 1.0],
		],
		[["Ctrl", "Ctrl", 1.5], ["", "", 1.2], ["Alt", "Alt", 1.2], ["Space", "Space", 5.6]],
	]
	const ARROWS := [["Up", 1, 3], ["Left", 0, 4], ["Down", 1, 4], ["Right", 2, 4]]

	var _lit := {}  # keycode string -> Group

	func _init() -> void:
		custom_minimum_size = Vector2(0, (U + GAP) * 5.0 + 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		for r: Array in ControlsScreen.ROWS:
			var actions: Array = ControlsScreen.MOVES if r[0] == "move" else [r[0]]
			for action: String in actions:
				for ev: InputEvent in InputMap.action_get_events(action):
					if ev is InputEventKey:
						var code := (ev as InputEventKey).physical_keycode
						_lit[OS.get_keycode_string(code)] = r[2]

	func _draw() -> void:
		var font := Style.font_bold()
		for ri in KEYS.size():
			var x := 2.0
			for key: Array in KEYS[ri]:
				var w: float = U * float(key[2]) + GAP * (float(key[2]) - 1.0)
				_key(Rect2(x, ri * (U + GAP), w, U), key[0], key[1], font)
				x += w + GAP
		var ax := 2.0 + (U + GAP) * 9.4
		for a: Array in ARROWS:
			var r := Rect2(ax + a[1] * (U + GAP), a[2] * (U + GAP), U, U)
			_key(r, "", a[0], font)
			_arrow(r.get_center(), a[0], _lit.has(a[0]))

	func _key(r: Rect2, label: String, code: String, font: Font) -> void:
		var lit: bool = _lit.has(code)
		var fill: Color = ControlsScreen.group_color(_lit[code]) if lit else Style.CARD
		var ink: Color = ControlsScreen.group_ink(_lit[code]) if lit else Style.INK_SOFT
		var poly := Craft.rounded(r, 6.0, 3)
		if lit:
			Craft.card(self, poly, fill, Style.WALNUT, 1.5)
		else:
			draw_colored_polygon(poly, fill)
			Craft.outline(self, poly, Style.CREAM_DARK, 1.5)
		if label != "":
			var size_px := Style.T_MICRO if label.length() > 1 else Style.T_CAPTION
			var at := Vector2(r.position.x, r.get_center().y + size_px * 0.36)
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size_px, ink)

	func _arrow(c: Vector2, dir: String, lit: bool) -> void:
		var angle: float = {"Up": 0.0, "Right": PI / 2.0, "Down": PI, "Left": -PI / 2.0}[dir]
		var tri := PackedVector2Array()
		for p: Vector2 in [Vector2(0, -6), Vector2(6, 5), Vector2(-6, 5)]:
			tri.append(c + p.rotated(angle))
		draw_colored_polygon(tri, Style.CHALK if lit else Style.INK_SOFT)


# --- The drawn controller ------------------------------------------------------------


class _PadPic:
	extends Control

	## Where each JoyButton sits on the drawn pad (pad-local, centre = 0,0).
	const SPOTS := {
		0: Vector2(104, 2),
		1: Vector2(126, -20),
		2: Vector2(82, -20),
		3: Vector2(104, -42),
		4: Vector2(-24, -30),
		6: Vector2(24, -30),
	}
	const LETTERS := {0: "A", 1: "B", 2: "X", 3: "Y"}
	const STICK_L := Vector2(-96, -22)
	const STICK_R := Vector2(48, 28)
	const DPAD := Vector2(-48, 28)

	var _lit := {}  # JoyButton index -> Group

	func _init() -> void:
		custom_minimum_size = Vector2(0, (_KeysPic.U + _KeysPic.GAP) * 5.0 + 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		for r: Array in ControlsScreen.ROWS:
			if r[0] == "move":
				continue
			for ev: InputEvent in InputMap.action_get_events(r[0]):
				if ev is InputEventJoypadButton:
					_lit[(ev as InputEventJoypadButton).button_index] = r[2]
		_lit[JOY_BUTTON_B] = _lit.get(JOY_BUTTON_B, ControlsScreen.Group.INFO)

	func _draw() -> void:
		draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5 + 14.0))
		var font := Style.font_bold()
		_shoulders(font)
		# Body: two grips and a bridge, as one walnut silhouette.
		for gx: float in [-112.0, 112.0]:
			draw_circle(Vector2(gx, 34) + Craft.SHADOW_OFFSET, 50.0, Style.SHADOW)
		for gx: float in [-112.0, 112.0]:
			draw_circle(Vector2(gx, 34), 50.0, Style.BROWN)
		var body := Craft.rounded(Rect2(-160, -66, 320, 112), 46.0, 6)
		draw_colored_polygon(body, Style.BROWN)
		Craft.stitch(self, body, Style.tint(Style.CREAM, 0.45), 7.0, 1.2)
		_stick(STICK_L, ControlsScreen.Group.MOVE, _lit.get(JOY_BUTTON_LEFT_STICK, -1), font)
		_stick(STICK_R, -1, _lit.get(JOY_BUTTON_RIGHT_STICK, -1), font)
		_dpad()
		for index: int in SPOTS:
			_button(index, font)
		draw_set_transform(Vector2.ZERO)

	func _shoulders(font: Font) -> void:
		var act := ControlsScreen.Group.ACT
		_shoulder(Rect2(-142, -104, 56, 20), "LT", -1, font)
		_shoulder(Rect2(86, -104, 56, 20), "RT", act, font)
		_shoulder(Rect2(-150, -82, 84, 18), "LB", _lit.get(JOY_BUTTON_LEFT_SHOULDER, -1), font)
		_shoulder(Rect2(66, -82, 84, 18), "RB", _lit.get(JOY_BUTTON_RIGHT_SHOULDER, -1), font)

	func _shoulder(r: Rect2, label: String, group: int, font: Font) -> void:
		var lit := group >= 0
		var fill: Color = ControlsScreen.group_color(group) if lit else Style.CARD
		var ink: Color = ControlsScreen.group_ink(group) if lit else Style.INK_SOFT
		var poly := Craft.rounded(r, 7.0, 3)
		draw_colored_polygon(poly, fill)
		Craft.outline(self, poly, Style.WALNUT if lit else Style.CREAM_DARK, 1.5)
		var at := Vector2(r.position.x, r.get_center().y + Style.T_MICRO * 0.36)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, Style.T_MICRO, ink)

	## `ring` lights the stick for moving; `click` lights its cap for the L3/R3 press.
	func _stick(at: Vector2, ring: int, click: int, font: Font) -> void:
		draw_circle(at, 24.0, Style.WALNUT)
		var rim: Color = ControlsScreen.group_color(ring) if ring >= 0 else Style.INK_SOFT
		draw_arc(at, 21.0, 0, TAU, 28, rim, 3.0, true)
		var cap: Color = ControlsScreen.group_color(click) if click >= 0 else Style.BROWN
		draw_circle(at, 14.0, cap)
		if click >= 0:
			var ink: Color = ControlsScreen.group_ink(click)
			var pos := at + Vector2(-14, Style.T_MICRO * 0.36)
			draw_string(font, pos, "L3", HORIZONTAL_ALIGNMENT_CENTER, 28, Style.T_MICRO, ink)

	func _dpad() -> void:
		draw_circle(DPAD, 24.0, Style.WALNUT)
		var col: Color = ControlsScreen.group_color(ControlsScreen.Group.MOVE)
		draw_rect(Rect2(DPAD + Vector2(-6, -18), Vector2(12, 36)), col)
		draw_rect(Rect2(DPAD + Vector2(-18, -6), Vector2(36, 12)), col)
		if _lit.has(JOY_BUTTON_DPAD_UP):
			var up: Color = ControlsScreen.group_color(_lit[JOY_BUTTON_DPAD_UP])
			draw_rect(Rect2(DPAD + Vector2(-6, -18), Vector2(12, 12)), up)

	func _button(index: int, font: Font) -> void:
		var at: Vector2 = SPOTS[index]
		var lit: bool = _lit.has(index)
		var fill: Color = ControlsScreen.group_color(_lit[index]) if lit else Style.CARD
		var ink: Color = ControlsScreen.group_ink(_lit[index]) if lit else Style.INK_SOFT
		var rad := 11.0 if LETTERS.has(index) else 7.0
		draw_circle(at, rad + 1.5, Style.WALNUT)
		draw_circle(at, rad, fill)
		if not LETTERS.has(index):
			var tag := "Back" if index == JOY_BUTTON_BACK else "Start"
			var under := at + Vector2(-24, 22)
			draw_string(
				font, under, tag, HORIZONTAL_ALIGNMENT_CENTER, 48, Style.T_MICRO, Style.CREAM
			)
		if LETTERS.has(index):
			var pos := at + Vector2(-rad, Style.T_CAPTION * 0.36)
			var text: String = LETTERS[index]
			draw_string(
				font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, Style.T_CAPTION, ink
			)
