extends SceneTree
## The opening film's staging, checked frame by frame in numbers: the ship flies the way its nose
## points, its exhaust trails behind it, the rift is where the ship is heading, nothing the
## player should read is covered by the caption, and the title slam leaves no tween spinning.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _boot() -> void:
	await process_frame
	_art()
	await _orbit()
	await _rift()
	await _cockpit()
	await _first_step_and_slam()
	print("[test_story_direction] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


# ── the art itself ──────────────────────────────────────────────────

func _opaque_in_column(img: Image, x: int) -> int:
	var n := 0
	for y in img.get_height():
		if img.get_pixel(x, y).a > 0.5:
			n += 1
	return n


func _art() -> void:
	var ship := (load("res://assets/pixel/cs_ship.png") as Texture2D).get_image()
	_check("the ship is 76 x 28 art pixels", ship.get_width() == 76 and ship.get_height() == 28)
	# Nose to the right: the right edge is a red cone, the left edge is the engine bell (dark grey).
	var nose := ship.get_pixel(68, 14)
	var bell := ship.get_pixel(4, 14)
	_check("the nose (right) is red and the engine bell (left) is dark", nose.r > 0.6 and nose.g < 0.4 and bell.r < 0.5 and bell.g < 0.5)
	# The nose tapers: far fewer opaque pixels in the last column than at the middle.
	_check("the right end tapers to a point", _opaque_in_column(ship, 74) < _opaque_in_column(ship, 40) / 2)
	var flame := (load("res://assets/pixel/cs_exhaust.png") as Texture2D).get_image()
	_check("three flame frames of 22 x 14", flame.get_width() == 66 and flame.get_height() == 14)
	# Each flame is attached at its RIGHT edge (the ship's tail) and points LEFT.
	for f in 3:
		var at_tail := _opaque_in_column(flame, f * 22 + 21)
		var at_tip := _opaque_in_column(flame, f * 22 + 3)
		_check("flame frame %d is widest at the tail and thins to the left" % f, at_tail > at_tip and at_tail >= 6)
	var bust := (load("res://assets/pixel/cs_trevor_bust.png") as Texture2D).get_image()
	_check("Trevor's bust has two 64 x 72 frames", bust.get_width() == 128 and bust.get_height() == 72)
	# The visor is dark glass in the middle of the helmet, in both frames.
	for f in 2:
		var v := bust.get_pixel(f * 64 + 32, 17)
		_check("bust frame %d has a dark visor" % f, v.a > 0.5 and v.b < 0.6 and v.r < 0.3)
	var calm := bust.get_pixel(40, 22)
	var alert := bust.get_pixel(64 + 24, 22)
	_check("the HUD is cyan when calm and amber on alert", calm.b > calm.r and alert.r > alert.b)


# ── helpers ─────────────────────────────────────────────────────────

func _scene(index: int) -> Cutscene:
	var cs := Cutscene.new()
	cs.speed = 1.0
	root.add_child(cs)
	cs._master.kill()
	cs._enter_scene(index)
	return cs


func _find_tex(cs: Cutscene, needle: String) -> TextureRect:
	for c in cs._world.get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			var path := ""
			var t: Texture2D = (c as TextureRect).texture
			if t is AtlasTexture and (t as AtlasTexture).atlas != null:
				path = (t as AtlasTexture).atlas.resource_path
			else:
				path = t.resource_path
			if path.ends_with(needle):
				return c
	return null


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


# ── scene 1: orbit ──────────────────────────────────────────────────

func _orbit() -> void:
	var cs := _scene(0)
	var ship := _find_tex(cs, "cs_ship.png")
	_check("the orbit scene has the ship", ship != null)
	if ship == null:
		return
	await _wait(0.6)
	var x0 := ship.position.x
	await _wait(1.6)
	var x1 := ship.position.x
	_check("the ship flies to the RIGHT, the way its nose points (%.0f -> %.0f)" % [x0, x1], x1 > x0 + 80.0)
	var flame := ship.get_meta("flame") as TextureRect
	_check("its flame is attached behind it, to the left of the hull", flame != null and flame.position.x < 0.0)
	_check("the flame sits at the engine height, inside the ship's height", flame != null and flame.position.y > 0.0 and flame.position.y < ship.size.y)
	# The camera never shows it flying backwards: x is monotonic over a longer sample.
	var last := ship.position.x
	var monotonic := true
	for _i in 8:
		await _wait(0.25)
		monotonic = monotonic and ship.position.x >= last
		last = ship.position.x
	_check("it never reverses", monotonic)
	cs.queue_free()
	await process_frame


# ── scene 3: the rift ───────────────────────────────────────────────

func _rift() -> void:
	var cs := _scene(2)
	var ship := _find_tex(cs, "cs_ship.png")
	var rift := _find_tex(cs, "rift.png")
	_check("the rift scene has the ship and the rift", ship != null and rift != null)
	if ship == null or rift == null:
		return
	var x0 := ship.position.x
	await _wait(2.5)
	var x1 := ship.position.x
	_check("the ship moves toward the rift (to the right) (%.0f -> %.0f)" % [x0, x1], x1 > x0 + 60.0)
	# The rift is centred at x = 238 art px; the ship is always to its left, nose toward it.
	var rift_x := 238.0 * Cutscene.ART
	_check("the ship stays to the left of the rift centre", ship.position.x + ship.size.x < rift_x)
	cs.queue_free()
	await process_frame


# ── scene 2: cockpit ────────────────────────────────────────────────

func _cockpit() -> void:
	var cs := _scene(1)
	await _wait(0.5)
	var bust := _find_tex(cs, "cs_trevor_bust.png")
	var panel: Control = cs._ui.get_node("CaptionPanel")
	_check("the cockpit has Trevor and a caption panel", bust != null and panel != null)
	if bust != null and panel != null:
		# Stage coordinates (the film's own 1920 x 1080 space), whatever the window is.
		var bust_rect := Rect2(bust.position + cs._world.position, bust.size)
		var panel_rect := Rect2(panel.position, panel.size)
		var overlap := bust_rect.intersection(panel_rect)
		_check("the caption does not cover Trevor (overlap %.0f px wide)" % overlap.size.x, overlap.size.x < 8.0 or overlap.size.y < 8.0)
		_check("Trevor is fully on screen %s" % str(bust_rect), bust_rect.position.x >= -14.0 and bust_rect.end.x <= 1920.0 + 14.0 and bust_rect.end.y <= 1080.0 + 14.0)
	# The alert HUD frame shows once the warning lights start to change.
	await _wait(2.4)
	var region := ((bust.texture as AtlasTexture).region) if bust != null else Rect2()
	_check("the visor HUD switches to alert (frame 2)", region.position.x == 64.0)
	cs.queue_free()
	await process_frame


# ── scene 8 and the slam ────────────────────────────────────────────

func _first_step_and_slam() -> void:
	var cs := _scene(7)
	await _wait(0.4)
	var bust := _find_tex(cs, "cs_trevor_bust.png")
	_check("the last scene has Trevor's bust", bust != null)
	if bust != null:
		var centre := bust.position.x + bust.size.x * 0.5
		_check("he is centred (%.0f px from the middle)" % absf(centre - 960.0), absf(centre - 960.0) < 150.0)
		_check("and fully on screen", bust.position.y >= -12.0 and bust.position.y + bust.size.y <= 1080.0 + 12.0)
	var before: Array = cs._tweens.duplicate()
	cs._slam()
	await process_frame
	var survivors := 0
	for t in before:
		if t != cs._master and t != null and t.is_valid():
			survivors += 1
	_check("the title slam stops every scene tween before freeing the scene (%d left running)" % survivors, survivors == 0)
	cs.queue_free()
	await process_frame
