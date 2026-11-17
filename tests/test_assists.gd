extends SceneTree
## The accessibility and assist settings do real things: hazard speed, fixed jump height,
## high-contrast platforms and colour-vision correction. Every one is checked against its
## off state so a setting that only exists in the menu fails here.

var _failures: int = 0
var _gs: Node


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	_gs.reset_settings()
	_color_vision()
	await _hazard_speed()
	await _jump_mode()
	await _high_contrast()
	await _colorblind_in_shader()
	print("[test_assists] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame
	await process_frame


# ── colour vision ───────────────────────────────────────────────────

func _apply(m: Basis, c: Vector3) -> Vector3:
	return m * c


func _color_vision() -> void:
	var id := ColorVision.matrix(ColorVision.Kind.OFF)
	_check("OFF is the identity", id == Basis.IDENTITY)
	var seen := {}
	for k in [1, 2, 3]:
		var m := ColorVision.matrix(k)
		var finite := true
		for v in [m.x, m.y, m.z]:
			finite = finite and is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
		_check("%s is a finite matrix that changes colours" % ColorVision.NAMES[k], finite and m != Basis.IDENTITY)
		var grey := _apply(m, Vector3(0.5, 0.5, 0.5))
		_check("%s leaves grey grey (%s)" % [ColorVision.NAMES[k], str(grey)], grey.distance_to(Vector3(0.5, 0.5, 0.5)) < 0.01)
		seen[str(m)] = true
	_check("the three corrections are different from each other", seen.size() == 3)
	# The matrix does what the row-major formula says.
	var rows := ColorVision.rows(ColorVision.Kind.DEUTAN)
	var c := Vector3(0.9, 0.2, 0.4)
	var expect := Vector3(
		rows[0][0] * c.x + rows[0][1] * c.y + rows[0][2] * c.z,
		rows[1][0] * c.x + rows[1][1] * c.y + rows[1][2] * c.z,
		rows[2][0] * c.x + rows[2][1] * c.y + rows[2][2] * c.z)
	_check("the Basis applies the row-major matrix correctly", _apply(ColorVision.matrix(ColorVision.Kind.DEUTAN), c).distance_to(expect) < 0.001)
	# Red and green (lava vs. a green pickup) become separable by blue for red-green weakness.
	var red := Vector3(1, 0, 0)
	var green := Vector3(0, 1, 0)
	var gap_before := absf(red.z - green.z)
	var pm := ColorVision.matrix(ColorVision.Kind.PROTAN)
	var gap_after := absf(_apply(pm, red).z - _apply(pm, green).z)
	_check("red-weak correction pushes red and green apart in blue (%.2f -> %.2f)" % [gap_before, gap_after], gap_after > gap_before + 0.2)


# ── hazard speed ────────────────────────────────────────────────────

func _pendulum_time(frames: int) -> float:
	var p := Pendulum.new()
	root.add_child(p)
	await _step(frames)
	var t: float = p._time
	p.queue_free()
	return t


func _hazard_speed() -> void:
	_gs.set_reg("assist_hazard_speed", 0)
	_check("NORMAL is full speed", is_equal_approx(HazardSpeed.scale, 1.0))
	var normal := await _pendulum_time(60)
	_gs.set_reg("assist_hazard_speed", 2)
	_check("SLOWEST sets the factor to 0.65", is_equal_approx(HazardSpeed.scale, 0.65))
	var slow := await _pendulum_time(60)
	_check("a pendulum clock really runs slower (%.2f vs %.2f)" % [slow, normal], slow < normal * 0.75 and slow > normal * 0.55)
	# Slower never makes a safe window shorter: phases are longer in real seconds.
	_gs.set_reg("assist_hazard_speed", 1)
	var mid := await _pendulum_time(60)
	_check("SLOWER sits between them (%.2f)" % mid, mid < normal and mid > slow)
	var blade := SpinningBlade.new()
	root.add_child(blade)
	_gs.set_reg("assist_hazard_speed", 0)
	await _step(30)
	var a_normal: float = blade._angle
	blade._angle = 0.0
	_gs.set_reg("assist_hazard_speed", 2)
	await _step(30)
	_check("a blade spins slower under the assist", blade._angle < a_normal * 0.8)
	blade.queue_free()
	_gs.reset_settings()
	_check("reset puts hazards back to full speed", is_equal_approx(HazardSpeed.scale, 1.0))


# ── jump mode ───────────────────────────────────────────────────────

func _floor(pos: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	b.add_child(c)
	b.collision_layer = 3
	b.position = pos
	root.add_child(b)
	return b


func _apex(player: Player, hold_frames: int) -> float:
	player.global_position = Vector2(0, 340)
	player.velocity = Vector2.ZERO
	player.reset_state()
	await _step(10)
	var start_y := player.global_position.y
	var apex := start_y
	Input.action_press("jump", 1.0)
	for f in 80:
		if f == hold_frames:
			Input.action_release("jump")
		await physics_frame
		apex = minf(apex, player.global_position.y)
	Input.action_release("jump")
	await _step(60)
	return start_y - apex


func _jump_mode() -> void:
	var ground := _floor(Vector2(0, 400), Vector2(3000, 40))
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	_gs.set_reg("ctl_jump_mode", 0)
	player._apply_feel()
	var tap := await _apex(player, 2)
	var held := await _apex(player, 40)
	_check("variable: a tap is lower than a hold (%.0f vs %.0f)" % [tap, held], held > tap + 25.0)
	_gs.set_reg("ctl_jump_mode", 1)
	player._apply_feel()
	_check("ALWAYS FULL removes the release trim", is_equal_approx(player.jump_release_damping, 1.0))
	var tap2 := await _apex(player, 2)
	var held2 := await _apex(player, 40)
	_check("fixed: a tap is as high as a hold (%.0f vs %.0f)" % [tap2, held2], absf(tap2 - held2) < 6.0 and tap2 > held * 0.9)
	_gs.reset_settings()
	player._apply_feel()
	_check("back to hold-for-height after a reset", player.jump_release_damping < 1.0)
	player.queue_free()
	ground.queue_free()
	await _step(2)


# ── high contrast ───────────────────────────────────────────────────

func _edge_height(plat: Node) -> float:
	var poly := (plat.get_node("TopEdge") as Polygon2D).polygon
	var top := 99999.0
	var bottom := -99999.0
	for v in poly:
		top = minf(top, v.y)
		bottom = maxf(bottom, v.y)
	return bottom - top


func _high_contrast() -> void:
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	root.add_child(scene)
	await _step(10)
	var plat: Node = null
	for c in scene.get_node("Terrain").get_children():
		if c.has_node("TopEdge"):
			plat = c
			break
	_check("found a platform to inspect", plat != null)
	var h0 := _edge_height(plat)
	var col0: Color = (plat.get_node("TopEdge") as Polygon2D).color
	_gs.set_reg("a11y_high_contrast", true)
	await _step(3)
	var h1 := _edge_height(plat)
	var col1: Color = (plat.get_node("TopEdge") as Polygon2D).color
	_check("high contrast thickens the edge (%.0f -> %.0f)" % [h0, h1], h1 >= 7.0 and h1 > h0)
	_check("and brightens it (%.2f -> %.2f)" % [col0.get_luminance(), col1.get_luminance()], col1.get_luminance() > col0.get_luminance() + 0.1)
	_gs.set_reg("a11y_high_contrast", false)
	await _step(3)
	_check("turning it off restores the edge", is_equal_approx(_edge_height(plat), h0))
	scene.queue_free()
	await _step(2)


# ── colour-blind correction reaches the shader ──────────────────────

func _colorblind_in_shader() -> void:
	var filter := PixelFilter.new()
	root.add_child(filter)
	await _step(3)
	var mat: ShaderMaterial = filter._material
	_check("by default the shader gets the identity", mat.get_shader_parameter("cvd") == Basis.IDENTITY)
	for k in [1, 2, 3]:
		_gs.set_reg("a11y_colorblind", k)
		await _step(2)
		_check("%s reaches the world shader" % ColorVision.NAMES[k], mat.get_shader_parameter("cvd") == ColorVision.matrix(k))
	_gs.reset_settings()
	await _step(2)
	_check("reset clears it", mat.get_shader_parameter("cvd") == Basis.IDENTITY)
	filter.queue_free()
