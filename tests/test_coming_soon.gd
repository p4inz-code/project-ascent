extends SceneTree
## The "next part coming soon" card after the ending: plays on its own, one press
## skips to the title card, a second closes it, and it follows the ending screen.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	await _card()
	await _chain()
	print("[test_coming_soon] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _card() -> void:
	var c := ComingSoon.new()
	root.add_child(c)
	await _step(3)
	_check("it opens on the first beat", c.caption_at(1.0) == "WE MADE IT TO THE TOP, TREVOR.")
	_check("the second beat reveals the tower goes on", "DOES NOT END" in c.caption_at(6.0))
	_check("the card has no caption (the title speaks)", c.caption_at(11.0) == "")
	_check("the title card is not showing yet", not c.in_card() and c._title.modulate.a == 0.0)
	c.time = 6.0
	c._apply()
	_check("mid-sequence the caption is visible", c._line.modulate.a > 0.5)
	var closed := [false]
	c.closed.connect(func(): closed[0] = true)
	c.press()
	_check("one press skips to the title card", c.time >= ComingSoon.BEATS[3])
	await _step(2)
	_check("the card shows COMING SOON", c._soon.modulate.a > 0.9 and c._title.modulate.a > 0.9)
	_check("and it has not closed itself", not closed[0])
	c.press()
	await _step(2)
	_check("a press on the card closes it", closed[0])

	var d := ComingSoon.new()
	d.skip_animation = true
	root.add_child(d)
	await _step(3)
	_check("skip_animation lands straight on the card", d._soon.modulate.a > 0.9)
	d.queue_free()
	await _step(2)


## Closing the ending screen opens the card (what game_scene wires up).
func _chain() -> void:
	var gs: Node = root.get_node("GameSettings")
	gs.intro_seen = true
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await _step(30)
	var gm: Node = root.get_node("GameManager")
	scene.call("_show_ending")
	await create_timer(1.9).timeout
	var e: EndingScreen = scene.get_node_or_null("EndingScreen")
	_check("the ending screen appears first", e != null)
	if e != null:
		e.skip_animation = true
		e.close()
		await _step(3)
		_check("closing it opens the coming-soon card", scene.get_node_or_null("ComingSoon") != null)
	scene.queue_free()
	await _step(2)
