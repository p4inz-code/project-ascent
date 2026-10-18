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

	# A second skip call and a skip after finish must be harmless.
	var s2 := _spawn(20.0)
	s2.skip()
	s2.skip()
	for _i in 120:
		await process_frame
	_check("double skip is harmless", not is_instance_valid(s2))

	print("[test_cutscene] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
