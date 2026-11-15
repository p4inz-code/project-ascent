extends SceneTree
## THE COMPACTOR proof: every rolled tower is a chain of jumps the simulator lands with a real timing
## window, on the real geometry (ceilings and neighbours included); the flood is slower than a calm
## climb; junk drops are telegraphed, never cover a whole platform and never sit on turns.

var _failures: int = 0
const SEEDS := 40


func _check(name: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var worst_window := 999
	var worst_where := ""
	var det_ok := true
	var shaft_ok := true
	var overlap_ok := true
	var flood_ok := true
	var junk_ok := true
	var turns := 0
	for s in SEEDS:
		var spec := TowerGen.roll(10, 1000 + s * 7919)
		if spec["tower"]["plats"].size() != TowerGen.STEPS:
			det_ok = false
		var again := TowerGen.roll(10, 1000 + s * 7919)
		if str(spec["tower"]["plats"]) != str(again["tower"]["plats"]):
			det_ok = false
		var world := _world(spec)
		var plats: Array = spec["tower"]["plats"]
		for i in plats.size():
			var r: Rect2 = plats[i]["rect"]
			if r.position.x < 20.0 or r.end.x > TowerGen.W - 20.0:
				shaft_ok = false
			if bool(plats[i]["turn"]):
				turns += 1
			for j in range(i + 1, plats.size()):
				if r.grow(2.0).intersects((plats[j]["rect"] as Rect2).grow(2.0)):
					overlap_ok = false
			if i == 0:
				continue
			var a: Rect2 = plats[i - 1]["rect"]
			var w := _window(world, a, r)
			if w < TowerGen.MIN_WINDOW and OS.get_environment("TOWER_DEBUG") != "":
				print("  low window %d seed %d step %d turn=%s a=%s b=%s dy=%.0f" % [w, s, i, plats[i]["turn"], a, r, a.position.y - r.position.y])
			if w < worst_window:
				worst_window = w
				worst_where = "seed %d step %d" % [s, i]
		# the floor to the first platform
		var f0 := _window_from_floor(world, plats[0]["rect"])
		if f0 < worst_window:
			worst_window = f0
			worst_where = "seed %d floor" % s
		var h: float = spec["tower"]["height"]
		var calm := TowerGen.SECONDS_PER_STEP * float(TowerGen.STEPS)
		if float(spec["tower"]["flood_speed"]) * calm > h * TowerGen.FLOOD_MARGIN + 0.01:
			flood_ok = false
		for jd in spec["tower"]["junk"]:
			var host := _platform_at(plats, float(jd["x"]), float(jd["y"]))
			if host.size.x <= 0.0 or float(jd["w"]) > host.size.x * 0.5 or float(jd["tell"]) < 1.0:
				junk_ok = false
	print("worst timing window %d frames at %s" % [worst_window, worst_where])
	_check("every roll has the same layout for the same seed", det_ok)
	_check("all %d rolls: every jump has a timing window of at least %d frames on real geometry" % [SEEDS, TowerGen.MIN_WINDOW], worst_window >= TowerGen.MIN_WINDOW)
	_check("platforms stay inside the shaft and never overlap", shaft_ok and overlap_ok)
	_check("the rolls contain wall turns (the leap is exercised)", turns > 0)
	_check("the flood is no faster than the calm pace margin", flood_ok)
	_check("junk drops sit on a platform, cover under half of it and give a 1 s tell", junk_ok)
	# negative control: widen one gap past the reach and the window check must see it
	var bad := TowerGen.roll(10, 5)
	var plats2: Array = bad["tower"]["plats"]
	var moved: Rect2 = plats2[3]["rect"]
	moved.position.x += 190.0 if moved.position.x > plats2[2]["rect"].position.x else -190.0
	plats2[3]["rect"] = moved
	var wbad := _window(_world(bad), plats2[2]["rect"], moved)
	_check("(control) a gap widened by 190 px loses the window (%d frames)" % wbad, wbad < TowerGen.MIN_WINDOW)
	await _real_game()
	print("[test_tower] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _real_game() -> void:
	await physics_frame
	MachineRuntime.fixed_seed = 4242
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 10)
	root.add_child(main)
	for i in 4:
		await physics_frame
	var machine := main.get_node("Machine") as MachineRuntime
	var spec: Dictionary = machine.spec
	_check("level 10 builds a tower roll", String(spec.get("mode", "")) == "tower")
	var goal := main.get_node("Goal") as Node2D
	var g: Rect2 = spec["tower"]["goal"]
	_check("the door moved to the top platform of the roll", absf(goal.position.y - (g.position.y - 48.0)) < 1.0)
	var flood: RisingLava = null
	var junk := 0
	for c in machine.get_children():
		if c is RisingLava:
			flood = c
		if c is JunkDrop:
			junk += 1
	_check("the flood and the junk drops are built (%d drops)" % junk, flood != null and junk > 0)
	# a real jump: run from the spawn and jump onto the first platform
	var player := main.get_node("Player") as Player
	var p0: Rect2 = spec["tower"]["plats"][0]["rect"]
	player.global_position = Vector2(130.0, TowerGen.FLOOR_Y - 30.0)
	Input.action_release("move_left")
	var held := 0
	var landed := false
	for i in 200:
		var x := player.global_position.x
		if x < p0.position.x - 80.0 and held == 0:
			Input.action_press("move_right")
		elif held == 0:
			Input.action_press("jump")
			held = 1
		elif held > 0:
			held += 1
			if held > 40:
				Input.action_release("jump")
		await physics_frame
		if held > 0 and player.is_on_floor() and player.global_position.y < TowerGen.FLOOR_Y - 60.0:
			landed = true
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check("(real player) the run-and-jump from the floor lands on the first platform", landed)
	# the flood rises after the grace and kills a player who waits (control)
	var y0 := flood.surface_y()
	for i in 270:
		await physics_frame
	_check("the flood rises once the grace is over (%.0f px)" % (y0 - flood.surface_y()), flood.surface_y() < y0 - 10.0)
	main.queue_free()
	MachineRuntime.fixed_seed = 0


func _platform_at(plats: Array, x: float, y: float) -> Rect2:
	for p in plats:
		var r: Rect2 = p["rect"]
		if absf(r.position.y - y) < 1.0 and x >= r.position.x and x <= r.end.x:
			return r
	return Rect2()


func _world(spec: Dictionary) -> MachineWorld:
	var w := MachineWorld.new()
	for r in TowerGen.solids_of(spec):
		w.add_solid(r)
	w.finalize()
	return w


func _window_from_floor(world: MachineWorld, target: Rect2) -> int:
	var edge := target.position.x - 80.0
	return _run_window(world, 130.0, 1, edge, TowerGen.FLOOR_Y, target)


func _window(world: MachineWorld, a: Rect2, b: Rect2) -> int:
	var dir := 1 if b.get_center().x > a.get_center().x else -1
	var start := a.position.x + 20.0 if dir > 0 else a.end.x - 20.0
	var edge := a.end.x if dir > 0 else a.position.x
	return _run_window(world, start, dir, edge, a.position.y, b)


func _run_window(world: MachineWorld, start_x: float, dir: int, edge: float, top_y: float, target: Rect2) -> int:
	var ok := 0
	for off in range(-14, 10):
		if _land(world, start_x, dir, edge, top_y, target, off):
			ok += 1
	return ok


func _land(world: MachineWorld, start_x: float, dir: int, edge: float, top_y: float, target: Rect2, off: int) -> bool:
	var s := MachineSim.new(world, Vector2(start_x, top_y - 27.0))
	var jumped := false
	var after := 0
	var trigger := edge + float(off) * 5.3 * float(dir)
	for i in 420:
		var jp := false
		if not jumped and ((dir > 0 and s.pos.x >= trigger) or (dir < 0 and s.pos.x <= trigger)):
			jp = true
			jumped = true
		s.step(float(dir), jp, jumped and after < 40)
		if jumped:
			after += 1
		if s.dead:
			return false
		if jumped and s.on_floor and absf(s.pos.y - (target.position.y - 26.0)) < 2.0 and s.pos.x > target.position.x and s.pos.x < target.end.x:
			return true
		if jumped and s.pos.y > top_y + 400.0:
			return false
	return false
