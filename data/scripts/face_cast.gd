class_name FaceCast
extends RefCounted

## Who wears which cut-paper face (docs/FACE_STYLE_GUIDE.md section 8). The player is J1;
## the named cast members wear their own preset with their hair colour and glasses; every
## other customer gets one of the cast presets picked from their name, so the same name
## always gets the same face (a regular across loads, an old save with no face_style in
## its look). Presets are FaceStyle resources in data/face_styles/. A woman's face gets the
## feminine kit on top of whatever preset she wears (style() with her gender): the lash
## strip and a lipstick mouth (guide section 9).

const DIR := "res://data/face_styles/"
const PLAYER := "paper_j1"
## The tutorial's Mr. Hemming (ui/tutorial/mentor_dialog.gd).
const MENTOR := "paper_hemming"
## The faces customers wear: the cast minus J1 (the player's), then the looks built from
## the approved piece vocabulary (guide section 9, 2026-09-27).
const CUSTOMER_PRESETS := [
	"paper_noble",
	"paper_dimmock",
	"paper_pettigrew",
	"paper_portobello",
	"paper_bellamy",
	"paper_hartley",
	"paper_vance",
	"paper_colonel",
	"paper_dandy",
	"paper_sprite",
	"paper_owl",
	"paper_sage",
	"paper_glint",
]
## Surname (lower case) -> [preset, hair colour, glasses ("" = none; a Wardrobe glasses
## style, "wire" is the guide's "round"), frame colour (CharacterRig.GLASSES_COLORS key),
## gender (Enums.Gender; ANY = the title decides)]. Applegarth, Zanetti, Rossi and Penrose
## share a face with the character the guide names; the titled nobles (Lady Ashcombe, Lord
## Tewkesbury) wear the noble's. The women are FEMALE, so they always wear the feminine
## kit, whatever body a collector with no remembered look was dressed on.
const BY_NAME := {
	"dimmock": ["paper_dimmock", Color("2a1d15"), "", "", Enums.Gender.ANY],
	"pettigrew": ["paper_pettigrew", Color("e9e4da"), "wire", "gold", Enums.Gender.ANY],
	"applegarth": ["paper_pettigrew", Color("e9e4da"), "", "", Enums.Gender.FEMALE],
	"portobello": ["paper_portobello", Color("5e2618"), "wire", "tortoise", Enums.Gender.FEMALE],
	"zanetti": ["paper_portobello", Color("2a1d15"), "", "", Enums.Gender.ANY],
	"bellamy": ["paper_bellamy", Color("4a4746"), "", "", Enums.Gender.ANY],
	"hartley": ["paper_hartley", Color("7a4326"), "", "", Enums.Gender.FEMALE],
	"rossi": ["paper_hartley", Color("7a4326"), "", "", Enums.Gender.ANY],
	"penrose": ["paper_hartley", Color("4a2f1e"), "", "", Enums.Gender.ANY],
	"vance": ["paper_vance", Color("15110f"), "wire", "black", Enums.Gender.ANY],
	"ashcombe": ["paper_noble", Color("1a1410"), "", "", Enums.Gender.FEMALE],
	"tewkesbury": ["paper_noble", Color("1a1410"), "", "", Enums.Gender.ANY],
}
## The feminine kit (owner, 2026-09-27: "definitely the E6 eyelashes for girls", lipstick
## for the lips): the lash strip's thickness and the lipstick rose, laid over any preset.
const LASH := 0.036
const LIPSTICK := Color("a8464a")

## The kit on or off for every woman's face; review tools switch it to compare.
static var feminine_kit := true
static var _cache := {}


## The face preset for a customer's display name ("Mr. Dimmock"): the cast member's own,
## else a pick from CUSTOMER_PRESETS by the name's hash (the same every run).
static func preset_for(display_name: String) -> String:
	var cast := cast_of(display_name)
	if not cast.is_empty():
		return cast["preset"]
	return CUSTOMER_PRESETS[_stable_hash(display_name) % CUSTOMER_PRESETS.size()]


## A random customer preset, for someone with no name yet (a passer-by).
static func random_preset(rng: RandomNumberGenerator) -> String:
	return CUSTOMER_PRESETS[rng.randi() % CUSTOMER_PRESETS.size()]


## The cast entry for a display name: {preset, hair (Color), glasses, glasses_color}, or
## {} for someone who is not in the cast.
static func cast_of(display_name: String) -> Dictionary:
	var words := display_name.strip_edges().split(" ", false)
	if words.is_empty():
		return {}
	var row: Array = BY_NAME.get(words[words.size() - 1].to_lower(), [])
	if row.is_empty():
		return {}
	return {
		"preset": row[0],
		"hair": row[1],
		"glasses": row[2],
		"glasses_color": row[3],
		"gender": row[4],
	}


## The FaceStyle for a preset name (cached; an unknown or empty name gives J1's). With
## `gender` FEMALE (an Enums.Gender) it is a copy with the feminine kit on top: the lash
## strip and the lipstick mouth (feminine()).
static func style(preset_name: String, gender := 0) -> FaceStyle:
	var key := preset_name if ResourceLoader.exists(DIR + preset_name + ".tres") else PLAYER
	if not _cache.has(key):
		_cache[key] = ResourceLoader.load(DIR + key + ".tres") as FaceStyle
	if gender != Enums.Gender.FEMALE or not feminine_kit:
		return _cache[key]
	var fem_key := key + "+feminine"
	if not _cache.has(fem_key):
		_cache[fem_key] = feminine(_cache[key])
	return _cache[fem_key]


## A copy of `base` with the feminine kit: the lash strip (E6) and the lipstick mouth, and
## no moustache or chin patch (X5, X6: a woman drawing the colonel or the sage wears the
## rest of the look). It is named "<preset>+feminine" (resource_name); its resource_path
## stays empty.
static func feminine(base: FaceStyle) -> FaceStyle:
	var out := base.duplicate() as FaceStyle
	out.eye_lash = maxf(out.eye_lash, LASH)
	out.mouth_color = LIPSTICK
	out.moustache = 0
	out.beard = Vector2.ZERO
	out.resource_name = base.resource_path.get_file().get_basename() + "+feminine"
	return out


## The preset a rig's FaceStyle came from ("paper_hartley"), the feminine kit's copies
## included; "" for none.
static func preset_of(face: FaceStyle) -> String:
	if face == null:
		return ""
	if face.resource_path != "":
		return face.resource_path.get_file().get_basename()
	return face.resource_name.trim_suffix("+feminine")


## Whether a preset name has a file (so a stored face_style can be trusted).
static func exists(preset_name: String) -> bool:
	return preset_name != "" and ResourceLoader.exists(DIR + preset_name + ".tres")


## A string hash that never changes between engine versions (String.hash() may).
static func _stable_hash(text: String) -> int:
	var h := 5381
	for i in text.length():
		h = (h * 33 + text.unicode_at(i)) % 2147483647
	return h
