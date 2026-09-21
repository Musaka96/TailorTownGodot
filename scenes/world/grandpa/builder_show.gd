class_name BuilderShow
extends RenovationFx

## The builders at work, on the spot: building work bought from the phone plays out here
## in a few seconds instead of happening overnight (docs/STORY_AND_RENOVATION.md §6.13).
##
## The camera glides to the job and the roof fades as if the player stood there; the
## builders' kit pops in; dust puffs and hammering, sawing or rolling while they work; a
## cloud goes up, the job is finished under it (Renovation.finish_build) and it clears on
## the finished room with a sparkle and a little tune. The RenovationDirector locks the
## player and stops the clock around perform().
##
## After the first show of a session a press of interact skips to the reveal.

## How long the show runs: a room (or the workshop roof) gets the whole thing, a smaller
## job the short one.
const FULL := 6.0
const SHORT := 4.5
const ARRIVE := 0.7  # the camera's glide over before the kit arrives
const KNOCK_EVERY := 0.55  # one bit of hammering (a puff and a knock) this often
const CLOUD_BEFORE := 2.4  # the big cloud goes up this long before the end
const SWAP_BEFORE := 2.0  # and the job is finished under it this long before the end
const CLOUD_LIFE := 1.3  # thick for half of it, then thinning: clear a second before the end
const SKIP_AFTER := 0.4  # the press that ordered the job must not also skip the show
const SKIPPED_SWAP := 0.35  # a skipped show still hides its swap in the cloud this long
const SKIPPED_TAIL := 0.8  # and shows the finished room for this long
## How near the camera comes, as a share of its usual distance from the player.
const ZOOM := 0.85
const TOOLS := ["reno_hammer", "reno_saw", "reno_hammer", "reno_drill"]
const PAINT_TOOLS := ["reno_roller", "reno_hammer", "reno_roller", "reno_drill"]
const PAINT_JOBS := ["front_paper", "facade_paint"]
const CLOUD := Color(0.92, 0.88, 0.82)
const CLOUD_SIZE := 1.5
const KIT_POP := 0.35
const REVEAL_BURSTS := 4

## Set once a whole show has played this session: from then on a press may skip one.
static var seen := false

var _quad_cloud: QuadMesh
var _playing := false
var _skip := false
var _elapsed := 0.0  # seconds into the show, in game time (frames, not the wall clock)


func _ready() -> void:
	super()
	_quad_cloud = _quad(CLOUD_SIZE, false)


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if not seen or _skip or _elapsed < SKIP_AFTER:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_skip = true


## Play the builders' job `id` over `box` (world space: where the work happens) and finish
## it. `kit` is the builders' clutter for that room, if it has any; `big` picks the long
## show. Returns once the camera is on its way back.
func perform(id: String, box: AABB, kit: Node3D, big: bool) -> void:
	_playing = true
	_skip = false
	_elapsed = 0.0
	var total := FULL if big else SHORT
	var centre := box.get_center()
	var ground := Vector3(centre.x, box.position.y, centre.z)
	_frame(ground)
	RoofManager.watch(ground)
	_sfx("reno_knock", -4.0)
	await _until(ARRIVE)
	if not _skip:
		_pop(kit)
		_motes(ground + Vector3(0, 0.4, 0), Vector3(0.8, 0.3, 0.8), DUST, 18, 1.0)
	var tools: Array = PAINT_TOOLS if id in PAINT_JOBS else TOOLS
	var at := ARRIVE + 0.3
	var knocks := 0
	while at < total - CLOUD_BEFORE and not _skip:
		await _until(at)
		if _skip:
			break
		_knock(box, str(tools[knocks % tools.size()]))
		knocks += 1
		at += KNOCK_EVERY
	await _until(total - CLOUD_BEFORE)
	_cloud(box)
	_sfx("reno_poof", -3.0)
	if _skip:
		await _wait(SKIPPED_SWAP)
	else:
		await _until(total - SWAP_BEFORE)
	Renovation.finish_build(id)
	await _wait(0.3)
	_reveal(box)
	if _skip:
		await _wait(SKIPPED_TAIL)
	else:
		await _until(total)
	_release()
	seen = true
	_playing = false


# --- The beats -----------------------------------------------------------------------


## Glide the camera over the job, a little nearer than usual.
func _frame(ground: Vector3) -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if rig == null:
		return
	var cam := rig.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var off := cam.global_position - rig.global_position
	rig.focus(ground + off * ZOOM, ground)


func _release() -> void:
	RoofManager.unwatch()
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if rig != null:
		rig.unfocus()


## The builders' kit turns up with a hop.
func _pop(kit: Node3D) -> void:
	if kit == null or not kit.visible:
		return
	kit.scale = Vector3.ONE * 0.05
	var hop := create_tween()
	hop.tween_property(kit, "scale", Vector3.ONE, KIT_POP).set_trans(Tween.TRANS_BACK)
	hop.set_ease(Tween.EASE_OUT)


## One bit of work somewhere in the room: a knock (or a saw stroke, a whirr, a roll), a
## few chips and a puff.
func _knock(box: AABB, sound: String) -> void:
	var inset := Vector3(0.4, 0, 0.4)
	var lo := box.position + inset
	var hi := box.end - inset
	var at := Vector3(
		randf_range(lo.x, maxf(lo.x, hi.x)),
		box.position.y + randf_range(0.3, 1.3),
		randf_range(lo.z, maxf(lo.z, hi.z)),
	)
	_burst(at, _quad_chip, DUST.darkened(0.25), 8, 1.2, 2.2, 0.5, false, -9.0)
	_motes(at, Vector3(0.25, 0.15, 0.25), DUST, 10, 0.9)
	_sfx(sound, -5.0, 0.93, 1.08)


## The big cloud: soft dust filling the whole job, thick enough to hide the change.
func _cloud(box: AABB) -> void:
	var floor_area := maxf(box.size.x * box.size.z, 1.0)
	var p := _particles(
		_quad_cloud, Color(CLOUD, 0.9), clampi(int(floor_area * 6.0), 40, 150), CLOUD_LIFE
	)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 1))
	ramp.add_point(0.45, Color(1, 1, 1, 1))
	p.color_ramp = ramp
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(box.size.x * 0.5, 0.6, box.size.z * 0.5)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, 0.1, 0)
	p.damping_min = 0.5
	p.damping_max = 0.9
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	_launch(p, box.get_center() + Vector3(0, 0.9 - box.size.y / 2.0, 0))


## The cloud clears on the finished job: a shower of gold and a little tune.
func _reveal(box: AABB) -> void:
	var ground := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	# a few glints from spots across the room: one burst of forty from a single point
	# stacks its additive quads into a white ball
	for i in REVEAL_BURSTS:
		var at := (
			ground
			+ Vector3(box.size.x * randf_range(-0.3, 0.3), 0.8, box.size.z * randf_range(-0.3, 0.3))
		)
		_burst(at, _quad_glint, GOLD, 8, 1.4, 2.6, 0.9, true)
	var spread := Vector3(box.size.x * 0.4, 0.8, box.size.z * 0.4)
	_motes(ground + Vector3(0, 1.0, 0), spread, GOLD, 36, 1.8)
	_sfx("reno_reveal", -3.0)


# --- Helpers ------------------------------------------------------------------------


func _sfx(sound: String, db: float, lo := 1.0, hi := 1.0) -> void:
	if Sfx != null:
		Sfx.play(sound, db, lo, hi)


## Wait until `seconds` into the show, or until the player skips.
func _until(seconds: float) -> void:
	while not _skip and _elapsed < seconds:
		await get_tree().process_frame
