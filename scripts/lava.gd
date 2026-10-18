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


const PX := 3.0
const BUBBLE_COUNT_MAX := 6
const EMBER_COUNT := 10

var _body_bands: Array[Polygon2D] = []
var _bubbles: Array[Polygon2D] = []
var _bubble_state: PackedFloat32Array = PackedFloat32Array()   # age 0..1 per bubble
var _embers: Array[Polygon2D] = []
var _ember_state: PackedFloat32Array = PackedFloat32Array()    # x, y, vx, life per ember (4 each)
var _crust_patches: Array[Polygon2D] = []
var _glow: Polygon2D
var _spill: Polygon2D


func _snap(v: float) -> float:
	return roundf(v / PX) * PX


## Top-to-bottom alpha fade on a quad polygon.
func _set_fade(poly: Polygon2D, top: Color, bottom: Color) -> void:
	poly.vertex_colors = PackedColorArray([top, top, bottom, bottom])


func _quad(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## A pool, not a pillar: a dark stone basin holds the lava, the surface is a
## quantised wave with a bright skin, dark crust patches drift on it, bubbles
## swell and pop into embers, and the whole thing breathes light into the air
## above it. Everything is built once; per-frame work only moves pooled nodes,
## so the node count stays flat during play.
func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var rim := 12.0

	# Basin: walls and floor in dark stone, drawn first so the lava sits inside.
	var basin_col := Color(0.10, 0.06, 0.07)
	var wall_l := Polygon2D.new()
	wall_l.polygon = _quad(-hx - rim, -hy - 6.0, -hx, hy + rim)
	wall_l.color = basin_col
	add_child(wall_l)
	var wall_r := Polygon2D.new()
	wall_r.polygon = _quad(hx, -hy - 6.0, hx + rim, hy + rim)
	wall_r.color = basin_col
	add_child(wall_r)
	var floor_p := Polygon2D.new()
	floor_p.polygon = _quad(-hx - rim, hy, hx + rim, hy + rim)
	floor_p.color = basin_col.darkened(0.3)
	add_child(floor_p)
	# Lit lips on top of each wall: the same "top edge catches light" cue the
	# platforms use, here glowing from below.
	for side in [-1.0, 1.0]:
		var lip := Polygon2D.new()
		var x0: float = (hx if side > 0.0 else -hx - rim)
		lip.polygon = _quad(x0, -hy - 6.0, x0 + rim, -hy - 3.0)
		lip.color = Color(0.75, 0.30, 0.12)
		add_child(lip)

	# Body: horizontal bands from deep red at the bottom to hot orange up top.
	var bands := 5
	for i in bands:
		var t := float(i) / float(bands - 1)
		var band := Polygon2D.new()
		var y0 := -hy + size.y * float(i) / float(bands)
		var y1 := -hy + size.y * float(i + 1) / float(bands)
		band.polygon = _quad(-hx, y0, hx, y1)
		band.color = glow_color.lerp(color.darkened(0.55), clampf(t * 1.15, 0.0, 1.0))
		add_child(band)
		_body_bands.append(band)

	# Surface skin: the waving top, redrawn each frame (see _rebuild_surface).
	_surface = Polygon2D.new()
	_surface.color = color.lightened(0.1)
	add_child(_surface)
	_crest = Polygon2D.new()
	_crest.color = Color(1.0, 0.86, 0.45)
	add_child(_crest)

	# Dark crust patches riding the surface and drifting slowly.
	var patch_count := maxi(2, int(size.x / 110.0))
	for i in patch_count:
		var patch := Polygon2D.new()
		var w := _snap(18.0 + float((i * 7) % 5) * 6.0)
		patch.polygon = _quad(-w * 0.5, -3.0, w * 0.5, 3.0)
		patch.color = Color(0.20, 0.07, 0.05)
		patch.position = Vector2(-hx + size.x * ((float(i) + 0.5) / float(patch_count)), -hy + 4.0)
		add_child(patch)
		_crust_patches.append(patch)

	# Bubbles: swell from the depths, then pop into embers.
	var bubble_count := mini(BUBBLE_COUNT_MAX, maxi(2, int(size.x / 70.0)))
	_bubble_state.resize(bubble_count)
	for i in bubble_count:
		var b := Polygon2D.new()
		b.polygon = _quad(-3.0, -3.0, 3.0, 3.0)
		b.color = Color(1.0, 0.82, 0.4)
		add_child(b)
		_bubbles.append(b)
		_bubble_state[i] = float(i) / float(bubble_count)

	# Embers: a fixed pool that drifts up off the surface and fades.
	_ember_state.resize(EMBER_COUNT * 4)
	for i in EMBER_COUNT:
		var e := Polygon2D.new()
		e.polygon = _quad(0.0, 0.0, PX, PX)
		e.color = Color(1.0, 0.7, 0.25)
		e.visible = false
		add_child(e)
		_embers.append(e)

	# Light: a broad soft glow above and a tight hot band along the surface.
	_glow = Polygon2D.new()
	_glow.polygon = _quad(-hx - 20.0, -hy - 54.0, hx + 20.0, -hy)
	# Vertex colours fade it to nothing upward, so it reads as light and not a lid.
	_glow.color = Color(1, 1, 1, 1)
	_set_fade(_glow, Color(glow_color.r, glow_color.g, glow_color.b, 0.0),
		Color(glow_color.r, glow_color.g, glow_color.b, 0.22))
	add_child(_glow)
	_spill = Polygon2D.new()
	_spill.polygon = _quad(-hx - 8.0, -hy - 16.0, hx + 8.0, -hy + 2.0)
	_spill.color = Color(1, 1, 1, 1)
	_set_fade(_spill, Color(1.0, 0.62, 0.2, 0.0), Color(1.0, 0.7, 0.25, 0.30))
	add_child(_spill)

	_rebuild_surface(0.0)


## The surface is re-polygonised every frame, with heights snapped to the pixel
## grid so the wave steps rather than smears. Two summed sines at different
## rates keep it from reading as one repeating wave.
func _rebuild_surface(t: float) -> void:
	if _surface == null:
		return
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var seg_w := PX * 4.0
	var segments := maxi(4, int(size.x / seg_w))
	var top := PackedVector2Array()
	for i in segments + 1:
		var f := float(i) / float(segments)
		var x := -hx + size.x * f
		var wave := sin(f * 11.0 + t * 2.0) * 3.5 + sin(f * 27.0 - t * 3.1) * 1.8
		# Pin the ends to the rim so the skin meets the basin walls cleanly.
		var edge := minf(1.0, minf(f, 1.0 - f) * 8.0)
		top.append(Vector2(_snap(x), _snap(-hy + wave * edge)))
	var body := top.duplicate()
	body.append(Vector2(hx, -hy + size.y * 0.22))
	body.append(Vector2(-hx, -hy + size.y * 0.22))
	_surface.polygon = body
	var crest := PackedVector2Array()
	for p in top:
		crest.append(p)
	for i in range(top.size() - 1, -1, -1):
		crest.append(top[i] + Vector2(0.0, PX * 1.5))
	_crest.polygon = crest


func _physics_process(delta: float) -> void:
	_time += delta
	_rebuild_surface(_time)
	var hx := size.x * 0.5
	var hy := size.y * 0.5

	# Crust patches drift sideways and bob with the wave.
	for i in _crust_patches.size():
		var patch := _crust_patches[i]
		var span := size.x - 20.0
		var x := fposmod(float(i) * span / float(_crust_patches.size()) + _time * 6.0, span) - span * 0.5
		patch.position = Vector2(_snap(x), _snap(-hy + 3.0 + sin(_time * 1.3 + float(i)) * 2.0))

	# Bubbles swell as they rise; at the surface they pop and shed embers.
	for i in _bubbles.size():
		_bubble_state[i] += delta * (0.35 + 0.05 * float(i % 3))
		var bx := -hx + size.x * fposmod(0.13 + float(i) * 0.37 + _time * 0.07, 1.0)
		if _bubble_state[i] >= 1.0:
			_bubble_state[i] = 0.0
			_spawn_embers(bx, -hy)
		var age := _bubble_state[i]
		var b := _bubbles[i]
		b.position = Vector2(_snap(bx), _snap(hy - age * size.y * 0.95))
		var grow := 0.6 + age * 1.4
		b.scale = Vector2(grow, grow)
		b.modulate.a = 0.35 + age * 0.65

	# Embers: drift upward, fading out.
	for i in EMBER_COUNT:
		var o := i * 4
		var life: float = _ember_state[o + 3]
		var e := _embers[i]
		if life <= 0.0:
			e.visible = false
			continue
		life -= delta
		_ember_state[o + 3] = life
		_ember_state[o] += _ember_state[o + 2] * delta
		_ember_state[o + 1] -= (40.0 + 25.0 * life) * delta
		e.position = Vector2(_snap(_ember_state[o]), _snap(_ember_state[o + 1]))
		e.modulate.a = clampf(life / 0.9, 0.0, 1.0)
		e.visible = life > 0.0

	# Pulsing light.
	var pulse := 0.5 + 0.5 * sin(_time * 2.2)
	_glow.modulate.a = 0.55 + 0.45 * pulse
	_spill.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_time * 3.3 + 1.0))


func _spawn_embers(x: float, y: float) -> void:
	var made := 0
	for i in EMBER_COUNT:
		if made >= 3:
			return
		var o := i * 4
		if _ember_state[o + 3] > 0.0:
			continue
		_ember_state[o] = x
		_ember_state[o + 1] = y
		_ember_state[o + 2] = (float(made) - 1.0) * 14.0 + float((i * 5) % 7 - 3)
		_ember_state[o + 3] = 0.9
		made += 1


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
