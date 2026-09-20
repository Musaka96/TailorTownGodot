extends Node

## Grandpa's side of the story — autoloaded as "Story".
##
## Two channels, both hung off the renovation, because that is what the player is doing
## (docs/STORY_AND_RENOVATION.md §2):
##  - KEEPSAKES: nearly every job turns something of his up. The find goes on the memory
##    shelf in the front room, where it can be read back at any time, so the shop fills
##    with family history at exactly the pace it is brought back to life.
##  - LETTERS: he is alive, retired to the coast, and writes when he hears how it is going.
##    A letter waits its turn and is handed over the moment nothing else is on screen.
##
## Both are saved with the game. Nothing here touches the shop: the scene side is
## RenovationDirector (the shelf) and UI.story_note (the paper).

signal changed
signal letter_ready(id: String)

const GRANDPA := 'Barnaby "Pops" Thimble'
## What each job turns up: project id -> what it is, and what the player makes of it.
## `prop` picks the little shape that stands on the shelf (RenovationDirector.KEEPSAKE_PROPS).
const KEEPSAKES := {
	"front_sheets":
	{
		"name": "Pops's shears",
		"prop": "shears",
		"text":
		(
			"Under the sheet on the cutting bench, laid square to the edge the way he always "
			+ "left them. The handles are worn to the shape of a hand. Somebody oiled these "
			+ "before they locked the door."
		),
	},
	"front_sweep":
	{
		"name": "A brass thimble",
		"prop": "thimble",
		"text":
		(
			"It came out from under the counter with the dust and a farthing. Too small for "
			+ "him — this was your grandmother's. He kept it where he could reach it."
		),
	},
	"front_boards":
	{
		"name": "A photograph in the frame",
		"prop": "photo",
		"text":
		(
			"Wedged behind the boards, face to the glass so the sun could not get at it: the "
			+ "shop on its opening day, awning out, the whole street squinting into the "
			+ "camera. He is the young one holding the shears like a trophy."
		),
	},
	"front_paper":
	{
		"name": "Measurements on the wall",
		"prop": "pencil",
		"text":
		(
			"The old paper came off and there they were, pencilled straight onto the plaster: "
			+ "forty years of shoulders and inside legs, name and date beside each one. Some "
			+ "of the names have three sets, boy to man. The decorators have papered over "
			+ "them again. You copied every one into the back of the notebook first."
		),
	},
	"workroom_clear":
	{
		"name": "A tin of photographs",
		"prop": "tin",
		"text":
		(
			"Under a floorboard that gave when you shifted the rubble: a toffee tin, rusted "
			+ "shut, full of photographs. Him at this bench. Him and a boy of about fifteen "
			+ "at this bench. The boy has Mr. Hemming's ears."
		),
	},
	"cloth_clear":
	{
		"name": "The order ledger",
		"prop": "ledger",
		"text":
		(
			"Damp has got the covers but the pages held. Every order he ever took, ruled and "
			+ "totted up in the same small hand. The last entry is a winter coat. Finished, "
			+ "collected, paid. Then half a page of nothing."
		),
	},
	"nook_clear":
	{
		"name": "The day's paper",
		"prop": "paper",
		"text":
		(
			"Folded into a crate to stop it rocking, yellow as weak tea. The date is the day "
			+ "he opened. Three lines at the bottom of page five: a new tailor on the lane, "
			+ "the neighbours wish him well."
		),
	},
}

## What he writes, and what sets him off. `after` = the job whose finish earns it;
## `arrival` = the first morning in his shop. `body` is his hand and nothing else; anything
## the player thinks about the letter goes in `note`, which is shown apart from the paper.
const LETTERS := {
	"arrival":
	{
		"title": "A letter, arrived before you did",
		"note":
		(
			"It was on the mat when you turned the key, so he must have posted it the day you "
			+ "wrote to him."
		),
		"body":
		(
			"My dear one. So you are going to open it up again. I will not pretend I am not "
			+ "pleased, but I will not pretend it is a kindness either: that shop is damp, the "
			+ "roof went in the year I left, and the workroom is nailed shut for a reason.\n\n"
			+ "Go and see Hemming on the Row before you touch anything. He learned at my bench "
			+ "and he owes me nothing, which is exactly why he will teach you properly.\n\n"
			+ "Start with the front room. A shop that can take one order is a shop.\n\n"
			+ "— Pops"
		),
	},
	"workroom_build":
	{
		"after": "workroom_build",
		"title": "A letter from the coast",
		"body":
		(
			"Hemming writes that the workroom is dry. I read it twice.\n\n"
			+ "That roof beat me. I put buckets under it for two winters and told myself I "
			+ "would see to it in the spring, and then there were no more springs in that "
			+ "shop. You have done in a week what I put off for two years.\n\n"
			+ "He will have told you my benches were in the wrong place. He has been saying it "
			+ "for forty years and he is still wrong.\n\n"
			+ "The benches go back where the light falls, not where there is room. You will "
			+ "see what I mean the first time you cut a dark cloth at four in the afternoon.\n\n"
			+ "— Pops"
		),
	},
	"cloth_build":
	{
		"after": "cloth_build",
		"title": "A letter about cloth",
		"body":
		(
			"A proper cloth store, he says. Shelved and dry.\n\n"
			+ "Then here is the only advice worth the stamp: buy the best cloth you can carry "
			+ "the cost of, and never let a customer talk you down to something that will look "
			+ "tired in a year. They will not remember what they paid. They will remember that "
			+ "it hung well at somebody's wedding.\n\n"
			+ "— Pops"
		),
	},
	"facade_paint":
	{
		"after": "facade_paint",
		"title": "A letter about the sign",
		"body":
		(
			"The name is back over the door.\n\n"
			+ "I will tell you what I never told anybody. When I put that sign up I was sick "
			+ "with it — my name, where the whole lane could read it, and me twenty-three and "
			+ "certain I would make a fool of us. It took a good few years before I could walk "
			+ "up the lane and look at it straight.\n\n"
			+ "Go outside and look at it straight.\n\n"
			+ "— Pops"
		),
	},
	"next_build":
	{
		"after": "next_build",
		"title": "A letter, and a question",
		"body":
		(
			"Two shops knocked into one. The lane will talk of nothing else for a month.\n\n"
			+ "I am too old to be much use to you now, but I am not too old for the train, and "
			+ "your grandmother always said I should have had a suit made by somebody who was "
			+ "not me.\n\n"
			+ "Would you take my measurements, if I came?\n\n"
			+ "— Pops"
		),
	},
}

var _found := {}  # keepsake (project) id -> true
var _read := {}  # letter id -> true
var _waiting: Array[String] = []  # letters earned, not handed over yet


func _ready() -> void:
	Renovation.project_finished.connect(_on_project_finished)
	EventBus.day_began.connect(_on_day_began)


# --- What the player has ---------------------------------------------------------


## The keepsakes turned up so far, in the order the jobs come.
func found_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in KEEPSAKES:
		if _found.has(id):
			out.append(id)
	return out


func has_found(id: String) -> bool:
	return _found.has(id)


func keepsake_count() -> int:
	return _found.size()


## Everything on the shelf, written out for the memory-shelf note.
func shelf_text() -> String:
	var ids := found_ids()
	if ids.is_empty():
		return (
			"Nothing on it yet but dust. Clear the shop out and see what he left behind — it "
			+ "all ends up here."
		)
	var parts: Array[String] = []
	for id: String in ids:
		var k: Dictionary = KEEPSAKES[id]
		parts.append("[b]%s[/b]\n%s" % [str(k["name"]), str(k["text"])])
	return "\n\n".join(parts)


## The letter the player has earned and not been handed yet ("" when there is none).
func next_letter() -> String:
	return _waiting[0] if not _waiting.is_empty() else ""


func letter(id: String) -> Dictionary:
	return LETTERS.get(id, {})


## Mark the waiting letter as read and take it off the pile.
func mark_read(id: String) -> void:
	_read[id] = true
	_waiting.erase(id)
	changed.emit()


# --- Earning it ------------------------------------------------------------------


func _on_project_finished(id: String) -> void:
	if KEEPSAKES.has(id) and not _found.has(id):
		_found[id] = true
		if UI != null and UI.has_method("toast"):
			UI.toast("Found: %s" % str(KEEPSAKES[id]["name"]).to_lower())
	for letter_id: String in LETTERS:
		if str(LETTERS[letter_id].get("after", "")) == id:
			_queue(letter_id)
	changed.emit()


## The first morning in his shop: the letter that was on the mat.
func _on_day_began(_day: int) -> void:
	if Locations != null and Locations.current == Locations.GRANDPA:
		_queue("arrival")


func _queue(id: String) -> void:
	if not LETTERS.has(id) or _read.has(id) or _waiting.has(id):
		return
	_waiting.append(id)
	letter_ready.emit(id)


# --- Save --------------------------------------------------------------------------


func save_state() -> Dictionary:
	return {"found": _found.keys(), "read": _read.keys(), "waiting": _waiting.duplicate()}


func restore(d: Variant) -> void:
	reset()
	if d is Dictionary:
		for id: Variant in (d as Dictionary).get("found", []):
			if KEEPSAKES.has(str(id)):
				_found[str(id)] = true
		for id: Variant in (d as Dictionary).get("read", []):
			if LETTERS.has(str(id)):
				_read[str(id)] = true
		for id: Variant in (d as Dictionary).get("waiting", []):
			if LETTERS.has(str(id)) and not _read.has(str(id)):
				_waiting.append(str(id))
	changed.emit()


func reset() -> void:
	_found.clear()
	_read.clear()
	_waiting.clear()
