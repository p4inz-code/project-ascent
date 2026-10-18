class_name TitleWorld
extends Control
## The live pixel scene behind the title menu: a night sky over THE SPIRE, with
## Trevor on a ledge and PIP hovering by him.
##
## It is interactive on purpose, so the title feels like a place rather than a
## poster: the layers drift with the mouse, PIP follows the cursor, Trevor walks
## toward where you point and jumps when you click, and a click sends out a ring
## of light. Everything is drawn on the UI pixel grid (UITheme.PX) with hard
## rectangles and nearest-filtered sprites, so it sits in the same pixel world as
## the rest of the game. No assets beyond the player sheet.
##
## Time and input are injected through `advance()` / `set_pointer()` / `click()`
## so tests can drive it deterministically without a window or a real mouse.

const PX := UITheme.PX
const SHEET_PATH := "res://assets/pixel/player_sheet.png"
const TABLE_PATH := "res://assets/pixel/player_sheet.json"
const SWAP_SHADER := preload("res://shaders/palette_swap.gdshader")

const STAR_COUNT := 140
const SKY_BANDS := 28
const WALK_SPEED := 150.0
const JUMP_VELOCITY := -620.0
const GRAVITY := 1800.0

var time: float = 0.0
## Pointer position in this control's own space; only meaningful once has_pointer.
var pointer: Vector2 = Vector2(-1, -1)
var has_pointer: bool = false

var _stars: Array[Vector3] = []          # x, y (0..1), phase
var _rings: Array[Vector3] = []          # x, y, age
var _sprite: AnimatedSprite2D
var _trevor_x: float = 0.0
var _trevor_vy: float = 0.0
var _trevor_lift: float = 0.0            # height above the ledge, >= 0
var _facing: int = 1
var _pip: Vector2 = Vector2.ZERO
var _parallax: Vector2 = Vector2.ZERO
var _comet: float = -1.0                 # age of the current shooting star, -1 = none
var _next_comet: float = 4.0
## Trevor and PIP are placed on the first frame the control has a real size:
## at _ready() a full-rect Control has often not been laid out yet.
var _placed: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 417
	for i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.8, rng.randf() * TAU))
	_build_sprite()
	resized.connect(queue_redraw)


func _build_sprite() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	var path: String = gs.sheet_path() if gs != null and gs.has_method("sheet_path") else SHEET_PATH
	var frames := PlayerVisuals.build_frames(path)
	if frames == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = SWAP_SHADER
	mat.set_shader_parameter("suit", gs.get_player_color() if gs != null else Color(0.42, 0.78, 1.0))
	PlayerVisuals.apply_look(mat, gs)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = mat
	# Twice the in-game scale: this is the hero shot, and still a whole number.
	_sprite.scale = Vector2(PX * 2, PX * 2)
	_sprite.centered = true
	_sprite.play("idle")
	add_child(_sprite)


# ── layout helpers ──────────────────────────────────────────────────

func ledge_y() -> float:
	return snappedf(size.y * 0.80, PX)


## The ledge spans the right of the screen so the left column stays clear for the menu.
func ledge_rect() -> Rect2:
	var x0 := snappedf(size.x * 0.42, PX)
	return Rect2(x0, ledge_y(), size.x - x0 + 60.0, size.y - ledge_y() + 60.0)


func trevor_range() -> Vector2:
	var r := ledge_rect()
	return Vector2(r.position.x + 60.0, minf(r.end.x - 60.0, size.x - 90.0))


func trevor_position() -> Vector2:
	return Vector2(_trevor_x, ledge_y() - _trevor_lift)


func pip_position() -> Vector2:
	return _pip


func ring_count() -> int:
	return _rings.size()


func current_animation() -> String:
	return String(_sprite.animation) if _sprite != null else ""


# ── input (real and injected) ───────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_pointer((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		click((event as InputEventMouseButton).position)


func set_pointer(p: Vector2) -> void:
	pointer = p
	has_pointer = true


## A click: a ring of light, and Trevor hops if he is standing.
func click(p: Vector2) -> void:
	set_pointer(p)
	_rings.append(Vector3(p.x, p.y, 0.0))
	if _rings.size() > 6:
		_rings.pop_front()
	if _trevor_lift <= 0.0:
		_trevor_vy = JUMP_VELOCITY
		_trevor_lift = 0.01
		_play("jump")


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	time += delta
	if not _placed and size.x > 0.0:
		_placed = true
		_trevor_x = size.x * 0.66
		_pip = Vector2(_trevor_x + 40.0, ledge_y() - 160.0)
	var aim := Vector2(0.5, 0.5)
	if has_pointer and size.x > 0.0 and size.y > 0.0:
		aim = Vector2(clampf(pointer.x / size.x, 0.0, 1.0), clampf(pointer.y / size.y, 0.0, 1.0))
	_parallax = _parallax.lerp((aim - Vector2(0.5, 0.5)) * 2.0, minf(1.0, delta * 3.0))

	# PIP trails the cursor, or idles on a lazy orbit around Trevor.
	var pip_target := Vector2(_trevor_x + sin(time * 0.9) * 70.0, ledge_y() - 170.0 + cos(time * 1.3) * 18.0)
	if has_pointer and pointer.x > size.x * 0.40:
		pip_target = pointer + Vector2(18.0, -18.0)
	_pip = _pip.lerp(pip_target, minf(1.0, delta * 4.0))

	_step_trevor(delta)

	for i in range(_rings.size() - 1, -1, -1):
		var r := _rings[i]
		r.z += delta
		if r.z > 0.9:
			_rings.remove_at(i)
		else:
			_rings[i] = r

	if _comet >= 0.0:
		_comet += delta
		if _comet > 1.1:
			_comet = -1.0
	else:
		_next_comet -= delta
		if _next_comet <= 0.0:
			_comet = 0.0
			_next_comet = 5.0 + fmod(time * 7.0, 5.0)
	queue_redraw()


func _step_trevor(delta: float) -> void:
	# Airborne arc.
	if _trevor_lift > 0.0:
		_trevor_vy += GRAVITY * delta
		_trevor_lift -= _trevor_vy * delta
		if _trevor_vy > 0.0:
			_play("fall")
		if _trevor_lift <= 0.0:
			_trevor_lift = 0.0
			_trevor_vy = 0.0
			_play("land")
	# Walk toward the pointer when it is out over the ledge; otherwise stand.
	var range_x := trevor_range()
	var want := _trevor_x
	if has_pointer and pointer.x > range_x.x - 40.0:
		want = clampf(pointer.x, range_x.x, range_x.y)
	var dx := want - _trevor_x
	if absf(dx) > 14.0:
		_facing = 1 if dx > 0.0 else -1
		_trevor_x += signf(dx) * minf(WALK_SPEED * delta, absf(dx))
		if _trevor_lift <= 0.0:
			_play("run")
	elif _trevor_lift <= 0.0 and _sprite != null and _sprite.animation != "land":
		_play("idle")
	_trevor_x = clampf(_trevor_x, range_x.x, range_x.y)
	if _sprite != null:
		_sprite.flip_h = _facing < 0
		# The cell's bottom edge (row 19 of 20) sits on the ledge.
		var half_h := 10.0 * _sprite.scale.y
		_sprite.position = Vector2(_trevor_x, ledge_y() - _trevor_lift - half_h + _sprite.scale.y)
		if _sprite.animation == "land" and not _sprite.is_playing():
			_play("idle")


func _play(anim: StringName) -> void:
	if _sprite != null and _sprite.animation != anim:
		_sprite.play(anim)


# ── drawing ─────────────────────────────────────────────────────────

func _snap(v: float) -> float:
	return floorf(v / PX) * PX


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(_snap(x), _snap(y), maxf(PX, _snap(w)), maxf(PX, _snap(h))), c)


func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_planet()
	_draw_comet()
	_draw_spires(0.35, Color(0.06, 0.08, 0.17), 0.55, 0)
	_draw_spires(0.62, Color(0.09, 0.12, 0.25), 0.8, 1)
	_draw_main_spire()
	_draw_ledge()
	_draw_pip()
	_draw_rings()


func _draw_sky() -> void:
	var top := Color(0.020, 0.030, 0.090)
	var low := Color(0.110, 0.130, 0.300)
	var band_h := maxf(PX, _snap(size.y / SKY_BANDS))
	var y := 0.0
	var i := 0
	while y < size.y:
		var t := clampf(float(i) / float(SKY_BANDS - 1), 0.0, 1.0)
		draw_rect(Rect2(0, y, size.x, band_h), top.lerp(low, t * t))
		y += band_h
		i += 1


func _draw_stars() -> void:
	for s in _stars:
		var tw := 0.55 + 0.45 * sin(time * 1.4 + s.z)
		var x := s.x * size.x - _parallax.x * 6.0
		var y := s.y * size.y - _parallax.y * 4.0
		var big := fmod(s.z, 1.0) > 0.86
		var c := Color(0.75, 0.82, 1.0, tw)
		if big:
			_rect(x, y, PX * 2, PX, c)
			_rect(x + PX / 2.0, y - PX, PX, PX * 3, c)
		else:
			_rect(x, y, PX, PX, c)


## A planet limb, drawn scanline by scanline so every edge is a hard pixel step.
func _draw_planet() -> void:
	var cx := size.x * 0.60 - _parallax.x * 10.0
	var cy := size.y * 0.24 - _parallax.y * 6.0
	var r := minf(size.x, size.y) * 0.12
	var y := -r
	while y <= r:
		var half := sqrt(maxf(0.0, r * r - y * y))
		var shade := clampf(0.7 + (-y / r) * 0.28, 0.0, 1.0)
		var base := Color(0.16, 0.18, 0.40).lerp(Color(0.35, 0.30, 0.60), shade)
		draw_rect(Rect2(_snap(cx - half), _snap(cy + y), _snap(half * 2.0), PX), base)
		# Terminator: the sunlit edge is a stepped amber band on the right.
		var lit := minf(half * 0.22, 40.0)
		draw_rect(Rect2(_snap(cx + half - lit), _snap(cy + y), _snap(lit), PX), Color(1.0, 0.78, 0.45, 0.30))
		y += PX


func _draw_comet() -> void:
	if _comet < 0.0:
		return
	var t := _comet / 1.1
	var x := size.x * (0.9 - 0.55 * t)
	var y := size.y * (0.10 + 0.30 * t)
	for i in 9:
		var a := (1.0 - float(i) / 9.0) * (1.0 - t)
		_rect(x + i * PX * 2, y - i * PX, PX * 2, PX, Color(1.0, 0.95, 0.8, a))


func _draw_spires(depth: float, colour: Color, height: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + seed_value
	var count := 7
	for i in count:
		var w := _snap(rng.randf_range(60.0, 130.0))
		var x := _snap((float(i) / count) * size.x + rng.randf_range(-30.0, 30.0) + size.x * 0.36 \
			- _parallax.x * 28.0 * depth)
		var h := size.y * height * rng.randf_range(0.45, 1.0)
		_rect(x, size.y - h, w, h, colour)
		_rect(x + w * 0.3, size.y - h - PX * 6, PX * 2, PX * 6, colour)


func _draw_main_spire() -> void:
	# The tower the whole game is about: stepped, lit windows, a blinking mast.
	var cx := _snap(size.x * 0.80 - _parallax.x * 16.0)
	var body := Color(0.10, 0.12, 0.22)
	var edge := Color(0.22, 0.27, 0.48)
	var tiers := [[260.0, 0.0], [210.0, 0.22], [160.0, 0.46], [110.0, 0.70], [64.0, 0.90]]
	for t in tiers:
		var w: float = t[0]
		var top_y: float = size.y * (1.0 - float(t[1]) - 0.30)
		var x := cx - w / 2.0
		_rect(x, top_y, w, size.y, body)
		_rect(x, top_y, w, PX, edge)
		_rect(x, top_y, PX, size.y, edge.darkened(0.3))
		# Windows: a lit grid, each flickering on its own phase.
		var wy := top_y + PX * 8
		var row := 0
		while wy < size.y * 0.95 and row < 6:
			var wx := x + PX * 6
			var col := 0
			while wx < x + w - PX * 8:
				var phase := float(row * 7 + col * 3) + w
				var on := sin(time * 0.8 + phase) > -0.35
				var colr := Color(1.0, 0.83, 0.47) if (row + col) % 3 != 0 else Color(0.35, 0.85, 1.0)
				if on:
					_rect(wx, wy, PX * 2, PX * 3, colr)
				wx += PX * 9
				col += 1
			wy += PX * 12
			row += 1
	# Mast and warning light.
	var mast_top := size.y * (1.0 - 0.90 - 0.30) - PX * 10
	_rect(cx - PX / 2.0, mast_top, PX, PX * 10, edge)
	if fmod(time, 1.6) < 0.5:
		_rect(cx - PX, mast_top - PX * 2, PX * 2, PX * 2, Color(1.0, 0.3, 0.3))


func _draw_ledge() -> void:
	var r := ledge_rect()
	var stone := Color(0.13, 0.15, 0.24)
	_rect(r.position.x, r.position.y, r.size.x, r.size.y, stone)
	_rect(r.position.x, r.position.y, r.size.x, PX * 2, Color(0.36, 0.44, 0.70))
	# Brick courses, matching the in-game stone tile rhythm.
	var by := r.position.y + PX * 4
	var row := 0
	while by < size.y:
		var bx: float = r.position.x + (PX * 8 if row % 2 == 1 else 0.0)
		while bx < r.end.x:
			_rect(bx, by, PX, PX * 5, Color(0.08, 0.09, 0.16))
			bx += PX * 16
		_rect(r.position.x, by + PX * 5, r.size.x, PX, Color(0.08, 0.09, 0.16))
		by += PX * 6
		row += 1
	# Amber lamp at the ledge end: the game's goal colour, used here as welcome.
	var lx := r.position.x + PX * 4
	_rect(lx, r.position.y - PX * 12, PX * 2, PX * 12, Color(0.30, 0.34, 0.5))
	var glow := 0.5 + 0.5 * sin(time * 2.0)
	_rect(lx - PX, r.position.y - PX * 15, PX * 4, PX * 3, Color(1.0, 0.83, 0.47, 0.6 + 0.4 * glow))


func _draw_pip() -> void:
	# PIP: an amber diamond with a pixel halo that breathes.
	var p := Vector2(_snap(_pip.x), _snap(_pip.y))
	var pulse := 0.5 + 0.5 * sin(time * 3.0)
	for ring in 3:
		var a := (0.16 - ring * 0.04) * (0.6 + 0.4 * pulse)
		var rr := (3 + ring * 2) * PX
		_rect(p.x - rr, p.y - PX, rr * 2, PX * 2, Color(1.0, 0.83, 0.47, a))
		_rect(p.x - PX, p.y - rr, PX * 2, rr * 2, Color(1.0, 0.83, 0.47, a))
	var amber := Color(1.0, 0.83, 0.47)
	_rect(p.x - PX, p.y - PX * 3, PX * 2, PX * 6, amber)
	_rect(p.x - PX * 3, p.y - PX, PX * 6, PX * 2, amber)
	_rect(p.x - PX * 2, p.y - PX * 2, PX * 4, PX * 4, amber)
	_rect(p.x - PX, p.y - PX, PX * 2, PX * 2, Color(1.0, 1.0, 0.9))


func _draw_rings() -> void:
	for r in _rings:
		var t: float = r.z / 0.9
		var radius := 12.0 + 90.0 * t
		var a := 0.8 * (1.0 - t)
		var n := 28
		for i in n:
			var ang := TAU * float(i) / n
			_rect(r.x + cos(ang) * radius, r.y + sin(ang) * radius, PX, PX, Color(0.6, 0.9, 1.0, a))
