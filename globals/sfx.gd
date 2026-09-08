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
const THEME := "music_stitch_shop_stroll"

## Logical name -> file under DIR. Add a sound here, then trigger it with
## Sfx.play("name") or wire it to a signal in _connect_events().
const LIB := {
	# UI
	"menu_open": "menu_open.wav",
	"page_turn": "page_turn.wav",
	"error": "error.wav",
	# customers & economy
	"door_chime": "door_chime.wav",
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
	"stitch": "stitch.wav",
	"sew_machine": "sew_machine.wav",
	"sew_machine_loop": "sew_machine_loop.wav",
	# music
	"music_stitch_shop_stroll": "music_stitch_shop_stroll.mp3",
	"music_thread_and_thimble": "music_thread_and_thimble.mp3",
}

var sfx_volume := 0.0
var music_volume := -8.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}
var _music: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	# Keep sounding while modal menus lock input or the day-change pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in LIB:
		var path: String = DIR + LIB[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_connect_events()
	play_music(THEME)


## Fire a one-shot from the pool. `volume_db` trims this hit; a little random pitch
## keeps repeated sounds (footsteps, snips) from sounding machine-gun identical.
func play(key: String, volume_db := 0.0, pitch_min := 0.98, pitch_max := 1.02) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = sfx_volume + volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()


## Start the looping level music (replaces whatever is playing).
func play_music(key: String) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	_set_loop(stream, true)
	_music.stream = stream
	_music.volume_db = music_volume
	_music.play()


func stop_music() -> void:
	_music.stop()


## Start a named continuous loop (its own player), e.g. the sewing machine while a
## seam is being stitched. Calling it again while already running is a no-op.
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
		add_child(p)
		_loops[key] = p
	_set_loop(stream, true)
	p.stream = stream
	p.volume_db = sfx_volume + volume_db
	p.play()


func stop_loop(key: String) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p != null:
		p.stop()


## Make a stream repeat, whichever kind it is (WAV vs. compressed music).
func _set_loop(stream: AudioStream, on: bool) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED
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


func _on_customer_waiting(_customer: Node) -> void:
	play("door_chime")


func _on_order_placed(_material: MaterialType, _length: float, _cost: int) -> void:
	play("phone_order")


func _on_order_delivered(_roll: Node) -> void:
	play("fabric_unroll")


func _on_order_created(_order: Resource) -> void:
	play("pin_in")


func _on_order_ready(_order: Resource) -> void:
	play("happy")


func _on_order_fulfilled(_order: Resource, _payout: int) -> void:
	play("coins")
	play("pin_out", -4.0)


func _on_order_expired(_order: Resource) -> void:
	play("unhappy")


func _on_item_stored(_item: Node, _station: Node) -> void:
	play("drawer", -3.0)


func _on_item_taken(_item: Node, _station: Node) -> void:
	play("drawer", -3.0)
