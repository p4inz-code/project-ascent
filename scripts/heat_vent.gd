# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name HeatVent
extends Area2D
## A floor vent on a calm cell of DAWN. For `tell` seconds before it blows the grate glows orange and
## hisses; while it blows (`active`) the hot air slows anyone standing in it to 70 percent of top speed.
## It never hurts. Matches MachineWorld.cyclic_active: blowing while fposmod(t + phase, period) >= period - active.
## Position is the floor top at the left end of the patch.

@export var width: float = 160.0
@export var period: float = 4.0
@export var active: float = 1.5
@export var tell: float = 1.0
@export var phase: float = 0.0

var _t: float = 0.0
var _grate: Polygon2D
var _haze: Polygon2D
var _shape: CollisionShape2D
var _hissed: bool = false
var _slowing: Player = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_grate = Polygon2D.new()
	_grate.polygon = PackedVector2Array([Vector2(8, -5), Vector2(width - 8, -5), Vector2(width - 8, 0), Vector2(8, 0)])
	_grate.color = Color(0.25, 0.12, 0.08)
	add_child(_grate)
	_haze = Polygon2D.new()
	_haze.polygon = PackedVector2Array([Vector2(10, 0), Vector2(width - 10, 0), Vector2(width - 30, -140), Vector2(30, -140)])
	_haze.color = Color(1.0, 0.55, 0.2, 0.0)
	add_child(_haze)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 70.0)
	_shape.shape = rect
	_shape.position = Vector2(width * 0.5, -35.0)
	add_child(_shape)


func is_active() -> bool:
	return fposmod(_t + phase, period) >= period - active


func is_telling() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active - tell and ph < period - active


func _physics_process(delta: float) -> void:
	_t += delta * HazardSpeed.scale
	var on := is_active()
	var found: Player = null
	if on:
		for b in get_overlapping_bodies():
			if b is Player:
				found = b
	if found != null:
		found.heat_scale = 0.7
		_slowing = found
	elif _slowing != null and is_instance_valid(_slowing):
		_slowing.heat_scale = 1.0
		_slowing = null
	if is_telling():
		var ph := fposmod(_t + phase, period)
		var f := (ph - (period - active - tell)) / maxf(tell, 0.001)
		_grate.color = Color(0.25, 0.12, 0.08).lerp(Color(1.0, 0.5, 0.15), f * (0.5 + 0.5 * float(int(_t * 24.0) % 2)))
		_haze.color.a = 0.0
		if not _hissed:
			_hissed = true
			SfxHub.play(get_tree(), "vent")
	elif on:
		_grate.color = Color(1.0, 0.55, 0.2)
		_haze.color.a = 0.28 + 0.08 * sin(_t * 18.0)
	else:
		_grate.color = Color(0.25, 0.12, 0.08)
		_haze.color.a = 0.0
		_hissed = false


func _exit_tree() -> void:
	if _slowing != null and is_instance_valid(_slowing):
		_slowing.heat_scale = 1.0
