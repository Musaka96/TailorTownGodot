extends Node3D

## The game's front door — the boot scene (project.godot run/main_scene). The 3D side is a scene (a
## Camera that eases between Marker3D "Viewpoints") edited by hand, with grandpa's shop added as the
## backdrop in code (_build_backdrop). The 2D side is built here: the shop's hanging fascia sign
## with the wordmark, a slim column of sewn-label buttons under it (or, on the Load / Settings
## pages, a cream plate with a title block), and a footer with the version and key prompts. It
## pauses the tree so the autoloaded sim stays frozen behind the menu, and runs anyway
## (PROCESS_MODE_ALWAYS). New/Load hand off to SaveManager.

## How fast the camera eases toward the active viewpoint (higher = snappier).
const CAM_SPEED := 3.2
## How far (metres, sideways / up) the idle camera drifts around its viewpoint.
const DRIFT := Vector2(0.45, 0.15)
## Which viewpoint marker each page frames.
const BACKDROP := "res://scenes/world/grandpa/grandpa_shop_room.tscn"
const VIEW_MAIN := "View_Main"
const VIEW_LOAD := "View_Load"
const VIEW_SETTINGS := "View_Settings"
const EDGE := 48.0  # gap from the screen's left edge to the sign
const SIGN_TOP := 44.0
const CAPTION_ROOM := 16  # px the Continue label grows for its day / money line
const COLUMN_W := 300.0  # the main page's button column
const PLATE_W := 480.0  # the Load / Settings plate
const HINTS_W := 460.0
const FOOTER_H := 32.0
## The community Discord (invite link), opened from the footer's bottom-right chip.
const DISCORD_URL := "https://discord.gg/U9zPC8fRFY"

var _sub := false  # true while the Load slot list is showing (Esc goes back)
var _target: Node3D
var _sign: PanelContainer
var _wordmark: Wordmark
var _plate: PanelContainer
var _head: TitleBlock
var _buttons: VBoxContainer
var _hints: Control
var _sign_down := false
var _drift := 0.0
var _controls: ControlsScreen = null  # the controls sheet, while it is up

@onready var _camera: Camera3D = $Camera
@onready var _viewpoints: Node3D = $Viewpoints
@onready var _root: Control = $MenuLayer/Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_backdrop()
	# The in-game HUD/newspaper autoload draws above the scene — hide it behind the
	# menu (SaveManager shows it again once a game is running).
	if UI != null:
		UI.visible = false
	_target = _view(VIEW_MAIN)
	if _target != null:
		_camera.global_transform = _target.global_transform
	_build_sign()
	_build_plate()
	_build_footer()
	_sign.position.y = -400.0
	_show_main()


# --- Layout ----------------------------------------------------------------


## Grandpa's shop behind the menu, as the newest save left it: boarded up for a new
## player, reglazed and swept for one who has been at it. Built here, after the state is
## set, so the renovation shows as it stands rather than fading in. The tree is paused
## behind the menu; the director may still run, so its fades finish.
func _build_backdrop() -> void:
	SaveManager.apply_menu_backdrop()
	var shop := (load(BACKDROP) as PackedScene).instantiate()
	shop.name = "Shop"
	shop.process_mode = Node.PROCESS_MODE_PAUSABLE
	var director := shop.get_node_or_null("RenovationDirector")
	if director != null:
		director.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(shop)
	move_child(shop, 0)


## The shop's name on a walnut fascia, hung on chains from the top of the screen.
func _build_sign() -> void:
	_sign = PanelContainer.new()
	_sign.position = Vector2(EDGE, SIGN_TOP)
	_root.add_child(_sign)
	SignBoard.dress(_sign).plate = false
	_wordmark = Wordmark.new()
	_sign.add_child(_wordmark)


## Everything under the sign. On the main page it is invisible and just holds the
## button column; on a sub-page it becomes a cream plate with a title block.
func _build_plate() -> void:
	_plate = PanelContainer.new()
	_root.add_child(_plate)
	UiScale.attach(_plate, UiScale.MENUS)  # toward its top-left corner
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S3)
	_plate.add_child(box)
	_head = TitleBlock.make("", "TailorTown", Style.BRASS)
	box.add_child(_head)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", Style.S2)
	box.add_child(_buttons)


func _build_footer() -> void:
	var number := str(ProjectSettings.get_setting("application/config/version", ""))
	var version := TitleBlock.meta_label("v%s" % (number if number != "" else "0.1"))
	version.add_theme_color_override("font_color", Style.CHALK)
	var chip := PanelContainer.new()
	var sb := Style.bar(Style.tint(Style.WALNUT, 0.75), Style.S2)
	sb.content_margin_left = Style.S2
	sb.content_margin_right = Style.S2
	chip.add_theme_stylebox_override("panel", sb)
	chip.add_child(version)
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.add_child(chip)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pin_bottom(holder, 0.0, EDGE, EDGE + 200.0)
	_root.add_child(holder)
	_build_discord()
	_hints = Style.hint_bar([["W/S", "Select"], ["E", "Choose"], ["Esc", "Back"]])
	_pin_bottom(_hints, 0.5, -HINTS_W * 0.5, HINTS_W * 0.5)
	_root.add_child(_hints)


## Bottom right: a chip like the version one that opens the community Discord in the
## browser. Mouse only, so it stays out of the W/S button column.
func _build_discord() -> void:
	var button := Button.new()
	button.text = "Join the Discord"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Style.font_medium())
	button.add_theme_font_size_override("font_size", Style.T_CAPTION)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Style.CHALK)
	var looks := {
		"normal": Style.tint(Style.WALNUT, 0.75),
		"hover": Style.tint(Style.BRASS, 0.9),
		"pressed": Style.tint(Style.WALNUT, 0.95),
	}
	for state: String in looks:
		var sb := Style.bar(looks[state], Style.S2)
		sb.content_margin_left = Style.S3
		sb.content_margin_right = Style.S3
		button.add_theme_stylebox_override(state, sb)
	button.pressed.connect(func() -> void: OS.shell_open(DISCORD_URL))
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(button)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pin_bottom(holder, 1.0, -EDGE - 260.0, -EDGE)
	_root.add_child(holder)


## Anchor `c` to the bottom edge, FOOTER_H tall, between two x offsets from `anchor_x`.
func _pin_bottom(c: Control, anchor_x: float, left: float, right: float) -> void:
	c.anchor_left = anchor_x
	c.anchor_right = anchor_x
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = left
	c.offset_right = right
	c.offset_top = -FOOTER_H - Style.S3
	c.offset_bottom = -Style.S3


## Dress the plate for a page: bare column (main) or titled cream plate (sub-page).
func _set_page(title: String) -> void:
	var sub := title != ""
	_head.visible = sub
	_head.title.text = title
	var width := PLATE_W if sub else COLUMN_W
	var sb: StyleBox = Style.skin_base(Style.BRASS) if sub else StyleBoxEmpty.new()
	_plate.add_theme_stylebox_override("panel", sb)
	_plate.custom_minimum_size = Vector2(width, 0)
	_plate.size = Vector2(width, 0)
	# Main page: the column hangs centred under the sign. Sub-page: the sign is hoisted
	# out of the way on its chains and the plate takes its place.
	var sign_size := _sign.get_combined_minimum_size()
	var inset := 0.0 if sub else (sign_size.x - COLUMN_W) * 0.5
	var top := SIGN_TOP if sub else SIGN_TOP + sign_size.y + Style.S4
	_plate.position = Vector2(EDGE + inset, top)
	_hang_sign(not sub)


## Lower the sign into view, or hoist it clear of the screen.
func _hang_sign(down: bool) -> void:
	if down == _sign_down:
		return
	_sign_down = down
	var y := SIGN_TOP if down else -_sign.get_combined_minimum_size().y - 40.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT if down else Tween.EASE_IN)
	tw.tween_property(_sign, "position:y", y, 0.55 if down else 0.35)
	Sfx.play("sign_drop" if down else "sign_hoist", -6.0)
	if down:
		_wordmark.sew_in(0.9, 0.35)


## Ease the camera toward the active page's viewpoint (position + rotation), with a slow
## drift around it so the town never sits as a still photograph.
func _process(delta: float) -> void:
	if _target == null:
		return
	_drift += delta
	var goal := _target.global_transform
	goal.origin += goal.basis.x * sin(_drift * 0.23) * DRIFT.x
	goal.origin += goal.basis.y * sin(_drift * 0.17 + 1.3) * DRIFT.y
	var w := clampf(delta * CAM_SPEED, 0.0, 1.0)
	_camera.global_transform = _camera.global_transform.interpolate_with(goal, w)


func _view(nm: String) -> Node3D:
	return _viewpoints.get_node_or_null(nm) as Node3D


func _unhandled_input(event: InputEvent) -> void:
	# A stray event can arrive mid scene-swap once we've handed off. Cache the viewport
	# up front so both branches use a verified-non-null reference.
	var vp := get_viewport()
	if vp == null or _controls != null:
		return
	# Esc backs out of the load list; on the main page it's swallowed so it can't reach
	# GameState and unpause the frozen sim behind the menu.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _sub:
			Sfx.play("ui_cancel", -4.0)
			_show_main()
		vp.set_input_as_handled()
		return
	if MenuKit.handle_nav(event, _buttons):
		vp.set_input_as_handled()


func _show_main() -> void:
	_sub = false
	_target = _view(VIEW_MAIN)
	_clear()
	_set_page("")
	if SaveManager.has_any_save():
		_buttons.add_child(_continue_button())
	_buttons.add_child(MenuKit.button("New Game", _new_game))
	_buttons.add_child(MenuKit.button("Load Game", _show_load))
	_buttons.add_child(MenuKit.button("Controls", _show_controls))
	_buttons.add_child(MenuKit.button("Settings", _show_settings))
	_buttons.add_child(MenuKit.button("Quit", func() -> void: get_tree().quit()))
	for child in _buttons.get_children():
		if child is Button:
			child.custom_minimum_size.x = COLUMN_W
	_focus_first()


func _show_controls() -> void:
	_controls = ControlsScreen.open(_root)
	_controls.closed.connect(
		func() -> void:
			_controls = null
			_focus_first()
	)


func _show_settings() -> void:
	_sub = true
	_target = _view(VIEW_SETTINGS)
	_clear()
	_set_page("Settings")
	SettingsUI.build(_buttons)
	_buttons.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _show_load() -> void:
	_sub = true
	_target = _view(VIEW_LOAD)
	_clear()
	_set_page("Load a save")
	for info: Dictionary in SaveManager.load_infos():
		var slot: Variant = info["slot"]
		if bool(info.get("exists", false)):
			_buttons.add_child(MenuKit.slot_row(info, func() -> void: _load(slot)))
		else:
			var empty := MenuKit.slot_row(info, Callable())
			empty.disabled = true
			_buttons.add_child(empty)
	_buttons.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


## Continue, with "Day 12 · $1,840" as a small second line inside the label, so the
## player knows what they are continuing without it taking a row of its own.
func _continue_button() -> Button:
	var button := MenuKit.button("Continue", _continue)
	var text := _latest_text()
	if text == "":
		return button
	button.custom_minimum_size.y = MenuKit.BTN_WIDE.y + CAPTION_ROOM
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var sb := button.get_theme_stylebox(state)
		sb.content_margin_bottom += CAPTION_ROOM
	var lbl := TitleBlock.meta_label(text, false)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -CAPTION_ROOM - Style.S2
	lbl.offset_bottom = -Style.S2
	button.add_child(lbl)
	return button


func _latest_text() -> String:
	var latest: Variant = SaveManager.latest_slot()
	if latest == null:
		return ""
	var info := SaveManager.info(latest)  # the autosave too, not only the numbered slots
	if not bool(info.get("exists", false)):
		return ""
	return "Day %d  ·  $%d" % [int(info.get("day", 1)), int(info.get("money", 0))]


func _new_game() -> void:
	_hand_off()
	SaveManager.new_game()


func _continue() -> void:
	var slot: Variant = SaveManager.latest_slot()
	if slot != null:
		_hand_off()
		SaveManager.load_from(slot)


func _load(slot: Variant) -> void:
	_hand_off()
	SaveManager.load_from(slot)


## About to swap scenes — stop reacting to input so no stray event hits this menu
## while it's being torn down.
func _hand_off() -> void:
	set_process_unhandled_input(false)


func _clear() -> void:
	# queue_free (not free): _clear runs from a button's own pressed handler, and a node
	# can't be freed while it's mid-emit. Hide now so the container drops it from layout
	# this frame and the new buttons don't briefly overlap the old.
	for child in _buttons.get_children():
		child.hide()
		child.queue_free()


func _focus_first() -> void:
	await get_tree().process_frame
	Craft.pop_in(_plate, 0.94, 0.3)
	for child in _buttons.get_children():
		if child is Button and child.visible and not child.disabled:
			if child is CraftButton:
				child.focus_quietly()
			else:
				child.grab_focus()
			return
