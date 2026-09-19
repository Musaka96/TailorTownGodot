class_name EspressoMinigame
extends CoffeeBench

## A proper espresso, once the Espresso Machine upgrade is in: grind the beans, tamp the
## puck, pull the shot — three one-button beats. Everything else lives in CoffeeBench.


func _beats() -> Array:
	return [Beat.GRIND, Beat.TAMP, Beat.POUR]


func _title() -> String:
	return "Espresso Machine"
