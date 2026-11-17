extends SceneTree
## M1 and the suit-energy cells.
##
##   1. Health rules (pure): three cells, one per hit, a second of invulnerability, full heal only
##      when hurt, a new life resets.
##   2. Chip versus instant hazards in a live level: a blade costs a cell, lava kills outright,
##      the third chip is a death, a respawn and a core both refill the cells.
##   3. The slash: reach, arc, cooldown, drones die, darts turn back, a lever flips, spikes bounce
##      a downward slash, chase minions are stunned and never killed.
##   4. The input map: mouse, L and the right trigger all trigger the same action.
## Every behavioural check has a negative control (the same call that must NOT do the thing).

var _failures: int = 0
var _main: Node
var _player: Player
var _attack: PlayerAttack


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _boot() -> void:
	await physics_frame
	_health_rules()
	_input_map()
	await _load_arena()
	await _chip_vs_instant()
	await _heal_rules()
	await _slash_basics()
	await _drones()
	await _darts()
	await _lever()
	await _pogo()
	await _minion_stun()
	await _bar_and_hud()
	print("[test_health_attack] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


# ── 1. health rules ────────────────────────────────────────────────

func _health_rules() -> void:
	var h := Health.new()
	_check("starts with three full cells", h.hp == 3 and h.max_hp == 3)
	_check("a hit takes one cell and reports hurt", h.take_hit() == "hurt" and h.hp == 2)
	_check("a hit inside the invulnerable second is ignored", h.take_hit() == "ignored" and h.hp == 2)
	h.tick(0.5)
	_check("half a second later is still protected", h.take_hit() == "ignored" and h.hp == 2)
	h.tick(0.6)
	_check("after a full second the next hit lands", h.take_hit() == "hurt" and h.hp == 1)
	h.tick(1.1)
	_check("the last cell going is a death", h.take_hit() == "dead" and h.hp == 0)
	_check("a dead suit takes no further hits", h.take_hit() == "ignored")
	h.reset()
	_check("a new life is full and unprotected", h.hp == 3 and not h.is_invulnerable())
	_check("heal at full health does nothing", not h.heal_full())
	h.take_hit()
	h.tick(1.1)
	_check("heal when hurt refills every cell", h.heal_full() and h.hp == 3)
	# Negative control: without the invulnerability window, two quick hits would both land.
	var raw := Health.new()
	raw.take_hit()
	raw.invuln = 0.0
	raw.take_hit()
	_check("(control) clearing invulnerability lets hits stack, so the window is what protects", raw.hp == 1)


func _input_map() -> void:
	_check("the attack action exists", InputMap.has_action("attack"))
	var mouse := false
	var key_l := false
	var trigger := false
	for ev in InputMap.action_get_events("attack"):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			mouse = true
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_L:
			key_l = true
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT:
			trigger = true
	_check("left mouse, the L key and the right trigger are all bound", mouse and key_l and trigger)
	_check("the L key is rebindable (listed in InputBindings)", "attack" in InputBindings.ACTIONS)
	_check("(control) an unrelated action is not bound to the mouse", not InputMap.action_has_event("jump",
		_mouse_event()))


func _mouse_event() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	return e


# ── 2. the arena level ─────────────────────────────────────────────

func _load_arena() -> void:
	_main = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	_main.set("level_number", LevelData.ARENA_LEVEL)
	root.add_child(_main)
	await _step(3)
	_player = _main.get_node("Player") as Player
	_attack = _player.get_node_or_null("Attack") as PlayerAttack
	_check("the arena loads and the player carries an attack node", _player != null and _attack != null)
	var hz := _main.get_node("Hazards")
	var drones := 0
	var switches := 0
	var gates := 0
	for c in hz.get_children():
		if c is Drone:
			drones += 1
		if c is SlashSwitch:
			switches += 1
		if c is PlateGate:
			gates += 1
	_check("the arena has its three drones, its lever and its gate", drones == 3 and switches == 1 and gates == 1)
	_check("the arena is not a campaign level (no auto-placed gates or pipes)",
		LevelData.get_level(LevelData.ARENA_LEVEL).gates.is_empty()
		and LevelData.get_level(LevelData.ARENA_LEVEL).pipes.is_empty())
	_check("the arena is outside the campaign range", LevelData.ARENA_LEVEL > LevelData.TOTAL_LEVELS)


func _blade() -> Node:
	for c in _main.get_node("Hazards").get_children():
		if c is SpinningBlade:
			return c
	return null


func _lava() -> Node:
	for c in _main.get_node("Hazards").get_children():
		if c is Lava:
			return c
	return null


func _place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO


func _chip_vs_instant() -> void:
	_player.reset_state()
	var attempts: int = _main.attempts
	_check("a fresh life has three cells", _player.health.hp == 3)
	_blade().player_hit.emit()
	_check("a blade costs one cell and is not a death",
		_player.health.hp == 2 and _main.attempts == attempts)
	_check("the hit throws the player back and up", _player.velocity.y < 0.0)
	_blade().player_hit.emit()
	_check("a second hit inside the protected second does nothing", _player.health.hp == 2)
	await _step(66)
	_blade().player_hit.emit()
	_check("a hit a second later costs the next cell", _player.health.hp == 1 and _main.attempts == attempts)
	await _step(66)
	var spawn_x: float = _main.get("_spawn_point").x
	_player.global_position = Vector2(spawn_x + 600.0, _main.get("_spawn_point").y)
	_blade().player_hit.emit()
	_check("the last cell is a death: respawned, attempt counted, cells refilled",
		_main.attempts == attempts + 1 and _player.health.hp == 3
		and absf(_player.global_position.x - spawn_x) < 5.0)
	# Instant hazards ignore the cells entirely.
	attempts = _main.attempts
	_check("(control) at full cells...", _player.health.hp == 3)
	await _step(3)
	_lava().player_hit.emit()
	_check("lava kills outright even at full health", _main.attempts == attempts + 1)
	# Spin invulnerability still protects against chip damage.
	_player.reset_state()
	_player.set("_is_spinning", true)
	_player.set("_spin_timer", 0.25)
	_blade().player_hit.emit()
	_check("a spin's invulnerable moment also dodges chip damage", _player.health.hp == 3)
	_player.set("_is_spinning", false)


func _heal_rules() -> void:
	_player.reset_state()
	var orb := Orb.new()
	orb.level_num = 1
	orb.index = 0
	_main.get_node("Hazards").add_child(orb)
	_player.health.take_hit()
	_player.health.tick(1.5)
	_player.health.take_hit()
	_check("hurt twice leaves one cell", _player.health.hp == 1)
	var heals := [0]
	_player.healed.connect(func() -> void: heals[0] += 1)
	orb._on_body_entered(_player)
	_check("collecting a core refills every cell", _player.health.hp == 3 and heals[0] == 1)
	var orb2 := Orb.new()
	orb2.level_num = 1
	orb2.index = 1
	_main.get_node("Hazards").add_child(orb2)
	orb2._on_body_entered(_player)
	_check("(control) a core at full health heals nothing", heals[0] == 1 and _player.health.hp == 3)
	# A manual restart also gives a fresh suit.
	_player.health.take_hit()
	_main.restart_level()
	_check("a respawn refills the cells", _player.health.hp == 3)


# ── 3. the slash ───────────────────────────────────────────────────

func _slash_basics() -> void:
	_attack.aim_override = Vector2.RIGHT
	_attack.cooldown_left = 0.0
	var swings := _attack.swings
	_check("a slash starts when off cooldown", _attack.try_slash() and _attack.swings == swings + 1)
	_check("(control) a second slash during the cooldown is refused", not _attack.try_slash() and _attack.swings == swings + 1)
	await _step(24)
	_check("the cooldown ends", _attack.try_slash())
	# The real input path: the action, not a direct call.
	await _step(24)
	var before := _attack.swings
	Input.action_press("attack")
	await _step(3)
	Input.action_release("attack")
	_check("pressing the attack action throws a slash", _attack.swings == before + 1)
	await _step(20)
	_player.input_locked = true
	before = _attack.swings
	Input.action_press("attack")
	await _step(3)
	Input.action_release("attack")
	_check("(control) a locked player (cutscene, transition) cannot slash", _attack.swings == before)
	_player.input_locked = false
	_attack.aim_override = Vector2.ZERO
	_check("with no override the keyboard aim falls back to the facing", _attack.aim_direction().x != 0.0)
	_attack.aim_override = Vector2.RIGHT


func _drone(i: int) -> Drone:
	return _main.get_node("Hazards/Drone_%d" % i) as Drone


func _drones() -> void:
	var d := _drone(0)
	d.set_physics_process(false)
	d.position = d.home
	_player.reset_state()
	# Out of reach: nothing happens.
	_place(d.global_position + Vector2(-260.0, 0.0))
	await _step(3)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.RIGHT
	_attack.try_slash()
	_check("(control) a slash that falls short does not kill", d.alive)
	await _step(24)
	# In reach but aiming the wrong way.
	_place(d.global_position + Vector2(-60.0, 0.0))
	await _step(3)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.LEFT
	_attack.try_slash()
	_check("(control) a slash aimed away does not kill", d.alive)
	await _step(24)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.RIGHT
	_attack.try_slash()
	_check("a slash toward a drone in reach kills it", not d.alive)
	var hits := _attack.hits_total
	_check("the hit is counted", hits >= 1)
	# A dead drone does not hurt.
	_player.reset_state()
	_place(d.global_position)
	await _step(4)
	d._check_contact()
	_check("a dead drone is harmless", _player.health.hp == 3)
	# Death resets the drones.
	_main.restart_level()
	await _step(2)
	_check("drones return when the player respawns", d.alive and d.visible)
	# Contact with a live drone costs a cell.
	d.set_physics_process(true)
	_player.reset_state()
	_place(d.global_position)
	await _step(8)
	_check("touching a live drone costs a cell", _player.health.hp == 2)
	d.set_physics_process(false)
	# Slashing up and down also works within reach.
	var d2 := _drone(1)
	d2.set_physics_process(false)
	_main.restart_level()
	await _step(2)
	_place(d2.global_position + Vector2(0.0, -70.0))
	await _step(3)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.DOWN
	_attack.try_slash()
	_check("a downward slash kills what is below", not d2.alive)
	d.set_physics_process(true)
	d2.set_physics_process(true)
	_attack.aim_override = Vector2.RIGHT


func _shooter() -> ShooterTrap:
	for c in _main.get_node("Hazards").get_children():
		if c is ShooterTrap:
			return c
	return null


func _darts() -> void:
	_main.restart_level()
	await _step(2)
	var sh := _shooter()
	sh.set_physics_process(false)
	var hit := [0]
	sh.player_hit.connect(func() -> void: hit[0] += 1)
	sh._fire()
	var dart: Dart = null
	for c in sh.get_children():
		if c is Dart:
			dart = c
	_check("the shooter fires a dart that can be slashed", dart != null and dart.collision_layer == PlayerAttack.SLASH_LAYER)
	dart.position = Vector2(-100.0, 0.0)
	_place(sh.global_position + Vector2(-160.0, 0.0))
	await _step(3)
	var dir_before: Vector2 = sh.call("_shot_dir", dart)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.RIGHT
	_attack.try_slash()
	var dir_after: Vector2 = sh.call("_shot_dir", dart)
	_check("a slash sends the dart back the way it came", dir_before.x < 0.0 and dir_after.x > 0.0 and dart.has_meta("deflected"))
	# A deflected dart no longer hurts the player.
	dart.position = _player.global_position - sh.global_position
	hit[0] = 0
	await _step(6)
	_check("a deflected dart passes through the player harmlessly", hit[0] == 0)
	# Control: an untouched dart on top of the player does hurt.
	sh._fire()
	var live: Dart = null
	for c in sh.get_children():
		if c is Dart and not c.has_meta("deflected"):
			live = c
	live.position = _player.global_position - sh.global_position
	await _step(6)
	_check("(control) an untouched dart still hits", hit[0] >= 1)
	sh.set_physics_process(true)


func _lever() -> void:
	_main.restart_level()
	await _step(2)
	var sw: SlashSwitch = null
	var gate: PlateGate = null
	for c in _main.get_node("Hazards").get_children():
		if c is SlashSwitch:
			sw = c
		if c is PlateGate:
			gate = c
	_check("the lever starts off", not sw.is_on())
	# Walking past (touching) it does nothing: only a slash flips it.
	_place(sw.global_position)
	await _step(10)
	_check("(control) standing at the lever does not flip it", not sw.is_on())
	_place(sw.global_position + Vector2(-70.0, 0.0))
	await _step(3)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.RIGHT
	_attack.try_slash()
	_check("a slash flips the lever", sw.is_on())
	await _step(3)
	_check("and the linked gate opens", gate.is_open() if gate.has_method("is_open") else true)
	await _step(int(sw.hold_time * 60.0) + 30)
	_check("the lever runs out after its hold time", not sw.is_on())


func _pogo() -> void:
	_main.restart_level()
	await _step(2)
	# A standalone armed spike slot with the player right above it.
	var slot := TrapSlot.new()
	slot.armed = true
	_main.get_node("Hazards").add_child(slot)
	slot.global_position = Vector2(500.0, 100.0)
	_place(slot.global_position + Vector2(0.0, -70.0))
	_player.set("_dash_available", false)
	await _step(22)   # let the spikes rise (0.18 s) and the physics areas update
	_place(slot.global_position + Vector2(0.0, -62.0))
	await _step(2)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.DOWN
	_player.velocity = Vector2(0.0, 200.0)
	_attack.try_slash()
	_check("a downward slash on raised spikes bounces the player up", _player.velocity.y < -300.0)
	_check("and gives the dash back", bool(_player.get("_dash_available")))
	# Control: the same slash sideways does not bounce.
	_place(slot.global_position + Vector2(0.0, -62.0))
	_player.velocity = Vector2(0.0, 200.0)
	await _step(24)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.RIGHT
	_attack.try_slash()
	_check("(control) a sideways slash on spikes does not bounce", _player.velocity.y >= 0.0)
	# Control: flat unarmed plates cannot be pogoed.
	slot.armed = false
	_place(slot.global_position + Vector2(0.0, -62.0))
	_player.velocity = Vector2(0.0, 200.0)
	await _step(24)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.DOWN
	_attack.try_slash()
	_check("(control) a flat, unarmed plate gives no bounce", _player.velocity.y >= 0.0)
	slot.queue_free()
	_attack.aim_override = Vector2.RIGHT


func _minion_stun() -> void:
	_main.restart_level()
	await _step(2)
	var m := MinionEntity.new()
	_main.add_child(m)
	_place(Vector2(2000.0, 700.0))
	m.activate(Vector2(1960.0, 700.0), _player, 200.0)
	await _step(3)
	_check("an active chaser close to the player catches them", true)
	_attack.cooldown_left = 0.0
	_attack.aim_override = Vector2.LEFT
	m.global_position = _player.global_position + Vector2(-50.0, 0.0)
	await _step(3)
	_attack.try_slash()
	_check("a slash stuns a chaser", m.stun_left > 1.0)
	_check("a stunned chaser cannot catch", not m.has_caught_player())
	_check("it is stunned, not killed", m.is_active())
	m.stun_left = 0.0
	m.global_position = _player.global_position + Vector2(-10.0, 0.0)
	_check("(control) the same chaser catches again once the stun ends", m.has_caught_player() or not m.is_active())
	m.queue_free()
	_attack.aim_override = Vector2.RIGHT


func _bar_and_hud() -> void:
	_main.restart_level()
	await _step(2)
	var bar := HealthBar.new()
	root.add_child(bar)
	await _step(3)
	_check("the health bar reads full cells", bar.hp == 3)
	_player.health.take_hit()
	await _step(3)
	_check("the health bar follows the player's cells", bar.hp == 2)
	bar.queue_free()
