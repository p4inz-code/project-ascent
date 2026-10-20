extends SceneTree
## Timing gates (laser / crusher): the cycle, the fairness rules for where they
## stand, and the real controller crossing a gap with one, waiting for the safe
## window (passes) versus jumping into the active phase (dies).

var _failures: int = 0
var _hits: int = 0
var _player: Player

const GROUND := 400.0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	# These check the classic layouts; machine levels have their own suites (docs/MACHINE_LEVELS.md).
	MachineLevel.suspended = true
	await physics_frame
	_cycle()
	_rules()
	await _crossing(TimedGate.Kind.LASER, "laser")
	await _crossing(TimedGate.Kind.CRUSHER, "crusher")
	await _suspended()
	print("[test_timed_gates] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _cycle() -> void:
	var g := TimedGate.new()
	_check("the default safe window is at least the minimum", g.safe_window() >= TimedGate.MIN_SAFE_WINDOW)
	_check("and more than twice the airtime of a jump (0.72 s)", g.safe_window() > 2.0 * 0.72)
	_check("cycle starts SAFE", g.phase_at(0.0) == TimedGate.Phase.SAFE)
	_check("then warns", g.phase_at(g.safe_time + 0.1) == TimedGate.Phase.WARN)
	_check("then is ACTIVE", g.phase_at(g.safe_time + g.warn_time + 0.1) == TimedGate.Phase.ACTIVE)
	_check("then repeats", g.phase_at(g.period() + 0.1) == TimedGate.Phase.SAFE)
	var active_fraction := g.active_time / g.period()
	_check("it is lethal for well under a quarter of the cycle (%.0f%%)" % (active_fraction * 100.0), active_fraction < 0.25)
	g.phase_offset = 1.0
	_check("a phase offset shifts the cycle",
		g.phase_at(0.0) == TimedGate.Phase.SAFE and g.phase_at(g.safe_time - 0.5) == TimedGate.Phase.WARN)
	g.free()


func _rect(x: float, w: float, y: float = GROUND) -> Rect2:
	return Rect2(x, y, w, 60.0)


func _rules() -> void:
	var plats: Array[Rect2] = [_rect(0.0, 300.0), _rect(500.0, 300.0)]   # gap 200
	_check("a gate mid-gap is valid", GateRules.problems(Vector2(400.0, GROUND), plats).is_empty())
	_check("a gate hugging a platform edge is rejected", not GateRules.problems(Vector2(320.0, GROUND), plats).is_empty())
	_check("a gate over a platform is rejected", not GateRules.problems(Vector2(150.0, GROUND), plats).is_empty())
	var tight: Array[Rect2] = [_rect(0.0, 300.0), _rect(400.0, 300.0)]   # gap 100
	_check("a gap too narrow is rejected", not GateRules.problems(Vector2(350.0, GROUND), tight).is_empty())
	var wide: Array[Rect2] = [_rect(0.0, 300.0), _rect(700.0, 300.0)]    # gap 400
	_check("a gap too wide is rejected", not GateRules.problems(Vector2(500.0, GROUND), wide).is_empty())
	var steep: Array[Rect2] = [_rect(0.0, 300.0), _rect(500.0, 300.0, GROUND - 200.0)]
	_check("a gap with a big rise is rejected", not GateRules.problems(Vector2(400.0, GROUND - 200.0), steep).is_empty())
	_check("a base below the higher surface is rejected",
		not GateRules.problems(Vector2(400.0, GROUND + 40.0), plats).is_empty())
	var one_sided: Array[Rect2] = [_rect(0.0, 300.0)]
	_check("a gate with no platform ahead is rejected", not GateRules.problems(Vector2(400.0, GROUND), one_sided).is_empty())

	# Every automatically placed gate in the real levels follows the rules.
	var total := 0
	var bad := 0
	var early := 0
	var levels_with := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var lv := LevelData.get_level(n)
		if n < 7 and not lv.gates.is_empty():
			early += 1
		if not lv.gates.is_empty():
			levels_with += 1
		var rects: Array[Rect2] = []
		for p in lv.platforms:
			if String(p.name).contains("Wall") or not GateRules.is_stationary_solid(String(p.kind)):
				continue
			rects.append(Rect2(p.position - p.size * 0.5, p.size))
		for g in lv.gates:
			total += 1
			var probs := GateRules.problems(g[0], rects)
			if not probs.is_empty():
				bad += 1
				print("  L%d gate at %s: %s" % [n, g[0], "; ".join(probs)])
	_check("every placed gate satisfies the rules (%d gates)" % total, bad == 0)
	_check("the early levels (1-6) have no gates", early == 0)
	_check("gates appear in several later levels (%d levels)" % levels_with, levels_with >= 3)
	var deep := 0
	for n in range(16, LevelData.TOTAL_LEVELS + 1):
		deep += LevelData.get_level(n).gates.size()
	_check("the late game has gates (%d)" % deep, deep >= 3)
	var kinds := {}
	for n in range(11, LevelData.TOTAL_LEVELS + 1):
		for g in LevelData.get_level(n).gates:
			kinds[g[1]] = true
	_check("deeper levels mix lasers and crushers", kinds.size() == 2)


# ── real controller ─────────────────────────────────────────────────

func _solid(pos: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	b.add_child(c)
	b.collision_layer = 3
	b.position = pos
	root.add_child(b)
	return b


## Two platforms with a 200 px gap and a gate in the middle. Returns the pieces.
func _arena(kind: int) -> Dictionary:
	var left := _solid(Vector2(150.0, GROUND + 30.0), Vector2(300.0, 60.0))
	var right := _solid(Vector2(650.0, GROUND + 30.0), Vector2(300.0, 60.0))
	var gate := TimedGate.new()
	gate.kind = kind
	gate.position = Vector2(400.0, GROUND)
	root.add_child(gate)
	_hits = 0
	gate.player_hit.connect(func(): _hits += 1)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	_player.global_position = Vector2(120.0, GROUND - 30.0)
	return {"left": left, "right": right, "gate": gate}


func _teardown(a: Dictionary) -> void:
	for act in ["move_right", "jump"]:
		Input.action_release(act)
	_player.queue_free()
	a["left"].queue_free()
	a["right"].queue_free()
	a["gate"].queue_free()
	await _step(2)


## Run right from the left platform and jump near its edge; true if the player
## lands on the right platform alive.
func _run_and_jump() -> bool:
	Input.action_press("move_right", 1.0)
	var hold := 0
	var jumped := false
	for _f in 240:
		await physics_frame
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("jump")
		if _hits > 0:
			return false
		if not jumped and _player.global_position.x >= 300.0 - 25.0 and _player.is_on_floor():
			Input.action_press("jump", 1.0)
			hold = 24
			jumped = true
		if _player.global_position.x > 520.0 and _player.is_on_floor():
			return true
	return false


func _crossing(kind: int, label: String) -> void:
	# Waiting for the safe window, then going: passes.
	var a := await _arena(kind)
	var gate: TimedGate = a["gate"]
	# Start the player's run at the very start of SAFE.
	gate._time = gate.period() - gate.phase_offset
	await physics_frame
	_check("%s: the cycle starts safe" % label, gate.current_phase() == TimedGate.Phase.SAFE)
	var ok := await _run_and_jump()
	_check("%s: crossing during the safe window succeeds" % label, ok and _hits == 0)
	await _teardown(a)

	# Negative control: somewhere in the ACTIVE phase, crossing is lethal. Sweep the
	# moment the run starts relative to the cycle; at least one start must be struck,
	# and every start that begins in the safe window must still pass.
	var struck := 0
	for offset in [0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75]:
		var b := await _arena(kind)
		var gate_b: TimedGate = b["gate"]
		gate_b._time = gate_b.safe_time + gate_b.warn_time - offset
		var survived := await _run_and_jump()
		if not survived and _hits > 0:
			struck += 1
		await _teardown(b)
	_check("%s: negative control: some crossings into the ACTIVE phase are lethal (%d of 7)" % [label, struck], struck >= 1)

	# A player standing in the column when it turns ACTIVE is caught too.
	var c := await _arena(kind)
	var gate_c: TimedGate = c["gate"]
	# For the crusher, stand where the slab slams: mid-air, held at the slam height.
	_player.global_position = Vector2(400.0, GROUND - 30.0)
	gate_c._time = gate_c.safe_time + gate_c.warn_time - 0.1
	if kind == TimedGate.Kind.CRUSHER:
		_player.global_position = Vector2(400.0, TimedGate.SLAM_Y + GROUND - 40.0)
		_player.set_physics_process(false)
	await _step(60)
	_player.set_physics_process(true)
	_check("%s: standing in the column when it activates is lethal" % label, _hits > 0)
	await _teardown(c)


func _suspended() -> void:
	var a := await _arena(TimedGate.Kind.LASER)
	var gate: TimedGate = a["gate"]
	TimedGate.suspended = true
	gate._time = gate.safe_time + gate.warn_time + 0.1
	_check("suspended gates are never lethal", not gate.is_lethal())
	_player.global_position = Vector2(400.0, GROUND - 30.0)
	await _step(40)
	_check("and never hit anyone", _hits == 0)
	TimedGate.suspended = false
	await _teardown(a)
