extends Node

## Central sound manager — autoloaded as "Sfx".
##
## Owns the sound library (a name -> file map), a small pool of one-shot players,
## the level music player and any named loops (e.g. the sewing machine). It wires
## itself to EventBus so gameplay moments make sound without each system knowing
## about audio; UI moments that aren't on the bus (menu open, page turn, the
## shop-closed buzz) call `Sfx.play("...")` directly. Runs while the game is paused
## or input is locked so menus and transitions still sound.

const DIR := "res://assets/audio/"
const POOL := 8
## The shop's working music, and the quieter one the main menu waits on.
const THEME := "music_stitch_shop_stroll"
const MENU_THEME := "music_thread_and_thimble"
## Music fades: how quiet "off" is, how swiftly a track bows out, and how gently the next
## one swells in behind the curtain.
const MUSIC_SILENT := -40.0
const MUSIC_OUT := 0.5
const MUSIC_IN := 2.5

## Logical name -> file under DIR. Add a sound here, then trigger it with
## Sfx.play("name") or wire it to a signal in _connect_events().
const LIB := {
	# UI
	"menu_open": "menu_open.wav",
	"page_turn": "page_turn.wav",
	"error": "error.wav",
	# customers & economy
	"door_chime": "door_chime.wav",
	"door_open": "door_open.wav",
	"door_close": "door_close.wav",
	# tutorial mentor's placeholder "cartoon talk" syllables (swap the files for real VO)
	"mentor_blip":
	[
		"mentor_blip_1.wav",
		"mentor_blip_2.wav",
		"mentor_blip_3.wav",
		"mentor_blip_4.wav",
		"mentor_blip_5.wav",
	],
	"phone_order": "phone_order.wav",
	"coins": "coins.wav",
	"happy": "happy.wav",
	"unhappy": "unhappy.wav",
	"pin_in": "pin_in.wav",
	"pin_out": "pin_out.wav",
	"fabric_unroll": "fabric_unroll.wav",
	# stations & handling
	"drawer": "drawer.wav",
	"chalk": "chalk.wav",
	"tape": "tape.wav",
	"snip": "snip.wav",
	"scissors_run": "scissors_run.wav",
	"scissors_glide": "scissors_glide_loop.wav",  # synthesised, build_cut_audio.gd
	# workshop furniture (synthesised, build_shop_audio.gd)
	"steam_hiss": "steam_hiss.wav",
	"coffee_pour": "coffee_pour.wav",
	# the pressing and coffee minigames (synthesised, build_comfort_audio.gd)
	"iron_glide": "iron_glide_loop.wav",
	"scorch": "scorch.wav",
	"grinder": "grinder_loop.wav",
	"tamp": "tamp.wav",
	"pour": "pour_loop.wav",
	"stitch": "stitch.wav",
	"sew_machine": "sew_machine.wav",
	"sew_machine_loop": "sew_machine_loop.wav",
	# the sewing minigame's per-tap cues (synthesised, build_sewing_audio.gd)
	"sew_stitch_good": "sew_stitch_good.wav",
	"sew_stitch_perfect": "sew_stitch_perfect.wav",
	"sew_tap": "sew_tap.wav",
	# menu navigation (generated locally, Stable Audio Open)
	"ui_move": "ui_move.wav",
	"ui_confirm": "ui_confirm.wav",
	"ui_cancel": "ui_cancel.wav",
	# player movement & handling (a footstep set is picked at random per step)
	"footstep_wood": ["footstep_wood_1.wav", "footstep_wood_2.wav", "footstep_wood_3.wav"],
	"footstep_rug": "footstep_rug.wav",
	"cloth_rustle": "cloth_rustle.wav",
	"pickup": "pickup.wav",
	"putdown": "putdown.wav",
	# the stage curtain over every scene change (synthesised, build_curtain_audio.gd)
	"curtain_close": "curtain_close.wav",
	"curtain_open": "curtain_open.wav",
	"sign_drop": "sign_drop.wav",
	"sign_hoist": "sign_hoist.wav",
	"sign_sew": "sign_sew.wav",
	"juice_note": "juice_note.wav",
	"juice_top": "juice_top.wav",
	"juice_drop": "juice_drop.wav",
	"juice_stamp": "juice_stamp.wav",
	# renovation by hand (synthesised, build_renovation_audio.gd)
	"reno_scoop": "reno_scoop.wav",
	"reno_tumble": "reno_tumble.wav",
	"reno_whip": "reno_whip.wav",
	"reno_creak": "reno_creak.wav",
	"reno_clatter": "reno_clatter.wav",
	"reno_tick": "reno_tick.wav",
	"reno_done": "reno_done.wav",
	"reno_open": "reno_open.wav",
	# the builders' show (BuilderShow): Stable Audio Open takes, trimmed; the poof is synthesised
	"reno_knock": "reno_knock.wav",
	"reno_hammer": "reno_hammer.wav",
	"reno_saw": "reno_saw.wav",
	"reno_drill": "reno_drill.wav",
	"reno_roller": "reno_roller.wav",
	"reno_poof": "reno_poof.wav",
	"reno_reveal": "reno_reveal.wav",
	# world stingers & ambience
	"new_order_ping": "new_order_ping.wav",
	"order_complete": "order_complete.wav",
	"day_start": "day_start.wav",
	"day_end": "day_end.wav",
	"ambience_loop": "ambience_loop.wav",
	# music
	"music_stitch_shop_stroll": "music_stitch_shop_stroll.mp3",
	"music_thread_and_thimble": "music_thread_and_thimble.mp3",
}

# Global trims — everything is deliberately soft and cozy, not in-your-face.
var sfx_volume := -7.0
var music_volume := -17.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}
var _singles: Dictionary = {}  # key -> its one dedicated player (play_single)
var _music: AudioStreamPlayer
var _next := 0
## Music fade in flight: where the volume is heading, how fast, and whether to stop there.
var _fade_target := 0.0
var _fade_rate := 0.0
var _fade_stops := false


func _ready() -> void:
	# Keep sounding while modal menus lock input or the day-change pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for key in LIB:
		var val: Variant = LIB[key]
		if val is Array:
			# A set of variants for one name (footsteps) — play() picks one at random.
			var variants: Array[AudioStream] = []
			for fname: String in val:
				var vp: String = DIR + fname
				if ResourceLoader.exists(vp):
					variants.append(load(vp))
			if not variants.is_empty():
				_streams[key] = variants
		else:
			var path: String = DIR + str(val)
			if ResourceLoader.exists(path):
				_streams[key] = load(path)
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_connect_events()
	play_music(MENU_THEME)  # the game boots into the main menu
	start_loop("ambience_loop", -18.0)


func _process(delta: float) -> void:
	if is_zero_approx(_fade_rate):
		return
	_music.volume_db = move_toward(_music.volume_db, _fade_target, _fade_rate * delta)
	if not is_equal_approx(_music.volume_db, _fade_target):
		return
	_fade_rate = 0.0
	if _fade_stops:
		_music.stop()
		_fade_stops = false


## Create the Music and SFX buses (routed to Master) if they don't exist, so the
## Settings sliders can set their volumes live. Runs before any player is created.
func _ensure_buses() -> void:
	for nm in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nm) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")


## Fire a one-shot from the pool. `volume_db` trims this hit; a little random pitch
## keeps repeated sounds (footsteps, snips) from sounding machine-gun identical.
func play(key: String, volume_db := 0.0, pitch_min := 0.98, pitch_max := 1.02) -> void:
	var stream := _pick(key)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = sfx_volume + volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()


## Like play(), but only one instance of `key` sounds at a time: each key gets its
## own dedicated player and retriggering stops the previous hit instead of layering.
## Use it for sounds that fire in quick succession (page turns, menu-move blips) so
## they don't stack when the player scrubs fast.
func play_single(key: String, volume_db := 0.0, pitch_min := 0.98, pitch_max := 1.02) -> void:
	var stream := _pick(key)
	if stream == null:
		return
	var p: AudioStreamPlayer = _singles.get(key)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_singles[key] = p
	p.stop()
	p.stream = stream
	p.volume_db = sfx_volume + volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()


## Play the right navigation blip for a menu input event — call once at the top of a
## menu's _unhandled_input. Directional actions tick, accept confirms, cancel (or a right
## click) backs out.
func ui(event: InputEvent) -> void:
	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("cut")
	):
		ui_confirm()
	elif (
		event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or event.is_action_pressed("orders")
		or MousePick.is_back(event)
	):
		ui_cancel()
	elif (
		event.is_action_pressed("move_left")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("move_forward")
		or event.is_action_pressed("move_back")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
	):
		ui_move()


## The blips Sfx.ui plays, for a menu the mouse drives (see MousePick): a hover that moves
## the selection ticks, a click that confirms a row confirms.
func ui_move() -> void:
	play_single("ui_move", -7.0)


func ui_confirm() -> void:
	play("ui_confirm", -4.0)


func ui_cancel() -> void:
	play("ui_cancel", -4.0)


## The stream for `key` (a random variant for sets), for nodes that play it through
## their own (e.g. positional) player. Null when the sound isn't in the library.
func stream(key: String) -> AudioStream:
	return _pick(key)


## Resolve a key to a single stream — a random one when the key holds a variant set.
func _pick(key: String) -> AudioStream:
	var entry: Variant = _streams.get(key)
	if entry is Array:
		if entry.is_empty():
			return null
		return entry[randi() % entry.size()]
	return entry as AudioStream


## Start the looping level music at once (replaces whatever is playing).
func play_music(key: String) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	_fade_rate = 0.0
	_fade_stops = false
	_set_loop(stream, true)
	_music.stream = stream
	_music.volume_db = music_volume
	_music.play()


## Take the music down to silence over `seconds`, then stop it — so a track bows out ahead
## of a scene change instead of being cut off mid-bar.
func fade_music_out(seconds := MUSIC_OUT) -> void:
	if not _music.playing:
		return
	_fade_target = MUSIC_SILENT
	_fade_rate = absf(_music.volume_db - MUSIC_SILENT) / maxf(seconds, 0.01)
	_fade_stops = true


## Bring `key` up from silence over `seconds`. A no-op if that track is already playing and
## not on its way out, so calling it again doesn't restart the music.
func fade_music_in(key: String, seconds := MUSIC_IN) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	if _music.playing and _music.stream == stream and not _fade_stops:
		return
	_set_loop(stream, true)
	_music.stream = stream
	_music.volume_db = MUSIC_SILENT
	_music.play()
	_fade_target = music_volume
	_fade_rate = absf(music_volume - MUSIC_SILENT) / maxf(seconds, 0.01)
	_fade_stops = false


func stop_music() -> void:
	_fade_rate = 0.0
	_fade_stops = false
	_music.stop()


## Start a named continuous loop (its own player), e.g. the sewing machine while a
## seam is being stitched. Calling it again while already running is a no-op, so the
## pitch a caller set with set_loop_pitch survives; a fresh start goes back to normal.
func start_loop(key: String, volume_db := 0.0) -> void:
	var existing: AudioStreamPlayer = _loops.get(key)
	if existing != null and existing.playing:
		return
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var p := existing
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_loops[key] = p
	_set_loop(stream, true)
	p.stream = stream
	p.volume_db = sfx_volume + volume_db
	p.pitch_scale = 1.0
	p.play()


## Speed a running loop up or down — the sewing machine racing under the sprint, say.
## Harmless when that loop isn't running.
func set_loop_pitch(key: String, pitch: float) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p != null:
		p.pitch_scale = clampf(pitch, 0.25, 3.0)


## Fade a running loop's level (relative to the SFX level, like start_loop's volume_db).
func set_loop_volume(key: String, volume_db: float) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p != null:
		p.volume_db = sfx_volume + volume_db


func stop_loop(key: String) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p != null:
		p.stop()


## Make a stream repeat, whichever kind it is (WAV vs. compressed music).
func _set_loop(stream: AudioStream, on: bool) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var samples := int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED
		# A WAV imported without a loop region has loop_end 0, so switching the mode on here
		# would leave it looping over nothing. Fall back to the whole sample.
		if on and wav.loop_end <= wav.loop_begin:
			wav.loop_begin = 0
			wav.loop_end = samples
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = on


func _connect_events() -> void:
	EventBus.customer_waiting.connect(_on_customer_waiting)
	EventBus.order_placed.connect(_on_order_placed)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.order_created.connect(_on_order_created)
	EventBus.order_ready.connect(_on_order_ready)
	EventBus.order_fulfilled.connect(_on_order_fulfilled)
	EventBus.order_expired.connect(_on_order_expired)
	EventBus.item_stored.connect(_on_item_stored)
	EventBus.item_taken.connect(_on_item_taken)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_dropped.connect(_on_item_dropped)
	EventBus.order_due.connect(_on_order_due)
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.shift_ended.connect(_on_shift_ended)


func _on_customer_waiting(_customer: Node) -> void:
	play("door_chime")


func _on_order_placed(_material: MaterialType, _length: float, _cost: int) -> void:
	play("phone_order")


func _on_order_delivered(_roll: Node) -> void:
	play("fabric_unroll")


func _on_order_created(_order: Resource) -> void:
	play("pin_in")


func _on_order_ready(_order: Resource) -> void:
	play("order_complete")


func _on_order_fulfilled(_order: Resource, _payout: int) -> void:
	play("coins")
	play("pin_out", -4.0)


func _on_order_expired(_order: Resource) -> void:
	play("unhappy")


func _on_item_stored(_item: Node, _station: Node) -> void:
	play("drawer", -3.0)


func _on_item_taken(_item: Node, _station: Node) -> void:
	play("drawer", -3.0)


func _on_item_picked_up(_item: Node) -> void:
	play("pickup", -2.0)


func _on_item_dropped(_item: Node) -> void:
	play("putdown", -2.0)


func _on_order_due(_order: Resource) -> void:
	play("new_order_ping")


func _on_shift_started(_start_hour: float) -> void:
	play("day_start")


func _on_shift_ended() -> void:
	play("day_end")
