@tool
class_name StarField
extends Node2D
## Procedural star layer for the backdrop's dead upper sky.
##
## Drawn once into the canvas item's command buffer via `_draw()` rather than
## spawned as child nodes: a few hundred stars would otherwise triple the scene's
## node count for something that never moves relative to its parallax layer, and
## the performance budget in docs/ARCHITECTURE.md depends on node count staying
## flat during play.

## Horizontal spread of the field, centred on the node's origin.
@export var span: float = 6000.0:
	set(value):
		span = maxf(value, 1.0)
		queue_redraw()

## Vertical spread, measured upward from the node's origin (stars sit above it).
@export var height: float = 900.0:
	set(value):
		height = maxf(value, 1.0)
		queue_redraw()

@export var count: int = 220:
	set(value):
		count = clampi(value, 0, 2000)
		queue_redraw()

@export var min_radius: float = 0.9:
	set(value):
		min_radius = maxf(value, 0.1)
		queue_redraw()

@export var max_radius: float = 2.3:
	set(value):
		max_radius = maxf(value, 0.1)
		queue_redraw()

@export var color: Color = Color(0.78, 0.85, 1.0, 1.0):
	set(value):
		color = value
		queue_redraw()

## Stars near the bottom of the field fade out, so the layer dissolves into the
## sky instead of ending on a hard line where the ridges begin.
@export var fade_bias: float = 0.65:
	set(value):
		fade_bias = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var rng_seed: int = 5:
	set(value):
		rng_seed = value
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var half_span := span * 0.5
	for _i in count:
		var x := rng.randf_range(-half_span, half_span)
		# Squared distribution: denser high up, thinning toward the horizon.
		var t := rng.randf()
		var y := -height * (1.0 - t * t)
		var radius := rng.randf_range(min_radius, max_radius)
		# Brightness tracks height so the field reads as depth, not confetti.
		var vertical := 1.0 - absf(y) / height
		var alpha := rng.randf_range(0.28, 1.0) * lerpf(1.0, 1.0 - vertical, fade_bias)
		draw_circle(Vector2(x, y), radius, Color(color, color.a * alpha))
