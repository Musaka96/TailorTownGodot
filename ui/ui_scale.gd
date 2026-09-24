class_name UiScale

## The player's interface sizes (Settings > Interface), one per category. A control is
## attached once to a category; it takes that category's size as its `scale` now and
## whenever the slider moves, shrinking toward the point it is anchored to: a centred
## panel toward its centre, a right-docked panel toward its right edge, a bottom-left
## widget toward its bottom-left corner. Only the attached control is scaled, so a menu's
## dimmer stays full-screen while its panel shrinks.
##   UiScale.attach(_panel, UiScale.MENUS)
## Anything that tweens an attached control's `scale` must rest at target_scale(c), not
## at Vector2.ONE (Craft.pop_in / bump do), and should leave its pivot alone. A control
## placed by a Container is re-scaled after each sort, since fitting a child resets its
## scale to one (showing a hidden menu sorts it again).

## Centred modals and docked station panels.
const MENUS := "menus"
## The clock, reputation, purse, toasts and the "Next job" tag.
const HUD := "hud"
## The bottom interaction prompt and the key pills.
const PROMPTS := "prompts"
## Speech bubbles, the fitting notepad, the mentor and the tutorial's marks.
const DIALOGUE := "dialogue"
const CATEGORIES: Array[String] = [MENUS, HUD, PROMPTS, DIALOGUE]
## `pivot` value for attach(): take the pivot from the control's anchors.
const FROM_ANCHORS := Vector2(-1.0, -1.0)

const _CAT := "ui_scale_cat"
const _PIVOT := "ui_scale_pivot"
const _LISTENER := "ui_scale_listener"
const _RESORT := "ui_scale_resort"


## Scale `c` by category `cat` from now on. `pivot` is the fixed point as a fraction of
## the control's own size (Vector2(0.5, 1.0) = bottom centre); by default it comes from
## the anchors, or the centre for a child of a container. Attaching again only updates
## the category and pivot.
static func attach(c: Control, cat: String, pivot := FROM_ANCHORS) -> void:
	if c == null:
		return
	var fresh := not c.has_meta(_CAT)
	c.set_meta(_CAT, cat)
	c.set_meta(_PIVOT, pivot)
	if fresh:
		var listener := func(changed: String, _value: float) -> void:
			if changed == str(c.get_meta(_CAT, "")):
				apply(c)
		c.set_meta(_LISTENER, listener)
		c.set_meta(_RESORT, func() -> void: apply(c))
		c.resized.connect(func() -> void: fit_pivot(c))
		c.tree_entered.connect(func() -> void: _listen(c, true))
		c.tree_exited.connect(func() -> void: _listen(c, false))
		if c.is_inside_tree():
			_listen(c, true)
	apply(c)


static func is_attached(c: Control) -> bool:
	return c != null and c.has_meta(_CAT)


## The scale `c` rests at: its category's size if attached, else Vector2.ONE.
static func target_scale(c: Control) -> Vector2:
	var settings := _settings()
	if not is_attached(c) or settings == null:
		return Vector2.ONE
	return Vector2.ONE * float(settings.call("ui_scale_of", str(c.get_meta(_CAT))))


## Snap `c` to its category's size (kills nothing: a running pop ends where it ends).
static func apply(c: Control) -> void:
	fit_pivot(c)
	c.scale = target_scale(c)


## Put `c`'s pivot back on its fixed point (after a resize, or an animation moved it).
static func fit_pivot(c: Control) -> void:
	var at: Vector2 = c.get_meta(_PIVOT, FROM_ANCHORS)
	if at == FROM_ANCHORS:
		at = _anchor_point(c)
	# Before its first layout a control can still read 0 x 0; it will be at least its
	# minimum, so pivot on that rather than the corner.
	var pivot := c.size.max(c.get_combined_minimum_size()) * at
	if not c.pivot_offset.is_equal_approx(pivot):
		c.pivot_offset = pivot


static func _anchor_point(c: Control) -> Vector2:
	if c.get_parent() is Container:
		return Vector2(0.5, 0.5)  # a container places it; its anchors mean nothing
	return Vector2((c.anchor_left + c.anchor_right) * 0.5, (c.anchor_top + c.anchor_bottom) * 0.5)


static func _listen(c: Control, on: bool) -> void:
	_follow_sorts(c, on)
	var settings := _settings()
	if settings == null:
		return
	var listener: Callable = c.get_meta(_LISTENER)
	var linked := settings.is_connected("ui_scale_changed", listener)
	if on and not linked:
		settings.connect("ui_scale_changed", listener)
		apply(c)
	elif not on and linked:
		settings.disconnect("ui_scale_changed", listener)


## A Container parent resets `c`'s scale to one each time it lays `c` out; put it back
## right after (sort_children fires once the children are fitted).
static func _follow_sorts(c: Control, on: bool) -> void:
	var box := c.get_parent() as Container
	if box == null:
		return
	var resort: Callable = c.get_meta(_RESORT)
	var linked := box.sort_children.is_connected(resort)
	if on and not linked:
		box.sort_children.connect(resort)
	elif not on and linked:
		box.sort_children.disconnect(resort)


## The Settings autoload, looked up by path: Craft (and so this script) is compiled by
## headless tool scripts before autoload names exist, so the bare name can't be used.
static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null else null
