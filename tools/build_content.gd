extends SceneTree

## Generates the material-roll .tres files in res://data/materials/ from the
## table below. Run headless:
##   godot --headless --path . --script res://tools/build_content.gd
## Re-run to regenerate. Authored data is the table here; the .tres are output.

const OUT_DIR := "res://data/materials"

# Enum ints (kept literal so this builder doesn't depend on the Enums class_name,
# which isn't registered in a --script run). Order matches enums.gd.
# Fabric:  0 worsted, 1 flannel, 2 tweed, 3 mohair_blend, 4 linen
# Pattern: 0 solid, 1 pinstripe, 2 herringbone, 3 houndstooth, 4 windowpane,
#          5 glen_check, 6 birdseye, 7 sharkskin, 8 nailhead

const ROLLS := [
	{"id": "navy_worsted_solid", "name": "Navy Worsted", "fab": 0, "pat": 0,
		"cloth": "1b2a4a", "acc": "e9ecf2", "gsm": 240, "super": 110, "price": 28, "len": 20.0},
	{"id": "charcoal_worsted_solid", "name": "Charcoal Worsted", "fab": 0, "pat": 0,
		"cloth": "36393f", "acc": "b7bcc4", "gsm": 250, "super": 110, "price": 28, "len": 20.0},
	{"id": "navy_worsted_pinstripe", "name": "Navy Pinstripe Worsted", "fab": 0, "pat": 1,
		"cloth": "1b2a4a", "acc": "e9ecf2", "gsm": 250, "super": 120, "price": 34, "len": 18.0},
	{"id": "charcoal_worsted_pinstripe", "name": "Charcoal Pinstripe Worsted", "fab": 0, "pat": 1,
		"cloth": "33363c", "acc": "c9ccd2", "gsm": 250, "super": 120, "price": 34, "len": 18.0},
	{"id": "lightgrey_worsted_sharkskin", "name": "Light Grey Sharkskin", "fab": 0, "pat": 7,
		"cloth": "9a9ea6", "acc": "cfd3d9", "gsm": 220, "super": 100, "price": 30, "len": 18.0},
	{"id": "midgrey_flannel_solid", "name": "Mid-Grey Flannel", "fab": 1, "pat": 0,
		"cloth": "6d7075", "acc": "8a8d92", "gsm": 320, "super": 0, "price": 26, "len": 16.0},
	{"id": "brown_tweed_herringbone", "name": "Brown Tweed Herringbone", "fab": 2, "pat": 2,
		"cloth": "5a4633", "acc": "b39b74", "gsm": 340, "super": 0, "price": 24, "len": 15.0},
	{"id": "grey_tweed_herringbone", "name": "Grey Tweed Herringbone", "fab": 2, "pat": 2,
		"cloth": "6b6f6d", "acc": "aeb2b0", "gsm": 340, "super": 0, "price": 24, "len": 15.0},
	{"id": "tan_linen_solid", "name": "Tan Linen", "fab": 4, "pat": 0,
		"cloth": "c8b48a", "acc": "ded0b0", "gsm": 200, "super": 0, "price": 22, "len": 18.0},
	{"id": "black_worsted_solid", "name": "Black Worsted", "fab": 0, "pat": 0,
		"cloth": "17181c", "acc": "42444a", "gsm": 250, "super": 110, "price": 30, "len": 20.0},
	{"id": "blue_worsted_glencheck", "name": "Blue Glen Check", "fab": 0, "pat": 5,
		"cloth": "3a4a63", "acc": "aab0bc", "gsm": 260, "super": 110, "price": 32, "len": 16.0},
	{"id": "burgundy_mohair_birdseye", "name": "Burgundy Mohair Birdseye", "fab": 3, "pat": 6,
		"cloth": "5c1f2a", "acc": "b98a92", "gsm": 230, "super": 120, "price": 38, "len": 14.0},
]


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var script := load("res://data/scripts/material_type.gd")
	if script == null:
		push_error("Could not load material_type.gd — is the class cache built? Run --import first.")
		quit(1)
		return

	var count := 0
	for r in ROLLS:
		var mat: Resource = script.new()
		mat.id = StringName(r["id"])
		mat.display_name = r["name"]
		mat.fabric = r["fab"]
		mat.pattern = r["pat"]
		mat.cloth_color = Color.html(r["cloth"])
		mat.pattern_color = Color.html(r["acc"])
		mat.weight_gsm = r["gsm"]
		mat.super_number = r["super"]
		mat.price_per_meter = r["price"]
		mat.roll_length_m = r["len"]

		var path := OUT_DIR.path_join(r["id"] + ".tres")
		var err := ResourceSaver.save(mat, path)
		if err != OK:
			push_error("Failed to save %s (err %d)" % [path, err])
		else:
			count += 1
	print("build_content: wrote %d material rolls." % count)
	quit(0)
