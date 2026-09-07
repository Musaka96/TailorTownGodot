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
	[0, 0, [1, 0, 3], [1, 2, 0], false, "Timeless and dark — pinstripe or plain."],
	[0, 1, [0, 1, 2], [0, 2, 7], false, "Elegant navy or grey, understated."],
	[0, 2, [0, 6, 7, 2], [0, 7, 6, 5], false, "Fresh colour, clean lines."],
	[0, 3, [4, 2, 6, 7, 8], [5, 4, 3], true, "Light and eye-catching — go bold with pattern."],
	[1, 0, [3, 1], [0, 2, 6], false, "Traditional mourning black, a fine weave at most."],
	[1, 1, [3, 1, 0], [0, 7, 8], false, "Sombre and plain — nothing loud."],
	[1, 2, [3, 1, 0, 9, 7], [0, 7, 8, 6], false, "Dark, but a deep colour is fine."],
	[1, 3, [1, 3, 7, 9], [4, 5, 3], true, "Dark base — but make it a statement."],
	[2, 0, [1, 0], [1, 2, 0], false, "Banker's classic — pinstripe, dark."],
	[2, 1, [0, 1, 2], [0, 1, 7, 8], false, "Professional navy or grey, understated."],
	[2, 2, [0, 6, 1, 2], [0, 7, 5, 6], false, "Sharp and current, subtle texture."],
	[2, 3, [6, 2, 7, 8], [4, 5, 3], true, "Creative professional — pattern-forward."],
	[3, 0, [5, 1, 9], [2, 3, 6], false, "Vintage tweed vibes."],
	[3, 1, [0, 1, 7], [0, 7, 2], false, "Smart but relaxed."],
	[3, 2, [7, 9, 8, 6], [0, 5, 4], false, "Rich colour, contemporary."],
	[3, 3, [4, 2, 8, 7, 6], [3, 4, 5, 1], true, "Anything goes — light and loud."],
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
