class_name HailColumn
extends Area2D
## A column of hail falling from the roof onto the deck, on a fixed cycle. It is only dangerous for
## `active` seconds at the end of each period; for `tell` seconds before that, streaks of ice rattle
## in the roof vent and a shadow darkens the deck below. Touching live hail costs one cell.
##
## Matches MachineWorld.cyclic_active: dangerous while fposmod(t + phase, period) >= period - active.

signal player_hit

@export var width: float = 110.0
@export var period: float = 2.4
@export var active: float = 0.8
@export var tell: float = 0.9
@export var phase: float = 0.0
## Column height, from the roof (local y 0 is the roof underside) to the deck top.
@export var height: float = MachinePieces.DECK_Y - MachinePieces.CEIL_Y

var _t: float = 0.0
var _hail: Polygon2D
var _shadow: Polygon2D
var _vent: Polygon2D
var _shape: CollisionShape2D
var _hissed: bool = false


func _ready() -> void:
	add_to_group("hazard_kind")
	set_meta("hazard_kind", "spikes")
	collision_layer = 0
	collision_mask = 1
	_vent = Polygon2D.new()
	_vent.polygon = PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width - 12, 14), Vector2(12, 14)])
	_vent.color = Color(0.30, 0.34, 0.42)
	add_child(_vent)
	_shadow = Polygon2D.new()
	_shadow.polygon = PackedVector2Array([Vector2(8, height - 6), Vector2(width - 8, height - 6), Vector2(width - 8, height), Vector2(8, height)])
	_shadow.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_shadow)
	_hail = Polygon2D.new()
	_hail.polygon = PackedVector2Array([Vector2(10, 14), Vector2(width - 10, 14), Vector2(width - 18, height), Vector2(18, height)])
	_hail.color = Color(0.75, 0.9, 1.0, 0.0)
	add_child(_hail)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 12.0, height)
	_shape.shape = rect
	_shape.position = Vector2(width * 0.5, height * 0.5)
	_shape.disabled = true
	add_child(_shape)


func is_active() -> bool:
	return fposmod(_t + phase, period) >= period - active


func is_telling() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active - tell and ph < period - active


func _physics_process(delta: float) -> void:
	_t += delta * HazardSpeed.scale
	var on := is_active()
	_shape.set_deferred("disabled", not on)
	_hail.color.a = 0.8 if on else 0.0
	if is_telling():
		var ph := fposmod(_t + phase, period)
		var f := (ph - (period - active - tell)) / maxf(tell, 0.001)
		_shadow.color.a = 0.15 + 0.5 * f
		_vent.color = Color(0.30, 0.34, 0.42).lerp(Color(0.75, 0.9, 1.0), f * (0.5 + 0.5 * float(int(_t * 24.0) % 2)))
		if not _hissed:
			_hissed = true
			SfxHub.play(get_tree(), "vent")
	else:
		_shadow.color.a = 0.0 if not on else 0.5
		_vent.color = Color(0.30, 0.34, 0.42)
		if not on:
			_hissed = false
	if on:
		for b in get_overlapping_bodies():
			if b is Player:
				player_hit.emit()
				return
