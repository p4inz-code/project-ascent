class_name SkyBody
extends Node2D
## A large celestial body — sun, moon, or distant planet — sitting far behind
## everything else in the sky.
##
## Built for the single most-reported visual problem: every level reads as the
## same place because the sky is an anonymous gradient in all 25. Colour alone
## was never going to fix that; the eye needs a landmark. A body whose shape,
## size and position change per Act gives each one an unmistakable identity in
## a single glance — including in a screenshot, which is how most people will
## first see this game.
##
## Deliberately drawn with Polygon2D rings rather than a texture: the whole
## backdrop is procedural vector, and a photographic sun pasted into it would
## read as borrowed art.

enum Kind { SUN, MOON, PLANET }

@export var kind: Kind = Kind.MOON:
	set(value):
		kind = value
		_rebuild()

@export var radius: float = 90.0:
	set(value):
		radius = maxf(value, 4.0)
		_rebuild()

@export var body_color: Color = Color(0.92, 0.94, 1.0, 1.0):
	set(value):
		body_color = value
		_rebuild()

## Outer glow colour. Alpha is scaled down across the halo rings, so pass the
## colour at full strength and let the build fade it.
@export var glow_color: Color = Color(0.6, 0.75, 1.0, 0.5):
	set(value):
		glow_color = value
		_rebuild()

## How many soft halo rings surround the disc. More rings = smoother falloff.
@export var glow_rings: int = 14:
	set(value):
		glow_rings = clampi(value, 0, 24)
		_rebuild()

## Crater/band seed so two moons in different Acts are not identical.
@export var detail_seed: int = 1:
	set(value):
		detail_seed = value
		_rebuild()

const SEGMENTS: int = 40


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()

	# Halo first so the disc draws over it.
	for i in range(glow_rings, 0, -1):
		var t := float(i) / float(maxi(glow_rings, 1))
		var ring := Polygon2D.new()
		ring.polygon = _circle(radius * (1.0 + t * 0.85), SEGMENTS)
		# Quadratic falloff reads as light scatter; linear looks like flat bands.
		# Many faint rings rather than a few strong ones. Five rings at 0.5
		# alpha stacked into a visible hard donut around the disc instead of
		# reading as light scatter; this divides the budget across the stack so
		# each ring is nearly invisible on its own.
		ring.color = Color(glow_color.r, glow_color.g, glow_color.b,
			glow_color.a * (1.0 - t) * (1.0 - t) * (1.6 / float(maxi(glow_rings, 1))))
		add_child(ring)

	var disc := Polygon2D.new()
	disc.polygon = _circle(radius, SEGMENTS)
	disc.color = body_color
	add_child(disc)

	match kind:
		Kind.MOON:
			_add_craters()
		Kind.PLANET:
			_add_bands()
		Kind.SUN:
			_add_corona()


## Darker pits scattered across the disc. Uses a seeded RNG so a given Act's
## moon looks the same every time it loads — a moon that reshuffles its craters
## on respawn would read as a rendering bug.
func _add_craters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed
	for _i in 5:
		var crater := Polygon2D.new()
		var cr := radius * rng.randf_range(0.10, 0.22)
		var angle := rng.randf() * TAU
		# sqrt keeps them area-uniform instead of clustering at the centre.
		var dist := sqrt(rng.randf()) * (radius - cr * 1.4)
		crater.polygon = _circle(cr, 14)
		crater.position = Vector2(cos(angle), sin(angle)) * dist
		crater.color = body_color.darkened(0.16)
		add_child(crater)


## Horizontal bands, clipped to the disc by construction: each band's width is
## derived from the circle's chord at that height, so nothing spills outside.
func _add_bands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed
	var y := -radius * 0.75
	while y < radius * 0.75:
		var h := radius * rng.randf_range(0.06, 0.15)
		# Clip to the chord at whichever of the band's two edges is FURTHER
		# from the centre — that edge is the narrower one. Using only `y` let
		# the lower half of every band spill outside the disc, which was
		# clearly visible on Act IV's planet.
		var edge := maxf(absf(y), absf(y + h))
		var half_w := sqrt(maxf(radius * radius - edge * edge, 0.0))
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([
			Vector2(-half_w, y), Vector2(half_w, y),
			Vector2(half_w, y + h), Vector2(-half_w, y + h)])
		band.color = body_color.darkened(rng.randf_range(0.08, 0.22))
		add_child(band)
		y += h + radius * rng.randf_range(0.05, 0.12)


## Radiating spikes, alternating length so the rim reads as irregular rather
## than as a gear.
func _add_corona() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var length := radius * rng.randf_range(1.15, 1.55)
		var spread := 0.055
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([
			Vector2(cos(angle - spread), sin(angle - spread)) * radius * 0.95,
			Vector2(cos(angle), sin(angle)) * length,
			Vector2(cos(angle + spread), sin(angle + spread)) * radius * 0.95,
		])
		ray.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.16)
		add_child(ray)


func _circle(r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
