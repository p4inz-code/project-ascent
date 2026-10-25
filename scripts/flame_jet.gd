class_name FlameJet
extends Area2D
## A grate that blows a column of flame on a fixed cycle. The column is only dangerous for `active`
## seconds at the end of each period; for `tell` seconds before that the grate glows and hisses, so
## the safe window is always visible. Touching live flame costs one cell (chip damage).
##
## Matches MachineWorld.cyclic_active: dangerous while fposmod(t + phase, period) >= period - active.

signal player_hit

@export var width: float = 160.0
@export var period: float = 2.4
@export var active: float = 0.8
@export var tell: float = 0.9
@export var phase: float = 0.0

const GRATE_H := 8.0

var _t: float = 0.0
var _flame: Polygon2D
var _glow: Polygon2D
var _grate: Polygon2D
var _shape: CollisionShape2D
var _hissed: bool = false


func _ready() -> void:
	add_to_group("hazard_kind")
	set_meta("hazard_kind", "fire")
	collision_layer = 0
	collision_mask = 1
	_grate = Polygon2D.new()
	_grate.polygon = PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, -GRATE_H), Vector2(0, -GRATE_H)])
	_grate.color = Color(0.20, 0.21, 0.27)
	add_child(_grate)
	for i in maxi(3, int(width / 22.0)):
		var bar := Polygon2D.new()
		var x := 6.0 + float(i) * ((width - 12.0) / float(maxi(3, int(width / 22.0)) - 1))
		bar.polygon = PackedVector2Array([Vector2(x - 2, 0), Vector2(x + 2, 0), Vector2(x + 2, -GRATE_H), Vector2(x - 2, -GRATE_H)])
		bar.color = Color(0.40, 0.42, 0.52)
		add_child(bar)
	_glow = Polygon2D.new()
	_glow.polygon = PackedVector2Array([Vector2(4, -GRATE_H), Vector2(width - 4, -GRATE_H), Vector2(width - 4, -GRATE_H - 10), Vector2(4, -GRATE_H - 10)])
	_glow.color = Color(1.0, 0.5, 0.15, 0.0)
	add_child(_glow)
	_flame = Polygon2D.new()
	_flame.polygon = PackedVector2Array([
		Vector2(6, -GRATE_H), Vector2(width - 6, -GRATE_H), Vector2(width - 14, -MachinePieces.FLAME_H),
		Vector2(14, -MachinePieces.FLAME_H)])
	_flame.color = Color(1.0, 0.45, 0.12, 0.0)
	add_child(_flame)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 12.0, MachinePieces.FLAME_H)
	_shape.shape = rect
	_shape.position = Vector2(width * 0.5, -MachinePieces.FLAME_H * 0.5)
	_shape.disabled = true
	add_child(_shape)


func is_active() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active


func is_telling() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active - tell and ph < period - active


func _physics_process(delta: float) -> void:
	_t += delta * HazardSpeed.scale
	var on := is_active()
	var telling := is_telling()
	_shape.set_deferred("disabled", not on)
	_flame.color.a = 0.85 if on else 0.0
	# The glow ramps up through the tell.
	if telling:
		var ph := fposmod(_t + phase, period)
		var f := (ph - (period - active - tell)) / maxf(tell, 0.001)
		_glow.color.a = 0.25 + 0.6 * f
		if not _hissed:
			_hissed = true
			SfxHub.play(get_tree(), "vent")
	else:
		_glow.color.a = 0.0 if not on else 0.5
		if not telling and not on:
			_hissed = false
	if on:
		for b in get_overlapping_bodies():
			if b is Player:
				player_hit.emit()
				return
