class_name CheckpointFlag
extends Area2D
## A mid-level respawn point, used only in Acts IV and V.
##
## Deliberately NOT in Acts I–III. Those levels are short enough that a full
## restart is the honest cost of a mistake, and removing that cost would strip
## the tension a precision platformer runs on. Acts IV and V are ~50% longer
## AND carry the ragebait traps, so a single late mistake there would otherwise
## cost several minutes — which turns "hard" into "not worth retrying".
##
## In-memory only, never written to the save file: a checkpoint is a
## within-attempt convenience, not progress. Quitting and returning still
## starts the level from its beginning, which keeps the save file meaning
## exactly what it meant before.

@export var size: Vector2 = Vector2(40.0, 90.0)
@export var idle_color: Color = Color(0.55, 0.62, 0.75, 1.0)
@export var active_color: Color = Color(0.45, 1.0, 0.62, 1.0)

signal activated(position: Vector2)

var _pole: Polygon2D
var _banner: Polygon2D
var _glow: Polygon2D
var _active: bool = false
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	var hy := size.y * 0.5

	_glow = Polygon2D.new()
	_glow.polygon = PackedVector2Array([
		Vector2(-18, -hy), Vector2(18, -hy), Vector2(18, hy), Vector2(-18, hy)])
	_glow.color = Color(idle_color.r, idle_color.g, idle_color.b, 0.0)
	add_child(_glow)

	_pole = Polygon2D.new()
	_pole.polygon = PackedVector2Array([
		Vector2(-2.5, -hy), Vector2(2.5, -hy), Vector2(2.5, hy), Vector2(-2.5, hy)])
	_pole.color = idle_color
	add_child(_pole)

	_banner = Polygon2D.new()
	_banner.polygon = PackedVector2Array([
		Vector2(2.5, -hy), Vector2(30, -hy + 9), Vector2(2.5, -hy + 18)])
	_banner.color = idle_color
	add_child(_banner)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	# A slow pulse once claimed, so the player can see at a glance that this
	# one is theirs — the flag is only useful if you know it took.
	var p := 0.5 + 0.5 * sin(_time * 3.0)
	_glow.color = Color(active_color.r, active_color.g, active_color.b, 0.10 + p * 0.12)
	_banner.scale.x = 1.0 + p * 0.08


func _on_body_entered(body: Node2D) -> void:
	if _active or not (body is Player):
		return
	_active = true
	_pole.color = active_color
	_banner.color = active_color
	activated.emit(global_position)


func is_active() -> bool:
	return _active


## Clear on level reload so a fresh attempt at the level starts unclaimed.
func reset() -> void:
	_active = false
	_pole.color = idle_color
	_banner.color = idle_color
	_glow.color = Color(idle_color.r, idle_color.g, idle_color.b, 0.0)
	_banner.scale.x = 1.0
