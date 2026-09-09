extends Node

## Autoloaded as "Shift". Owns the working-day lifecycle on top of DayNight's clock:
## which day it is, whether the shop is OPEN (you can work and shoppers arrive), and
## the end-of-day ritual. When the closing bell rings (EventBus.shift_ended) the shop
## closes — no new shoppers, and the work stations refuse ("labour laws") — and a
## "Lock up shop" prompt appears at the door. Interacting there plays the UI
## day-transition and starts the next day (DayNight.start_shift) back at midday.
##
## The door prompt is a code-spawned Interactable whose target is this manager, so no
## scene needs editing. Systems ask is_open() to gate work/spawns.

var day := 1
var open := true

var _transitioning := false
var _day_start_money := 0
var _door: Interactable


func _ready() -> void:
	_day_start_money = GameState.money
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.shift_ended.connect(_on_shift_ended)


func is_open() -> bool:
	return open


## The wallet balance at the start of today, for the end-of-day "earned" tally.
func day_start_money() -> int:
	return _day_start_money


## Restore that baseline after a mid-day load so the day's earnings read correctly.
func set_day_baseline(amount: int) -> void:
	_day_start_money = amount


# --- Interactable target (the door) ----------------------------------------


func get_interaction_prompt(_actor) -> String:
	return "Lock up shop — finish day %d" % day


func interact(_actor) -> void:
	close_shop()


# --- Day lifecycle ---------------------------------------------------------


## Player locked up at the door: play the transition, then roll into the next day.
func close_shop() -> void:
	if open or _transitioning:
		return
	_transitioning = true
	GameState.input_locked = true
	_remove_door()
	var earned := GameState.money - _day_start_money
	UI.play_day_transition(day, day + 1, earned, _begin_next_day, _end_transition)


func _begin_next_day() -> void:
	day += 1
	DayNight.start_shift()  # emits shift_started, which reopens the shop


func _end_transition() -> void:
	_transitioning = false
	GameState.input_locked = false


func _on_shift_started(_hour: float) -> void:
	open = true
	_day_start_money = GameState.money


func _on_shift_ended() -> void:
	open = false
	_spawn_door()


# --- Door prompt -----------------------------------------------------------


func _spawn_door() -> void:
	if _door != null and is_instance_valid(_door):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var door := Interactable.new()
	door.collision_layer = 4  # the interactable layer the player's Interactor scans
	door.collision_mask = 0
	door.monitorable = true
	door.target = self
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	shape.shape = sphere
	door.add_child(shape)
	scene.add_child(door)
	var marker := scene.find_child("DoorInside", true, false)
	var pos := (marker as Node3D).global_position if marker is Node3D else Vector3(0, 0, 7.2)
	door.global_position = pos + Vector3(0.0, 0.6, 0.0)
	_door = door


func _remove_door() -> void:
	if _door != null and is_instance_valid(_door):
		_door.queue_free()
	_door = null
