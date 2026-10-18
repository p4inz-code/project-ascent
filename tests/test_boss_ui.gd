extends SceneTree
## Boss warning UX and the chase NPCs: the alarm banner, the off-screen pursuer
## arrows with distances, the closing-in glow, and the animated Warden and Sparks.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_edge_math()
	await _indicator()
	await _warning()
	await _npcs()
	print("[test_boss_ui] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _edge_math() -> void:
	var rect := Rect2(0, 0, 1000, 600)
	var on := ChaseIndicator.edge_point(Vector2(500, 300), rect)
	_check("a point on screen is reported on screen", bool(on["on_screen"]))
	var right := ChaseIndicator.edge_point(Vector2(2000, 300), rect)
	_check("a point far right pins to the right edge", not bool(right["on_screen"])
		and is_equal_approx(right["pos"].x, 1000.0 - ChaseIndicator.MARGIN) and is_equal_approx(right["pos"].y, 300.0))
	_check("and the arrow points right", absf(float(right["angle"])) < 0.01)
	var left := ChaseIndicator.edge_point(Vector2(-900, 300), rect)
	_check("a point far left pins to the left edge", is_equal_approx(left["pos"].x, ChaseIndicator.MARGIN)
		and absf(absf(float(left["angle"])) - PI) < 0.01)
	var above := ChaseIndicator.edge_point(Vector2(500, -700), rect)
	_check("a point far above pins to the top edge", is_equal_approx(above["pos"].y, ChaseIndicator.MARGIN))
	var diag := ChaseIndicator.edge_point(Vector2(3000, 2000), rect)
	var inner := rect.grow(-ChaseIndicator.MARGIN)
	_check("a diagonal point lands inside the margin box",
		inner.grow(1.0).has_point(diag["pos"]))
	var always_inside := true
	for i in 36:
		var p := rect.get_center() + Vector2.from_angle(TAU * float(i) / 36.0) * 5000.0
		var e := ChaseIndicator.edge_point(p, rect)
		always_inside = always_inside and inner.grow(1.0).has_point(e["pos"])
	_check("every direction gives an on-screen arrow position", always_inside)
	_check("danger is 0 when far", ChaseIndicator.danger_at(2000.0) == 0.0)
	_check("danger is 1 when on top of the player", ChaseIndicator.danger_at(50.0) == 1.0)
	_check("danger grows as it closes in",
		ChaseIndicator.danger_at(600.0) < ChaseIndicator.danger_at(400.0) and ChaseIndicator.danger_at(400.0) < ChaseIndicator.danger_at(250.0))


func _indicator() -> void:
	var ind := ChaseIndicator.new()
	root.add_child(ind)
	await _step(2)
	var a := Node2D.new()
	a.position = Vector2(5000, 300)
	root.add_child(a)
	var b := Node2D.new()
	b.position = Vector2(-4000, 300)
	root.add_child(b)
	ind.targets = [a, b] as Array[Node2D]
	var rect := Rect2(0, 0, 1000, 600)
	ind.refresh(Vector2(500, 300), rect, Transform2D.IDENTITY)
	_check("inactive: no arrows", ind.arrow_count() == 0)
	# Pursuers arriving together share one arrow with a count.
	var c := Node2D.new()
	c.position = Vector2(5020, 310)
	root.add_child(c)
	ind.targets = [a, b, c] as Array[Node2D]
	ind.active = true
	ind.refresh(Vector2(500, 300), rect, Transform2D.IDENTITY)
	_check("two pursuers on the same edge merge into one arrow (3 targets, 2 arrows)", ind.arrow_count() == 2)
	_check("and the merged arrow counts them", int(ind._arrows[0]["count"]) + int(ind._arrows[1]["count"]) == 3)
	ind.targets = [a, b] as Array[Node2D]
	c.free()
	ind.active = false
	ind.active = true
	ind.refresh(Vector2(500, 300), rect, Transform2D.IDENTITY)
	_check("active with two off-screen pursuers: two arrows", ind.arrow_count() == 2)
	_check("the nearest distance is reported", is_equal_approx(ind.nearest_distance(), 4500.0))
	a.position = Vector2(600, 300)
	ind.refresh(Vector2(500, 300), rect, Transform2D.IDENTITY)
	_check("a pursuer that is on screen gets no arrow", ind.arrow_count() == 1)
	_check("but still drives the closing-in glow", ind._glow.modulate.a >= 0.0 and ind.nearest_distance() <= 100.0)
	ind.active = false
	ind.refresh(Vector2(500, 300), rect, Transform2D.IDENTITY)
	_check("switching off clears everything", ind.arrow_count() == 0 and ind._glow.modulate.a == 0.0)
	a.free()
	b.free()
	ind.queue_free()
	await _step(2)


func _warning() -> void:
	var w := BossWarning.new()
	w.skip_animation = true
	root.add_child(w)
	await _step(3)
	_check("the banner is fully in at the hold", w.slide_at(1.0) == 1.0)
	_check("and off-screen at the start and the end", is_zero_approx(w.slide_at(0.0)) and absf(w.slide_at(w.total_time())) < 0.001)
	_check("it lasts a few seconds, not a blink", w.total_time() > 2.0 and w.total_time() < 4.0)
	_check("it says WARNING", w._title.text == "WARNING")
	_check("it names the threat and tells the player what to do",
		w._sub.text.length() > 5 and w._hint.text.contains("KEEP MOVING"))
	w.queue_free()
	await _step(2)

	# A running one finishes and frees itself.
	var live := BossWarning.new()
	root.add_child(live)
	var done := [false]
	live.finished.connect(func(): done[0] = true)
	for _i in 200:
		await physics_frame
		if done[0]:
			break
		live.time += 0.02
	if is_instance_valid(live) and not done[0]:
		live.time = live.total_time() + 0.1
		await _step(3)
	_check("a running warning finishes on its own", done[0])

	# The boss shows it only when Boss warnings is on.
	var gs: Node = root.get_node("GameSettings")
	var boss := BossEntity.new()
	root.add_child(boss)
	await _step(2)
	gs.boss_warnings = true
	boss._show_warning()
	_check("with warnings on, the boss raises the banner", boss.get_node_or_null("BossWarning") != null)
	boss._hide_warning()
	await _step(2)
	_check("hiding removes it", boss.get_node_or_null("BossWarning") == null)
	gs.boss_warnings = false
	boss._show_warning()
	_check("with warnings off, no banner", boss.get_node_or_null("BossWarning") == null)
	gs.boss_warnings = true
	boss.queue_free()
	await _step(2)


func _npcs() -> void:
	var boss := BossEntity.new()
	root.add_child(boss)
	await _step(3)
	var ws: AnimatedSprite2D = boss.get_node_or_null("WardenSprite")
	_check("the boss is an animated sprite", ws != null and ws.sprite_frames.get_frame_count("idle") == 4)
	_check("it animates", ws != null and ws.is_playing())
	_check("the old flat polygon is hidden", not boss._boss_body.visible)
	_check("the sprite uses a whole-number scale", ws != null and is_equal_approx(ws.scale.x, round(ws.scale.x)))
	boss.queue_free()
	var m := MinionEntity.new()
	root.add_child(m)
	await _step(3)
	var ss: AnimatedSprite2D = m.get_node_or_null("SparkSprite")
	_check("minions are animated sprites too", ss != null and ss.sprite_frames.get_frame_count("idle") == 4)
	_check("their flat polygon is hidden", not m._minion_body.visible)
	m.queue_free()
	await _step(2)
