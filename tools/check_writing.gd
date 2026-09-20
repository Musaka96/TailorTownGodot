extends SceneTree

## Writing style-guide compliance checker (headless). Enforces the [CHECK] rules from
## docs/WRITING_STYLE_GUIDE.md against every file that holds player-facing prose.
##
## The point is not to beat an AI detector — those don't work (see
## docs/RESEARCH_ai_writing_tells.md §0). The point is that the tells are real writing
## faults: the participial tail, the mood-adjective standing in for a fact, the three
## em-dashes in one breath. Cutting them makes the line better whoever wrote it.
##
## Two tiers, because the shop's UI and the shop's world have different typography:
##   IN_WORLD  — letters, newspaper, handbook, mentor, barks, item/upgrade descriptions.
##               Every rule, including the bans on emoji and markdown: a letter is
##               handwriting and the Gazette is a printed page, neither has ** in it.
##   UI_CHROME — menus, minigame feedback, station prompts. Lexical and structural rules
##               only; glyphs like ★ ✓ 🔒 are icons here, not emoji-as-formatting.
##
## Rules (W1-W8), all against the string literals only, never the code around them:
##   W1  banned vocabulary          ERROR   §4 word list
##   W2  banned set phrases         ERROR   §4 ("not just X but Y", "a testament to", ...)
##   W3  participial tail           ERROR   §2.1 ", creating a sense of ..."
##   W4  curly quote in player text ERROR   §4 typography (the game is straight-quoted)
##   W5  emoji as formatting        ERROR   §3.6, IN_WORLD only
##   W6  markdown bold              ERROR   §3.6, IN_WORLD only
##   W7  em-dash budget             ERROR at 3+, warn at 2      §2.6
##   W8  rule-of-three list         warn                        §2.5
##
## W7-at-2 and W8 are warnings on purpose: both are legitimate often enough that a ban
## would just teach people to route around the checker. The warning list is the to-do
## list (style guide §6), not a wall.
##
## A line that must break a rule takes a `# writing-check-ignore` comment saying why.
##
## Run: godot --headless --path . --script res://tools/check_writing.gd
## Report: .dev/writing_check.log

const IN_WORLD := [
	"res://globals/story.gd",
	"res://globals/tutorial.gd",
	"res://globals/upgrades.gd",
	"res://globals/renovation.gd",
	"res://globals/news_manager.gd",
	"res://globals/reputation.gd",
	"res://globals/front_desk.gd",
	"res://globals/shift_manager.gd",
	"res://data/scripts/handbook.gd",
	"res://data/scripts/customer_preference.gd",
	"res://tools/build_news.gd",
	"res://ui/newspaper.gd",
	"res://entities/customer/street_pitch.gd",
	"res://entities/customer/customer_wait.gd",
	"res://entities/customer/customer.gd",
	"res://stations/apprentice_bench/apprentice_bench.gd",
]
const UI_CHROME := [
	"res://globals/order_manager.gd",
	"res://ui/phone_order.gd",
	"res://ui/customer_request.gd",
	"res://ui/rack_menu.gd",
	"res://ui/shelf_menu.gd",
	"res://ui/orders_menu.gd",
	"res://ui/cloth_ledger.gd",
	"res://ui/worktable_screen.gd",
	"res://ui/suit_builder.gd",
	"res://ui/minigame_screen.gd",
	"res://ui/apprentice_menu.gd",
	"res://ui/day_transition.gd",
	"res://ui/handbook.gd",
	"res://ui/main_menu.gd",
	"res://ui/pause_menu.gd",
	"res://ui/controls_screen.gd",
	"res://ui/story_note.gd",
	"res://ui/ui.gd",
]
## Every article resource under this directory is scanned as IN_WORLD.
const NEWS_DIR := "res://data/news"

# W1. The excess-vocabulary list, from Kobak et al. 2025 (14.2M PubMed abstracts),
# Juzek & Ward 2025 and Wikipedia:Signs of AI writing. Style guide §4.
const BANNED_WORDS := (
	"delves?|delving|underscore[sd]?|showcas(?:e|es|ing)|fostering|bolster(?:ed|s)?"
	+ "|leverages?|elevates?|embark(?:s|ing)?|garner(?:s|ed)?"
	+ "|myriad|plethora|tapestry|testament|interplay|intricac(?:y|ies)|complexities"
	+ "|symphony|beacon|cornerstone|treasure trove"
	+ "|meticulous(?:ly)?|intricate|vibrant|bustling|pivotal|comprehensive"
	+ "|seamless(?:ly)?|nuanced|profound|timeless|invaluable|renowned|groundbreaking"
	+ "|unwavering|whimsical|quaint|nestled"
	+ "|moreover|furthermore|additionally|undoubtedly|arguably"
)
# W2. Set phrases and frames. §4.
const BANNED_PHRASES := (
	"not just|not merely|more than just|it'?s worth noting|important to note"
	+ "|in conclusion|at the end of the day|a testament to|here'?s the thing"
	+ "|whether you'?re|dive into|in today'?s|a reminder that|let'?s be honest"
	+ "|in the heart of|plays? a (?:crucial|key|vital) role|setting the stage"
	+ "|and that'?s what makes it"
)
# W3. The -ing tail: a final clause that explains the effect of the sentence. §2.1.
const TAIL := (
	", (?:creating|making|adding|bringing|leaving|turning|giving|offering|ensuring"
	+ "|allowing|transforming|evoking|inviting|reflecting|lending|blending"
	+ "|highlighting|showcasing|underscoring|emphasi[sz]ing|fostering|providing) \\w"
)
# W8. "a, b and c" — the model's default rhythm. §2.5.
const TRIAD := "\\b\\w+, \\w+,? and \\w+\\b"
## Any quoted run in a .gd or .tres line. Non-greedy over escapes so "a\"b" stays one.
const STRING_LITERAL := "\"((?:[^\"\\\\]|\\\\.)*)\""

# W4/W5. Matched by codepoint, not regex: a character class spanning the astral plane is
# the one thing PCRE2 escaping inside a GDScript string literal makes genuinely awkward.
## The four curly quotes — the game is straight-quoted throughout.
const CURLY_QUOTES: PackedInt32Array = [0x2018, 0x2019, 0x201C, 0x201D]
## Emoji-as-formatting only: check, cross, sparkles, bang, star, rocket, brain, bulb,
## target, pin, fire, bolt. The UI's own glyphs (star, tick, lock) are icons rather than
## formatting, and stay allowed in every tier.
const FORMATTING_EMOJI: PackedInt32Array = [
	0x2705,
	0x274C,
	0x2728,
	0x2757,
	0x2B50,
	0x1F680,
	0x1F9E0,
	0x1F4A1,
	0x1F3AF,
	0x1F4CC,
	0x1F525,
	0x26A1,
]


func _initialize() -> void:
	var report: Array[String] = []
	var errors := 0
	var warnings := 0
	report.append("TailorTown writing compliance — %s" % Time.get_datetime_string_from_system())
	report.append("")

	var tiers := {"IN_WORLD": _in_world_files(), "UI_CHROME": UI_CHROME}
	for tier: String in tiers:
		report.append("== %s ==" % tier)
		var files: Array = tiers[tier]
		for path: String in files:
			var issues := _check(path, tier == "IN_WORLD")
			for issue: Dictionary in issues:
				if issue["tag"] == "ERROR":
					errors += 1
				else:
					warnings += 1
			report.append_array(_format(path, issues))
		report.append("")

	var summary := "Result: %d error(s), %d warning(s) across %d file(s)."
	var total: int = _in_world_files().size() + UI_CHROME.size()
	report.append(summary % [errors, warnings, total])
	if errors == 0:
		report.append("Warnings are the backlog, not a failure — see WRITING_STYLE_GUIDE.md §6.")

	var text := "\n".join(report)
	DirAccess.make_dir_recursive_absolute("res://.dev")
	var f := FileAccess.open("res://.dev/writing_check.log", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print(text)
	quit(1 if errors > 0 else 0)


## IN_WORLD plus every article resource in data/news (they are authored copy, one per file).
func _in_world_files() -> Array:
	var out: Array = IN_WORLD.duplicate()
	var dir := DirAccess.open(NEWS_DIR)
	if dir == null:
		return out
	for entry in dir.get_files():
		if entry.ends_with(".tres"):
			out.append(NEWS_DIR + "/" + entry)
	return out


## Returns [{line, tag, rule, message, text}, ...] for one file.
func _check(path: String, in_world: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		out.append(_issue(0, "ERROR", "W0", "file not found", ""))
		return out
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var trimmed := line.strip_edges()
		if trimmed.begins_with("#") or line.contains("writing-check-ignore"):
			continue
		for s in _prose_in(line):
			out.append_array(_check_string(s, i + 1, in_world))
	return out


## The quoted runs on one line that are prose: they have a space and some letters, which
## filters out node paths, resource ids, format keys and "%s".
func _prose_in(line: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string(STRING_LITERAL)
	for m in re.search_all(line):
		var s := m.get_string(1)
		if not s.contains(" ") or s.begins_with("res://"):
			continue
		if RegEx.create_from_string("[A-Za-z]{3}").search(s) == null:
			continue
		out.append(s)
	return out


func _check_string(s: String, line_no: int, in_world: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var low := s.to_lower()
	for hit in _matches(low, "\\b(?:" + BANNED_WORDS + ")\\b"):
		out.append(_issue(line_no, "ERROR", "W1", "banned word '%s'" % hit, s))
	for hit in _matches(low, BANNED_PHRASES):
		out.append(_issue(line_no, "ERROR", "W2", "banned phrase '%s'" % hit, s))
	for hit in _matches(low, TAIL):
		out.append(_issue(line_no, "ERROR", "W3", "participial tail '%s'" % hit, s))
	if _has_any(s, CURLY_QUOTES):
		out.append(_issue(line_no, "ERROR", "W4", "curly quote — the game is straight-quoted", s))
	if in_world and _has_any(s, FORMATTING_EMOJI):
		out.append(_issue(line_no, "ERROR", "W5", "emoji as formatting in in-world text", s))
	if in_world and s.contains("**"):
		out.append(_issue(line_no, "ERROR", "W6", "markdown bold in in-world text", s))
	var dashes := s.count("—")
	if dashes >= 3:
		out.append(_issue(line_no, "ERROR", "W7", "%d em-dashes in one string" % dashes, s))
	elif dashes == 2:
		out.append(_issue(line_no, "warn ", "W7", "2 em-dashes — one wants to be a stop", s))
	for hit in _matches(low, TRIAD):
		out.append(_issue(line_no, "warn ", "W8", "rule-of-three '%s'" % hit, s))
	return out


func _matches(text: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string(pattern)
	if re == null:
		return out
	for m in re.search_all(text):
		out.append(m.get_string(0))
	return out


## True when any of `points` appears in `s`. Codepoint comparison, so an astral-plane
## emoji counts as one character here instead of a pair of surrogate halves.
func _has_any(s: String, points: PackedInt32Array) -> bool:
	for i in s.length():
		if points.has(s.unicode_at(i)):
			return true
	return false


func _issue(line_no: int, tag: String, rule: String, message: String, text: String) -> Dictionary:
	return {"line": line_no, "tag": tag, "rule": rule, "message": message, "text": text}


func _format(path: String, issues: Array[Dictionary]) -> Array[String]:
	var short := path.trim_prefix("res://")
	if issues.is_empty():
		return ["  OK    %s" % short]
	var out: Array[String] = []
	for issue: Dictionary in issues:
		var excerpt: String = issue["text"].substr(0, 64).replace("\n", " ")
		out.append(
			(
				"  %s %s  %s:%d  %s\n           | %s"
				% [issue["tag"], issue["rule"], short, issue["line"], issue["message"], excerpt]
			)
		)
	return out
