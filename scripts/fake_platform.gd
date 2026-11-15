# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name FakePlatform
extends StaticBody2D
## A platform that looks solid and vanishes the instant you land on it.
##
## The ragebait mechanic, introduced in Act IV. Two rules keep this fair
## rather than cheap, and both are load-bearing:
##
##   1. **It always has a tell.** The owner's explicit call was that no trap
##      may be genuinely unavoidable the first time. The tell here is a subtle
##      flicker in the edge highlight — easy to miss when you're moving fast,
##      obvious the moment you know to look. That is the difference between
##      "hard" and "unfair".
##   2. **It reforms.** A one-shot fake would turn a death into a permanently
##      changed level, so a player who died to it would face a different route
##      on the retry. It comes back, so the level you learn is the level you
##      replay.
##
## Distinct from CrumblePlatform, which telegraphs by shaking and gives a
## grace period. This one gives no grace at all — that IS the joke.

@export var size: Vector2 = Vector2(120.0, 24.0)
@export var color: Color = Color(0.212, 0.231, 0.302, 1.0)
@export var edge_color: Color = Color(0.42, 0.58, 0.76, 1.0)
## Seconds before it returns. Long enough that the player has to solve the
## section without it, short enough that a retry after a death finds it back.
@export var reform_time: float = 2.2
## How strongly the tell flickers. 0 disables it — which would make this trap
## genuinely unfair, so it is deliberately not the default.
@export_range(0.0, 1.0) var tell_strength: float = 0.55

signal fell_away

var _poly: Polygon2D
var _edge: Polygon2D
var _shape: CollisionShape2D
var _sensor: Area2D
var _time: float = 0.0
var _gone: bool = false


func _ready() -> void:
	_build_visual()

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	# Layers 1+2 like every other solid — see platform.gd for why terrain
	# carries the second layer.
	collision_layer = 3

	# Thin sensor on the top face, same pattern as crumble_platform.gd and
	# conveyor_belt.gd: it must trigger on LANDING, not on brushing a side.
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var ss := CollisionShape2D.new()
	var sr := RectangleShape2D.new()
	sr.size = Vector2(size.x - 4.0, 6.0)
	ss.shape = sr
	ss.position = Vector2(0.0, -size.y * 0.5 - 2.0)
	_sensor.add_child(ss)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_poly.color = color
	add_child(_poly)

	_edge = Polygon2D.new()
	var eh := minf(5.0, size.y * 0.5)
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + eh), Vector2(-hx, -hy + eh)])
	_edge.color = edge_color
	add_child(_edge)
	# The readable tell: hairline cracks across the face. A fake tile must look like a TRAP once you know the
	# sign, never like a broken platform: cracked and shimmering means it will not hold you.
	var crack_col := Color(0.03, 0.03, 0.05, 0.85)
	var n := maxi(2, int(size.x / 40.0))
	for i in n:
		var cx := -hx + size.x * (float(i) + 0.5) / float(n)
		var crack := Polygon2D.new()
		crack.polygon = PackedVector2Array([
			Vector2(cx - 2.0, -hy + 2.0), Vector2(cx + 1.0, -hy + 2.0), Vector2(cx + 5.0, 0.0),
			Vector2(cx + 1.0, hy - 2.0), Vector2(cx - 2.0, hy - 2.0), Vector2(cx + 2.0, 0.0)])
		crack.color = crack_col
		add_child(crack)


func _physics_process(delta: float) -> void:
	if _gone or _edge == null:
		return
	_time += delta
	# The tell. Slow enough to miss at speed, unmistakable once you know.
	var flicker := 1.0 - tell_strength * 0.5 * (1.0 + sin(_time * 5.5))
	_edge.color = Color(edge_color.r, edge_color.g, edge_color.b,
		clampf(edge_color.a * flicker, 0.0, 1.0))
	# the whole face dims in time with the edge, so the shimmer reads from a distance
	_poly.color = color.darkened(0.28 * tell_strength * 0.5 * (1.0 + sin(_time * 5.5)))


func _on_body_entered(body: Node2D) -> void:
	if _gone or not (body is Player):
		return
	_gone = true
	fell_away.emit()
	# Disable collision deferred — we are inside a physics callback, and
	# mutating the shape here would be a mid-query state change.
	_shape.set_deferred("disabled", true)
	visible = false
	# it breaks apart (dust), so the fall reads as "that was a trap", not "the platform glitched"
	ImpactFx.spawn(get_parent(), global_position, ImpactFx.Kind.DUST, 1.6)
	SfxHub.play(get_tree(), "vent")
	await get_tree().create_timer(reform_time).timeout
	if not is_instance_valid(self):
		return
	_gone = false
	visible = true
	_shape.set_deferred("disabled", false)


## Exposed for tests: is the platform currently solid?
func is_solid() -> bool:
	return not _gone
