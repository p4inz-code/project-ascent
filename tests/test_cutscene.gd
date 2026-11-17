extends SceneTree
## The opening cutscene (docs/design/STORYBOARD.md): all eight scenes play in
## order, it finishes, and it can be skipped from EVERY scene without leaving a
## stuck tween or a leaked node. Driven with a speed-up so 45 s runs in a couple
## of seconds; behaviour is otherwise identical.

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _spawn(spd: float) -> Cutscene:
	var cs := Cutscene.new()
	cs.speed = spd
	root.add_child(cs)
	return cs


func _run() -> void:
	# Full play-through, scenes in order.
	var seen: Array[int] = []
	var done := [false]
	var cs := _spawn(20.0)
	cs.scene_changed.connect(func(i): seen.append(i))
	cs.finished.connect(func(): done[0] = true)
	var frames := 0
	while not done[0] and frames < 900:
		await process_frame
		frames += 1
	_check("plays all eight scenes in order %s" % [seen], seen == [0, 1, 2, 3, 4, 5, 6, 7])
	_check("finishes on its own (%d frames)" % frames, done[0])
	await process_frame
	_check("frees itself when finished", not is_instance_valid(cs))

	# Skip from each scene.
	for target in range(8):
		var d := [false]
		var s := _spawn(20.0)
		s.finished.connect(func(): d[0] = true)
		var guard := 0
		while s.scene_index() < target and guard < 800:
			await process_frame
			guard += 1
		_check("reached scene %d before skipping" % (target + 1), s.scene_index() >= target)
		s.skip()
		guard = 0
		while not d[0] and guard < 300:
			await process_frame
			guard += 1
		_check("skip from scene %d finishes cleanly" % (target + 1), d[0])
		await process_frame
		_check("skip from scene %d leaves no node behind" % (target + 1), not is_instance_valid(s))

	# A key still held from the button that started the film must not skip it.
	var held_done := [false]
	Input.action_press("ui_accept", 1.0)
	var hs := _spawn(1.0)
	hs.finished.connect(func(): held_done[0] = true)
	for _i in 40:
		await process_frame
	_check("a key held from the start does not skip the film", not held_done[0] and hs.scene_index() >= 0 and not hs._skipping)
	Input.action_release("ui_accept")
	await process_frame
	await process_frame
	_check("once released, the film is armed", hs._armed)
	Input.action_press("ui_accept", 1.0)
	for _i in 60:
		await process_frame
		if hs._skipping:
			break
	_check("a fresh hold then skips it", hs._skipping)
	Input.action_release("ui_accept")
	await create_timer(3.0, true, false, true).timeout       # the title slam takes ~1.5 s of real time
	_check("and it finishes after the title slam", held_done[0])
	# Every way of saying "skip" works: back, pause (START on a pad), Escape.
	for act in ["ui_cancel", "pause"]:
		var sk := _spawn(1.0)
		for _i in 3:
			await process_frame
		Input.action_press(act, 1.0)
		var seen_skip := false
		for _i in 80:
			await process_frame
			if sk._skipping:
				seen_skip = true
				break
		Input.action_release(act)
		_check("holding %s skips" % act, seen_skip)
		sk.skip()
		await create_timer(2.0, true, false, true).timeout
	# Flashes and shakes respect Reduce Motion.
	var gs: Node = root.get_node("GameSettings")
	gs.death_flash = true
	gs.screen_shake = true
	var f1 := _spawn(1.0)
	_check("flash is full strength by default", is_equal_approx(f1._flash_strength(), 1.0) and f1._shake_allowed())
	gs.death_flash = false
	gs.screen_shake = false
	_check("with the death flash off the flash is a faint wash (%.2f)" % f1._flash_strength(), f1._flash_strength() < 0.3)
	_check("with screen shake off the film does not shake", not f1._shake_allowed())
	f1._do_flash()
	_check("the flash it draws is faint", f1._flash.modulate.a < 0.3)
	f1.skip()
	await create_timer(2.0, true, false, true).timeout
	gs.death_flash = true
	gs.screen_shake = true

	# A second skip call and a skip after finish must be harmless.
	var s2 := _spawn(20.0)
	s2.skip()
	s2.skip()
	for _i in 120:
		await process_frame
	_check("double skip is harmless", not is_instance_valid(s2))

	print("[test_cutscene] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
