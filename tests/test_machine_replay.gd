extends SceneTree
## The final link between the proof and the game: the inputs a bot used to clear a piece in the
## SIMULATOR are replayed on the REAL player in the REAL nodes (spikes, flames, jets, pits, belts),
## and the real player must end where the sim says, without a hit.
##
## If the sim were optimistic about a piece, the real player would die or stall here.
## Negative control: the same replay with the jump input removed does not clear.

var _failures: int = 0
const LAG_JUMP := 1


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _boot() -> void:
	await physics_frame
	var cases := [
		["spikes 140", MachineKit.spikes("L", 135.0), null],
		["spikes 170 on a belt with the player", MachineKit.spikes("L", 150.0), MachineKit.belt_of(160.0)],
		["spikes 140 on a belt against the player", MachineKit.spikes("L", 135.0), MachineKit.belt_of(-160.0)],
		["pit 170", MachineKit.pit(170.0), null],
		["hump 70", MachineKit.hump("L", MachineKit.HUMPS[1]), null],
		["flame 200", MachineKit.flame(MachineKit.FLAMES[1], 0.0), null],
		["air jet to the deck", MachineKit.jet(), null],
		["deck gap 150", MachineKit.gap(150.0), null],
		["roof spikes over a gap", MachineKit.rspike(MachineKit.RSPIKE[1]), null],
		["deck spikes 100", MachineKit.spikes("U", 100.0), null],
		["ambush spikes 120", _flag(MachineKit.spikes("L", 120.0), "ambush"), null],
		["pit 170 with a fake tile in it", _flag(MachineKit.pit(170.0), "fake"), null],
		["crusher 110", MachineKit.crusher(MachineKit.CRUSHERS[1], 0.0), null],
		["crusher 130 fast", MachineKit.crusher(MachineKit.CRUSHERS[2], 0.0), null],
		["hail column on the deck", MachineKit.hail(MachineKit.HAILS[1], 0.0), null],
		["spikes 120 on ice", MachineKit.on_surface(MachineKit.spikes("L", 120.0), "ice"), null],
		["pit 140 on ice", MachineKit.on_surface(MachineKit.pit(140.0), "ice"), null],
		["hump on rain-slick", MachineKit.on_surface(MachineKit.hump("L", MachineKit.HUMPS[1]), "slick"), null],
		["spikes 135 on rain-slick", MachineKit.on_surface(MachineKit.spikes("L", 135.0), "slick"), null],
	]
	for c in cases:
		await _replay(String(c[0]), c[1], c[2])
	await _replay("(control) spikes 140 with no jump input", MachineKit.spikes("L", 135.0), null, true)
	print("[test_machine_replay] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _flag(piece: Dictionary, flag: String) -> Dictionary:
	var p := piece.duplicate()
	p[flag] = true
	return p


func _replay(label: String, piece: Dictionary, belt: Variant, drop_jump: bool = false) -> void:
	var spec := MachineProbe.probe_spec(piece, belt)
	var lane: String = String(piece.get("lane", "L"))
	var start_lane := "U" if lane == "U" else "L"
	var route: Array = [start_lane, start_lane, start_lane]
	var events: Array = []
	for e in MachineBot.events_for(spec, route, start_lane):
		if int(e["cell"]) == 1:
			events.append(e)
	var world := MachinePieces.build_world(spec)
	var start_y := (MachinePieces.DECK_Y if start_lane == "U" else MachinePieces.FLOOR_Y) - MachineSim.HALF.y - 0.01
	var goal_x: float = float(spec["end_x"]) - 120.0
	var bot := MachineBot.new(world, events, Vector2(MachineProbe.PROBE_X0 + 140.0, start_y), goal_x, 0.0, null, 0.0)
	bot.record_inputs = true
	var res := bot.run(30.0)
	var sim_ok := bool(res["finished"]) and int(res["hits"]) == 0
	if not drop_jump:
		_check("%s: the sim clears it first" % label, sim_ok)
	var inputs: Array = bot.inputs
	var sim_states: Array = bot.states

	# --- the real world ---
	var holder := Node2D.new()
	root.add_child(holder)
	var hits := [0]
	var kills := [0]
	var rt := MachineRuntime.new()
	holder.add_child(rt)
	rt.setup(5, null, func() -> void: kills[0] += 1, func(_x: float = NAN) -> void: hits[0] += 1)
	rt.build_spec(spec)
	# The start hinge the level normally provides.
	var ground := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(1400.0, 400.0)
	cs.shape = rs
	ground.add_child(cs)
	ground.collision_layer = 3
	ground.position = Vector2(-400.0 + 700.0, MachinePieces.FLOOR_Y + 200.0)
	holder.add_child(ground)
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	holder.add_child(player)
	player.global_position = Vector2(MachineProbe.PROBE_X0 + 140.0, start_y)
	await physics_frame
	await physics_frame
	# Re-zero the flames so their cycle matches the sim's clock, which started at the first input.
	for ch in rt.get_children():
		if ch is FlameJet:
			(ch as FlameJet)._t = 0.0
	player.global_position = Vector2(MachineProbe.PROBE_X0 + 140.0, start_y)
	player.velocity = Vector2.ZERO
	await physics_frame
	for ch in rt.get_children():
		if ch is FlameJet:
			(ch as FlameJet)._t = 0.0
	var prev_jump := false
	var prev_move := 0.0
	var worst := 0.0
	var first_div := -1
	var n := inputs.size()
	for i in n:
		var inp: Array = inputs[i]
		# The real player sees a jump press one frame after it is issued, so issue it one frame early.
		var ahead: Array = inputs[mini(i + LAG_JUMP, n - 1)]
		var mv: float = inp[0]
		var jh: bool = ahead[2]
		if drop_jump:
			jh = false
		if mv != prev_move:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if mv > 0.0:
				Input.action_press("move_right", 1.0)
			elif mv < 0.0:
				Input.action_press("move_left", 1.0)
			prev_move = mv
		if jh and not prev_jump:
			Input.action_press("jump", 1.0)
		elif prev_jump and not jh:
			Input.action_release("jump")
		prev_jump = jh
		await physics_frame
		if i < sim_states.size():
			var dd := player.global_position.distance_to(sim_states[i])
			if dd > 2.0 and first_div < 0:
				first_div = i
				print("  [%s] first divergence > 2 px at frame %d: real %s sim %s floor=%s vel=%s" % [label, i, str(player.global_position), str(sim_states[i]), str(player.is_on_floor()), str(player.velocity)])
			worst = maxf(worst, dd)
	for a in ["move_left", "move_right", "jump"]:
		Input.action_release(a)
	var end_real := player.global_position
	var end_sim: Vector2 = sim_states[sim_states.size() - 1]
	if drop_jump:
		var moved_on: bool = end_real.x > goal_x - 200.0 and kills[0] == 0 and hits[0] == 0
		_check("%s: the real player does NOT clear it (stuck, hit or dead)" % label, not moved_on or hits[0] > 0 or kills[0] > 0)
	else:
		var close := end_real.distance_to(end_sim) <= 14.0
		_check("%s: the real player ends where the sim does (%.1f px apart, worst %.1f along the way)" % [label, end_real.distance_to(end_sim), worst], close)
		_check("%s: and takes no hit and does not die in the real nodes (hits %d, kills %d)" % [label, hits[0], kills[0]], hits[0] == 0 and kills[0] == 0)
	holder.queue_free()
	await physics_frame
