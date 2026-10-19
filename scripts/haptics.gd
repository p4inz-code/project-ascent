class_name Haptics
extends Node
## Controller rumble for the moments that deserve it: a hard landing, a dash, a ground pound,
## a wall kick, a death. The strength setting scales (or silences) all of it. Lives under the
## Player like the camera nodes; `sink` can be replaced so tests can see exactly what is sent.

## Called as sink(weak, strong, seconds). Defaults to the real controllers.
static var sink: Callable = Callable()
## Tests set this so no physical pad is needed.
static var assume_pad: bool = false

var _player: Player = null


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		return
	_player.dashed.connect(func(): pulse(0.25, 0.0, 0.08))
	_player.landed.connect(_on_landed)
	_player.ground_pounded.connect(func(): pulse(0.5, 0.9, 0.25))
	_player.wall_jumped.connect(func(): pulse(0.2, 0.2, 0.07))


func _on_landed(fall_speed: float) -> void:
	# A soft step is silent; a hard fall thumps.
	if fall_speed > 380.0:
		var f := clampf((fall_speed - 380.0) / 700.0, 0.0, 1.0)
		pulse(0.2 + 0.4 * f, 0.1 + 0.6 * f, 0.08 + 0.12 * f)


## The strength setting, 0..1.
static func strength() -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gs: Node = (loop as SceneTree).root.get_node_or_null("GameSettings")
		if gs != null and gs.has_method("get_reg"):
			return float(gs.get_reg("ctl_vibration"))
	return 0.5


## Rumble the connected pads, scaled by the strength setting. Does nothing at strength 0.
static func pulse(weak: float, strong: float, seconds: float) -> void:
	var s := strength()
	if s <= 0.0:
		return
	if not assume_pad and Input.get_connected_joypads().is_empty():
		return
	var w := clampf(weak * s, 0.0, 1.0)
	var st := clampf(strong * s, 0.0, 1.0)
	if sink.is_valid():
		sink.call(w, st, seconds)
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, w, st, seconds)


## The death thump, called by the level when the player is lost.
static func death() -> void:
	pulse(0.6, 1.0, 0.35)
