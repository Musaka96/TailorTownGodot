extends "res://tools/shot_cloth_light.gd"

## Post study for Cloth Look v3: the same subjects and cameras as
## tools/shot_cloth_light.gd, but every variant keeps the full game_live stack (the shop's
## own directional light untouched, shop environment, camera DoF, outline, CRT PostFX)
## and changes only what its name says. PostFX / Outline profiles are duplicated in
## memory and the cloth dials are set on the built materials: no file is edited.
##   post_<variant>.png    title + settings line, then figures close / rolls close /
##                         figures from the gameplay camera / its centre zoomed 4x
##   post_ALL_figures.png  every variant's figures-close row, with name bands
##   post_ALL_rolls.png    the same for the rolls rows
##   post_ALL_game.png     the same for the 4x gameplay-camera zooms
## NOT headless (needs a GPU), and it must quit:
##   timeout 300 godot --path . --script res://tools/shot_cloth_post.gd

const POST_ROW_DIR := "res://.dev/post_rows/"
# PostFxProfile fields.
const CRT_SOFT := {
	"film_strength": 0.04,
	"scanline_strength": 0.03,
	"scanline_count": 500.0,
	"chromatic_aberration": 0.03,
	"barrel_distortion": 0.12,
}
const CRT_TUBE := {
	"film_strength": 0.08,
	"scanline_strength": 0.07,
	"scanline_count": 400.0,
	"chromatic_aberration": 0.09,
	"barrel_distortion": 0.26,
	"vignette_strength": 0.2,
}
# Environment properties.
const CONTRAST := {
	"adjustment_contrast": 1.12,
	"adjustment_saturation": 1.15,
	"tonemap_exposure": 1.1,
}
# OutlineProfile fields.
const OUTLINE_THIN := {"thickness": 0.3, "opacity": 0.35}
# Cloth shader dials; sheen_strength is scaled instead (it is set per fabric).
const CLOTH_DEEP := {"normal_depth": 2.2, "grain_contrast": 1.4, "wrap": 0.35}
const SHEEN_SCALE := 1.5
const POST_VARIANTS: Array[String] = [
	"game_live",
	"crt_soft",
	"crt_tube",
	"contrast",
	"agx",
	"ambient_low",
	"ssao_strong",
	"outline_thin",
	"cloth_deep",
	"cloth_deep_crt_soft",
	"combo",
]
# What each variant changes on top of game_live.
const CHANGES := {
	"game_live": {},
	"crt_soft": {"pfx": CRT_SOFT},
	"crt_tube": {"pfx": CRT_TUBE},
	"contrast": {"env": CONTRAST},
	"agx": {"env": {"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 1.15}},
	"ambient_low": {"env": {"ambient_light_energy": 0.35}},
	"ssao_strong":
	{
		"env":
		{
			"ssao_radius": 0.4,
			"ssao_intensity": 2.5,
			"ssao_light_affect": 0.1,
			"ssil_enabled": true,
			"ssil_intensity": 1.5,
		},
	},
	"outline_thin": {"outline": OUTLINE_THIN},
	"cloth_deep": {"cloth": true},
	"cloth_deep_crt_soft": {"pfx": CRT_SOFT, "cloth": true},
	"combo":
	{
		"pfx": CRT_SOFT,
		"env":
		{
			"adjustment_contrast": 1.12,
			"adjustment_saturation": 1.15,
			"tonemap_exposure": 1.1,
			"ambient_light_energy": 0.45,
		},
		"outline": OUTLINE_THIN,
		"cloth": true,
	},
}
const BAND := {
	"game_live": "reference, as played",
	"crt_soft": "softer CRT",
	"crt_tube": "stronger CRT + vignette 0.2",
	"contrast": "contrast 1.12, sat 1.15, exposure 1.1",
	"agx": "AgX, exposure 1.15",
	"ambient_low": "ambient 0.55 -> 0.35",
	"ssao_strong": "SSAO 2.5 r0.4 + SSIL 1.5",
	"outline_thin": "outline 0.3, opacity 0.35",
	"cloth_deep": "deeper cloth dials",
	"cloth_deep_crt_soft": "cloth_deep + crt_soft",
	"combo": "crt_soft + contrast + ambient 0.45 + outline_thin + cloth_deep",
}

var _base_pfx: Resource
var _base_outline: Resource
## Cloth ShaderMaterial -> {dial: value as built}, to put back between variants.
var _cloth_orig := {}


func _variant_list() -> Array[String]:
	return POST_VARIANTS


func _row_dir() -> String:
	return POST_ROW_DIR


func _sheet_prefix() -> String:
	return "post_"


func _band_line(name: String) -> String:
	return BAND[name]


func _contact_list() -> Array:
	return [
		["post_ALL_figures.png", "POST, FIGURES CLOSE", "figures_close", POST_VARIANTS],
		["post_ALL_rolls.png", "POST, ROLLS CLOSE", "rolls_close", POST_VARIANTS],
		["post_ALL_game.png", "POST, GAMEPLAY CAMERA 4x", "figures_game_zoom", POST_VARIANTS],
	]


func _after_build() -> void:
	_base_pfx = _pfx_profile
	_base_outline = load(OUTLINE_PROFILE)
	for node: Node3D in [_figures, _rolls]:
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			_collect_cloth(mi)
	var sheens := {}
	for sm: ShaderMaterial in _cloth_orig:
		var o: Dictionary = _cloth_orig[sm]
		sheens["%.3f" % float(o["sheen_strength"])] = true
		var line := (
			"cloth as built: normal_depth %.2f, grain_contrast %.2f, wrap %.2f, sheen %.3f"
			% [o["normal_depth"], o["grain_contrast"], o["wrap"], o["sheen_strength"]]
		)
		if not _notes.has(line):
			_notes.append(line)
	print("shot_cloth_post: %d cloth materials, sheens %s" % [_cloth_orig.size(), sheens.keys()])


func _collect_cloth(mi: MeshInstance3D) -> void:
	var mats: Array[Material] = [mi.material_override]
	if mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s))
	for m: Material in mats:
		var sm := m as ShaderMaterial
		if sm == null or _cloth_orig.has(sm):
			continue
		if sm.shader != ClothMaterial.SHADER and sm.shader != ClothMaterial.SHADER_TRIPLANAR:
			continue
		var orig := {}
		for key: String in CLOTH_DEEP.keys() + ["sheen_strength"]:
			var v: Variant = sm.get_shader_parameter(key)
			if v == null:
				v = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), key)
			orig[key] = v
		_cloth_orig[sm] = orig


func _apply_variant(name: String) -> void:
	for c in _lights.get_children():
		c.free()
	var change: Dictionary = CHANGES[name]
	# PostFX first: _game_sun() reads its lighting override (off in the chew profile).
	var prof: Resource = _base_pfx.duplicate()
	var pfx_changes: Dictionary = change.get("pfx", {})
	for field: String in pfx_changes:
		prof.set(field, pfx_changes[field])
	var pfx := root.get_node_or_null("PostFX")
	if pfx != null:
		pfx.call("set_profile", prof)
	_pfx_profile = prof
	if _postfx != null:
		_postfx.visible = true
	var env: Environment = _game_env.duplicate()
	var env_changes: Dictionary = change.get("env", {})
	for prop: String in env_changes:
		env.set(prop, env_changes[prop])
	_we.environment = env
	_game_sun()
	_cam.attributes = _game_cam.get("attributes")
	_apply_outline(change.get("outline", {}))
	_set_cloth(bool(change.get("cloth", false)))
	_summaries[name] = _post_summary(name, change)


## The Outline pass from a copy of the game's profile with `fields` changed.
func _apply_outline(fields: Dictionary) -> void:
	var prof: Resource = _base_outline.duplicate()
	for field: String in fields:
		prof.set(field, fields[field])
	var mat := _outline.material_override as ShaderMaterial
	for param in OUTLINE_PARAMS:
		mat.set_shader_parameter(param, prof.get(param))
	_outline.visible = bool(prof.get("enabled"))


func _set_cloth(deep: bool) -> void:
	for sm: ShaderMaterial in _cloth_orig:
		var orig: Dictionary = _cloth_orig[sm]
		for key: String in orig:
			var v: Variant = orig[key]
			if deep:
				v = float(v) * SHEEN_SCALE if key == "sheen_strength" else CLOTH_DEEP[key]
			sm.set_shader_parameter(key, v)


func _post_summary(name: String, change: Dictionary) -> String:
	if change.is_empty():
		return "Reference: shop light, shop env, DoF, outline; " + _postfx_summary()
	var parts: PackedStringArray = []
	parts.append(_changed("PostFX", change.get("pfx", {}), _base_pfx))
	parts.append(_changed("env", change.get("env", {}), _game_env))
	parts.append(_changed("outline", change.get("outline", {}), _base_outline))
	if change.get("cloth", false):
		var o: Dictionary = _cloth_orig.values()[0] if not _cloth_orig.is_empty() else {}
		var cloth := PackedStringArray()
		for key: String in CLOTH_DEEP:
			cloth.append("%s %s (was %s)" % [key, _fmt(CLOTH_DEEP[key]), _fmt(o.get(key))])
		cloth.append("sheen_strength x%.1f" % SHEEN_SCALE)
		parts.append("cloth " + ", ".join(cloth))
	var used := PackedStringArray()
	for p in parts:
		if p != "":
			used.append(p)
	return name + " = game_live + " + "; ".join(used)


## "label field new (was old), ..." for the fields a variant sets on `base`.
func _changed(label: String, fields: Dictionary, base: Object) -> String:
	if fields.is_empty():
		return ""
	var out := PackedStringArray()
	for field: String in fields:
		var now: Variant = fields[field]
		var was: Variant = base.get(field)
		if field == "tonemap_mode":
			now = TONEMAPS[int(now)]
			was = TONEMAPS[int(was)]
		out.append("%s %s (was %s)" % [field, _fmt(now), _fmt(was)])
	return label + " " + ", ".join(out)


func _fmt(v: Variant) -> String:
	if v is float:
		return str(snappedf(v, 0.001))
	if v is bool:
		return "on" if v else "off"
	return str(v)
