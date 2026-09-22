class_name UpgradeParts
extends Node

## Shows a station's upgrades on its model. The model (assets/models/stations/, built by
## IMPORT/town_kit/build_stations_v1.py) has a part per upgrade: "Upg_<id>" parts are hidden
## until upgrade <id> is owned, "Base_<x>" parts show unless an owned upgrade replaces them.
## Which parts each upgrade shows and hides is in the model's manifest (stations_v1.json).

const MANIFEST := "res://assets/models/stations/stations_v1.json"

## The model's instance (the glTF scene) under the station.
@export var model_path: NodePath = ^"../Model"
## This station's entry in the manifest ("worktable", "sewing").
@export var manifest_key := ""

var _rules: Dictionary = {}
var _parts: Node3D  # the glTF's root empty, which holds the parts


func _ready() -> void:
	var model := get_node_or_null(model_path)
	var base := model.find_child("Base", true, false) if model != null else null
	if base == null:
		push_warning("UpgradeParts: no model with a Base part at %s" % model_path)
		return
	_parts = base.get_parent() as Node3D
	var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if all is Dictionary:
		_rules = (all as Dictionary).get(manifest_key, {})
	if Upgrades != null:
		Upgrades.changed.connect(apply)
	apply()


## Show the parts of every owned upgrade, and take away the base parts they replace.
func apply() -> void:
	if _parts == null:
		return
	for child in _parts.get_children():
		var part := child as Node3D
		if part != null:
			part.visible = not str(part.name).begins_with("Upg_")
	for id: String in _rules:
		if Upgrades == null or not Upgrades.has(id):
			continue
		var rule: Dictionary = _rules[id]
		_show_all(rule.get("show", []), true)
		_show_all(rule.get("hide", []), false)


func _show_all(names: Array, on: bool) -> void:
	for n: Variant in names:
		var part := _parts.get_node_or_null(str(n)) as Node3D
		if part != null:
			part.visible = on
