extends SceneTree
## Owner test round 2 (2026-11-16): one check per reported bug, each with a control. See docs/BUGS_round2.md.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	await _boss_ghost()
	await _hinge()
	await _level_select()
	print("[test_round2] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


## A death or restart during the boss's 1.5 s warning must not leave it switched on beside the spawn.
func _boss_ghost() -> void:
	MachineRuntime.fixed_seed = 4242
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 40)
	root.add_child(main)
	await _step(4)
	var boss := main.get_node_or_null("Boss") as BossEntity
	var player := main.get_node("Player") as Player
	_check("level 40 has a boss", boss != null)
	if boss == null:
		main.queue_free()
		return
	# control: an activation that is left alone does switch the boss on
	boss.activate(Vector2(300.0, 600.0), player, 100.0)
	await create_timer(1.9).timeout
	_check("(control) an undisturbed activation switches the boss on", boss.is_active() and boss.visible)
	boss.deactivate()
	# the bug: activate, then die/restart inside the warning
	boss.activate(Vector2(300.0, 600.0), player, 100.0)
	await create_timer(0.4).timeout
	main.restart_level()
	boss.deactivate()
	await create_timer(1.9).timeout
	_check("a restart during the warning leaves the boss off and hidden (active %s, visible %s)" % [str(boss.is_active()), str(boss.visible)],
		not boss.is_active() and not boss.visible)
	# and a fresh chase after that still works
	boss.activate(Vector2(300.0, 600.0), player, 100.0)
	await create_timer(1.9).timeout
	_check("the next chase still starts normally", boss.is_active() and boss.visible)
	# round 3: the real slash reaches the big chaser and staggers it (it had no hitbox before)
	await physics_frame
	var atk := player.get_node_or_null("Attack") as PlayerAttack
	if atk == null:
		for c in player.get_children():
			if c is PlayerAttack:
				atk = c
	boss.global_position = player.global_position + Vector2(50.0, -8.0)
	boss.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	if atk != null:
		atk.cooldown_left = 0.0
		atk._strike(Vector2.RIGHT)
	_check("a slash connects with the big chaser and staggers it (stun %.2f)" % boss.stun_left, atk != null and boss.stun_left > 0.0)
	_check("(control) a staggered chaser cannot catch", not boss.has_caught_player())
	boss.deactivate()
	_check("deactivating clears the stagger", boss.stun_left == 0.0)
	main.queue_free()
	await _step(2)


## The start platform of a machine level wears the machine's colours and surface (no dark bare slab, no seam).
func _hinge() -> void:
	var bad: Array = []
	for lv in [8, 12, 36, 40]:
		MachineRuntime.fixed_seed = 4242
		var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		main.set("level_number", lv)
		root.add_child(main)
		await _step(4)
		var ground := main.get_node_or_null("Terrain/Ground")
		var machine := main.get_node_or_null("Machine") as MachineRuntime
		var legacy: Color = LevelData.get_level(lv).theme.wall_color
		var first_floor: Node = null
		for c in machine.get_children():
			if c is GreyboxPlatform and absf((c as Node2D).position.y - (MachinePieces.FLOOR_Y + MachinePieces.FLOOR_THICK * 0.5)) < 2.0:
				if first_floor == null or (c as Node2D).position.x < (first_floor as Node2D).position.x:
					first_floor = c
		if ground == null or first_floor == null:
			bad.append("%d: missing nodes" % lv)
		elif not (ground.color as Color).is_equal_approx(first_floor.color) or ground.get_node_or_null("HingeDecor") == null:
			bad.append("%d: ground %s vs floor %s" % [lv, str(ground.color), str(first_floor.color)])
		elif lv == 8 and (ground.color as Color).is_equal_approx(legacy):
			bad.append("%d: still the old theme colour" % lv)
		# a re-roll must not stack a second decor on the hinge
		main.restart_level()
		await _step(3)
		var decors := 0
		for c in ground.get_children():
			if String(c.name).begins_with("HingeDecor"):
				decors += 1
		if decors != 1:
			bad.append("%d: %d hinge decors after a re-roll" % [lv, decors])
		main.queue_free()
		await _step(2)
	MachineRuntime.fixed_seed = 0
	_check("the start platform matches the rolled floor on levels 8, 12, 36, 40 %s" % str(bad), bad.is_empty())


## LEVELS opens with the level you are on selected, not level 1.
func _level_select() -> void:
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		_check("GameManager is available", false)
		return
	var completed_before: Array = gm.save_system.levels_completed.duplicate()
	var level_before: int = gm.current_level
	for i in range(1, 9):
		if not (i in gm.save_system.levels_completed):
			gm.save_system.levels_completed.append(i)
	gm.current_level = 8
	var menu: Node = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _step(3)
	menu.visible = true
	await _step(2)
	menu._show_view("levels")
	await _step(3)
	var focus := root.gui_get_focus_owner()
	var buttons: Array = menu.get("_level_buttons")
	_check("the level select focuses level 8 when you are on level 8 (focus on '%s')" % (focus.text if focus is Button else "nothing"),
		focus == buttons[7])
	_check("(control) it is not the first button", focus != buttons[0])
	_check("the current level's button is marked", String((buttons[7] as Button).text).contains(">") and (buttons[0] as Button).text == "1")
	menu.queue_free()
	gm.save_system.levels_completed = completed_before
	gm.current_level = level_before
	await _step(2)
