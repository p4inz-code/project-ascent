@tool
class_name StarField
extends MultiMeshInstance2D
## Procedural star layer for the backdrop's upper sky.
##
## A `MultiMeshInstance2D`, not a `_draw()` loop and not child nodes, because the
## target platform is WebGL2 where draw-call overhead is the expensive part. The
## first implementation issued one `draw_circle()` per star, which put ~430 of the
## frame's ~470 draw calls into background dressing — 90% of the frame's calls for
## something that never moves. A multimesh is one draw call for the whole field,
## and the instance buffer is built once on rebuild, never per frame.
##
## Stars are 1–2 px quads rather than circles. At that size the difference is
## invisible and the quads are marginally crisper.

## Horizontal spread of the field, centred on the node's origin.
@export var span: float = 4200.0:
	set(value):
		span = maxf(value, 1.0)
		_rebuild()

## Vertical spread, measured upward from the node's origin (stars sit above it).
@export var height: float = 780.0:
	set(value):
		height = maxf(value, 1.0)
		_rebuild()

@export var count: int = 430:
	set(value):
		count = clampi(value, 0, 4000)
		_rebuild()

@export var min_size: float = 1.6:
	set(value):
		min_size = maxf(value, 0.1)
		_rebuild()

@export var max_size: float = 3.4:
	set(value):
		max_size = maxf(value, 0.1)
		_rebuild()

@export var star_color: Color = Color(0.78, 0.85, 1.0, 1.0):
	set(value):
		star_color = value
		_rebuild()

## Stars near the bottom of the field fade out, so the layer dissolves into the
## sky instead of ending on a hard line where the ridges begin.
@export_range(0.0, 1.0) var fade_bias: float = 0.55:
	set(value):
		fade_bias = value
		_rebuild()

@export var rng_seed: int = 5:
	set(value):
		rng_seed = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	mesh.mesh = _quad()
	mesh.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var half_span := span * 0.5
	for i in count:
		var x := rng.randf_range(-half_span, half_span)
		# Squared distribution: denser high up, thinning toward the horizon.
		var t := rng.randf()
		var y := -height * (1.0 - t * t)
		var size := rng.randf_range(min_size, max_size)
		mesh.set_instance_transform_2d(i,
			Transform2D(0.0, Vector2(size, size), 0.0, Vector2(x, y)))
		# Brightness tracks height so the field reads as depth, not confetti.
		var vertical := 1.0 - absf(y) / height
		var alpha := rng.randf_range(0.28, 1.0) * lerpf(1.0, 1.0 - vertical, fade_bias)
		mesh.set_instance_color(i, Color(star_color, star_color.a * alpha))
	multimesh = mesh


## A unit quad centred on the origin, built by hand rather than with QuadMesh so
## the vertex colours the multimesh modulates are guaranteed to be present.
func _quad() -> ArrayMesh:
	var vertices := PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
	])
	var colors := PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
