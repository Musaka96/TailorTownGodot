extends SceneTree

## UI style-guide compliance checker (headless). Enforces the [CHECK] rules from
## docs/UI_STYLE_GUIDE.md against the menu scripts:
##   - a per-menu skin (Style.apply_skin), never the generic Style.panel()
##   - a fixed frame (the panel sets custom_minimum_size, so it can't stretch)
##   - key-cap hints via Style.hint_bar(), never raw "Esc close" hint text
##   - no hard-coded Color(...) literals in a menu (pull from Style)
##   - a screen title uses TitleBlock (T4)
##
## MIGRATED menus must pass every rule — a violation is an ERROR and fails the run
## (exit 1), so a refactored screen can't silently regress. PENDING menus are
## reported as warnings so the report doubles as the migration to-do list.
##
## Typography guardrails (T1-T5, style guide §2) run separately, against every
## `.gd` file under `res://ui/` (recursively) except `style.gd` itself — a hardcoded
## font size or a faux-bold is wrong wherever it lives, not just in a titled panel:
##   T1. No numeric font-size literal (add_theme_font_size_override / font_size=,
##       normal_font_size=, bold_font_size=) — use Style.T_* or a named local const.
##   T2. No FontVariation.new() and no preload() of a file under assets/fonts/.
##   T3. No variation_embolden (faux bold; real weights exist now).
##   T4. No Style.title_label() anywhere (retired); MIGRATED menus with a screen
##       title must build it with TitleBlock (checked with the rest of the
##       structural rules below, honouring CHROME_BASE).
##   T5. No Style.LEAF (legacy accent; money/positive is Style.FOREST).
##
## Run: godot --headless --path . --script res://tools/check_ui.gd
## Report: .dev/ui_check.log
##
## Known gap: draw_string()/draw_multiline_string() calls also take a font-size
## argument, but it is positional (5th/6th arg, differs between the two calls) and
## several call sites wrap across lines with commas inside the wrapped text — a
## line-oriented regex can't isolate that argument robustly, so those calls are not
## checked. Numeric sizes there still need eyeballing during review.

const MIGRATED := [
	"phone_order.gd",
	"handbook.gd",
	"shelf_menu.gd",
	"worktable_screen.gd",
	"suit_builder.gd",
	"orders_menu.gd",
	"minigame_screen.gd",
	"cutting_minigame.gd",
	"sew_minigame.gd",
	"cut_bench.gd",
	"cut_allowance_minigame.gd",
	"cut_strokes_minigame.gd",
	"sew_pedal_minigame.gd",
	"apprentice_menu.gd",
	"press_minigame.gd",
	"coffee_bench.gd",
	"coffee_art.gd",
	"coffee_pour_minigame.gd",
	"espresso_minigame.gd",
	"controls_screen.gd",
	"rack_menu.gd",  # apply_skin(MIRROR) + FRAME_TALL + TitleBlock — just missing from this list
	"debug_panel.gd",  # the F3 debug panel (debug builds only): WORK skin, docked left
]
const PENDING: Array[String] = []
# Not standard panel-menus: sewing_screen only hosts the sewing minigame, and
# bench_game_screen the pressing and coffee games;
# orders_panel is the always-on HUD ticket strip; customer_request is a small
# speech-bubble dialog (ui/speech_tail.gd), not an atelier panel.
const EXEMPT := [
	"sewing_screen.gd",
	"bench_game_screen.gd",
	"orders_panel.gd",
	"customer_request.gd",
]
## Menus whose panel is built by a shared base class: the structural rules (skin,
## fixed frame, key-cap hints, TitleBlock) are satisfied by the base, so they are
## checked against it — the per-line rules (no Color() literals, no raw hint text)
## still apply to the menu's own file.
const CHROME_BASE := {
	"cutting_minigame.gd": "minigame_screen.gd",
	"sew_minigame.gd": "minigame_screen.gd",
	"cut_bench.gd": "minigame_screen.gd",
	"cut_allowance_minigame.gd": "minigame_screen.gd",
	"cut_strokes_minigame.gd": "minigame_screen.gd",
	"sew_pedal_minigame.gd": "minigame_screen.gd",
	"press_minigame.gd": "minigame_screen.gd",
	"coffee_bench.gd": "minigame_screen.gd",
	"coffee_art.gd": "minigame_screen.gd",
	"coffee_pour_minigame.gd": "minigame_screen.gd",
	"espresso_minigame.gd": "minigame_screen.gd",
}
## Files that carry real text and need the typography rules, but have no atelier
## skin panel and no screen title to hold a TitleBlock — so only T1-T5 apply, not
## the structural rules or T4's TitleBlock requirement. One line each, why.
const TYPE_ONLY := {
	"pause_menu.gd": "a hanging SignBoard, not a skinned panel — typography rules only",
	"main_menu.gd": "the front door: fascia sign + button column, not a skinned panel",
	"newspaper.gd": "own masthead + private sub-scale (guide §2), not an atelier menu panel",
	"day_transition.gd": "full-screen day-card transition, not an interactive menu panel",
	"hud.gd": "always-on HUD strips (purse, prompt bar) — no panel, no screen title",
	"settings_ui.gd": "row builder embedded in another menu's own panel, not one of its own",
	"tutorial/coach_mark.gd": "tutorial callout pill, not a panel menu",
	"tutorial/goal_tag.gd": "tutorial goal card, not a panel menu",
	"tutorial/mentor_dialog.gd": "tutorial speech board, not a panel menu",
	"tutorial/pointer_pin.gd": "tutorial pointer marker — draws shapes only, no title",
}


func _initialize() -> void:
	var report: Array[String] = []
	var errors := 0
	report.append("TailorTown UI compliance — %s" % Time.get_datetime_string_from_system())
	report.append("")

	report.append("== MIGRATED (must comply) ==")
	for menu_name in MIGRATED:
		var issues := _check("res://ui/" + menu_name)
		errors += issues.size()
		report.append_array(_format(menu_name, issues, "ERROR"))

	report.append("")
	report.append("== PENDING migration (warnings) ==")
	if PENDING.is_empty():
		report.append("  (none — all panel menus migrated)")
	for menu_name in PENDING:
		var issues := _check("res://ui/" + menu_name)
		report.append_array(_format(menu_name, issues, "warn"))

	report.append("")
	report.append("== EXEMPT (not panel menus) ==")
	for menu_name in EXEMPT:
		report.append("  n/a   %s" % menu_name)

	report.append("")
	report.append("== TYPE_ONLY (typography rules only — no skin panel / title) ==")
	for menu_name: String in TYPE_ONLY:
		report.append("  n/a   %s  — %s" % [menu_name, TYPE_ONLY[menu_name]])

	var type_errors := 0
	var scripts := _all_ui_scripts()
	report.append("")
	report.append("== Typography (T1-T5, every ui/*.gd except style.gd) ==")
	for rel_path: String in scripts:
		var issues := _check_typography("res://ui/" + rel_path)
		type_errors += issues.size()
		report.append_array(_format(rel_path, issues, "ERROR"))
	if type_errors == 0:
		report.append("  (no typography violations)")
	errors += type_errors

	var structural_errors := errors - type_errors
	var summary_fmt := (
		"Result: %d error(s) across %d migrated menu(s); "
		+ "%d typography violation(s) across %d ui script(s)."
	)
	report.append("")
	report.append(summary_fmt % [structural_errors, MIGRATED.size(), type_errors, scripts.size()])

	var text := "\n".join(report)
	DirAccess.make_dir_recursive_absolute("res://.dev")
	var f := FileAccess.open("res://.dev/ui_check.log", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print(text)
	quit(1 if errors > 0 else 0)


## Returns a list of "line N: message" issues for one menu file (structural rules +
## T4's TitleBlock requirement). Typography (T1/T2/T3/T5) is checked separately by
## _check_typography() against every ui script, not just this MIGRATED/PENDING one.
func _check(path: String) -> Array[String]:
	var issues: Array[String] = []
	if not FileAccess.file_exists(path):
		issues.append("line 0: file not found")
		return issues
	var text := FileAccess.get_file_as_string(path)
	# The chrome may live in a shared base — check the structural rules against it.
	var structural := text
	var base: String = CHROME_BASE.get(path.get_file(), "")
	if base != "":
		structural += FileAccess.get_file_as_string("res://ui/" + base)

	# Match the bare call names (not the "Style." prefix) so gdformat line-wrapping
	# between "Style" and ".apply_skin(" can't defeat the substring check.
	if not structural.contains("apply_skin("):
		issues.append("line 0: no Style.apply_skin() — menu has no skin (guide §5)")
	if not structural.contains("_panel.custom_minimum_size"):
		issues.append("line 0: panel never sets custom_minimum_size — can stretch (§3)")
	if not structural.contains("hint_bar("):
		issues.append("line 0: no Style.hint_bar() — hints must use key-caps (§4)")
	if not structural.contains("TitleBlock."):
		(
			issues
			. append(
				"line 0: no TitleBlock — screen title should use TitleBlock.make()/adopt() (T4, guide §4.1)"
			)
		)

	for n in _lines_with(text, "Style.panel("):
		issues.append("line %d: generic Style.panel() — use Style.skin_base() (§5)" % n)
	for n in _lines_with(text, "Color("):
		issues.append("line %d: hard-coded Color() — use a Style token (§2)" % n)
	for n in _lines_with(text, "_hint.text"):
		issues.append("line %d: raw hint text — build it with Style.hint_bar() (§4)" % n)
	return issues


## Typography guardrails (T1-T5) for one ui script — called for every file under
## ui/ recursively, independent of the MIGRATED/PENDING/EXEMPT/TYPE_ONLY split.
func _check_typography(path: String) -> Array[String]:
	if not FileAccess.file_exists(path):
		return ["line 0: file not found"]
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var issues: Array[String] = []

	issues.append_array(_check_font_sizes(text, lines))
	for n in _lines_with(text, "FontVariation.new("):
		issues.append("line %d: FontVariation.new() — real weights live in Style (T2)" % n)
	for n in _lines_with(text, 'preload("res://assets/fonts/'):
		issues.append("line %d: preload() of a font file — get faces from Style (T2)" % n)
	for n in _lines_with(text, "variation_embolden"):
		issues.append(
			"line %d: variation_embolden — faux bold is banned, use Style.font_bold() (T3)" % n
		)
	for n in _lines_with(text, "title_label("):
		issues.append(
			"line %d: Style.title_label() is retired — use TitleBlock (T4, guide §4.1)" % n
		)
	for n in _lines_with(text, "Style.LEAF"):
		issues.append("line %d: Style.LEAF is legacy — money/positive is Style.FOREST (T5)" % n)
	return issues


## T1 — no bare numeral as a font-size argument. Two shapes: the theme-override call
## (matched across line wraps with the DOTALL "(?s)" modifier, since a long call can
## be wrapped by gdformat) and a direct property assignment (`font_size = 14` on a
## LabelSettings-style resource). A numeral anywhere in the argument is a violation
## (so `26 if lead else 18` is still caught), not only a lone literal — but a plain
## identifier (`Style.T_BODY`, a file-local const, a passed-in parameter) is fine.
func _check_font_sizes(text: String, lines: Array) -> Array[String]:
	var issues: Array[String] = []
	var call_re := RegEx.new()
	var call_pattern := (
		'(?s)add_theme_font_size_override\\(\\s*"'
		+ "(font_size|normal_font_size|bold_font_size)"
		+ '"\\s*,\\s*(.+?)\\)'
	)
	call_re.compile(call_pattern)
	for m in call_re.search_all(text):
		var arg := m.get_string(2)
		if not _has_bare_int(arg):
			continue
		var from_line := _line_of(text, m.get_start())
		var to_line := _line_of(text, m.get_end())
		if _span_ignored(lines, from_line, to_line):
			continue
		issues.append(
			"line %d: numeric font size (%s) — use Style.T_* (T1)" % [from_line, arg.strip_edges()]
		)
	var prop_re := RegEx.new()
	prop_re.compile("\\b(font_size|normal_font_size|bold_font_size)\\s*=\\s*(-?\\d+)\\b")
	for m in prop_re.search_all(text):
		var ln := _line_of(text, m.get_start())
		if _span_ignored(lines, ln, ln):
			continue
		issues.append(
			"line %d: numeric %s = %s — use Style.T_* (T1)" % [ln, m.get_string(1), m.get_string(2)]
		)
	return issues


func _has_bare_int(expr: String) -> bool:
	var re := RegEx.new()
	re.compile("\\b\\d+\\b")
	return re.search(expr) != null


## 1-based line number containing byte offset `idx` in `text`.
func _line_of(text: String, idx: int) -> int:
	return text.substr(0, idx).count("\n") + 1


## True if any line in [from_line, to_line] (1-based, inclusive) is a comment-only
## line or carries the "ui-check-ignore" marker (for legitimate data literals).
func _span_ignored(lines: Array, from_line: int, to_line: int) -> bool:
	for i in range(from_line - 1, mini(to_line, lines.size())):
		var line: String = lines[i]
		if line.strip_edges().begins_with("#") or line.contains("ui-check-ignore"):
			return true
	return false


## Every ".gd" file under res://ui/, recursively, except style.gd — sorted, relative
## to res://ui/ (so a file in ui/tutorial/ reports as "tutorial/coach_mark.gd").
func _all_ui_scripts() -> Array[String]:
	var out: Array[String] = []
	_scan_dir("res://ui", "", out)
	out.sort()
	return out


func _scan_dir(abs_dir: String, rel_prefix: String, out: Array[String]) -> void:
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var rel := rel_prefix + entry
			if dir.current_is_dir():
				_scan_dir(abs_dir + "/" + entry, rel + "/", out)
			elif entry.ends_with(".gd") and rel != "style.gd":
				out.append(rel)
		entry = dir.get_next()
	dir.list_dir_end()


## 1-based line numbers where `needle` appears. Skips comment-only lines and any
## line carrying a "ui-check-ignore" marker (for legitimate data literals).
func _lines_with(text: String, needle: String) -> Array[int]:
	var out: Array[int] = []
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.strip_edges().begins_with("#") or line.contains("ui-check-ignore"):
			continue
		if line.contains(needle):
			out.append(i + 1)
	return out


func _format(menu_name: String, issues: Array[String], tag: String) -> Array[String]:
	var out: Array[String] = []
	if issues.is_empty():
		out.append("  OK    %s" % menu_name)
		return out
	for issue in issues:
		out.append("  %s  %s  %s" % [tag, menu_name, issue])
	return out
