extends SceneTree
## THE WARDEN'S MILE: a perfect player (pocket to pocket, sprinting only when the whole sprint stays out
## of the cone) reaches the door unseen on 200 rolls; a player who just runs is seen (negative control);
## in the real scene a player in the open is hunted, one in a pocket never is, and a catch is a chip.

var _failures: int = 0
const DT := 1.0 / 60.0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


## The careful player. Returns [seen, seconds]. Sprints from pocket k to k+1 only when a forward
## simulation of the Warden says nobody sees the sprint.
func _perfect(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wx := rng.randf_range(1500.0, 4000.0)
	var wdir := 1 if rng.randf() < 0.5 else -1
	var px := WardenDirector.pocket_x(0)
	var t := 0.0
	var k := 0
	var seen := false
	var sprint_t := WardenDirector.POCKET_STEP / WardenDirector.SPRINT_SPEED + 0.25
	while k < WardenDirector.POCKETS - 1 and t < 600.0:
		# can we go now?
		var sx := wx
		var sd := wdir
		var ok := true
		var f := 0.0
		var ppx := px
		while f < sprint_t:
			var st := WardenDirector.patrol_step(sx, sd, DT)
			sx = st[0]
			sd = st[1]
			ppx = minf(ppx + WardenDirector.SPRINT_SPEED * DT, WardenDirector.pocket_x(k + 1))
			if WardenDirector.sees(sx, sd, ppx, 0.0):
				ok = false
				break
			f += DT
		if ok:
			# go: replay the sprint on the real state
			var g := 0.0
			while g < sprint_t:
				var st2 := WardenDirector.patrol_step(wx, wdir, DT)
				wx = st2[0]
				wdir = st2[1]
				px = minf(px + WardenDirector.SPRINT_SPEED * DT, WardenDirector.pocket_x(k + 1))
				if WardenDirector.sees(wx, wdir, px, 0.0):
					seen = true
				g += DT
				t += DT
			px = WardenDirector.pocket_x(k + 1)
			k += 1
		else:
			var st3 := WardenDirector.patrol_step(wx, wdir, DT)
			wx = st3[0]
			wdir = st3[1]
			t += DT
	return [seen, t, k]


## The reckless player: runs straight through, never hiding. True if the Warden ever sees him for long
## enough to raise the alarm.
func _reckless(seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wx := rng.randf_range(1500.0, 4000.0)
	var wdir := 1 if rng.randf() < 0.5 else -1
	var px := 160.0
	var exposed := 0.0
	var t := 0.0
	while px < WardenDirector.LENGTH - 200.0:
		var st := WardenDirector.patrol_step(wx, wdir, DT)
		wx = st[0]
		wdir = st[1]
		px += WardenDirector.SPRINT_SPEED * DT
		if WardenDirector.sees(wx, wdir, px, 0.0):
			exposed += DT
		t += DT
	return exposed >= WardenDirector.SUSPECT_TIME


func _run() -> void:
	var def := LevelData.get_level(15)
	_check("level 15 is the warden level with no chasers", def.warden and not def.boss_config.enabled)
	var ice := false
	for p in def.platforms:
		if p.name == "Ground" and p.kind == "ice":
			ice = true
	_check("the corridor floor is ice", ice)
	_check("the hunt is slower than a sprint, the catch is only a chip", WardenDirector.HUNT_SPEED < WardenDirector.SPRINT_SPEED)
	var unseen := 0
	var worst_t := 0.0
	var stuck := 0
	for s in 200:
		var r := _perfect(9000 + s * 31)
		if not bool(r[0]):
			unseen += 1
		if int(r[2]) < WardenDirector.POCKETS - 1:
			stuck += 1
		worst_t = maxf(worst_t, float(r[1]))
	_check("a careful player crosses unseen on 200 of 200 rolls (%d unseen, %d stuck, worst %.0f s)" % [unseen, stuck, worst_t], unseen == 200 and stuck == 0)
	_check("(and the worst wait is under two minutes)", worst_t < 120.0)
	var seen_rolls := 0
	for s in 200:
		if _reckless(9000 + s * 31):
			seen_rolls += 1
	_check("(control) a player who just runs is caught in the lantern on %d of 200 rolls" % seen_rolls, seen_rolls >= 20)
	_check("a pocket hides you and the open does not", WardenDirector.in_pocket(WardenDirector.pocket_x(2)) and not WardenDirector.in_pocket(WardenDirector.pocket_x(2) + 260.0))
	_check("the cone sees ahead, not behind", WardenDirector.sees(1000.0, 1, 1300.0, 0.0) and not WardenDirector.sees(1000.0, 1, 700.0, 0.0))
	# real scene
	await physics_frame
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 15)
	root.add_child(main)
	for i in 6:
		await physics_frame
	var warden := main.get_node_or_null("Warden") as WardenDirector
	_check("the Warden is built in the real level", warden != null)
	if warden == null:
		quit(1)
		return
	var cores := 0
	var idx_seen := {}
	for c in warden.get_children():
		if c is Orb:
			cores += 1
			idx_seen[c.index] = true
	_check("three optional cores are built (%d, indices %s)" % [cores, str(idx_seen.keys())], cores == 3 and idx_seen.size() == 3)
	var player := main.get_node("Player") as Player
	player.set_physics_process(false)
	# in a pocket: never hunted
	warden.reset()
	warden.wx = 2000.0
	warden.wdir = 1
	var pk := WardenDirector.pocket_x(5)
	for i in 240:
		warden.wx = pk - 200.0
		warden.wdir = 1
		player.global_position = Vector2(pk, WardenDirector.FLOOR_Y - 26.0)
		await physics_frame
	_check("(real) a player standing in a pocket in the lantern is never hunted (%d alarms)" % warden.alarms, warden.alarms == 0)
	# in the open: hunted within a second
	warden.reset()
	for i in 90:
		warden.wx = pk + 140.0 - 300.0
		warden.wdir = 1
		player.global_position = Vector2(pk + 140.0, WardenDirector.FLOOR_Y - 26.0)
		await physics_frame
	_check("(real) a player standing in the open in the lantern raises the alarm (%d)" % warden.alarms, warden.alarms >= 1)
	# a catch is a chip
	var before := warden.chips
	player.global_position = Vector2(warden.wx + 10.0, WardenDirector.FLOOR_Y - 26.0)
	for i in 20:
		await physics_frame
	_check("(real) being caught is one chip (%d -> %d)" % [before, warden.chips], warden.chips == before + 1)
	main.queue_free()
	print("[test_warden] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
