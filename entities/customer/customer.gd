class_name Customer
extends Node3D

## Placeholder customer that stands at the mirror. Exposes anchor points so the
## suit builder can frame the whole figure or zoom to a specific garment part.
## AI / preferences / budget come later.


func center() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


## Which way the customer faces (its local +Z) — the camera frames from here.
func facing() -> Vector3:
	return global_transform.basis.z


func part_position(garment_type: int) -> Vector3:
	match garment_type:
		Enums.GarmentType.SHIRT:
			return $ShirtAnchor.global_position
		Enums.GarmentType.PANTS:
			return $PantsAnchor.global_position
		Enums.GarmentType.JACKET:
			return $JacketAnchor.global_position
	return center()
