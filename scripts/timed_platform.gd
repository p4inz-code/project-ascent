class_name TimedPlatform
extends StaticBody2D
## A platform on a fixed on/off cycle. Solid and lit while ON, a hollow outline
## while OFF.
##
## The design rule that makes this fair rather than a coin flip: the cycle is
## FIXED and always visible, and it never starts a level mid-fade. A player can
## stand next to it and learn its rhythm before committing, which turns it into
## a timing problem — the thing this game is about — rather than a gamble.
##
## The warning beat before it vanishes is not decoration. Without it the
## platform simply disappears under you, which reads as the game cheating.

@export var size: Vector2 = Vector2(140.0, 22.0)
@export var color: Color = Color(0.22, 0.24, 0.32, 1.0)
@export var edge_color: Color = Color(0.55, 0.75, 1.0, 1.0)
## Seconds solid, then seconds hollow. Deliberately asymmetric by default: more
## time on than off, so the platform is an opportunity you can miss rather than
## a wall you occasionally get through.
@export var on_time: float = 2.4
@export var off_time: float = 1.4
## Offset into the cycle at build time, so a row of these can alternate.
@export var phase: float = 0.0
## How long before it turns off that the warning flash begins.
@export var warn_time: float = 0.55

var _poly: Polygon2D
var _edge: Polygon2D
var _shape: CollisionShape2D
var _t: float = 0.0
var _solid: bool = true


func _ready() -> void:
	_build_visual()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	collision_layer = 3
	_t = phase
	_apply(_phase_is_on())


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy),
	])
	_poly.color = color
	add_child(_poly)

	var edge_h := minf(5.0, hy)
	_edge = Polygon2D.new()
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, -hy + edge_h), Vector2(-hx, -hy + edge_h),
	])
	_edge.color = edge_color
	add_child(_edge)


func _phase_is_on() -> bool:
	return fmod(_t, on_time + off_time) < on_time


func _physics_process(delta: float) -> void:
	_t += delta
	var on := _phase_is_on()
	if on != _solid:
		_apply(on)
	if _solid:
		# Warning flash in the last moments of the ON phase.
		var into := fmod(_t, on_time + off_time)
		if into > on_time - warn_time:
			var f := sin(_t * 30.0) * 0.5 + 0.5
			_edge.color = edge_color.lerp(Color(1.0, 0.45, 0.35), f)
		else:
			_edge.color = edge_color


func _apply(on: bool) -> void:
	_solid = on
	# set_deferred: toggling a collision shape from inside physics is unsafe.
	_shape.set_deferred("disabled", not on)
	_poly.color = Color(color.r, color.g, color.b, 1.0 if on else 0.10)
	_edge.color = edge_color if on else Color(edge_color.r, edge_color.g, edge_color.b, 0.30)


func is_solid() -> bool:
	return _solid
