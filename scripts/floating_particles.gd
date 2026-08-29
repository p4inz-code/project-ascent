@tool
class_name FloatingParticles
extends MultiMeshInstance2D
## Procedural floating particles for atmospheric depth.
##
## Small dots/diamonds that drift slowly, creating environmental atmosphere.
## Uses MultiMeshInstance2D for efficient rendering (single draw call).

## Horizontal spread.
@export var span: float = 4000.0

## Vertical spread.
@export var height: float = 600.0

## Number of particles.
@export var count: int = 80

## Particle size range.
@export var min_size: float = 1.0
@export var max_size: float = 3.0

## Random seed.
@export var rng_seed: int = 99

## Particle color (set by the palette system).
var particle_color: Color = Color(0.5, 0.6, 0.8, 0.4)

## Drift speed (pixels per second, set by the palette system).
var drift_speed: float = 8.0


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if multimesh == null or multimesh.instance_count == 0:
		return
	# Slow upward drift
	for i in range(multimesh.instance_count):
		var transform := multimesh.get_instance_transform(i)
		transform.origin.y -= drift_speed * delta
		# Wrap around when off screen
		if transform.origin.y < -height * 0.5:
			transform.origin.y = height * 0.5
		multimesh.set_instance_transform(i, transform)


func _rebuild() -> void:
	var mm := MultiMesh.new()
	mm.instance_count = count
	mm.transform_format = MultiMesh.TRANSFORM_2D

	var mesh := RectangleMesh.new()
	mesh.size = Vector2(2, 2)
	mm.mesh = mesh

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	for i in range(count):
		var x := rng.randf_range(-span * 0.5, span * 0.5)
		var y := rng.randf_range(-height * 0.5, height * 0.5)
		var s := rng.randf_range(min_size, max_size)

		var t := Transform2D()
		t.origin = Vector2(x, y)
		t = t.scaled(Vector2(s, s))
		mm.set_instance_transform(i, t)

		# Vary alpha per particle
		var alpha := rng.randf_range(0.2, 0.6)
		mm.set_instance_color(i, Color(particle_color.r, particle_color.g, particle_color.b, alpha))

	multimesh = mm
