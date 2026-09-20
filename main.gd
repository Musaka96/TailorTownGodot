extends Node3D

## Root of the playable scene. Composes the level, player and camera rig, which
## are wired together in main.tscn.
##
## Top-level input (pause / quit) is handled by the GameState autoload, which
## sits above the pausable scene tree. Add cross-scene wiring or level loading
## here as the game grows.


func _ready() -> void:
	# The scene file marks this root "Always"; the shop must obey pause (pause menu,
	# handbook, tutorial mentor), so force it back to pausable here.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Auto-opening shop doors: hook up every "*_Doors" group in the level.
	ShopDoor.attach_all(self)
	# The OPEN / CLOSED sign by the door: flipping it opens the shop and ends the day.
	DoorSign.attach(self)
	# Cosmetic interior recolour (data/shop_looks/); F4 cycles it in debug builds.
	if ShopLookApplier.has_shop(self):
		ShopLookApplier.attach(self)
	# A little dust in the light of the sunlit shop windows.
	DustMotes.attach_all(self)
	# An apprentice stays in until the lesson is done (customers still come and go).
	if SaveManager.kept_indoors():
		_bar_the_door()
	# A letter from grandpa waits for a quiet moment rather than barging in mid-order.
	Story.letter_ready.connect(_on_letter_ready)
	# The shop scene is fully built now (children _ready before this). Let the save
	# system apply a queued load / start a new day / resume a direct boot.
	SaveManager.notify_game_ready()


## An unseen stop across the doorway, for the player only: customers walk by script, not
## by physics, so they pass straight through it.
func _bar_the_door() -> void:
	var inside := find_child("DoorInside", true, false) as Node3D
	var outside := find_child("DoorOutside", true, false) as Node3D
	if inside == null or outside == null:
		return
	var body := StaticBody3D.new()
	body.name = "DoorBar"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.4)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	var mid := inside.global_position.lerp(outside.global_position, 0.5)
	body.global_position = mid + Vector3.UP * 1.5


## A letter has been earned. Hold it back until the player is not in a menu, a minigame or a
## conversation, then hand it over — and only in a shop that is theirs.
func _on_letter_ready(_id: String) -> void:
	if not is_inside_tree():
		return
	await UI.quiet_moment()
	var waiting := Story.next_letter()
	if waiting == "" or UI == null or UI.story_note == null:
		return
	var note := Story.letter(waiting)
	UI.story_note.open(
		str(note.get("title", "A letter")),
		str(note.get("body", "")),
		func() -> void: Story.mark_read(waiting),
		str(note.get("note", ""))
	)
