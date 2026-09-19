class_name CoffeePourMinigame
extends CoffeeBench

## Instant coffee from the Coffee Machine: one beat. Hold to pour, let go at the line —
## over the rim and the cup is lost. Everything else lives in CoffeeBench.


func _beats() -> Array:
	return [Beat.POUR]


func _title() -> String:
	return "Coffee Machine"
