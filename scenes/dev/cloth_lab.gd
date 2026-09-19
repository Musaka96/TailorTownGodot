extends Control

## Cloth Lab — dev harness for the cloth look (docs/RESEARCH_cloth_look.md). Open this
## scene and press F6. Pick a subject (a suit on a rig, fabric / pattern lineups, a flat
## swatch for raking light, the item models), then tune every cloth dial live. Per-fabric
## and per-pattern dials edit the lab's working copy of the ClothMaterial tables for the
## fabric / pattern selected above them; "Copy tuning" puts those tables on the clipboard
## as GDScript, ready to paste into data/scripts/cloth_material.gd.
##
## Judge everything at the "Gameplay cam" preset — close-ups lie.
##
## Command-line (for automated shots via tools/screenshot.gd, after the scene/out/frames
## args): subject=N fabric=N pattern=N color=N preset=live|off|tier1 cam=game light=raking
## rim=V (selected fabric), or any global dial as key=V (e.g. rim_tint=0.3). Order matters.

const RIG_SCENE := preload("res://entities/character/character_rig.tscn")
const ROLL_SCENE := preload("res://entities/items/material_roll.tscn")
const PIECE_SCENE := preload("res://entities/items/garment_piece.tscn")
const SUIT_SCENE := preload("res://entities/items/suit.tscn")
const SUBJECTS := ["Suit on rig", "Fabric lineup", "Pattern lineup", "Flat cloth", "Items row"]
# Camera look-at height per subject for the free (non-gameplay) view.
const SUBJECT_FOCUS := [1.0, 1.0, 1.0, 0.7, 0.3]
# Free-view camera distance per subject, so a whole lineup fits in frame.
const SUBJECT_DIST := [4.6, 8.5, 16.0, 5.0, 6.0]
const RIG_SPACING := 1.3
# The five suitings, left to right, in the fabric lineup.
const SUITINGS := [0, 1, 2, 3, 4]
# Pattern lineup pages: suitings, then shirtings (14 animated rigs at once is heavy).
const PATTERN_PAGES := [[0, 1, 2, 3, 4, 5, 6, 7, 8], [9, 10, 11, 12, 13]]
const FLAT_UV_SCALE := 6.0  # matches CharacterRig.CLOTH_UV_SCALE
const SKIN := Color(0.8, 0.62, 0.48)
const HAIR := Color(0.35, 0.22, 0.12)
# Gameplay camera (scenes/camera/camera_rig.tscn): 55 deg down, 7.66 m out, default fov.
const GAME_PITCH := 55.0
const GAME_DIST := 7.66
const GAME_FOV := 75.0
# Tier 1 bundle: the tuned values the "Tier 1" preset switches on. Features whose
# uniform isn't in the shader yet are shown greyed out and never sent.
const TIER1 := {"normal_depth": 1.8, "macro_strength": 0.12}
# Globals that live on the base .tres (tools/build_cloth_materials.gd).
const BASE_KEYS := [
	"fabric_strength", "pattern_strength", "pattern_relief", "rim_power", "rim_tint"
]
# Global shader dials: [key, label, min, max, step].
const GLOBAL_DIALS := [
	["fabric_strength", "fabric_strength", 0.0, 1.0, 0.01],
	["pattern_strength", "pattern_strength", 0.0, 1.0, 0.01],
	["pattern_relief", "pattern_relief", 0.0, 1.0, 0.01],
	["scale_mult", "uv/tri scale  x", 0.25, 3.0, 0.05],
]
# Feature dials with an enable checkbox: [key, label, min, max, step].
const FEATURE_DIALS := [
	["normal_depth", "normal_depth  (B2)", 0.0, 3.0, 0.05],
	["macro_strength", "macro_strength  (B4)", 0.0, 0.3, 0.005],
	["shot_strength", "shot_strength  (C2)", 0.0, 0.5, 0.01],
]

var _view: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _root3d: Node3D
var _status: Label
var _pc2_button: ColorPickerButton
var _subject := 0
var _page := 0
var _fabric := 0
var _pattern := 1
var _cloth := Color("1b2a4a")
var _accent := 0
var _pattern_color2 := Color("7a2230")
var _dress_shirt := false
var _turntable := false
var _freeze := false
# Working copies of the ClothMaterial tables (what Copy tuning exports).
var _rim: Array = []
var _pscale: Array = []
var _pint: Array = []
var _g := {}  # global dial values by key
var _on := {}  # feature enable flags by key ("rim", "normal_depth", ...)
var _ab_new := true  # A/B toggle state: true = Tier 1 look, false = pre-Tier-1
var _uniforms := {}  # uniform names present in cloth.gdshader
# Every node the lab dresses: {node, kind, fabric, pattern} (-1 = follow the controls).
var _dressers: Array = []
# Every live cloth material: {sm, fabric, pattern, scale_param, scale}.
var _entries: Array = []
var _sliders := {}
var _val_labels := {}
var _checks := {}
var _fabric_opt: OptionButton
var _pattern_opt: OptionButton
var _color_btn: ColorPickerButton
var _az := -32.0
var _el := 38.0
var _sun_energy := 1.0
var _ambient := 1.05
var _dist := 4.6
var _yaw := 0.0
var _pitch := 8.0
var _focus_y := 1.0
var _fov := 35.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_show_game_hud(false)
	_read_uniforms()
	_load_live()
	_build()
	_build_subject()
	_apply_light()
	_apply_view()
	_apply_cmdline()


func _exit_tree() -> void:
	_show_game_hud(true)


func _process(delta: float) -> void:
	if not _turntable:
		return
	for d: Dictionary in _dressers:
		var n := d["node"] as Node3D
		if is_instance_valid(n):
			n.rotation.y += delta * 0.4


## The game HUD autoload (clock, rating, money) would sit over the control column.
func _show_game_hud(on: bool) -> void:
	var hud := get_tree().root.get_node_or_null("UI")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = on
	elif hud is CanvasItem:
		(hud as CanvasItem).visible = on


# --- Layout ----------------------------------------------------------------


func _build() -> void:
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	add_child(split)

	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	scroll.add_child(col)
	left.add_child(scroll)
	split.add_child(left)

	var right := SubViewportContainer.new()
	right.stretch = true
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = false
	_view.msaa_3d = Viewport.MSAA_2X
	right.add_child(_view)
	split.add_child(right)
	_build_world()
	_build_controls(col)


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.5, 0.55, 0.62)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.9, 0.9, 0.95)
	var we := WorldEnvironment.new()
	we.environment = _env
	_view.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_view.add_child(_sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mi.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.46, 0.44, 0.42)
	floor_mat.roughness = 1.0
	floor_mi.material_override = floor_mat
	_view.add_child(floor_mi)
	_root3d = Node3D.new()
	_view.add_child(_root3d)
	_cam = Camera3D.new()
	_view.add_child(_cam)
	_cam.current = true


func _build_controls(col: VBoxContainer) -> void:
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_heading("Subject"))
	col.add_child(_dropdown("Subject", SUBJECTS, _subject, _on_subject))
	col.add_child(_dropdown("Pattern page", ["Suitings 0-8", "Shirtings 9-13"], 0, _on_page))
	col.add_child(_check("Dress the shirt too", "shirt", _dress_shirt, _on_shirt))
	col.add_child(_check("Turntable", "turntable", _turntable, _on_turntable))
	col.add_child(_check("Freeze animation", "freeze", _freeze, _on_freeze))
	_build_material_controls(col)
	_build_dial_controls(col)
	_build_light_controls(col)
	_build_camera_controls(col)
	col.add_child(_heading("Export"))
	col.add_child(_button("Copy tuning", _copy_tuning))
	col.add_child(_status)


func _build_material_controls(col: VBoxContainer) -> void:
	col.add_child(_heading("Material"))
	var fab := _dropdown("Fabric", _fabric_names(), _fabric, _on_fabric)
	_fabric_opt = fab.get_child(1)
	col.add_child(fab)
	var pat := _dropdown("Pattern", _pattern_names(), _pattern, _on_pattern)
	_pattern_opt = pat.get_child(1)
	col.add_child(pat)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Cloth colour"
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	_color_btn = ColorPickerButton.new()
	_color_btn.color = _cloth
	_color_btn.edit_alpha = false
	_color_btn.custom_minimum_size = Vector2(0, 26)
	_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_btn.color_changed.connect(_on_cloth_color)
	row.add_child(_color_btn)
	col.add_child(row)
	col.add_child(_mill_swatches())
	var accents: Array = []
	for i in MaterialFactory.pattern_accent_count():
		accents.append(MaterialFactory.pattern_accent_name(i))
	col.add_child(_dropdown("Accent dye", accents, _accent, _on_accent))


func _build_dial_controls(col: VBoxContainer) -> void:
	col.add_child(_heading("Presets"))
	var presets := HBoxContainer.new()
	presets.add_child(_button("Current live", _preset_live))
	presets.add_child(_button("Everything off", _preset_off))
	presets.add_child(_button("Tier 1", _preset_tier1))
	col.add_child(presets)
	col.add_child(_button("A / B  old-new  (Tab)", _ab_toggle))
	col.add_child(_heading("Global dials"))
	for d: Array in GLOBAL_DIALS:
		col.add_child(_slider(d[1], d[2], d[3], d[4], _g[d[0]], _on_global.bind(d[0]), d[0]))
	col.add_child(_heading("Per pattern  (edits the selected pattern)"))
	col.add_child(
		_slider("pattern_scale", 0.2, 3.0, 0.05, _pscale[_pattern], _on_pscale, "pattern_scale")
	)
	col.add_child(
		_slider("pattern_intensity", 0.0, 1.5, 0.01, _pint[_pattern], _on_pint, "pattern_intensity")
	)
	col.add_child(_heading("Tier 1  (tick = on; A/B each alone)"))
	col.add_child(_check("Rim sheen  (B1)", "rim", _on["rim"], _on_feature.bind("rim")))
	col.add_child(
		_slider("rim_strength  (selected fabric)", 0.0, 1.0, 0.01, _rim[_fabric], _on_rim, "rim")
	)
	var rim_cb := _on_global.bind("rim_power")
	var rim_power: float = _g["rim_power"]
	var rim_label := "rim_power  (higher = thinner)"
	col.add_child(_slider(rim_label, 0.5, 8.0, 0.1, rim_power, rim_cb, "rim_power"))
	var tint_cb := _on_global.bind("rim_tint")
	var tint: float = _g["rim_tint"]
	var tint_label := "rim_tint  (0 white, 1 cloth colour)"
	col.add_child(_slider(tint_label, 0.0, 1.0, 0.05, tint, tint_cb, "rim_tint"))
	for d: Array in FEATURE_DIALS:
		var key: String = d[0]
		col.add_child(_check("Enable", key, _on[key], _on_feature.bind(key)))
		col.add_child(_slider(d[1], d[2], d[3], d[4], _g[key], _on_global.bind(key), key))
		_grey_if_missing(key)
	col.add_child(_pattern_color2_row())


func _build_light_controls(col: VBoxContainer) -> void:
	col.add_child(_heading("Light"))
	col.add_child(_slider("Sun azimuth", -180, 180, 1, _az, _on_light.bind("az"), "az"))
	col.add_child(_slider("Sun elevation", 5, 80, 1, _el, _on_light.bind("el"), "el"))
	col.add_child(_slider("Sun energy", 0.0, 3.0, 0.05, _sun_energy, _on_light.bind("sun"), "sun"))
	col.add_child(_slider("Ambient energy", 0.0, 2.0, 0.05, _ambient, _on_light.bind("amb"), "amb"))
	col.add_child(_check("Shadows", "shadows", true, _on_shadows))
	var row := HBoxContainer.new()
	row.add_child(_button("Raking", _preset_raking))
	row.add_child(_button("Default light", _preset_default_light))
	col.add_child(row)


func _build_camera_controls(col: VBoxContainer) -> void:
	col.add_child(_heading("Camera"))
	col.add_child(_slider("Zoom (m)", 0.6, 14.0, 0.05, _dist, _on_cam.bind("dist"), "dist"))
	col.add_child(_slider("Orbit", -180, 180, 1, _yaw, _on_cam.bind("yaw"), "yaw"))
	col.add_child(_slider("Pitch (down)", -20, 85, 1, _pitch, _on_cam.bind("pitch"), "pitch"))
	col.add_child(_slider("Look height", 0.0, 1.8, 0.02, _focus_y, _on_cam.bind("y"), "y"))
	col.add_child(_slider("FOV", 15, 80, 1, _fov, _on_cam.bind("fov"), "fov"))
	var row := HBoxContainer.new()
	row.add_child(_button("Gameplay cam", _preset_game_cam))
	row.add_child(_button("Close-up", _preset_close_cam))
	col.add_child(row)


# --- Control builders ------------------------------------------------------


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	return l


func _dropdown(label: String, items: Array, current: int, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		opt.add_item(str(items[i]), i)
	opt.selected = clampi(current, 0, maxi(0, items.size() - 1))
	opt.item_selected.connect(cb)
	row.add_child(opt)
	return row


func _slider(
	label: String, lo: float, hi: float, step: float, value: float, cb: Callable, key := ""
) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := Label.new()
	val.text = _fmt(value, step)
	head.add_child(val)
	box.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.scrollable = false
	s.value_changed.connect(func(v: float) -> void: val.text = _fmt(v, step))
	s.value_changed.connect(cb)
	s.gui_input.connect(_slider_wheel.bind(s, step))
	box.add_child(s)
	if not key.is_empty():
		_sliders[key] = s
		_val_labels[key] = val
	return box


func _check(label: String, key: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = on
	c.toggled.connect(cb)
	_checks[key] = c
	return c


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


## One click-to-pick swatch per standard mill colour (MaterialFactory.COLORS).
func _mill_swatches() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for i in MaterialFactory.color_count():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 22)
		b.tooltip_text = MaterialFactory.color_name(i)
		var sb := StyleBoxFlat.new()
		sb.bg_color = MaterialFactory.color_value(i)
		sb.set_corner_radius_all(3)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(_on_mill_color.bind(i))
		grid.add_child(b)
	return grid


## Tier 2 stub: the second accent colour (C1). Greyed out until the uniform exists.
func _pattern_color2_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_check("pattern_color2 (C1)", "pattern_color2", false, _on_pc2_toggle))
	_pc2_button = ColorPickerButton.new()
	_pc2_button.color = _pattern_color2
	_pc2_button.edit_alpha = false
	_pc2_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pc2_button.color_changed.connect(_on_pc2_color)
	row.add_child(_pc2_button)
	if not _uniforms.has("pattern_color2"):
		(_checks["pattern_color2"] as CheckBox).disabled = true
		_pc2_button.disabled = true
	return row


## Grey out a feature's controls when the shader has no uniform for it yet.
func _grey_if_missing(key: String) -> void:
	if _uniforms.has(key):
		return
	(_checks[key] as CheckBox).disabled = true
	(_checks[key] as CheckBox).text = "Enable  (not in shader yet)"
	(_sliders[key] as HSlider).editable = false


func _slider_wheel(event: InputEvent, s: HSlider, step: float) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	var dir := 0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		dir = 1
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		dir = -1
	if dir == 0 or not s.editable:
		return
	var mult := 0.1 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	s.value = snappedf(s.value + dir * step * mult, step * mult)
	accept_event()


func _set_slider(key: String, v: float) -> void:
	if not _sliders.has(key):
		return
	var s: HSlider = _sliders[key]
	s.set_value_no_signal(v)
	(_val_labels[key] as Label).text = _fmt(v, s.step)


func _set_check(key: String, on: bool) -> void:
	if _checks.has(key):
		(_checks[key] as CheckBox).set_pressed_no_signal(on)


# --- Subjects --------------------------------------------------------------


## (Re)build the viewport contents for the current subject, then dress them.
func _build_subject() -> void:
	for c in _root3d.get_children():
		_root3d.remove_child(c)
		c.queue_free()
	_dressers.clear()
	match _subject:
		1:
			for i in SUITINGS.size():
				_add_rig(Vector3((i - 2) * RIG_SPACING, 0, 0), SUITINGS[i], -1)
		2:
			var page: Array = PATTERN_PAGES[_page]
			for i in page.size():
				var x := (i - (page.size() - 1) * 0.5) * RIG_SPACING
				_add_rig(Vector3(x, 0, 0), -1, page[i])
		3:
			_add_flat()
		4:
			_add_items()
		_:
			_add_rig(Vector3.ZERO, -1, -1)
	_restyle()
	_preset_close_cam()


func _add_rig(pos: Vector3, fabric: int, pattern: int) -> void:
	var rig := RIG_SCENE.instantiate() as Node3D
	rig.position = pos
	_root3d.add_child(rig)
	rig.set_head(0)
	rig.set_hair(0)
	rig.set_palette(SKIN)
	rig.set_hair_color(HAIR)
	var ap := rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.play("idle")
	_dressers.append({"node": rig, "kind": "rig", "fabric": fabric, "pattern": pattern})
	_apply_freeze(rig)


func _add_flat() -> void:
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2, 2)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	sheet.mesh = plane
	sheet.position = Vector3(-0.7, 0.75, 0)
	sheet.rotation_degrees = Vector3(30, 0, 0)
	_root3d.add_child(sheet)
	_dressers.append({"node": sheet, "kind": "mesh", "fabric": -1, "pattern": -1})
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 1.3
	cyl.radial_segments = 48
	tube.mesh = cyl
	tube.position = Vector3(1.2, 0.65, 0)
	_root3d.add_child(tube)
	_dressers.append({"node": tube, "kind": "mesh", "fabric": -1, "pattern": -1})


## The item models, fed the current cloth: roll (UV), shelf roll (triplanar), a cut
## jacket piece and an assembled suit — UV-vs-triplanar parity check.
func _add_items() -> void:
	var mat := _material(_fabric, _pattern)
	var roll := ROLL_SCENE.instantiate() as Node3D
	roll.material = mat
	_place_item(roll, -1.5, "roll")
	var shelf := ROLL_SCENE.instantiate() as Node3D
	shelf.material = mat
	_place_item(shelf, -0.5, "roll_tri")
	var piece := PIECE_SCENE.instantiate() as Node3D
	piece.material = mat
	piece.garment_type = Enums.GarmentType.JACKET
	_place_item(piece, 0.5, "piece")
	_place_item(SUIT_SCENE.instantiate() as Node3D, 1.5, "suit")


func _place_item(item: Node3D, x: float, kind: String) -> void:
	item.position = Vector3(x, 0, 0)
	_root3d.add_child(item)
	_dressers.append({"node": item, "kind": kind, "fabric": -1, "pattern": -1})


## Re-dress every subject node with fresh materials (fabric / pattern / shirt changed),
## re-collect the live materials, then push every dial onto them.
func _restyle() -> void:
	_entries.clear()
	for d: Dictionary in _dressers:
		var f: int = _fabric if int(d["fabric"]) < 0 else int(d["fabric"])
		var p: int = _pattern if int(d["pattern"]) < 0 else int(d["pattern"])
		_dress(d["node"], String(d["kind"]), _material(f, p))
		_collect(d["node"], f, p)
	_push_all()


func _dress(node: Node3D, kind: String, mat: MaterialType) -> void:
	match kind:
		"rig":
			node.set_outfit(mat, mat if _dress_shirt else null, mat)
		"mesh":
			(node as MeshInstance3D).material_override = ClothMaterial.build(mat, FLAT_UV_SCALE)
		"roll", "piece":
			node.material = mat
			node._apply_visual()
		"roll_tri":
			node.material = mat
			var mesh := node.get_node("Mesh") as MeshInstance3D
			mesh.material_override = ClothMaterial.build_triplanar(mat)
		"suit":
			node.parts = {Enums.GarmentType.JACKET: {"material": mat}}
			node._apply_visual()


## Register every cloth ShaderMaterial under `node` (outline next_passes are skipped:
## that material is a shared static instance).
func _collect(node: Node, fabric: int, pattern: int) -> void:
	if node is MeshInstance3D:
		var sm := (node as MeshInstance3D).material_override as ShaderMaterial
		if sm != null and _is_cloth(sm):
			var tri := sm.shader == ClothMaterial.SHADER_TRIPLANAR
			var param := "tri_scale" if tri else "uv_scale"
			var e := {"sm": sm, "fabric": fabric, "pattern": pattern, "scale_param": param}
			e["scale"] = float(sm.get_shader_parameter(param))
			_entries.append(e)
	for c in node.get_children():
		_collect(c, fabric, pattern)


func _is_cloth(sm: ShaderMaterial) -> bool:
	return sm.shader == ClothMaterial.SHADER or sm.shader == ClothMaterial.SHADER_TRIPLANAR


func _material(fabric: int, pattern: int) -> MaterialType:
	var mat := MaterialType.new()
	mat.fabric = fabric as Enums.Fabric
	mat.pattern = pattern as Enums.Pattern
	mat.cloth_color = _cloth
	mat.pattern_color = MaterialFactory.pattern_color_for(_cloth, _accent)
	mat.display_name = "Lab cloth"
	return mat


# --- Pushing dials ---------------------------------------------------------


func _push_all() -> void:
	var accent := MaterialFactory.pattern_color_for(_cloth, _accent)
	for e: Dictionary in _entries:
		_push(e, accent)
	_status.text = "%d cloth materials live" % _entries.size()


func _push(e: Dictionary, accent: Color) -> void:
	var sm: ShaderMaterial = e["sm"]
	var f: int = e["fabric"]
	var p: int = e["pattern"]
	_set_param(sm, "cloth_color", _cloth)
	_set_param(sm, "pattern_color", accent)
	for key: String in BASE_KEYS:
		_set_param(sm, key, _g[key])
	_set_param(sm, e["scale_param"], float(e["scale"]) * float(_g["scale_mult"]))
	_set_param(sm, "pattern_scale", _pscale[p])
	_set_param(sm, "pattern_intensity", _pint[p])
	_set_param(sm, "rim_strength", _rim[f] if _on["rim"] else 0.0)
	for d: Array in FEATURE_DIALS:
		var key: String = d[0]
		_set_param(sm, key, _g[key] if _on[key] else 0.0)
	if _on["pattern_color2"]:
		_set_param(sm, "pattern_color2", _pattern_color2)


## Only uniforms the shader actually has — the Tier 2 stubs are never sent early.
func _set_param(sm: ShaderMaterial, key: String, v: Variant) -> void:
	if _uniforms.has(key):
		sm.set_shader_parameter(key, v)


func _read_uniforms() -> void:
	for u: Dictionary in ClothMaterial.SHADER.get_shader_uniform_list():
		_uniforms[String(u["name"])] = true


# --- Handlers --------------------------------------------------------------


func _on_subject(i: int) -> void:
	_subject = i
	_build_subject()


func _on_page(i: int) -> void:
	_page = i
	if _subject == 2:
		_build_subject()


func _on_shirt(on: bool) -> void:
	_dress_shirt = on
	_restyle()


func _on_turntable(on: bool) -> void:
	_turntable = on
	if not on:
		for d: Dictionary in _dressers:
			(d["node"] as Node3D).rotation.y = 0.0


func _on_freeze(on: bool) -> void:
	_freeze = on
	for d: Dictionary in _dressers:
		if d["kind"] == "rig":
			_apply_freeze(d["node"])


func _apply_freeze(rig: Node) -> void:
	rig.process_mode = Node.PROCESS_MODE_DISABLED if _freeze else Node.PROCESS_MODE_INHERIT


func _on_fabric(i: int) -> void:
	_fabric = i
	_set_slider("rim", _rim[i])
	_restyle()


func _on_pattern(i: int) -> void:
	_pattern = i
	_set_slider("pattern_scale", _pscale[i])
	_set_slider("pattern_intensity", _pint[i])
	_restyle()


func _on_cloth_color(c: Color) -> void:
	_cloth = c
	_push_all()


func _on_mill_color(i: int) -> void:
	_cloth = MaterialFactory.color_value(i)
	_color_btn.color = _cloth
	_push_all()


func _on_accent(i: int) -> void:
	_accent = i
	_push_all()


func _on_global(v: float, key: String) -> void:
	_g[key] = v
	_push_all()


func _on_pscale(v: float) -> void:
	_pscale[_pattern] = v
	_push_all()


func _on_pint(v: float) -> void:
	_pint[_pattern] = v
	_push_all()


func _on_rim(v: float) -> void:
	_rim[_fabric] = v
	_push_all()


func _on_feature(on: bool, key: String) -> void:
	_on[key] = on
	_push_all()


func _on_pc2_toggle(on: bool) -> void:
	_on["pattern_color2"] = on
	_push_all()


func _on_pc2_color(c: Color) -> void:
	_pattern_color2 = c
	_push_all()


func _on_light(v: float, key: String) -> void:
	match key:
		"az":
			_az = v
		"el":
			_el = v
		"sun":
			_sun_energy = v
		"amb":
			_ambient = v
	_apply_light()


func _on_shadows(on: bool) -> void:
	_sun.shadow_enabled = on


func _on_cam(v: float, key: String) -> void:
	match key:
		"dist":
			_dist = v
		"yaw":
			_yaw = v
		"pitch":
			_pitch = v
		"y":
			_focus_y = v
		"fov":
			_fov = v
	_apply_view()


# --- Presets ---------------------------------------------------------------


## Seed every dial from what the game renders today: the base .tres globals and the
## ClothMaterial tables. Features the game doesn't have yet start at 0 / off.
func _load_live() -> void:
	var base := load(ClothMaterial.BASE_PATH) as ShaderMaterial
	for key: String in BASE_KEYS:
		var v: Variant = base.get_shader_parameter(key) if base != null else null
		_g[key] = float(v) if v != null else 0.0
	_g["scale_mult"] = 1.0
	_rim = ClothMaterial.FABRIC_RIM.duplicate()
	_pscale = ClothMaterial.PATTERN_SCALE.duplicate()
	_pint = ClothMaterial.PATTERN_INTENSITY.duplicate()
	_on["rim"] = true
	_on["pattern_color2"] = false
	# Feature dials read their LIVE values off the base .tres too (B2/B4 ship on);
	# a Tier 2 stub that isn't on the .tres yet stays 0/off.
	for d: Array in FEATURE_DIALS:
		var v: Variant = base.get_shader_parameter(d[0]) if base != null else null
		_g[d[0]] = float(v) if v != null else 0.0
		_on[d[0]] = _g[d[0]] > 0.0


func _preset_live() -> void:
	_load_live()
	_sync_dials()
	_status.text = "Preset: current live"


## The pre-Tier-1 look: every new feature off, the existing dials as live.
func _preset_off() -> void:
	_load_live()
	_on["rim"] = false
	for d: Array in FEATURE_DIALS:
		_on[d[0]] = false
	_sync_dials()
	_status.text = "Preset: everything off (pre-Tier-1)"


## One-key flip between the old look and the Tier 1 bundle — stare at the suit
## and hammer Tab until you see it.
func _ab_toggle() -> void:
	_ab_new = not _ab_new
	if _ab_new:
		_preset_tier1()
	else:
		_preset_off()
	_status.text = "A/B: %s  (Tab flips)" % ("NEW — Tier 1" if _ab_new else "OLD — pre-Tier-1")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_TAB:
			_ab_toggle()
			get_viewport().set_input_as_handled()


func _preset_tier1() -> void:
	_load_live()
	for key: String in TIER1:
		if _uniforms.has(key):
			_g[key] = TIER1[key]
			_on[key] = true
	_sync_dials()
	_status.text = "Preset: Tier 1"


## Push the dial state back into every control, then onto the materials.
func _sync_dials() -> void:
	for d: Array in GLOBAL_DIALS:
		_set_slider(d[0], _g[d[0]])
	for d: Array in FEATURE_DIALS:
		_set_slider(d[0], _g[d[0]])
		_set_check(d[0], _on[d[0]])
	_set_slider("rim_power", _g["rim_power"])
	_set_slider("rim_tint", _g["rim_tint"])
	_set_slider("rim", _rim[_fabric])
	_set_slider("pattern_scale", _pscale[_pattern])
	_set_slider("pattern_intensity", _pint[_pattern])
	_set_check("rim", _on["rim"])
	_set_check("pattern_color2", _on["pattern_color2"])
	_push_all()


func _preset_raking() -> void:
	_set_light(90.0, 8.0)


func _preset_default_light() -> void:
	_set_light(-32.0, 38.0)


func _set_light(az: float, el: float) -> void:
	_az = az
	_el = el
	_set_slider("az", az)
	_set_slider("el", el)
	_apply_light()


func _preset_game_cam() -> void:
	_set_cam(GAME_DIST, 0.0, GAME_PITCH, 0.0, GAME_FOV)


func _preset_close_cam() -> void:
	_set_cam(SUBJECT_DIST[_subject], 0.0, 8.0, SUBJECT_FOCUS[_subject], 35.0)


func _set_cam(dist: float, yaw: float, pitch: float, y: float, fov: float) -> void:
	_dist = dist
	_yaw = yaw
	_pitch = pitch
	_focus_y = y
	_fov = fov
	for pair: Array in [["dist", dist], ["yaw", yaw], ["pitch", pitch], ["y", y], ["fov", fov]]:
		_set_slider(pair[0], pair[1])
	_apply_view()


# --- Applying --------------------------------------------------------------


func _apply_light() -> void:
	_sun.rotation_degrees = Vector3(-_el, _az, 0)
	_sun.light_energy = _sun_energy
	_env.ambient_light_energy = _ambient


## Orbit the look-at point: `pitch` is degrees above the horizon (the gameplay camera
## sits 55 deg up, 7.66 m out, looking at the player's feet).
func _apply_view() -> void:
	var e := deg_to_rad(_pitch)
	var y := deg_to_rad(_yaw)
	var target := Vector3(0, _focus_y, 0)
	var dir := Vector3(sin(y) * cos(e), sin(e), cos(y) * cos(e))
	_cam.fov = _fov
	_cam.look_at_from_position(target + dir * _dist, target, Vector3.UP)


## key=value args after the screenshot tool's own (see the header).
func _apply_cmdline() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			_apply_arg(kv[0], kv[1])


func _apply_arg(key: String, value: String) -> void:
	match key:
		"subject":
			_subject = int(value)
			_build_subject()
		"fabric":
			_fabric_opt.select(int(value))
			_on_fabric(int(value))
		"pattern":
			_pattern_opt.select(int(value))
			_on_pattern(int(value))
		"color":
			_on_mill_color(int(value))
		"preset":
			var presets := {"live": _preset_live, "off": _preset_off, "tier1": _preset_tier1}
			if presets.has(value):
				(presets[value] as Callable).call()
		"cam":
			if value == "game":
				_preset_game_cam()
		"light":
			if value == "raking":
				_preset_raking()
		"rim":
			_rim[_fabric] = float(value)
			_sync_dials()
		_:
			if _g.has(key):
				_g[key] = float(value)
				_sync_dials()


# --- Export ----------------------------------------------------------------


## The tuned tables as GDScript, formatted like ClothMaterial's, on the clipboard.
func _copy_tuning() -> void:
	var out := "# Cloth Lab tuning — paste into data/scripts/cloth_material.gd\n"
	out += _table("FABRIC_RIM", _rim, _fabric_names())
	out += _table("PATTERN_SCALE", _pscale, _pattern_names())
	out += _table("PATTERN_INTENSITY", _pint, _pattern_names())
	out += "# Globals for tools/build_cloth_materials.gd:\n"
	for key: String in BASE_KEYS:
		out += '#   mat.set_shader_parameter("%s", %s)\n' % [key, _num(_g[key])]
	for d: Array in FEATURE_DIALS:
		var state := "on" if _on[d[0]] else "off"
		out += "#   %s = %s  (%s)\n" % [d[0], _num(_g[d[0]]), state]
	out += "#   rim sheen: %s\n" % ("on" if _on["rim"] else "off")
	DisplayServer.clipboard_set(out)
	print(out)
	_status.text = "Tuning copied to the clipboard (also printed to Output)"


func _table(const_name: String, values: Array, names: Array) -> String:
	var out := "const %s := [\n" % const_name
	for i in values.size():
		out += "\t%s,  # %s\n" % [_num(values[i]), String(names[i]).to_lower()]
	return out + "]\n"


func _num(v: float) -> String:
	var s := "%.3f" % v
	s = s.rstrip("0")
	return s + "0" if s.ends_with(".") else s


# --- Data helpers ----------------------------------------------------------


func _fabric_names() -> Array:
	var out: Array = []
	for i in Enums.Fabric.size():
		out.append(Enums.fabric_name(i as Enums.Fabric))
	return out


func _pattern_names() -> Array:
	var out: Array = []
	for i in Enums.Pattern.size():
		out.append(Enums.pattern_name(i as Enums.Pattern))
	return out


func _fmt(v: float, step: float) -> String:
	if step < 0.01:
		return "%.3f" % v
	if step < 1.0:
		return "%.2f" % v
	return "%d" % int(v)
