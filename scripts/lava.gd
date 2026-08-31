class_name Lava
extends Node2D
## A static instant-death hazard filling a rectangular zone — this project's
## second lethal obstacle after SpinningBlade, and the anchor mechanic for the
## "obby gauntlet" levels (see LevelData's gauntlet levels): a flat trek
## interrupted by pits the player must clear with a jump, a dash, or a spin,
## rather than by simply walking. Lives in the Hazards container alongside
## wind zones and spinning blades, for the same reason: it's not part of the
## landable route, so route-walking code (terrain builders, reachability
## checks) that iterates Terrain's children in order must never see it.

@export var size: Vector2 = Vector2(160.0, 40.0)
@export var color: Color = Color(0.85, 0.25, 0.08, 1.0)
@export var glow_color: Color = Color(1.0, 0.55, 0.15, 1.0)
## Seconds before the pit can trigger again after a hit — same reasoning as
## SpinningBlade.retrigger_cooldown: main_scene.gd rebuilds terrain once per
## level load, not per respawn, so without this the pit would go harmless
## after the first hit for the rest of the attempt.
@export var retrigger_cooldown: float = 1.0

## Emitted the instant the player touches the lava surface. main_scene.gd
## connects this to the same respawn path used for falling/boss catches/the
## spinning blade — this hazard only needs to signal "the run just ended."
signal player_hit

var _surface: Polygon2D
var _crest: Polygon2D
var _glow_blobs: Array[Polygon2D] = []
var _sensor: Area2D
var _time: float = 0.0
var _triggered: bool = false


func _ready() -> void:
	_build_visual()

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Slightly narrower/shorter than the visual so a player merely grazing
	# the pit's edge pixel isn't killed by a hitbox wider than what they see.
	rect.size = Vector2(maxf(size.x - 8.0, 4.0), maxf(size.y * 0.6, 4.0))
	shape.shape = rect
	shape.position = Vector2(0.0, size.y * 0.2)
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5

	# Depth: a darker pool under a hotter upper band, so the pit reads as
	# something with volume rather than a flat red rectangle.
	var deep := Polygon2D.new()
	deep.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	deep.color = color.darkened(0.45)
	add_child(deep)

	# Fade the pool out downward instead of ending on a hard edge. Without
	# this each pit read as an orange COLUMN hanging in the air with a visible
	# bottom, rather than a channel dropping away into the dark. The sensor is
	# unaffected — this is purely the visual continuing past it.
	var fade_steps := 6
	for i in fade_steps:
		var t0 := float(i) / float(fade_steps)
		var t1 := float(i + 1) / float(fade_steps)
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([
			Vector2(-hx, hy + size.y * t0), Vector2(hx, hy + size.y * t0),
			Vector2(hx, hy + size.y * t1), Vector2(-hx, hy + size.y * t1)
		])
		var c := color.darkened(0.55 + t0 * 0.35)
		band.color = Color(c.r, c.g, c.b, (1.0 - t0) * 0.85)
		add_child(band)

	_surface = Polygon2D.new()
	_surface.color = color
	add_child(_surface)

	# Bright crest riding the very top of the surface — this is what actually
	# reads as "molten" at a glance and marks the exact lethal boundary.
	_crest = Polygon2D.new()
	_crest.color = glow_color
	add_child(_crest)

	# Upward light spill, so the pit lights the air above it.
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-hx, -hy - 26.0), Vector2(hx, -hy - 26.0),
		Vector2(hx, -hy + 4.0), Vector2(-hx, -hy + 4.0)
	])
	glow.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.16)
	add_child(glow)

	# Rising bubbles.
	var blob_count := maxi(3, int(size.x / 50.0))
	for i in blob_count:
		var blob := Polygon2D.new()
		blob.polygon = PackedVector2Array([
			Vector2(-5, 4), Vector2(5, 4), Vector2(3, -4), Vector2(-3, -4)
		])
		blob.color = glow_color
		blob.position = Vector2(-hx + size.x * ((float(i) + 0.5) / float(blob_count)), hy)
		add_child(blob)
		_glow_blobs.append(blob)

	_rebuild_surface(0.0)


## The surface is re-polygonised every frame so it visibly churns. Two summed
## sines at different rates keep it from reading as a single repeating wave.
func _rebuild_surface(t: float) -> void:
	if _surface == null:
		return
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var segments := maxi(8, int(size.x / 16.0))

	var top := PackedVector2Array()
	var crest := PackedVector2Array()
	for i in segments + 1:
		var f := float(i) / float(segments)
		var x := -hx + size.x * f
		var wave := sin(f * 9.0 + t * 2.1) * 3.0 + sin(f * 21.0 - t * 3.4) * 1.6
		top.append(Vector2(x, -hy + wave))
	# Close the body downward.
	var body := top.duplicate()
	body.append(Vector2(hx, hy))
	body.append(Vector2(-hx, hy))
	_surface.polygon = body

	# Crest is a thin ribbon following the same wave.
	for i in top.size():
		crest.append(top[i])
	for i in range(top.size() - 1, -1, -1):
		crest.append(top[i] + Vector2(0, 5.0))
	_crest.polygon = crest


func _physics_process(delta: float) -> void:
	_time += delta
	_rebuild_surface(_time)
	for i in _glow_blobs.size():
		var blob := _glow_blobs[i]
		var phase := fposmod(_time * 0.6 + float(i) * 0.37, 1.0)
		blob.position.y = size.y * 0.5 - phase * size.y
		blob.modulate.a = 1.0 - phase


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is Player):
		return
	# A well-timed spin phases through. Checked here rather than in each
	# hazard's own way so every lethal obstacle honours it identically.
	if (body as Player).is_invulnerable():
		return
	_triggered = true
	player_hit.emit()
	await get_tree().create_timer(retrigger_cooldown).timeout
	if not is_instance_valid(self):
		return
	_triggered = false
