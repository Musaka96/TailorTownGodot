class_name RenovationFx
extends Node3D

## The hands-on renovation jobs played out instead of snapped away. The player leans in
## and works at it for a moment, the thing comes away with a little animation and a puff
## of dust, and a sparkle says it is done. The RenovationDirector owns one of these and
## waits on play() before it clears the spot (docs/STORY_AND_RENOVATION.md §6.12).
##
## Nothing here changes the renovation's state. play() leaves the host hidden with every
## piece under it put back where it was, so the director's own show/hide takes over again.

enum Kind { PILE, SHEET, BOARDS }

## How long each job takes, from the press to the moment it is gone. A pile is a scoop, a
## sheet is a whip, boards are a wrench.
const SECONDS := {Kind.PILE: 0.6, Kind.SHEET: 0.9, Kind.BOARDS: 1.2}
## The sparkle tail after the job, before the player can move again.
const PAYOFF := 0.25
const DUST := Color(0.82, 0.74, 0.62)
const GOLD := Color(1.0, 0.85, 0.48)
const FLOOR_Y := 0.06  # where a falling plank comes to rest (the shop floor, near enough)

## Each plank's part in the wrench: when it starts, relative to the job.
const BOARD_FIRST := 0.2
const BOARD_SPREAD := 0.75  # the planks' starts are shared out over this long
const PRY := 0.14
const FALL := 0.32
const SHRINK := 0.22

var _quad_soft: QuadMesh
var _quad_glint: QuadMesh
var _quad_chip: BoxMesh


func _ready() -> void:
	_quad_soft = _quad(0.28, false)
	_quad_glint = _quad(0.1, true)
	_quad_chip = BoxMesh.new()
	_quad_chip.size = Vector3(0.05, 0.03, 0.05)
	var chip := StandardMaterial3D.new()
	chip.vertex_color_use_as_albedo = true
	chip.roughness = 1.0
	_quad_chip.material = chip


## Play one job on `host` (a mess pile, a dust sheet, or boards across an opening), with
## `player` doing it if there is one. Returns once the host has gone.
func play(kind: Kind, host: Node3D, player: Node3D) -> void:
	var seconds: float = SECONDS[kind]
	var saved := _remember(host)
	if player != null and player.has_method("work_at"):
		player.call("work_at", _centre(host), seconds)
	var toward := _toward(host, player)
	match kind:
		Kind.PILE:
			await _pile(host, toward, seconds)
		Kind.SHEET:
			await _sheet(host, toward, seconds)
		Kind.BOARDS:
			await _boards(host, toward)
	host.visible = false
	_restore(saved)


## The job is done: a pinch of gold where it was. `big` when it finished the whole
## project, and `opens` when it let the player into a room.
func celebrate(at: Vector3, big: bool, opens: bool) -> void:
	var count := 32 if big else 14
	_burst(at, _quad_glint, GOLD, count, 1.4, 2.2, 0.6, true)
	if Sfx != null:
		Sfx.play("reno_tick", -3.0, 0.95, 1.08)
	if not big or Sfx == null:
		return
	await get_tree().create_timer(0.12).timeout
	Sfx.play("reno_open" if opens else "reno_done", -2.0)
	if opens:  # light spilling in through the doorway
		_motes(at + Vector3(0, 0.6, 0), Vector3(0.6, 0.9, 0.6), GOLD, 30, 1.8)


# --- The three jobs ----------------------------------------------------------------


## Scoop the heap up in handfuls: it squashes under the first grab, then its bits hop one
## after another toward the player and shrink away, as if into a sack.
func _pile(host: Node3D, toward: Vector3, seconds: float) -> void:
	if Sfx != null:
		Sfx.play("reno_scoop", -2.0, 0.9, 1.1)
	var squash := create_tween()
	squash.tween_interval(0.08)
	squash.tween_property(host, "scale", Vector3(1.18, 0.55, 1.18), 0.1)
	squash.tween_property(host, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	var bits := _meshes(host)
	for i in bits.size():
		var bit := bits[i]
		var local_toward := _local_dir(bit, toward)
		var start := 0.14 + 0.3 * float(i) / maxf(1.0, bits.size() - 1.0)
		var hop := create_tween()
		hop.tween_interval(start)
		var to := bit.position + local_toward * 0.5 + Vector3(0, 0.35, 0)
		var up := bit.position + local_toward * 0.2 + Vector3(0, 0.7, 0)
		hop.tween_property(bit, "position", up, 0.1).set_ease(Tween.EASE_OUT)
		hop.tween_property(bit, "position", to, 0.12).set_ease(Tween.EASE_IN)
		hop.parallel().tween_property(bit, "scale", Vector3.ZERO, 0.12).set_ease(Tween.EASE_IN)
	await _wait(0.2)
	var at := _centre(host)
	_burst(at, _quad_chip, _tint(host).darkened(0.15), 16, 1.8, 2.8, 0.55, false, -9.0)
	_motes(at, Vector3(0.5, 0.2, 0.5), DUST, 20, 1.0)
	await _wait(0.22)
	if Sfx != null:
		Sfx.play("reno_tumble", -3.0, 0.92, 1.08)
	await _wait(seconds - 0.42)


## Two tugs, then the whip: the sheet flies up and over toward the player, crumpling as it
## goes, and leaves a cloud of old dust hanging where it lay.
func _sheet(host: Node3D, toward: Vector3, seconds: float) -> void:
	if Sfx != null:
		Sfx.play("cloth_rustle", -2.0, 0.95, 1.1)
	# tipping about this axis leans the top toward the player
	var axis := Vector3.UP.cross(_local_dir(host, toward)).normalized()
	var rest := host.quaternion
	var tug := create_tween()
	for i in 2:
		var lean := Quaternion(axis, deg_to_rad(5.0)) * rest
		tug.tween_property(host, "quaternion", lean, 0.08).set_trans(Tween.TRANS_SINE)
		tug.tween_property(host, "quaternion", rest, 0.09).set_trans(Tween.TRANS_SINE)
	await _wait(0.35)
	if Sfx != null:
		Sfx.play("reno_whip", -1.0, 0.95, 1.05)
	var at := _centre(host)
	var box := _box(host)
	_motes(at, box.size * 0.5, DUST, 24, 1.3)
	var go := _local_dir(host, toward) * 0.7 + Vector3(0, 0.9, 0)
	var whip := seconds - 0.35
	var fly := create_tween().set_parallel()
	fly.tween_property(host, "position", host.position + go, whip).set_ease(Tween.EASE_OUT)
	var over := Quaternion(axis, deg_to_rad(110.0)) * rest
	fly.tween_property(host, "quaternion", over, whip).set_trans(Tween.TRANS_SINE)
	fly.tween_property(host, "scale", Vector3(0.35, 0.12, 0.35), whip).set_ease(Tween.EASE_IN)
	await fly.finished


## Prise the planks off one by one: each gives with a creak, tips, tumbles to the floor,
## bounces, and is gone.
func _boards(host: Node3D, toward: Vector3) -> void:
	var planks := _meshes(host)
	var last := 0.0
	for i in planks.size():
		var start := BOARD_FIRST + BOARD_SPREAD * float(i) / maxf(1.0, planks.size() - 1.0)
		_prise(planks[i], toward, start)
		last = start
	await _wait(last + PRY + FALL + SHRINK + 0.05)


func _prise(plank: MeshInstance3D, toward: Vector3, start: float) -> void:
	await _wait(start)
	if Sfx != null:
		Sfx.play("reno_creak", -3.0, 0.9, 1.15)
	var parent := plank.get_parent() as Node3D
	# one end gives first: a turn in the plank's own face
	var tip := Quaternion(Vector3.BACK, deg_to_rad(randf_range(14.0, 24.0)))
	var pried := plank.quaternion * tip
	var out := _local_dir(plank, toward) * 0.12
	var give := create_tween().set_parallel()
	give.tween_property(plank, "quaternion", pried, PRY).set_trans(Tween.TRANS_BACK)
	give.tween_property(plank, "position", plank.position + out, PRY)
	await give.finished
	var land := plank.global_position + toward * randf_range(0.3, 0.5)
	land.y = FLOOR_Y
	var land_local := parent.to_local(land) if parent != null else land
	# lying flat on the floor, at a careless angle
	var flat := Quaternion(Vector3.UP, randf_range(-0.6, 0.6)) * Quaternion(Vector3.RIGHT, PI * 0.5)
	if parent != null:
		flat = parent.global_basis.get_rotation_quaternion().inverse() * flat
	var fall := create_tween().set_parallel()
	fall.tween_property(plank, "position", land_local, FALL).set_ease(Tween.EASE_IN)
	fall.tween_property(plank, "quaternion", flat, FALL).set_trans(Tween.TRANS_QUAD)
	await fall.finished
	if Sfx != null:
		Sfx.play("reno_clatter", -3.0, 0.9, 1.1)
	_burst(land, _quad_chip, _tint(plank), 6, 1.0, 1.8, 0.4, false, -9.0)
	_motes(land, Vector3(0.3, 0.05, 0.3), DUST, 6, 0.7)
	var gone := create_tween()
	var size := plank.scale
	gone.tween_property(plank, "scale", size * Vector3(1.1, 0.6, 1.1), 0.07)
	gone.tween_property(plank, "scale", Vector3.ZERO, SHRINK - 0.07).set_ease(Tween.EASE_IN)


# --- Particles ---------------------------------------------------------------------


## A one-shot spray from `at`: `count` bits flung outwards and up.
func _burst(
	at: Vector3,
	mesh: Mesh,
	color: Color,
	count: int,
	speed_lo: float,
	speed_hi: float,
	life: float,
	glow: bool,
	fall := -2.0,
) -> void:
	var p := _particles(mesh, color, count, life)
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed_lo
	p.initial_velocity_max = speed_hi
	p.gravity = Vector3(0, fall, 0)
	p.scale_amount_min = 0.6 if glow else 0.5
	p.scale_amount_max = 1.4 if glow else 1.3
	if not glow:  # solid chips can't fade, so they tumble and shrink away instead
		p.angle_max = 180.0
		var shrink := Curve.new()
		shrink.add_point(Vector2(0.0, 1.0))
		shrink.add_point(Vector2(0.7, 0.8))
		shrink.add_point(Vector2(1.0, 0.0))
		p.scale_amount_curve = shrink
	_launch(p, at)


## Slow soft dust hanging in the air through a box, drifting up and thinning out.
func _motes(at: Vector3, extents: Vector3, color: Color, count: int, life: float) -> void:
	var p := _particles(_quad_soft, Color(color, 0.45), count, life)
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0, 0.15, 0)
	p.damping_min = 0.3
	p.damping_max = 0.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	_launch(p, at)


func _particles(mesh: Mesh, color: Color, count: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p


## Particles live under this node, not the host, so hiding the host doesn't cut them off.
func _launch(p: CPUParticles3D, at: Vector3) -> void:
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


func _quad(size: float, glow: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	if glow:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	else:
		mat.albedo_texture = _soft_dot()
	quad.material = mat
	return quad


## A round, soft-edged dot, so a dust puff is a puff and not a square.
func _soft_dot() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex


# --- Helpers -----------------------------------------------------------------------


## Every piece under `host` and the host itself, as they stand now: node -> [transform,
## visible], so play() can put them all back once the host is hidden.
func _remember(host: Node3D) -> Dictionary:
	var saved := {host: [host.transform, host.visible]}
	for node in host.find_children("*", "Node3D", true, false):
		var piece := node as Node3D
		saved[piece] = [piece.transform, piece.visible]
	return saved


func _restore(saved: Dictionary) -> void:
	var first := true
	for key: Variant in saved:
		if not is_instance_valid(key):
			continue
		var node := key as Node3D
		node.transform = saved[node][0]
		if not first:  # the host itself stays hidden; the director decides when it shows
			node.visible = saved[node][1]
		first = false


func _meshes(host: Node3D) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree():
			found.append(mesh)
	return found


func _box(host: Node3D) -> AABB:
	var box := AABB(host.global_position, Vector3.ZERO)
	for mesh in _meshes(host):
		box = box.merge(mesh.global_transform * mesh.get_aabb())
	return box


func _centre(host: Node3D) -> Vector3:
	return _box(host).get_center()


## Flat unit vector in the world from the host toward the player (or toward the camera's
## side of the room when there is no player).
func _toward(host: Node3D, player: Node3D) -> Vector3:
	var to := Vector3(0, 0, 1)
	if player != null:
		to = player.global_position - _centre(host)
	to.y = 0.0
	return to.normalized() if to.length_squared() > 0.0001 else Vector3(0, 0, 1)


## A world direction in `node`'s parent space, so it can be added to its position.
func _local_dir(node: Node3D, world_dir: Vector3) -> Vector3:
	var parent := node.get_parent() as Node3D
	if parent == null:
		return world_dir
	return (parent.global_basis.inverse() * world_dir).normalized()


## The colour of the first piece under `host`, for chips that match what they broke off.
func _tint(host: Node3D) -> Color:
	for mesh in _meshes(host):
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			mat = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat != null:
			return mat.albedo_color
	return DUST


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(maxf(seconds, 0.0)).timeout
