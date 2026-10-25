class_name Crusher
extends Area2D
## A piston that slams a plate down through the floor lane on a fixed cycle. The slam kills (crush is
## instant death), so the cycle is generous and fully telegraphed: for `tell` seconds before the slam
## the plate drops a little and shakes, and a hiss plays; the slam lasts `active` seconds; then the
## plate rises and the way is clear for the rest of the period.
##
## Matches MachineWorld.cyclic_active: dangerous while fposmod(t + phase, period) >= period - active.

signal player_hit

@export var width: float = 110.0
@export var period: float = 2.4
@export var active: float = 0.8
@export var tell: float = 0.9
@export var phase: float = 0.0
## Where the plate hangs when idle (top) and when slammed (bottom), in local y; 0 is the floor top.
@export var top_y: float = -(MachinePieces.FLOOR_Y - (MachinePieces.DECK_Y + MachinePieces.DECK_THICK))

var _t: float = 0.0
var _plate: Polygon2D
var _rod: Polygon2D
var _shape: CollisionShape2D
var _hissed: bool = false


func _ready() -> void:
	add_to_group("hazard_kind")
	set_meta("hazard_kind", "crusher")
	collision_layer = 0
	collision_mask = 1
	_rod = Polygon2D.new()
	_rod.color = Color(0.30, 0.32, 0.40)
	add_child(_rod)
	_plate = Polygon2D.new()
	_plate.color = Color(0.55, 0.57, 0.66)
	add_child(_plate)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var h := -top_y
	rect.size = Vector2(width, h)
	_shape.shape = rect
	_shape.position = Vector2(width * 0.5, top_y + h * 0.5)
	_shape.disabled = true
	add_child(_shape)
	_draw_plate(0.0)


func is_active() -> bool:
	return fposmod(_t + phase, period) >= period - active


func is_telling() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active - tell and ph < period - active


## `drop` 0 = hanging at the top, 1 = slammed to the floor.
func _draw_plate(drop: float) -> void:
	var travel := -top_y - 26.0
	var y := top_y + 26.0 + travel * drop
	_plate.polygon = PackedVector2Array([
		Vector2(0, y - 26), Vector2(width, y - 26), Vector2(width, y), Vector2(0, y)])
	_rod.polygon = PackedVector2Array([
		Vector2(width * 0.5 - 8.0, top_y), Vector2(width * 0.5 + 8.0, top_y),
		Vector2(width * 0.5 + 8.0, y - 26), Vector2(width * 0.5 - 8.0, y - 26)])


func _physics_process(delta: float) -> void:
	_t += delta * HazardSpeed.scale
	var on := is_active()
	_shape.set_deferred("disabled", not on)
	var ph := fposmod(_t + phase, period)
	var drop := 0.0
	if on:
		drop = 1.0
	elif is_telling():
		var f := (ph - (period - active - tell)) / maxf(tell, 0.001)
		drop = 0.12 * f + (0.015 if int(_t * 30.0) % 2 == 0 else 0.0)
		if not _hissed:
			_hissed = true
			SfxHub.play(get_tree(), "vent")
	else:
		_hissed = false
		# rising after a slam
		var since := ph
		if since < 0.25:
			drop = 1.0 - since / 0.25
	_draw_plate(drop)
	if on:
		for b in get_overlapping_bodies():
			if b is Player:
				player_hit.emit()
				return
