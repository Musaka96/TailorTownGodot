class_name FaceCast
extends RefCounted

## Who wears which cut-paper face (docs/FACE_STYLE_GUIDE.md section 8). The player is J1;
## the named cast members wear their own preset with their hair colour and glasses; every
## other customer gets one of the cast presets picked from their name, so the same name
## always gets the same face (a regular across loads, an old save with no face_style in
## its look). Presets are FaceStyle resources in data/face_styles/.

const DIR := "res://data/face_styles/"
const PLAYER := "paper_j1"
## The tutorial's Mr. Hemming (ui/tutorial/mentor_dialog.gd).
const MENTOR := "paper_hemming"
## The faces customers wear: the cast minus J1 (the player's).
const CUSTOMER_PRESETS := [
	"paper_noble",
	"paper_dimmock",
	"paper_pettigrew",
	"paper_portobello",
	"paper_bellamy",
	"paper_hartley",
	"paper_vance",
]
## Surname (lower case) -> [preset, hair colour, glasses ("" = none; a Wardrobe glasses
## style, "wire" is the guide's "round"), frame colour (CharacterRig.GLASSES_COLORS key)].
## Applegarth, Zanetti, Rossi and Penrose share a face with the character the guide names;
## the titled nobles (Lady Ashcombe, Lord Tewkesbury) wear the noble's.
const BY_NAME := {
	"dimmock": ["paper_dimmock", Color("2a1d15"), "", ""],
	"pettigrew": ["paper_pettigrew", Color("e9e4da"), "wire", "gold"],
	"applegarth": ["paper_pettigrew", Color("e9e4da"), "", ""],
	"portobello": ["paper_portobello", Color("5e2618"), "wire", "tortoise"],
	"zanetti": ["paper_portobello", Color("2a1d15"), "", ""],
	"bellamy": ["paper_bellamy", Color("4a4746"), "", ""],
	"hartley": ["paper_hartley", Color("7a4326"), "", ""],
	"rossi": ["paper_hartley", Color("7a4326"), "", ""],
	"penrose": ["paper_hartley", Color("4a2f1e"), "", ""],
	"vance": ["paper_vance", Color("15110f"), "wire", "black"],
	"ashcombe": ["paper_noble", Color("1a1410"), "", ""],
	"tewkesbury": ["paper_noble", Color("1a1410"), "", ""],
}

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
	return {"preset": row[0], "hair": row[1], "glasses": row[2], "glasses_color": row[3]}


## The FaceStyle for a preset name (cached; an unknown or empty name gives J1's).
static func style(preset_name: String) -> FaceStyle:
	var key := preset_name if ResourceLoader.exists(DIR + preset_name + ".tres") else PLAYER
	if not _cache.has(key):
		_cache[key] = ResourceLoader.load(DIR + key + ".tres") as FaceStyle
	return _cache[key]


## Whether a preset name has a file (so a stored face_style can be trusted).
static func exists(preset_name: String) -> bool:
	return preset_name != "" and ResourceLoader.exists(DIR + preset_name + ".tres")


## A string hash that never changes between engine versions (String.hash() may).
static func _stable_hash(text: String) -> int:
	var h := 5381
	for i in text.length():
		h = (h * 33 + text.unicode_at(i)) % 2147483647
	return h
