class_name TitleBlock
extends VBoxContainer

## The head of every panel (style guide §4.1), top-left:
##
##   ORDER PAD                     kicker — what surface this is, in the skin accent
##   Harrow's Haberdashery         title  — the specific thing, display face, ink
##   ━━━━╸ ─ ─ ─ ─ ─ ─ ─ ─ ─       rule   — bar tack + running stitch
##   Budget $500 · 3 rolls         meta   — optional; the one home for what sits under a title
##
## `right` shares the title's row (a minigame's slips and pips). `meta` is hidden until
## something is added to it. Build one with make(), or adopt() a Title label a scene
## already owns so the menu's `_title.text = ...` keeps working.

var title: Label
var kicker: Label
var right: HBoxContainer
var meta: HFlowContainer
var rule: StitchRule


static func make(text: String, kicker_text := "", accent := Style.BRASS) -> TitleBlock:
	var block := TitleBlock.new()
	block._build(Label.new(), kicker_text, accent)
	block.title.text = text
	return block


## Wrap a Title label that already lives in a scene: the block takes the label's place
## in its parent and the label moves inside it.
static func adopt(label: Label, kicker_text := "", accent := Style.BRASS) -> TitleBlock:
	var host := label.get_parent()
	var at := label.get_index()
	host.remove_child(label)
	var block := TitleBlock.new()
	block._build(label, kicker_text, accent)
	host.add_child(block)
	host.move_child(block, at)
	return block


## Plain caption text for the meta row; `strong` sets it in bold ink (a value).
static func meta_label(text: String, strong := false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", Style.font_bold() if strong else Style.font_body())
	lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
	lbl.add_theme_color_override("font_color", Style.INK if strong else Style.INK_SOFT)
	return lbl


func set_kicker(text: String) -> void:
	kicker.text = text.to_upper()
	kicker.visible = text != ""


func _build(label: Label, kicker_text: String, accent: Color) -> void:
	name = "TitleBlock"
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	kicker = Label.new()
	kicker.add_theme_font_override("font", Style.font_caps())
	kicker.add_theme_font_size_override("font_size", Style.T_MICRO)
	kicker.add_theme_color_override("font_color", Style.text_accent(accent))
	add_child(kicker)
	set_kicker(kicker_text)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	add_child(row)
	title = label
	title.add_theme_font_override("font", Style.font_display())
	title.add_theme_font_size_override("font_size", Style.T_TITLE)
	title.add_theme_color_override("font_color", Style.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	right = HBoxContainer.new()
	right.add_theme_constant_override("separation", Style.S2)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)

	rule = StitchRule.make(accent)
	add_child(rule)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, Style.S1)
	add_child(pad)
	meta = HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", Style.S3)
	meta.add_theme_constant_override("v_separation", Style.S1)
	meta.visible = false
	meta.child_entered_tree.connect(func(_n: Node) -> void: meta.visible = true)
	add_child(meta)
