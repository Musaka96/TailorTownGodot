class_name CutVariants

## The cutting games side by side, so the worktable (and the F3 debug panel) can run
## any of them. They share one contract: start(garment_type, title, material) and
## finished(success, quality). See docs/RESEARCH_cutting_minigame.md.

enum Variant { STEER, ALLOWANCE, STROKES }

const NAMES := ["v1 · Steer", "v2 · Seam allowance", "v3 · Strokes"]


static func current() -> int:
	return Config.data.cut_variant if Config.data != null else Variant.STEER


static func create(variant: int) -> MinigameScreen:
	match variant:
		Variant.ALLOWANCE:
			return CutAllowanceMinigame.new()
		Variant.STROKES:
			return CutStrokesMinigame.new()
	return CuttingMinigame.new()
