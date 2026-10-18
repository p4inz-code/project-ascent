extends SceneTree
## The end-of-campaign screen: 100 cores opens the gate, 90-99 is "so close",
## less is "needs 100". The dev core command is session-only and never saved.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_results()
	_dev_bonus()
	await _screen()
	print("[test_ending] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _results() -> void:
	_check("100 opens the gate", EndingScreen.result_for(100, 100) == EndingScreen.Result.OPEN)
	_check("more than 100 also opens", EndingScreen.result_for(140, 100) == EndingScreen.Result.OPEN)
	_check("99 is 'so close'", EndingScreen.result_for(99, 100) == EndingScreen.Result.CLOSE)
	_check("90 is still 'so close'", EndingScreen.result_for(90, 100) == EndingScreen.Result.CLOSE)
	_check("89 is shut", EndingScreen.result_for(89, 100) == EndingScreen.Result.SHUT)
	_check("zero is shut", EndingScreen.result_for(0, 100) == EndingScreen.Result.SHUT)


func _dev_bonus() -> void:
	var save := SaveSystem.new()
	save.collect_orb(5, 0)
	save.collect_orb(6, 0)
	_check("real total is 2", save.orb_total() == 2)
	save.dev_set_orb_total(99)
	_check("dev command makes the total exactly 99", save.orb_total() == 99)
	save.dev_set_orb_total(100)
	_check("and exactly 100", save.orb_total() == 100)
	_check("the bonus is not written to the save file", not JSON.stringify(save.to_dict() if save.has_method("to_dict") else {}).contains("dev_orb"))
	_check("remaining reads 0 at 100", save.orbs_remaining() == 0)
	save.dev_set_orb_total(1)
	_check("it never lowers real orbs below what was collected", save.orb_total() == 2)


func _screen() -> void:
	for pair in [[100, "THE GATE OPENS"], [99, "ONE CORE SHORT"], [95, "5 CORES SHORT"], [21, "THE GATE STAYS SHUT"]]:
		var e := EndingScreen.new()
		e.total = pair[0]
		e.skip_animation = true
		root.add_child(e)
		await physics_frame
		_check("%d cores -> '%s'" % [pair[0], pair[1]], e._headline.text == pair[1])
		_check("%d cores: counter reads %d / 100" % [pair[0], pair[0]], e._counter.text == "%d / 100 CORES" % pair[0])
		_check("%d cores: CONTINUE is available" % pair[0], e._button.visible)
		if pair[0] >= 100:
			_check("the gate is open at 100", e._opened >= 1.0)
		else:
			_check("the gate stays closed below 100", e._opened == 0.0)
		var closed := [false]
		e.closed.connect(func(): closed[0] = true)
		e.close()
		await physics_frame
		_check("CONTINUE closes it", closed[0])
