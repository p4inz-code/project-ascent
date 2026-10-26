class_name CollapseFront
extends Node2D
## DAWN's collapse: the tube falls apart behind you. A wall of falling slabs and embers chases the
## player along the machine at `speed` px/s, starting when the player first moves after a respawn (the
## same clock the simulator proved it against: MachineWorld hazards with "vx"). It kills on touch. It is
## always slower than the player even when slowed, so it only punishes waiting.

signal player_hit

@export var start_x: float = -500.0
@export var speed: float = 170.0

const WIDTH := 500.0

var _t: float = 0.0
var _started: bool = false
var _player: Player = null
var _wall: Polygon2D
var _embers: Array[Polygon2D] = []


func _ready() -> void:
	z_index = 5
	_wall = Polygon2D.new()
	_wall.polygon = PackedVector2Array([
		Vector2(-WIDTH, MachinePieces.CEIL_Y - 300.0), Vector2(0.0, MachinePieces.CEIL_Y - 300.0),
		Vector2(40.0, MachinePieces.FLOOR_Y + 60.0), Vector2(-WIDTH, MachinePieces.FLOOR_Y + 60.0)])
	_wall.color = Color(0.05, 0.02, 0.03, 0.96)
	add_child(_wall)
	for i in 14:
		var e := Polygon2D.new()
		var y := MachinePieces.CEIL_Y - 100.0 + float(i) * 55.0
		e.polygon = PackedVector2Array([Vector2(0, y), Vector2(18, y + 4), Vector2(6, y + 14)])
		e.color = Color(1.0, 0.55, 0.15, 0.8)
		add_child(e)
		_embers.append(e)
	position.x = start_x


func _physics_process(delta: float) -> void:
	if not _started:
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Player
		if _player != null and absf(_player.velocity.x) > 1.0:
			_started = true
		else:
			return
	_t += delta * HazardSpeed.scale
	position.x = start_x + speed * _t
	for i in _embers.size():
		_embers[i].position.x = 18.0 * sin(_t * 9.0 + float(i)) + 14.0
	if _player != null and is_instance_valid(_player):
		# the wall's right edge is at position.x + 40; touching it (or being inside) is the end
		if _player.global_position.x - 14.0 < position.x + 40.0:
			player_hit.emit()
