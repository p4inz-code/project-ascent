# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name JunkDrop
extends Area2D
## A crate that falls from the ceiling of the Compactor onto one spot of a platform, on a cycle. For
## `tell` seconds before it falls a dark shadow grows on the platform and the chute above rattles;
## the crate is only dangerous while it falls (`active`). A hit costs one cell (a chip), never a kill.
## Position is the platform top at the crate's centre x.

signal player_hit

@export var width: float = 84.0
@export var period: float = 3.6
@export var active: float = 0.45
@export var tell: float = 1.0
@export var phase: float = 0.0
@export var drop_height: float = 420.0

var _t: float = 0.0
var _crate: Polygon2D
var _shadow: Polygon2D
var _chute: Polygon2D
var _shape: CollisionShape2D
var _hissed: bool = false


func _ready() -> void:
	add_to_group("hazard_kind")
	set_meta("hazard_kind", "spikes")
	collision_layer = 0
	collision_mask = 1
	var hw := width * 0.5
	_chute = Polygon2D.new()
	_chute.polygon = PackedVector2Array([Vector2(-hw, -drop_height), Vector2(hw, -drop_height), Vector2(hw - 10, -drop_height + 16), Vector2(-hw + 10, -drop_height + 16)])
	_chute.color = Color(0.30, 0.22, 0.18)
	add_child(_chute)
	_shadow = Polygon2D.new()
	_shadow.polygon = PackedVector2Array([Vector2(-hw, -6), Vector2(hw, -6), Vector2(hw, 0), Vector2(-hw, 0)])
	_shadow.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_shadow)
	_crate = Polygon2D.new()
	_crate.polygon = PackedVector2Array([Vector2(-hw + 6, -width + 6), Vector2(hw - 6, -width + 6), Vector2(hw - 6, 0), Vector2(-hw + 6, 0)])
	_crate.color = Color(0.62, 0.42, 0.22, 0.0)
	add_child(_crate)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 12.0, width)
	_shape.shape = rect
	_shape.disabled = true
	add_child(_shape)


func is_active() -> bool:
	return fposmod(_t + phase, period) >= period - active


func is_telling() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active - tell and ph < period - active


## 0 at the chute, 1 on the platform, while falling.
func fall_progress() -> float:
	return clampf((fposmod(_t + phase, period) - (period - active)) / maxf(active, 0.001), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_t += delta * HazardSpeed.scale
	var on := is_active()
	_shape.set_deferred("disabled", not on)
	if on:
		var f := fall_progress()
		var cy := lerpf(-drop_height + width, 0.0, f * f)
		_crate.position = Vector2(0.0, cy)
		_crate.color.a = 1.0
		_shape.position = Vector2(0.0, cy - width * 0.5)
		_shadow.color.a = 0.6
		for b in get_overlapping_bodies():
			if b is Player:
				player_hit.emit()
				return
	else:
		_crate.color.a = 0.0
	if is_telling():
		var ph := fposmod(_t + phase, period)
		var f2 := (ph - (period - active - tell)) / maxf(tell, 0.001)
		_shadow.color.a = 0.15 + 0.5 * f2
		_chute.color = Color(0.30, 0.22, 0.18).lerp(Color(0.95, 0.6, 0.25), f2 * (0.5 + 0.5 * float(int(_t * 24.0) % 2)))
		if not _hissed:
			_hissed = true
			SfxHub.play(get_tree(), "vent")
	elif not on:
		_shadow.color.a = 0.0
		_chute.color = Color(0.30, 0.22, 0.18)
		_hissed = false
