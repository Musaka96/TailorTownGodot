extends SceneTree

## UI style-guide compliance checker (headless). Enforces the [CHECK] rules from
## docs/UI_STYLE_GUIDE.md against the menu scripts:
##   - a per-menu skin (Style.skin_base), never the generic Style.panel()
##   - a fixed frame (the panel sets custom_minimum_size, so it can't stretch)
##   - key-cap hints via Style.hint_bar(), never raw "Esc close" hint text
##   - no hard-coded Color(...) literals in a menu (pull from Style)
##
## MIGRATED menus must pass every rule — a violation is an ERROR and fails the run
## (exit 1), so a refactored screen can't silently regress. PENDING menus are
## reported as warnings so the report doubles as the migration to-do list.
##
## Run: godot --headless --path . --script res://tools/check_ui.gd
## Report: .dev/ui_check.log

const MIGRATED := ["phone_order.gd", "handbook.gd"]
const PENDING := [
	"shelf_menu.gd",
	"suit_builder.gd",
	"worktable_screen.gd",
	"sewing_screen.gd",
	"customer_request.gd",
	"orders_menu.gd",
	"orders_panel.gd",
]


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
	for menu_name in PENDING:
		var issues := _check("res://ui/" + menu_name)
		report.append_array(_format(menu_name, issues, "warn"))

	report.append("")
	report.append("Result: %d error(s) across %d migrated menu(s)." % [errors, MIGRATED.size()])

	var text := "\n".join(report)
	DirAccess.make_dir_recursive_absolute("res://.dev")
	var f := FileAccess.open("res://.dev/ui_check.log", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print(text)
	quit(1 if errors > 0 else 0)


## Returns a list of "line N: message" issues for one menu file.
func _check(path: String) -> Array[String]:
	var issues: Array[String] = []
	if not FileAccess.file_exists(path):
		issues.append("line 0: file not found")
		return issues
	var text := FileAccess.get_file_as_string(path)

	if not text.contains("Style.skin_base("):
		issues.append("line 0: no Style.skin_base() — menu has no skin (guide §5)")
	if not text.contains("_panel.custom_minimum_size"):
		issues.append("line 0: panel never sets custom_minimum_size — can stretch (§3)")
	if not text.contains("Style.hint_bar("):
		issues.append("line 0: no Style.hint_bar() — hints must use key-caps (§4)")

	for n in _lines_with(text, "Style.panel("):
		issues.append("line %d: generic Style.panel() — use Style.skin_base() (§5)" % n)
	for n in _lines_with(text, "Color("):
		issues.append("line %d: hard-coded Color() — use a Style token (§2)" % n)
	for n in _lines_with(text, "_hint.text"):
		issues.append("line %d: raw hint text — build it with Style.hint_bar() (§4)" % n)
	return issues


## 1-based line numbers where `needle` appears (ignores comment-only lines).
func _lines_with(text: String, needle: String) -> Array[int]:
	var out: Array[int] = []
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.strip_edges().begins_with("#"):
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
