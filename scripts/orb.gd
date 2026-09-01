class_name Orb
extends Area2D
## Trevor's currency. 100 of them buy the last door and the way out.
##
## Two kinds, and the difference is the whole design:
##
##   ROUTE     sits on the path you have to walk anyway. Cannot be missed.
##             This is what teaches the mechanic and guarantees progress.
##   OPTIONAL  sits on a line you have to CHOOSE to take. This is the one that
##             makes the currency mean something — a collectible on the only
##             path collects itself and is therefore not a decision.
##
## Collection is saved per level and per index, so replaying a level to pick up
## what you missed works and cannot double-count. That is what stops a player
## who skipped optional orbs from being soft-locked at the final door: Level
## Select already exists, so a shortfall is a reason to go back, never a dead
## end.

enum Kind { ROUTE, OPTIONAL }

## Emitted when this orb is collected for the first time this save.
signal collected(level_num: int, index: int)

@export var kind: Kind = Kind.ROUTE
## Which level this orb belongs to, and its index within that level. Together
## they are the save key.
@export var level_num: int = 1
@export var index: int = 0

const RADIUS: float = 11.0
const ROUTE_COLOR := Color(0.55, 0.88, 1.00)
const OPTIONAL_COLOR := Color(1.00, 0.82, 0.35)

var _core: Polygon2D
var _halo: Polygon2D
var _time: float = 0.0
var _taken: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	# Generous relative to the visual: a collectible you can see and still miss
	# is only annoying, and nothing about picking one up should be precise.
	circle.radius = RADIUS * 1.9
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	var col: Color = ROUTE_COLOR if kind == Kind.ROUTE else OPTIONAL_COLOR
	# The optional ones are gold and larger-haloed on purpose: they are the ones
	# worth crossing a room for, so they have to read as worth it from across
	# the screen.
	var halo_scale := 1.9 if kind == Kind.OPTIONAL else 1.5

	_halo = Polygon2D.new()
	_halo.polygon = _circle(RADIUS * halo_scale, 16)
	_halo.color = Color(col.r, col.g, col.b, 0.16)
	add_child(_halo)

	_core = Polygon2D.new()
	_core.polygon = _circle(RADIUS, 14)
	_core.color = col
	add_child(_core)

	var inner := Polygon2D.new()
	inner.polygon = _circle(RADIUS * 0.42, 10)
	inner.color = Color(1, 1, 1, 0.85)
	add_child(inner)


func _circle(r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	# Bob and pulse. Motion is what separates a pickup from scenery at a glance,
	# which matters more here than usual because the levels are otherwise built
	# from static rectangles.
	position.y += sin(_time * 2.4) * 0.35
	var pulse := 1.0 + sin(_time * 3.1) * 0.12
	_halo.scale = Vector2(pulse, pulse)


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	_taken = true
	collected.emit(level_num, index)
	# Pop and fade rather than vanish, so the pickup registers even when the
	# player is moving fast enough to be past it before they notice.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)


## Hide an orb that this save has already collected. Called at level build.
func mark_already_taken() -> void:
	_taken = true
	visible = false
	set_process(false)
