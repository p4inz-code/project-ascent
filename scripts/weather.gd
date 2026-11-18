# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name Weather
extends Node2D
## Per-Act weather: drifting snow, driving rain with lightning, or rising embers.
##
## Act IV is *named* Storm and had no weather at all — its only difference from
## Act III was a slightly different sky gradient. Weather is the cheapest way to
## make an Act feel like a place rather than a palette swap, and unlike the
## backdrop it moves, so it reads even in a still frame.
##
## Drawn as a pool of Polygon2D particles recycled forever, never instanced per
## frame — the performance audit relies on node count staying flat during play,
## and a rain effect that allocates would break that property in the level where
## the most is already happening on screen.

## SPARKS: fast bright flecks thrown up (Scrapyard). STEAM: big soft puffs that rise (Underworks).
## SHARDS: glassy diamonds drifting sideways (Rift). PULSE: slow red motes and a heartbeat glow (Core).
enum Kind { NONE, SNOW, RAIN, EMBERS, SPARKS, STEAM, SHARDS, PULSE }

## The heartbeat glow is a slow brightness swell, never a flash: 70 beats a minute, at most 7% opacity.
const PULSE_PERIOD := 0.86
const PULSE_MAX_ALPHA := 0.07

@export var kind: Kind = Kind.NONE:
	set(value):
		kind = value
		_rebuild()

@export var particle_count: int = 90:
	set(value):
		particle_count = clampi(value, 0, 400)
		_rebuild()

@export var tint: Color = Color(1, 1, 1, 0.6):
	set(value):
		tint = value
		_rebuild()

## Area the effect fills. Generous so it still covers the screen when the
## camera moves; particles wrap within it rather than tracking the player.
@export var field_size: Vector2 = Vector2(2600, 1600)

## Lightning only applies to RAIN. Seconds between strikes, randomised +/-50%.
@export var lightning_interval: float = 7.0

var _parts: Array[Polygon2D] = []
var _vel: Array[Vector2] = []
var _phase: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
var _flash: ColorRect = null
var _next_strike: float = 0.0


func _ready() -> void:
	_rng.seed = 20260831
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_parts.clear()
	_vel.clear()
	_phase = PackedFloat32Array()
	_flash = null

	if kind == Kind.NONE or particle_count <= 0:
		return

	for _i in particle_count:
		var p := Polygon2D.new()
		p.polygon = _shape_for_kind()
		p.color = tint
		p.position = _random_start()
		add_child(p)
		_parts.append(p)
		_vel.append(_velocity_for_kind())
		_phase.append(_rng.randf() * TAU)

	if kind == Kind.PULSE:
		var pc := CanvasLayer.new()
		pc.layer = 89
		add_child(pc)
		_flash = ColorRect.new()
		_flash.color = Color(tint.r, tint.g, tint.b, 0.0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		pc.add_child(_flash)
	if kind == Kind.RAIN:
		# Screen-space flash so a strike lights the whole frame, not a patch of
		# world that happens to be near the camera.
		var canvas := CanvasLayer.new()
		canvas.layer = 90
		add_child(canvas)
		_flash = ColorRect.new()
		_flash.color = Color(0.75, 0.85, 1.0, 0.0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(_flash)
		_next_strike = lightning_interval * _rng.randf_range(0.5, 1.5)


func _shape_for_kind() -> PackedVector2Array:
	match kind:
		Kind.SNOW:
			var r := _rng.randf_range(1.6, 3.2)
			return PackedVector2Array([
				Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r)])
		Kind.RAIN:
			var len := _rng.randf_range(12.0, 22.0)
			return PackedVector2Array([
				Vector2(-0.9, 0), Vector2(0.9, 0),
				Vector2(0.9 + 2.0, len), Vector2(-0.9 + 2.0, len)])
		Kind.EMBERS, Kind.PULSE:
			var e := _rng.randf_range(1.4, 2.8)
			return PackedVector2Array([
				Vector2(-e, -e), Vector2(e, -e), Vector2(e, e), Vector2(-e, e)])
		Kind.SPARKS:
			var sp := _rng.randf_range(0.9, 1.7)
			return PackedVector2Array([Vector2(-sp, -sp * 2.4), Vector2(sp, -sp * 2.4), Vector2(sp, sp * 2.4), Vector2(-sp, sp * 2.4)])
		Kind.STEAM:
			var st := _rng.randf_range(16.0, 34.0)
			return PackedVector2Array([Vector2(-st, -st * 0.7), Vector2(st, -st * 0.7), Vector2(st, st * 0.7), Vector2(-st, st * 0.7)])
		Kind.SHARDS:
			var sh := _rng.randf_range(2.0, 5.0)
			return PackedVector2Array([Vector2(0, -sh * 1.6), Vector2(sh, 0), Vector2(0, sh * 1.6), Vector2(-sh, 0)])
	return PackedVector2Array()


func _velocity_for_kind() -> Vector2:
	match kind:
		Kind.SNOW:
			return Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(26.0, 58.0))
		Kind.RAIN:
			return Vector2(_rng.randf_range(150.0, 210.0), _rng.randf_range(700.0, 950.0))
		Kind.EMBERS:
			return Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-52.0, -22.0))
		Kind.SPARKS:
			return Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-190.0, -80.0))
		Kind.STEAM:
			return Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-34.0, -14.0))
		Kind.SHARDS:
			return Vector2(_rng.randf_range(30.0, 70.0), _rng.randf_range(-22.0, 6.0))
		Kind.PULSE:
			return Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-28.0, -10.0))
	return Vector2.ZERO


func _random_start() -> Vector2:
	return Vector2(
		_rng.randf_range(-field_size.x * 0.5, field_size.x * 0.5),
		_rng.randf_range(-field_size.y * 0.5, field_size.y * 0.5))


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	_time += delta
	var half := field_size * 0.5

	for i in _parts.size():
		var p := _parts[i]
		var v := _vel[i]
		# Snow and embers wander; rain falls hard and straight.
		if kind != Kind.RAIN and kind != Kind.SPARKS:
			v.x += sin(_time * 0.7 + _phase[i]) * 8.0 * delta
		p.position += v * delta

		# Wrap rather than respawn, so the pool never changes size.
		if p.position.y > half.y:
			p.position = Vector2(_rng.randf_range(-half.x, half.x), -half.y)
		elif p.position.y < -half.y:
			p.position = Vector2(_rng.randf_range(-half.x, half.x), half.y)
		if p.position.x > half.x:
			p.position.x = -half.x
		elif p.position.x < -half.x:
			p.position.x = half.x

	if kind == Kind.RAIN and _flash != null:
		_tick_lightning(delta)
	elif kind == Kind.PULSE and _flash != null:
		_flash.color.a = pulse_alpha(_time)


## The heartbeat: a soft double swell (lub-dub) once per PULSE_PERIOD. Pure function so it can be tested.
static func pulse_alpha(t: float) -> float:
	var ph := fposmod(t, PULSE_PERIOD) / PULSE_PERIOD
	var lub := exp(-pow((ph - 0.10) / 0.07, 2.0))
	var dub := 0.65 * exp(-pow((ph - 0.32) / 0.08, 2.0))
	return clampf(lub + dub, 0.0, 1.0) * PULSE_MAX_ALPHA


## Two quick pulses rather than one, which is what real lightning looks like
## and reads far better than a single fade.
func _tick_lightning(delta: float) -> void:
	_next_strike -= delta
	if _next_strike > 0.0:
		return
	_next_strike = lightning_interval * _rng.randf_range(0.5, 1.5)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.30, 0.04)
	tween.tween_property(_flash, "color:a", 0.04, 0.09)
	tween.tween_property(_flash, "color:a", 0.20, 0.05)
	tween.tween_property(_flash, "color:a", 0.0, 0.35)
