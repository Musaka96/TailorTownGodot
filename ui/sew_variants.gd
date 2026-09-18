class_name SewVariants

## The sewing games side by side, so the sewing machine (and the F3 debug panel) can run
## either. Both answer start_piece(garment_type, title, material) and emit
## finished(success, quality). See docs/RESEARCH_sewing_minigame.md.

enum Variant { RHYTHM, PEDAL }

const NAMES := ["v1 · Rhythm", "v2 · Pedal & Guide"]


static func current() -> int:
	return Config.data.sew_variant if Config.data != null else Variant.RHYTHM


static func create(variant: int) -> MinigameScreen:
	if variant == Variant.PEDAL:
		return SewPedalMinigame.new()
	return SewMinigame.new()
