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
	await _cinematic_and_choices()
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
		_check("%d cores: the three choices are available" % pair[0],
			e._button.visible and e._home.visible and e._reset.visible and e.options_visible())
		if pair[0] >= 100:
			_check("the gate is open at 100", e._opened >= 1.0)
		else:
			_check("the gate stays closed below 100", e._opened == 0.0)
		var closed := [false]
		e.closed.connect(func(): closed[0] = true)
		e.close()
		await physics_frame
		_check("CONTINUE closes it", closed[0])


## The cinematic ending (100 cores) and the three choices.
func _cinematic_and_choices() -> void:
	var e := EndingScreen.new()
	e.total = 100
	root.add_child(e)
	await physics_frame
	_check("100 cores is the cinematic", e.is_cinematic())
	_check("it runs about ten seconds before the choices", EndingScreen.T_OPTIONS >= 10.0 and EndingScreen.T_OPTIONS <= 12.0)
	_check("choices are hidden while it plays", not e.options_visible())
	_check("it has PIP lines", e.cinematic_lines().size() >= 3)
	var ordered := true
	var last := -1.0
	for l in e.cinematic_lines():
		ordered = ordered and float(l[0]) > last
		last = float(l[0])
	_check("the lines are in time order", ordered)
	# Drive the timeline directly.
	e._time = 3.5
	e._step_cinematic()
	_check("mid-way the gate is opening", e._opened > 0.0 and e._opened < 1.0)
	e._time = 6.0
	e._step_cinematic()
	_check("Trevor walks in during the middle", e._trevor != null and e._trevor.visible)
	_check("and PIP is speaking", e._line.text != "")
	e._time = EndingScreen.T_OPTIONS + 0.1
	e._step_cinematic()
	_check("the choices appear at the end", e.options_visible())
	_check("Trevor has gone", e._trevor == null or not e._trevor.visible)
	e.queue_free()
	await physics_frame

	# A key press skips to the choices.
	var k := EndingScreen.new()
	k.total = 100
	root.add_child(k)
	await physics_frame
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	k._input(ev)
	_check("any key skips to the choices", k.options_visible())
	_check("with the gate fully open", k._opened >= 1.0)

	# HOME asks the game to go home and leaves without CONTINUE.
	var got_home := [false]
	var got_closed := [false]
	k.home_requested.connect(func(): got_home[0] = true)
	k.closed.connect(func(): got_closed[0] = true)
	k._home.pressed.emit()
	await physics_frame
	_check("HOME SCREEN requests home", got_home[0])
	_check("and does not play the coming-soon card", not got_closed[0])

	# RESET needs a confirmation, and no cancels it.
	var r := EndingScreen.new()
	r.total = 100
	r.skip_animation = true
	root.add_child(r)
	await physics_frame
	var reset_asked := [false]
	r.reset_requested.connect(func(): reset_asked[0] = true)
	r._reset.pressed.emit()
	_check("RESET PROGRESS asks first, does not erase", r._confirm.visible and not reset_asked[0])
	_check("the other choices step aside while asking", not r._button.visible and not r._home.visible)
	r._confirm.get_node("ConfirmNo").pressed.emit()
	_check("NO goes back to the three choices", r._button.visible and r._home.visible and r._reset.visible and not r._confirm.visible)
	_check("and nothing was erased", not reset_asked[0])
	r._reset.pressed.emit()
	r._confirm.get_node("ConfirmYes").pressed.emit()
	await physics_frame
	_check("YES, ERASE requests the reset", reset_asked[0])

	# CONTINUE closes (and in the game, plays the coming-soon card).
	var c := EndingScreen.new()
	c.total = 100
	c.skip_animation = true
	root.add_child(c)
	await physics_frame
	var cont := [false]
	c.closed.connect(func(): cont[0] = true)
	c._button.pressed.emit()
	await physics_frame
	_check("CONTINUE closes", cont[0])
