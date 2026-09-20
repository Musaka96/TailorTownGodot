extends SceneTree

## Generates the default dress-code rulebook (res://data/dress_code.tres) — one
## rule per occasion x style. Edit the .tres in the Inspector afterwards to tune;
## re-run this to reset to defaults (won't overwrite unless you delete it first is
## not enforced — it always writes).
##   godot --headless --path . --script res://tools/build_dress_code.gd
##
## Colour indices: 0 Navy 1 Charcoal 2 LightGrey 3 Black 4 Tan 5 Brown 6 Blue
##                 7 Burgundy 8 Olive 9 Forest
## Pattern indices: 0 Solid 1 Pinstripe 2 Herringbone 3 Houndstooth 4 Windowpane
##                  5 GlenCheck 6 Birdseye 7 Sharkskin 8 Nailhead
## Occasion: 0 Wedding 1 Funeral 2 Business 3 Party
## Style:    0 Old-School 1 Classic 2 Modern 3 Fashion

const OUT := "res://data/dress_code.tres"
const DRESS_RULE := "res://data/scripts/dress_rule.gd"
const DRESS_CODE := "res://data/scripts/dress_code.gd"

# [occasion, style, colors, patterns, require_pattern, hint]
const RULES := [
	[0, 0, [1, 0, 3], [1, 2, 0], false, "Dark, the old way. Pinstripe or plain."],
	[0, 1, [0, 1, 2], [0, 2, 7], false, "Navy or grey. Nothing that shouts."],
	[0, 2, [0, 6, 7, 2], [0, 7, 6, 5], false, "Lighter colour, clean lines."],
	[0, 3, [4, 2, 6, 7, 8], [5, 4, 3], true, "Light and loud. It must have a pattern."],
	[1, 0, [3, 1], [0, 2, 6], false, "Mourning black. A fine weave at most."],
	[1, 1, [3, 1, 0], [0, 7, 8], false, "Black or charcoal, and plain."],
	[1, 2, [3, 1, 0, 9, 7], [0, 7, 8, 6], false, "Dark. A deep colour will pass."],
	[1, 3, [1, 3, 7, 9], [4, 5, 3], true, "Dark cloth, bold pattern. Both."],
	[2, 0, [1, 0], [1, 2, 0], false, "The banker's suit. Pinstripe, dark."],
	[2, 1, [0, 1, 2], [0, 1, 7, 8], false, "Navy or grey. Keep the pattern small."],
	[2, 2, [0, 6, 1, 2], [0, 7, 5, 6], false, "Sharp, with a texture in the cloth."],
	[2, 3, [6, 2, 7, 8], [4, 5, 3], true, "Office, but with a pattern that talks."],
	[3, 0, [5, 1, 9], [2, 3, 6], false, "Old country tweed. Brown or green."],
	[3, 1, [0, 1, 7], [0, 7, 2], false, "Smart, but he means to sit down in it."],
	[3, 2, [7, 9, 8, 6], [0, 5, 4], false, "A deep colour. Burgundy, forest, olive."],
	[3, 3, [4, 2, 8, 7, 6], [3, 4, 5, 1], true, "Anything light and loud. Pattern needed."],
]


func _initialize() -> void:
	var code: Resource = load(DRESS_CODE).new()
	var rule_script := load(DRESS_RULE)
	for entry in RULES:
		var rule: Resource = rule_script.new()
		rule.occasion = entry[0]
		rule.style = entry[1]
		rule.allowed_colors.assign(entry[2])
		rule.allowed_patterns.assign(entry[3])
		rule.require_pattern = entry[4]
		rule.hint = entry[5]
		code.rules.append(rule)

	var dir := (OUT as String).get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if ResourceSaver.save(code, OUT) != OK:
		push_error("save failed: " + OUT)
	else:
		print("wrote %s (%d rules)" % [OUT, code.rules.size()])
	quit(0)
