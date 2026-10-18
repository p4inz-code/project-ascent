class_name Gantry
extends Node2D
## A visible frame that holds a road obstacle up: two steel posts standing on the
## road with a crossbar at the top (for lasers, crushers and pendulums), or a single
## pillar under a turret. Pure decoration; it never collides.
##
## Origin: the road surface at the centre of the frame. Posts rise to -height.

enum Style { FRAME, PILLAR }

const PX := 3.0
const STEEL := Color(0.62, 0.68, 0.82)
const STEEL_DARK := Color(0.15, 0.17, 0.26)
const BOLT := Color(0.85, 0.9, 1.0)

var style: Style = Style.FRAME
var span: float = 150.0      # distance between the posts (FRAME)
var height: float = 250.0    # how tall it stands


func _ready() -> void:
	z_index = 0
	queue_redraw()


func _snap(v: float) -> float:
	return roundf(v / PX) * PX


func _post(x: float, top: float, width: float) -> void:
	draw_rect(Rect2(_snap(x - width * 0.5) - 1.0, _snap(top), width + 2.0, -_snap(top)), STEEL_DARK)
	draw_rect(Rect2(_snap(x - width * 0.5), _snap(top), width, -_snap(top)), STEEL)
	draw_rect(Rect2(_snap(x - width * 0.5), _snap(top), PX, -_snap(top)), BOLT)
	# A foot plate on the road.
	draw_rect(Rect2(_snap(x - width), -PX * 2.0, width * 2.0, PX * 2.0), STEEL_DARK)


func _bolt(p: Vector2) -> void:
	draw_rect(Rect2(_snap(p.x) - PX * 2.0, _snap(p.y) - PX * 2.0, PX * 4.0, PX * 4.0), STEEL_DARK)
	draw_rect(Rect2(_snap(p.x) - PX, _snap(p.y) - PX, PX * 2.0, PX * 2.0), BOLT)


func _draw() -> void:
	if style == Style.PILLAR:
		_post(0.0, -height, PX * 5.0)
		_bolt(Vector2(0.0, -height))
		return
	var half := span * 0.5
	_post(-half, -height, PX * 4.0)
	_post(half, -height, PX * 4.0)
	# Crossbar with a diagonal brace on each side.
	draw_rect(Rect2(-half - PX * 3.0, -height - PX * 4.0, span + PX * 6.0, PX * 4.0), STEEL_DARK)
	draw_rect(Rect2(-half - PX * 3.0, -height - PX * 4.0, span + PX * 6.0, PX), STEEL)
	for side in [-1.0, 1.0]:
		var x0: float = half * side
		draw_line(Vector2(x0, -height + 40.0), Vector2(x0 - side * 34.0, -height), STEEL, PX * 1.5)
		_bolt(Vector2(x0, -height))
