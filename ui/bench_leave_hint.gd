class_name BenchLeaveHint
extends Label

## One line along the bottom of the screen while a bench game runs, saying how to walk
## away from it — and, while a shopper stands at the counter waiting to be greeted, that
## they are waiting. Each minigame host (worktable_screen, sewing_screen,
## bench_game_screen) adds one over its game and shows it only while the game is up.
## The hosts live as long as the UI, so it follows the shoppers from the start on
## EventBus.customer_waiting / customer_answered and never polls.

const LEAVE := "Esc to leave the bench"
const WAITING := "A customer is waiting. Esc to leave the bench"
const OUTLINE := 6  # px of walnut outline, so it reads over the scrim
const LIFT := 24  # px above the bottom edge

var _waiting: Array[Node] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_override("font", Style.font_medium())
	add_theme_font_size_override("font_size", Style.T_BODY)
	add_theme_color_override("font_outline_color", Style.WALNUT)
	add_theme_constant_override("outline_size", OUTLINE)
	EventBus.customer_waiting.connect(_on_waiting)
	EventBus.customer_answered.connect(_on_answered)
	_refresh()
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, LIFT)
	UiScale.attach(self, UiScale.PROMPTS, Vector2(0.5, 1.0))


## True while a shopper who came in is still waiting to be greeted.
func customer_waiting() -> bool:
	return not _waiting.is_empty()


func _on_waiting(cust: Node) -> void:
	if cust == null or _waiting.has(cust):
		return
	_waiting.append(cust)
	var gone := _forget.bind(cust)
	if not cust.tree_exiting.is_connected(gone):
		cust.tree_exiting.connect(gone, CONNECT_ONE_SHOT)
	_refresh()


func _on_answered(_choice: String, cust: Node) -> void:
	_forget(cust)


func _forget(cust: Node) -> void:
	_waiting.erase(cust)
	_refresh()


func _refresh() -> void:
	var busy := customer_waiting()
	text = WAITING if busy else LEAVE
	add_theme_color_override("font_color", Style.BRASS_LIGHT if busy else Style.CHALK)
