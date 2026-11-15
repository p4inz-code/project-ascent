extends SceneTree
## THE TEMPEST (level 20), the long version: three sealed sections and eight rods. The geometry is climbable
## (every step within a jump), nothing from the classic placement pipeline is in the level, every hazard has a
## tell and a safe window, a player who keeps moving is never struck, rods only count a real ground pound, and
## each section's gate opens when its rods are done.

var _failures: int = 0
const T := preload("res://scripts/tempest_director.gd")


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var def := LevelData.get_level(20)
	_check("level 20 is the tempest, scripted, with no chasers", def.tempest and def.scripted and not def.boss_config.enabled)
	_check("it is long: a 5200 px hall with 8 rods in 3 sections", TempestDirector.HALL_W >= 5000.0 and TempestDirector.RODS.size() == 8 and def.plate_gates.size() == 3)
	_check("(regression) nothing from the classic pipeline: no pipes, timing gates, old storm, checkpoints or special tiles",
		def.pipes.is_empty() and def.gates.is_empty() and not def.storm and def.checkpoints.is_empty() and _all_solid(def))
	# geometry: every climb is a chain of steps no higher than MAX_STEP_RISE
	_check("every stack and the dais can be climbed: no step is more than %d px up" % int(TempestDirector.MAX_STEP_RISE), _climbs_ok())
	_check("(control) a 300 px wall with no steps would fail the climb check", not _chain_ok([0.0, 300.0]))
	# hazards: tells and safe windows
	_check("arc plates: a 1 s tell, and safe for longer than it takes to cross one",
		TempestDirector.ARC_TELL >= 1.0 and (TempestDirector.ARC_PERIOD - TempestDirector.ARC_ACTIVE) > _widest_plate() / 320.0 + 0.5)
	_check("the beam is low enough to jump (48 px against a 96 px jump) and announces itself for a second", TempestDirector.BEAM_H <= 60.0 and TempestDirector.BEAM_TELL >= 1.0)
	_check("the beam function: charging gives no beam, then it travels right to left",
		is_nan(TempestDirector.beam_x(0.5, 0.0)) and TempestDirector.beam_x(1.2, 0.0) > TempestDirector.beam_x(2.2, 0.0))
	_check("arc function: live only in the last %.1f s of the period" % TempestDirector.ARC_ACTIVE,
		not TempestDirector.arc_active(0.5, 0.0) and TempestDirector.arc_active(TempestDirector.ARC_PERIOD - 0.2, 0.0) and TempestDirector.arc_telling(TempestDirector.ARC_PERIOD - TempestDirector.ARC_ACTIVE - 0.5, 0.0))
	_check("lightning gets faster section by section but the tell stays 1.25 s", TempestDirector.STRIKE_EVERY[0] > TempestDirector.STRIKE_EVERY[1] and TempestDirector.STRIKE_EVERY[1] > TempestDirector.STRIKE_EVERY[2] and TempestDirector.TELL >= 1.25)
	_check("every core spot is within a jump of something to stand on", _cores_reachable())
	await physics_frame
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 20)
	root.add_child(main)
	for i in 6:
		await physics_frame
	var tempest := main.get_node_or_null("Tempest") as TempestDirector
	_check("the director is built", tempest != null)
	if tempest == null:
		quit(1)
		return
	var stray := 0
	for c in main.get_node("Hazards").get_children():
		if c is PipeTube or c is StormDirector or c is CheckpointFlag or c is TimedGate:
			stray += 1
	_check("(regression) the real level has no pipe, old storm, flag or timing gate nodes (%d)" % stray, stray == 0)
	var cores := 0
	for c in tempest.get_children():
		if c is Orb:
			cores += 1
	_check("three moving cores are placed (%d)" % cores, cores == 3)
	var player := main.get_node("Player") as Player
	player.set_physics_process(false)
	# a player who keeps moving on the floor of section A is never struck by lightning
	tempest.reset()
	var x := 300.0
	var dir := 1.0
	for i in 600:
		# always the same way (a turn-around walks you back onto your own mark, which is the one way to be hit)
		x += dir * 200.0 / 60.0
		if x > 1400.0:
			x = 300.0
		player.global_position = Vector2(x, TempestDirector.FLOOR_Y - 30.0)
		await physics_frame
	_check("a player who keeps moving is never struck (%d strikes fell, %d chips)" % [tempest.strikes_fired, tempest.chips], tempest.chips == 0 and tempest.strikes_fired > 3)
	tempest.reset()
	player.global_position = Vector2(400.0, TempestDirector.FLOOR_Y - 30.0)
	for i in 420:
		await physics_frame
	_check("(control) a player who stands still is struck (%d chips)" % tempest.chips, tempest.chips >= 1)
	# standing on a live arc plate is a chip; standing on a step beside it is not
	tempest.reset()
	tempest._since_strike = -1000.0
	var plate: Array = TempestDirector.ARC_PLATES[0]
	tempest._arc_phase[0] = TempestDirector.ARC_PERIOD - TempestDirector.ARC_ACTIVE + 0.1 - tempest._t
	tempest._t = TempestDirector.GRACE + 0.01
	tempest._arc_phase[0] = TempestDirector.ARC_PERIOD - TempestDirector.ARC_ACTIVE + 0.1 - tempest._t
	player.global_position = Vector2((float(plate[0]) + float(plate[1])) * 0.5, TempestDirector.FLOOR_Y - 26.0)
	for i in 4:
		await physics_frame
	_check("standing on a live arc plate costs a chip (%d)" % tempest.chips, tempest.chips >= 1)
	var before := tempest.chips
	player.global_position = Vector2(2110.0, TempestDirector.FLOOR_Y - 76.0 - 26.0)
	tempest._since_strike = -1000.0
	for i in 4:
		await physics_frame
	_check("(control) standing on the step beside it does not (%d -> %d)" % [before, tempest.chips], tempest.chips == before)
	# rods: real ground pounds, section by section
	tempest.reset()
	tempest.storm_enabled = false
	player.heal_full()
	player.set_physics_process(true)
	await physics_frame
	var opened: Array = []
	tempest.gate_open.connect(func(id: int) -> void: opened.append(id))
	_pound_at(player, 700.0, TempestDirector.FLOOR_Y - 220.0)
	for i in 40:
		await physics_frame
	_release()
	_check("(control) a pound on the bare floor lights nothing", tempest.rods_done() == 0)
	for r in TempestDirector.RODS.size():
		var rod: Array = TempestDirector.RODS[r]
		_pound_at(player, float(rod[0]), TempestDirector.FLOOR_Y - float(rod[1]) - 200.0)
		for i in 44:
			await physics_frame
		_release()
		for i in 10:
			await physics_frame
		if r == 2:
			_check("after the three rods of section A, gate 1 opens and only gate 1 %s" % str(opened), opened == [1])
	_check("a real ground pound onto each cap lights all eight rods (%s)" % str(tempest.pounded), tempest.rods_done() == 8)
	_check("the three gates opened in order %s" % str(opened), opened == [1, 2, 3])
	main.queue_free()
	print("[test_tempest] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _all_solid(def) -> bool:
	for p in def.platforms:
		if p.kind != "solid":
			return false
	return true


func _widest_plate() -> float:
	var w := 0.0
	for ap in TempestDirector.ARC_PLATES:
		w = maxf(w, float(ap[1]) - float(ap[0]))
	return w


func _chain_ok(heights: Array) -> bool:
	for i in range(1, heights.size()):
		if float(heights[i]) - float(heights[i - 1]) > TempestDirector.MAX_STEP_RISE:
			return false
	return true


## Every rod cap is reached from the floor by adjacent steps (within 130 px of each other) rising at most MAX_STEP_RISE.
func _climbs_ok() -> bool:
	for rod in TempestDirector.RODS:
		var rx: float = float(rod[0])
		var rh: float = float(rod[1])
		if rh <= TempestDirector.MAX_STEP_RISE:
			continue
		for side in [-1.0, 1.0]:
			# walk outward from the cap (or from the dais edge for the rods that stand on it), nearest step first
			var chain: Array = [rh]
			var edge := rx
			if int(rod[2]) == 2:
				edge = TempestDirector.DAIS.position.x + 55.0 if side < 0.0 else TempestDirector.DAIS.end.x - 55.0
			var guard := 0
			while guard < 8:
				guard += 1
				var best := -1
				for i in TempestDirector.STEPS.size():
					var s: Array = TempestDirector.STEPS[i]
					var d: float = (float(s[0]) - edge) * float(side)
					if d > 20.0 and d < 260.0 and float(s[1]) < float(chain[chain.size() - 1]):
						if best < 0 or d < (float(TempestDirector.STEPS[best][0]) - edge) * float(side):
							best = i
				if best < 0:
					break
				chain.append(float(TempestDirector.STEPS[best][1]))
				edge = float(TempestDirector.STEPS[best][0])
			chain.append(0.0)
			chain.reverse()
			if not _chain_ok(chain):
				print("  climb fails at rod x=%.0f side %.0f: %s" % [rx, side, str(chain)])
				return false
	return true


## A core spot is reachable when some standing surface (floor, step, rod cap, dais) lies within a full jump below it.
func _cores_reachable() -> bool:
	for spot in TempestDirector.CORE_SPOTS:
		var x: float = float(spot[0])
		var h: float = float(spot[1])
		var ok := h <= 122.0 + 21.0      # from the floor: centre apex 122, plus the pickup radius
		for rod in TempestDirector.RODS:
			if absf(float(rod[0]) - x) <= 200.0 and h - float(rod[1]) <= 122.0 + 21.0 and h >= float(rod[1]):
				ok = true
		for s in TempestDirector.STEPS:
			if absf(float(s[0]) - x) <= 200.0 and h - float(s[1]) <= 122.0 + 21.0 and h >= float(s[1]):
				ok = true
		if not ok:
			print("  unreachable core spot %s" % str(spot))
			return false
	return true


func _pound_at(player: Player, x: float, y: float) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	Input.action_press("slide")
	Input.action_press("jump")


func _release() -> void:
	Input.action_release("slide")
	Input.action_release("jump")
