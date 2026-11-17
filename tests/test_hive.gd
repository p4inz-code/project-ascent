extends SceneTree
## THE HIVE (level 30), the long version: two drone halls with kill quotas, two acid runs and the Mother. The
## level is long, nothing from the classic pipeline is in it, every jump is short, drones are slower than the
## player, kills only count toward their own hall, a sac only takes a slash while it is open, and each gate opens
## when its hall is done.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var def := LevelData.get_level(30)
	_check("level 30 is the hive, scripted, with no chasers", def.hive and def.scripted and not def.boss_config.enabled)
	_check("it is long (%d px) with three gates and five acid pits" % int(HiveDirector.LENGTH), HiveDirector.LENGTH >= 5500.0 and def.plate_gates.size() == 3 and def.lava_pits.size() == 5)
	_check("(regression) nothing from the classic pipeline: no pipes, timing gates, storm or checkpoints", def.pipes.is_empty() and def.gates.is_empty() and not def.storm and def.checkpoints.is_empty())
	var widest := 0.0
	var narrowest_land := 9999.0
	for i in HiveDirector.PITS.size():
		var p: Array = HiveDirector.PITS[i]
		widest = maxf(widest, float(p[1]) - float(p[0]))
		if i > 0 and float(p[0]) - float(HiveDirector.PITS[i - 1][1]) < 400.0:
			narrowest_land = minf(narrowest_land, float(p[0]) - float(HiveDirector.PITS[i - 1][1]))
	_check("every acid pit is at most 150 px wide (%d) and the landings between them at least 100 px (%d)" % [int(widest), int(narrowest_land)], widest <= 150.0 and narrowest_land >= 100.0)
	var acid := true
	for l in def.lava_pits:
		if l.style != 1:
			acid = false
	_check("the pits are acid, not lava", acid)
	var slow := true
	for h in HiveDirector.HALLS:
		if float(h["speed"]) >= 320.0 * 0.5:
			slow = false
	_check("every drone is slower than half the player's run speed", slow)
	_check("the sacs can be reached by a jump and slash from the floor (centre %d px up, jump apex 122)" % int(HiveDirector.SAC_H), HiveDirector.SAC_H <= 122.0 + 70.0)
	_check("a sac is open for longer than its tell and for under half its cycle", HiveDirector.SAC_OPEN > HiveDirector.SAC_TELL and HiveDirector.SAC_OPEN < HiveDirector.SAC_PERIOD * 0.5)
	_check("hall_of: a hall, an acid run, the Mother", HiveDirector.hall_of(700.0) == 0 and HiveDirector.hall_of(1900.0) == -1 and HiveDirector.hall_of(5000.0) == 2)
	await physics_frame
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 30)
	root.add_child(main)
	for i in 6:
		await physics_frame
	var hive := main.get_node_or_null("Hive") as HiveDirector
	_check("the director is built", hive != null)
	if hive == null:
		quit(1)
		return
	var cores := 0
	for c in hive.get_children():
		if c is Orb:
			cores += 1
	_check("three moving cores are placed (%d)" % cores, cores == 3)
	var opened: Array = []
	hive.gate_open.connect(func(id: int) -> void: opened.append(id))
	var player := main.get_node("Player") as Player
	player.set_physics_process(false)
	# hall 1: stand far from the vents; drones come out after the grace and the tell
	player.global_position = Vector2(200.0, HiveDirector.FLOOR_Y - 26.0)
	for i in 90:
		await physics_frame
	_check("(control) nothing spawns during the grace (%d)" % hive.spawned, hive.spawned == 0)
	for i in 300:
		player.global_position = Vector2(200.0, HiveDirector.FLOOR_Y - 600.0)      # out of reach, so nothing bites
		await physics_frame
	_check("drones are released in the hall you are in (%d)" % hive.spawned, hive.spawned >= 2)
	_check("never more than %d alive in a hall" % HiveDirector.MAX_ALIVE, hive.alive_in(0) <= HiveDirector.MAX_ALIVE)
	# kill until the quota
	var guard := 0
	while not (1 in opened) and guard < 3000:
		guard += 1
		for d in hive.drones:
			if is_instance_valid(d) and d.alive:
				d.slash_hit(Vector2.RIGHT, player)
				break
		await physics_frame
	_check("slashing %d drones opens gate 1 (kills %d) %s" % [int(HiveDirector.HALLS[0]["quota"]), hive.kills[0], str(opened)], opened == [1] and hive.kills[0] == int(HiveDirector.HALLS[0]["quota"]))
	_check("the hall falls silent: no drone of hall 1 is left alive", hive.alive_in(0) == 0)
	var spawned_before := hive.spawned
	for i in 240:
		await physics_frame
	_check("(control) a finished hall releases nothing more", hive.spawned == spawned_before)
	# the Mother: closed sacs ignore a slash, open ones take two
	player.global_position = Vector2(5000.0, HiveDirector.FLOOR_Y - 600.0)
	await physics_frame
	var sac = hive.sacs[0]
	sac.phase = -hive._t                                   # cycle position 0: closed
	await physics_frame
	sac.slash_hit(Vector2.RIGHT, player)
	_check("(control) a closed sac shrugs off a slash", sac.hp == 2 and not sac.dead and not sac.is_open())
	for s in hive.sacs:
		s.phase = HiveDirector.SAC_PERIOD - HiveDirector.SAC_OPEN + 0.2 - hive._t
	await physics_frame
	_check("the sacs are open now", hive.sacs[0].is_open())
	for s in hive.sacs:
		s.clock = hive._t
		s.slash_hit(Vector2.RIGHT, player)
		s.slash_hit(Vector2.RIGHT, player)
	await physics_frame
	_check("two slashes on each open sac burst all three (%d) and open gate 3 %s" % [hive.sacs_burst, str(opened)], hive.sacs_burst == 3 and 3 in opened)
	# a respawn puts everything back
	hive.reset()
	_check("a reset restores the sacs, the quotas and the drones", hive.sacs.size() == 3 and hive.sacs_burst == 0 and hive.kills == [0, 0, 0] and hive.drones.is_empty())
	main.queue_free()
	print("[test_hive] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
