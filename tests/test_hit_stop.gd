extends SceneTree
## Round 3 (2026-11-16): the death freeze must never leave the game slowed down. The first version restored the
## time scale from a coroutine on the level; a level freed inside the freeze left the game at 3% speed for good
## (the frozen "second Trevor"). HitStop lives on the root and restores by real time.
## Headless runs skip freezes in the game, so this drives HitStop's own clock directly.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var hs := HitStop.new()
	hs.name = "HitStop"
	root.add_child(hs)
	await process_frame
	hs._start(0.05)
	_check("a freeze slows the game", is_equal_approx(Engine.time_scale, HitStop.SLOW))
	# the node that asked for it disappears at once: the freeze must still end
	var level := Node2D.new()
	root.add_child(level)
	level.queue_free()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await process_frame
	_check("the freeze ends by itself in real time (scale %.2f)" % Engine.time_scale, is_equal_approx(Engine.time_scale, 1.0))
	# overlapping freezes extend, never stack into a permanent slow
	hs._start(0.05)
	hs._start(0.03)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await process_frame
	_check("overlapping freezes still end at full speed", is_equal_approx(Engine.time_scale, 1.0))
	# the safety net used by every level load
	hs._start(10.0)
	HitStop.clear(self)
	_check("a level load clears any freeze at once", is_equal_approx(Engine.time_scale, 1.0) and not HitStop.active(self))
	# control: without the root node nothing restores, which is why it must live on the root
	Engine.time_scale = 1.0
	print("[test_hit_stop] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
