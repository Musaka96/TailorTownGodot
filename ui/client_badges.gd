class_name ClientBadges
extends HFlowContainer

## A row of little stamp-style badges that say what kind of client this is at a glance:
## NEW CLIENT / REGULAR ★N, RUSH, PICKY, APPOINTMENT, REFERRAL. Built from a
## CustomerPreference (see FrontDesk / docs/CUSTOMERS.md). Used by the greeting bubble and
## the suit builder.


## Badges for `pref` (an empty row for a browser with no brief).
static func make(pref) -> ClientBadges:
	var row := ClientBadges.new()
	row.add_theme_constant_override("h_separation", Style.S1 + 2)
	row.add_theme_constant_override("v_separation", Style.S1)
	row.show_for(pref)
	return row


## Rebuild the badges for `pref`.
func show_for(pref) -> void:
	for c in get_children():
		c.queue_free()
	if pref == null:
		visible = false
		return
	visible = true
	if pref.regular_level > 0:
		add_child(_badge("REGULAR ★%d" % pref.regular_level, Style.BRASS, Style.WALNUT))
	else:
		add_child(_badge("NEW CLIENT", Style.CARD, Style.INK_SOFT))
	if pref.arrival == "appointment":
		add_child(_badge("APPOINTMENT", Style.FOREST, Style.CHALK))
	elif pref.arrival == "referral":
		add_child(_badge("REFERRED", Style.PATCH, Style.CHALK))
	if pref.rush:
		var bonus := roundi(FrontDesk.RUSH_BONUS * 100.0)
		add_child(_badge("RUSH · TOMORROW · +%d%%" % bonus, Style.CLAY, Style.CHALK))
	if pref.picky:
		add_child(_badge("PICKY · 2× TIPS", Style.BURGUNDY, Style.CHALK))


func _badge(text: String, fill: Color, ink: Color) -> Control:
	var tag := CraftPanel.new()
	tag.pad = Vector2(Style.S2, 1)
	tag.setup(
		CraftPanel.Shape.ROUNDED,
		fill,
		ink.darkened(0.2) if fill == Style.CARD else fill.darkened(0.35)
	)
	tag.radius = 8.0
	tag.line_width = 1.5
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", Style.bold_font())
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", ink)
	tag.add_child(lbl)
	return tag
