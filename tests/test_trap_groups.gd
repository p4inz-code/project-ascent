extends SceneTree
## Random traps that are always passable.
##
## Three layers, from cheap to real:
##   1. the arming logic: exactly K of N, uniform, re-rolled, exhaustive subsets;
##   2. the construction rules (TrapGroup.problems) with negative controls;
##   3. the REAL controller: one fixed "jump before every slot" policy clears the
##      all-armed worst case and every K-subset of it, while a player who never
##      jumps dies. (A jump over an unarmed slot is harmless, so the all-armed
##      proof covers every subset; the sweep below checks that claim directly.)
## Plus: telegraphing (spikes only rise on approach), inert unarmed slots, and the
## per-attempt re-roll hook in the level controller.

var _failures: int = 0
var _hits: int = 0
var _player: Player

const PITCH := TrapGroup.MIN_PITCH
const GROUND_TOP := 400.0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_logic()
	_construction()
	_levels()
	await _telegraph_and_inert()
	await _passability()
	await _level_reroll()
	print("[test_trap_groups] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


# ── 1. arming logic ─────────────────────────────────────────────────

func _logic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var always_k := true
	var in_range := true
	var seen := {}
	for _i in 600:
		var s := TrapGroup.pick_subset(4, 2, rng)
		always_k = always_k and s.size() == 2 and s[0] != s[1]
		for v in s:
			in_range = in_range and v >= 0 and v < 4
		seen[str(s)] = seen.get(str(s), 0) + 1
	_check("pick_subset always returns exactly K distinct indices", always_k)
	_check("indices stay in range", in_range)
	_check("every one of the C(4,2)=6 subsets occurs", seen.size() == 6)
	var even := true
	for k in seen:
		even = even and seen[k] > 60   # expected 100 each
	_check("and none is starved (roughly uniform)", even)

	_check("all_subsets(5,2) enumerates C(5,2)=10", TrapGroup.all_subsets(5, 2).size() == 10)
	_check("all_subsets(5,5) is the single full set", TrapGroup.all_subsets(5, 5).size() == 1)
	_check("all_subsets(4,0) is just the empty set", TrapGroup.all_subsets(4, 0).size() == 1)
	_check("all_subsets refuses more than MAX_SLOTS", TrapGroup.all_subsets(TrapGroup.MAX_SLOTS + 1, 2).is_empty())
	var distinct := {}
	for s in TrapGroup.all_subsets(5, 3):
		distinct[str(s)] = true
	_check("enumerated subsets are all distinct", distinct.size() == 10)


# ── 2. construction rules ───────────────────────────────────────────

func _slot_row(n: int, pitch: float, x0: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		out.append(Vector2(x0 + pitch * float(i), GROUND_TOP))
	return out


func _construction() -> void:
	var platform := Rect2(0.0, GROUND_TOP, 3000.0, 60.0)
	var plat: Array[Rect2] = [platform]
	var ok := _slot_row(4, PITCH, 400.0)
	_check("a well-spaced group on a wide platform is valid", TrapGroup.problems(ok, 2, plat).is_empty())
	_check("too close together is rejected", not TrapGroup.problems(_slot_row(3, PITCH - 40.0, 400.0), 1, plat).is_empty())
	_check("no run-up before the first slot is rejected", not TrapGroup.problems(_slot_row(3, PITCH, 60.0), 1, plat).is_empty())
	_check("no landing room after the last slot is rejected",
		not TrapGroup.problems(_slot_row(3, PITCH, 3000.0 - 2.0 * PITCH - 40.0), 1, plat).is_empty())
	_check("arming every slot is allowed", TrapGroup.problems(ok, 4, plat).is_empty())
	_check("arming zero slots is rejected", not TrapGroup.problems(ok, 0, plat).is_empty())
	_check("arming more than exist is rejected", not TrapGroup.problems(ok, 9, plat).is_empty())
	_check("more than MAX_SLOTS is rejected", not TrapGroup.problems(_slot_row(TrapGroup.MAX_SLOTS + 1, PITCH, 300.0), 1, plat).is_empty())
	var wrong_height := _slot_row(2, PITCH, 400.0)
	wrong_height[1].y = GROUND_TOP - 50.0
	_check("a slot floating off the surface is rejected", not TrapGroup.problems(wrong_height, 1, plat).is_empty())
	_check("an empty group is rejected", not TrapGroup.problems([] as Array[Vector2], 1, plat).is_empty())


## Every authored group in the real levels must satisfy the rules.
func _levels() -> void:
	var total := 0
	var bad := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var lv := LevelData.get_level(n)
		var rects: Array[Rect2] = []
		for p in lv.platforms:
			rects.append(Rect2(p.position - p.size * 0.5, p.size))
		for g in lv.trap_groups:
			total += 1
			# Surface y of the host platform is its top edge.
			var probs := TrapGroup.problems(g.positions, g.arm_count, rects)
			if not probs.is_empty():
				bad += 1
				print("  L%d: %s" % [n, "; ".join(probs)])
	_check("every authored trap group is valid (%d groups)" % total, bad == 0)


# ── 3. real controller ──────────────────────────────────────────────

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


func _arena(n: int, armed: Array) -> Dictionary:
	var ground := _solid(Vector2(2500, GROUND_TOP + 30.0), Vector2(5600, 60))
	var group := TrapGroup.new()
	root.add_child(group)
	group.setup(_slot_row(n, PITCH, 600.0), n)
	group.armed_indices = [] as Array[int]
	for i in group.slots.size():
		group.slots[i].armed = i in armed
		if i in armed:
			group.armed_indices.append(i)
	_hits = 0
	group.slot_hit.connect(func(): _hits += 1)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	_player.global_position = Vector2(200, GROUND_TOP - 30.0)
	return {"ground": ground, "group": group}


func _teardown(a: Dictionary) -> void:
	for a_ in ["move_right", "jump", "dash", "slide"]:
		Input.action_release(a_)
	_player.queue_free()
	a["group"].queue_free()
	a["ground"].queue_free()
	await _step(2)


## The fixed policy: hold right, and jump when the player is `lead` px before the
## slot's left edge. Returns true if the player reached past the last slot alive.
func _run_policy(a: Dictionary, lead: float, jump_over: bool) -> bool:
	var group: TrapGroup = a["group"]
	var last_x: float = group.slots[group.slots.size() - 1].global_position.x + 260.0
	Input.action_press("move_right", 1.0)
	var next := 0
	var hold := 0
	for _f in 900:
		await physics_frame
		# Hold jump through the whole rise: an early release trims it to a hop.
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("jump")
		if _hits > 0:
			if OS.get_cmdline_user_args().has("debug"):
				print("   died at x=%d y=%d vx=%d lead=%d next=%d" % [_player.global_position.x, _player.global_position.y, _player.velocity.x, lead, next])
			return false
		if jump_over and next < group.slots.size():
			var edge: float = group.slots[next].global_position.x - TrapSlot.WIDTH * 0.5 - lead
			if _player.global_position.x >= edge and _player.is_on_floor():
				Input.action_press("jump", 1.0)
				hold = 24
				next += 1
		if _player.global_position.x > last_x:
			return true
	return false


func _telegraph_and_inert() -> void:
	var a := await _arena(3, [1])
	await _step(10)
	var far_armed: TrapSlot = a["group"].slots[1]
	_check("an armed slot is flat while the player is far away", far_armed.raised() < 0.05)
	_player.global_position = Vector2(far_armed.global_position.x - 300.0, GROUND_TOP - 30.0)
	await _step(30)
	_check("an armed slot rises as the player approaches", far_armed.raised() > 0.95)
	var unarmed: TrapSlot = a["group"].slots[0]
	_player.global_position = Vector2(unarmed.global_position.x - 100.0, GROUND_TOP - 30.0)
	await _step(30)
	_check("an unarmed slot never rises, however close", unarmed.raised() < 0.01)
	_check("walking over an unarmed slot is harmless", _hits == 0)
	await _teardown(a)

	# Negative control: someone who never jumps dies on an armed slot.
	var b := await _arena(3, [0, 1, 2])
	var survived := await _run_policy(b, 90.0, false)
	_check("negative control: never jumping dies on armed spikes", not survived and _hits > 0)
	await _teardown(b)


func _passability() -> void:
	# Find the lead that clears the worst case (all slots armed) with the real controller.
	var lead := 0.0
	var found := false
	for candidate in [60.0, 80.0, 100.0, 120.0, 140.0, 160.0]:
		var a := await _arena(TrapGroup.MAX_SLOTS, range(TrapGroup.MAX_SLOTS))
		var ok := await _run_policy(a, candidate, true)
		await _teardown(a)
		if ok:
			lead = candidate
			found = true
			break
	_check("the all-armed worst case is clearable with one fixed jump policy", found)
	if not found:
		return

	# Every K-subset (every K) of the full group, same policy, must pass.
	var checked := 0
	var failed := 0
	for k in range(1, TrapGroup.MAX_SLOTS + 1):
		for subset in TrapGroup.all_subsets(TrapGroup.MAX_SLOTS, k):
			var a := await _arena(TrapGroup.MAX_SLOTS, subset)
			var ok := await _run_policy(a, lead, true)
			await _teardown(a)
			checked += 1
			if not ok:
				failed += 1
				print("  failed subset ", subset)
	_check("every one of the %d armed subsets is passable (lead %d)" % [checked, int(lead)], failed == 0)
	_check("all 2^5-1 = 31 non-empty subsets were exercised", checked == 31)


# ── 4. per-attempt re-roll in the level controller ──────────────────

func _level_reroll() -> void:
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	root.add_child(scene)
	await _step(4)
	var group := TrapGroup.new()
	scene.get_node("Hazards").add_child(group)
	group.setup(_slot_row(4, PITCH, 400.0), 2)
	var groups: Array[TrapGroup] = [group]
	scene.set("_trap_groups", groups)
	var seen := {}
	var always_two := true
	for _i in 24:
		scene.call("_respawn", MainScene.RespawnCause.MANUAL)
		await physics_frame
		seen[str(group.armed_indices)] = true
		always_two = always_two and group.armed_indices.size() == 2
	_check("each attempt arms exactly K slots", always_two)
	_check("different attempts arm different subsets (%d seen)" % seen.size(), seen.size() >= 3)
	scene.queue_free()
	await _step(2)
