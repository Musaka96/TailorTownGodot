extends SceneTree

## Generates the shipped shop-look presets in data/shop_looks/ (see docs/SHOP_LOOKS.md).
## Run to (re)create or reset them; afterwards they're edited in the Inspector.
##   godot --headless --path . --script res://tools/build_shop_looks.gd
##
## Texture sets live at res://assets/textures/shop_looks/<set>_{albedo,normal,rough}.png.
## Wallpapers are greyscale tint sets made by IMPORT/town_kit/textures/_src (stage 1-3);
## rugs are drawn by _src/make_rugs.py: one colour family = rect + round + runner images.

const OUT_DIR := "res://data/shop_looks/"
const TEX_DIR := "res://assets/textures/shop_looks/"
const SHOP_LOOK := "res://data/scripts/shop_look.gd"
const SHOP_LOOK_SLOT := "res://data/scripts/shop_look_slot.gd"

# Wallpapers are authored at 1 m/tile but the wall bakes 2 m, hence uv_scale 2.0 on them
# (see ShopLookSlot.uv_scale / docs/SHOP_LOOKS.md).


func _initialize() -> void:
	var presets := {
		"sage_panel":
		_look(
			"sage_panel",
			"Sage & Panel",
			"Soft sage walls over green board panelling.",
			0,
			0,
			_slot("paint", Color("B7C4A6"), 1.0),
			_slot("wood_panel", Color("3F5A3A")),
			_slot("floor_planks", Color("FFFFFF")),
			"green",
			_slot("velvet", Color("2F5A3E"))
		),
		"forest_green":
		_look(
			"forest_green",
			"Forest Green",
			"Full-height green board panelling, dark and cosy.",
			0,
			0,
			_slot("wood_panel", Color("3F5A3A"), 1.0),
			_slot("wood_panel", Color("3A5236")),
			_slot("floor_planks", Color("FFFFFF")),
			"green",
			_slot("velvet", Color("2F5A3E"))
		),
		"oxblood":
		_look(
			"oxblood",
			"Oxblood",
			"Deep red panelling and parquet: a bolder, richer atelier.",
			120,
			40,
			_slot("wood_panel", Color("6E2A2C"), 1.0),
			_slot("wood_panel", Color("652527")),
			_slot("parquet", Color("FFFFFF")),
			"red",
			_slot("velvet", Color("6E1E24"))
		),
		"cream_walnut":
		_look(
			"cream_walnut",
			"Cream & Walnut",
			"Pale plastered walls over warm walnut wainscot.",
			260,
			40,
			_slot("plaster", Color("F1E7D2"), 1.0),
			_slot("wood_panel", Color("7A5238")),
			_slot("floor_planks", Color("FFFFFF")),
			"camel",
			_slot("velvet", Color("C39A68"))
		),
		"navy_atelier":
		_look(
			"navy_atelier",
			"Navy Atelier",
			"Striped wallpaper over navy panelling, with dark-stained parquet.",
			320,
			120,
			_slot("wallpaper_stripe", Color("E9DFC8"), 2.0),
			_slot("wood_panel", Color("2F3A60")),
			_slot("parquet", Color("A08C84")),
			"navy",
			_slot("velvet", Color("2F3A60"))
		),
		"plum_damask":
		_look(
			"plum_damask",
			"Plum Damask",
			"Damask wallpaper over deep plum panelling.",
			480,
			260,
			_slot("wallpaper_damask", Color("BFA3B8"), 2.0),
			_slot("wood_panel", Color("4A2E45")),
			_slot("parquet", Color("FFFFFF")),
			"plum",
			_slot("velvet", Color("5A2F52"))
		),
		"fern_damask":
		_look(
			"fern_damask",
			"Fern Damask",
			"The shop default: green damask wallpaper over dark green panelling.",
			0,
			0,
			_slot("wallpaper_damask", Color("A9C29A"), 2.0),
			_slot("wood_panel", Color("33503A")),
			_slot("floor_planks", Color("FFFFFF")),
			"green",
			_slot("velvet", Color("2F5A3E"))
		),
		"mint_trellis":
		_look(
			"mint_trellis",
			"Mint Trellis",
			"Fresh mint trellis wallpaper with painted cream panelling.",
			300,
			80,
			_slot("wallpaper_trellis", Color("BFE0C8"), 2.0),
			_slot("wood_panel", Color("EFE8D6")),
			_slot("floor_planks", Color("FFFFFF")),
			"mint",
			_slot("velvet", Color("6FA287"))
		),
		"olive_fern":
		_look(
			"olive_fern",
			"Olive Fern",
			"Botanical wallpaper in soft olive over moss panelling.",
			340,
			120,
			_slot("wallpaper_fern", Color("C2C68C"), 2.0),
			_slot("wood_panel", Color("5C6030")),
			_slot("parquet", Color("FFFFFF")),
			"olive",
			_slot("velvet", Color("6B6F35"))
		),
		"sage_blossom":
		_look(
			"sage_blossom",
			"Sage Blossom",
			"Little flowers on sage wallpaper over soft green panelling.",
			240,
			40,
			_slot("wallpaper_floral", Color("BCCDA9"), 2.0),
			_slot("wood_panel", Color("6E8B6A")),
			_slot("floor_planks", Color("FFFFFF")),
			"mint",
			_slot("velvet", Color("4F7B5B"))
		),
		"chestnut_stripe":
		_look(
			"chestnut_stripe",
			"Chestnut & Toffee",
			"Toffee striped wallpaper over chestnut panelling: warm and brown all over.",
			280,
			80,
			_slot("wallpaper_stripe", Color("E2C39C"), 2.0),
			_slot("wood_panel", Color("5E3B28")),
			_slot("parquet", Color("C9B4A4")),
			"brown",
			_slot("velvet", Color("7A4A2E"))
		),
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for file_name: String in presets:
		var path: String = OUT_DIR + file_name + ".tres"
		if ResourceSaver.save(presets[file_name], path) == OK:
			print("  wrote ", path)
		else:
			printerr("  FAILED ", path)
			failed += 1
	print("build_shop_looks: %d preset(s), %d failed" % [presets.size(), failed])
	quit(1 if failed > 0 else 0)


func _look(
	id: String,
	display_name: String,
	description: String,
	price: int,
	reputation_required: int,
	wall: Resource,
	wainscot: Resource,
	floor: Resource,
	rug_family: String,
	drape: Resource
) -> Resource:
	var look: Resource = load(SHOP_LOOK).new()
	look.id = StringName(id)
	look.display_name = display_name
	look.description = description
	look.price = price
	look.reputation_required = reputation_required
	look.wall = wall
	look.wainscot = wainscot
	look.floor = floor
	look.rug = _slot("rug_" + rug_family, Color.WHITE)
	look.rug_round = _slot("rug_%s_round" % rug_family, Color.WHITE)
	look.rug_runner = _slot("rug_%s_runner" % rug_family, Color.WHITE)
	look.drape = drape
	return look


func _slot(set_name: String, tint: Color, uv_scale := 1.0) -> Resource:
	var slot: Resource = load(SHOP_LOOK_SLOT).new()
	slot.albedo_texture = load(TEX_DIR + set_name + "_albedo.png")
	slot.normal_texture = load(TEX_DIR + set_name + "_normal.png")
	slot.roughness_texture = load(TEX_DIR + set_name + "_rough.png")
	slot.tint = tint
	slot.uv_scale = uv_scale
	return slot
