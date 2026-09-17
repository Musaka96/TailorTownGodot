@tool
class_name MouthShapes
extends Resource

## What each mouth sprite (assets/textures/faces/mouth_N.png) looks like, so talking can
## flip between CLOSED and OPEN shapes instead of stretching one picture. Edit
## res://data/mouth_shapes.tres in the inspector: `kinds[N]` is a dropdown for mouth_N.
## Add a new mouth PNG → add an entry here (missing entries count as SPECIAL, never used
## for talking).
##   CLOSED      a closed line / smile (resting + the "closed" talk frame)
##   SMALL_OPEN  a slightly parted mouth (in-between talk frame)
##   WIDE_OPEN   a clearly open mouth (the "open" talk frame)
##   SPECIAL     expressions (tongue out, clenched teeth…) — never used for talking

enum Kind { CLOSED, SMALL_OPEN, WIDE_OPEN, SPECIAL }

const PATH := "res://data/mouth_shapes.tres"

static var _cache: MouthShapes

## kinds[N] describes mouth_N.png.
@export var kinds: Array[Kind] = []


static func load_or_default() -> MouthShapes:
	if _cache == null:
		_cache = load(PATH) as MouthShapes if ResourceLoader.exists(PATH) else null
		if _cache == null:
			_cache = MouthShapes.new()
	return _cache


func kind_of(index: int) -> Kind:
	return kinds[index] if index >= 0 and index < kinds.size() else Kind.SPECIAL


## All mouth indices of `kind`.
func of_kind(kind: Kind) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in kinds.size():
		if kinds[i] == kind:
			out.append(i)
	return out


## The closed frame for a character resting on mouth `rest`: the rest mouth itself when
## it is closed, else the first closed shape (or `rest` if none are marked).
func closed_for(rest: int) -> int:
	if kind_of(rest) == Kind.CLOSED:
		return rest
	var closed := of_kind(Kind.CLOSED)
	return closed[0] if not closed.is_empty() else rest
