class_name ShopFixtures
extends Node3D

## Two of the front room's building jobs that had nothing to show for themselves, given
## something to change (docs/STORY_AND_RENOVATION.md §6.13):
##  - "Reglaze the shop window": until it is done a film of grime, with a crack or two, sits
##    on each shop window (one per boarded window, sized from its boards).
##  - "Fix the wiring and lamps": three little wall lamps on the front room's west wall.
##    Grey, dusty and drooping off their arms until then (one has lost its shade); after,
##    cream shades and bright brass, sitting up straight. They are never lit: a lamp that
##    glows in daylight only looked silly (owner, 2026-09-22).
## Drawn from primitives and small generated textures, to stay cute and simple. The
## RenovationDirector builds this and calls apply() whenever the renovation changes.

const WINDOW_JOB := "front_window"
const LIGHTS_JOB := "front_lights"
## Where the lamps are fixed: on the front room's WEST wall (it stands full height and never
## fades), above the keepsake shelf, between the rack and the mirror, and over the mirror.
## x is the wall's face; y is the arm's height.
const LAMPS: Array[Vector3] = [
	Vector3(-4.22, 2.05, 3.3),
	Vector3(-4.22, 2.05, 5.95),
	Vector3(-4.22, 2.05, 7.6),
]
const ARM := 0.16  # how far the arm reaches out from the wall (before LAMP_SCALE)
## The lamp is modelled at real size and then scaled up: at the game camera's distance a
## real wall lamp was a speck. Chunky reads as cute.
const LAMP_SCALE := 2.0
const SHADE_TOP := 0.11
const SHADE_BOTTOM := 0.05
const SHADE_TALL := 0.14
const PLATE := 0.06
const DEAD_SHADE := Color(0.30, 0.29, 0.28)
const LIT_SHADE := Color(0.99, 0.9, 0.62)
const DULL_BRASS := Color(0.36, 0.33, 0.28)
const BRASS := Color(0.78, 0.6, 0.3)
const DROOP := 38.0  # degrees a broken lamp hangs off its arm
## The grime on the old glass: how much of the pane it hides, and its colour.
const GRIME := Color(0.36, 0.34, 0.29, 0.8)
const FILM_OUT := 0.03  # just behind the boards' inner face, on the glass

var _films: Array[MeshInstance3D] = []
var _lamps: Array[Dictionary] = []  # {head, shade, bulb}
var _shade_mat: StandardMaterial3D
var _brass_mat: StandardMaterial3D


## Build the films over the windows (`windows`: each window's boards, as world boxes) and the
## lamps. Everything is placed in world space (LAMPS too).
func build(windows: Array[AABB]) -> void:
	_build_films(windows)
	_build_lamps()


func apply() -> void:
	var glazed := Renovation.is_done(WINDOW_JOB)
	for film in _films:
		film.visible = not glazed
	var fixed := Renovation.is_done(LIGHTS_JOB)
	_shade_mat.albedo_color = LIT_SHADE if fixed else DEAD_SHADE
	_brass_mat.albedo_color = BRASS if fixed else DULL_BRASS
	_brass_mat.metallic = 0.7 if fixed else 0.1
	for i in _lamps.size():
		var lamp: Dictionary = _lamps[i]
		var head := lamp["head"] as Node3D
		# one tips forward off its arm, the next sags sideways
		head.rotation_degrees = Vector3.ZERO
		if not fixed and i % 2 == 0:
			head.rotation_degrees.z = -DROOP
		elif not fixed:
			head.rotation_degrees.x = DROOP * 0.7
		(lamp["shade"] as Node3D).visible = fixed or i != 1  # the middle one lost its shade
		(lamp["bulb"] as Node3D).visible = fixed


## World boxes the builders work at for these jobs: the windows, or the lamps.
func work_boxes(job: String) -> Array[AABB]:
	var out: Array[AABB] = []
	if job == WINDOW_JOB:
		for film in _films:
			var size := Vector3((film.mesh as QuadMesh).size.x, (film.mesh as QuadMesh).size.y, 0.4)
			out.append(AABB(film.global_position - size / 2.0, size))
	elif job == LIGHTS_JOB:
		for lamp in _lamps:
			var at := (lamp["head"] as Node3D).global_position
			out.append(AABB(at - Vector3(0.1, 0.5, 0.45), Vector3(0.6, 0.9, 0.9)))
	return out


# --- Building --------------------------------------------------------------------


func _build_films(windows: Array[AABB]) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grime_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	for box in windows:
		var film := MeshInstance3D.new()
		film.name = "WindowGrime"
		var quad := QuadMesh.new()
		quad.size = Vector2(box.size.x * 0.92, box.size.y * 0.92)
		film.mesh = quad
		film.material_override = mat
		film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(film)
		film.global_position = Vector3(box.get_center().x, box.get_center().y, box.position.z)
		film.global_position.z -= FILM_OUT
		_films.append(film)


func _build_lamps() -> void:
	_shade_mat = StandardMaterial3D.new()
	_shade_mat.roughness = 0.8
	_shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_brass_mat = StandardMaterial3D.new()
	_brass_mat.roughness = 0.4
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(0.98, 0.96, 0.9)
	bulb_mat.roughness = 0.2
	for at in LAMPS:
		var lamp := Node3D.new()  # on the wall, facing into the room (+x)
		lamp.name = "WallLamp"
		add_child(lamp)
		lamp.global_position = at
		lamp.scale = Vector3.ONE * LAMP_SCALE
		var plate := _mesh(_cylinder(PLATE, PLATE, 0.02), _brass_mat)
		plate.rotation_degrees.z = 90.0
		lamp.add_child(plate)
		var arm := _mesh(_cylinder(0.012, 0.012, ARM), _brass_mat)
		arm.rotation_degrees.z = 90.0
		arm.position.x = ARM / 2.0
		lamp.add_child(arm)
		var head := Node3D.new()  # the end of the arm: a broken lamp droops from here
		head.position.x = ARM
		lamp.add_child(head)
		var cup := _mesh(_cylinder(0.025, 0.025, 0.05), _brass_mat)
		cup.position.y = 0.025
		head.add_child(cup)
		var shade := _mesh(_cylinder(SHADE_TOP, SHADE_BOTTOM, SHADE_TALL), _shade_mat)
		shade.position.y = 0.05 + SHADE_TALL / 2.0
		head.add_child(shade)
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.035
		bulb_mesh.height = 0.07
		var bulb := _mesh(bulb_mesh, bulb_mat)
		bulb.position.y = 0.09
		head.add_child(bulb)
		_lamps.append({"head": head, "shade": shade, "bulb": bulb})


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _cylinder(top: float, bottom: float, tall: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = tall
	c.radial_segments = 16
	c.cap_top = false
	c.cap_bottom = false
	return c


## Grey-brown grime, thicker at the edges, with a couple of cracks drawn across it.
func _grime_texture() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.06
	for y in n:
		for x in n:
			var edge := minf(minf(x, n - 1 - x), minf(y, n - 1 - y)) / (n * 0.5)
			var thick := 0.75 + 0.35 * noise.get_noise_2d(x, y) + 0.3 * (1.0 - edge)
			img.set_pixel(x, y, Color(GRIME, clampf(GRIME.a * thick, 0.45, 0.95)))
	var cracks: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(18, 10), Vector2(40, 38), Vector2(36, 60), Vector2(58, 92)]),
		PackedVector2Array([Vector2(40, 38), Vector2(70, 44), Vector2(96, 30)]),
		PackedVector2Array([Vector2(110, 118), Vector2(92, 96), Vector2(98, 74)]),
	]
	for line in cracks:
		for i in line.size() - 1:
			_draw_line(img, line[i], line[i + 1], Color(0.92, 0.92, 0.88, 0.85))
	return ImageTexture.create_from_image(img)


func _draw_line(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		img.set_pixel(clampi(int(p.x), 0, img.get_width() - 1), clampi(int(p.y), 0, 127), color)
