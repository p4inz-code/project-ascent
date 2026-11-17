# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name HiveDirector
extends Node2D
## THE HIVE (level 30): a long nest in five parts.
##
##   1  THE BROOD HALL    two ceiling vents release hunting drones. Slash 6 and the first gate opens.
##   2  ACID RUN          three acid pits to jump (acid is instant, the jumps are short and fixed).
##   3  THE DEEP HALL     three vents, faster drones, a two-tier ledge. Slash 10.
##   4  ACID RUN          two wider pits.
##   5  THE MOTHER        she hangs from the roof with three egg sacs. A sac is armoured except while it is OPEN
##                        (it pulses for 0.8 s, then opens for 1.8 s of every 4.2 s): slash each open sac twice.
##                        She keeps releasing drones (four at most) until the last sac bursts.
##
## Fair by construction: a vent glows for a second before it releases, drones are slower than you run and a
## touch is one cell (never a kill), at most six are alive in a hall, every fifth kill and every burst sac refill
## your cells, and every jump in the level is at most 150 across and 76 up. Timings and cores re-roll per attempt.

signal chip(source_x: float)
signal gate_open(id: int)

## One egg sac. Slashing it only counts while it is open.
class Sac extends Area2D:
	signal burst
	var hp: int = 2
	var phase: float = 0.0
	var clock: float = 0.0
	var dead: bool = false

	func is_open() -> bool:
		return not dead and fposmod(clock + phase, HiveDirector.SAC_PERIOD) >= HiveDirector.SAC_PERIOD - HiveDirector.SAC_OPEN

	func is_telling() -> bool:
		var ph := fposmod(clock + phase, HiveDirector.SAC_PERIOD)
		return not dead and ph >= HiveDirector.SAC_PERIOD - HiveDirector.SAC_OPEN - HiveDirector.SAC_TELL and ph < HiveDirector.SAC_PERIOD - HiveDirector.SAC_OPEN

	func slash_hit(_dir: Vector2, _attacker: Node) -> void:
		if dead or not is_open():
			return
		hp -= 1
		if hp <= 0:
			dead = true
			set_deferred("monitorable", false)
			burst.emit()


const LEVEL := 30
const FLOOR_Y := 800.0
const LENGTH := 5900.0
const VENT_H := 330.0
const TELL := 1.0
const SPAWN_EVERY := 2.6
const MAX_ALIVE := 6
const HEAL_EVERY := 5
const GRACE := 2.0
const SAC_PERIOD := 4.2
const SAC_OPEN := 1.8
const SAC_TELL := 0.8
const SAC_H := 140.0
const MOTHER_SPAWN_EVERY := 4.5
const MOTHER_MAX_ALIVE := 4

## Halls: {x0, x1, vents, quota, speed, gate x, link id}. The Mother's hall has sacs instead of a quota.
const HALLS: Array = [
	{"x0": 0.0, "x1": 1500.0, "vents": [500.0, 1000.0], "quota": 6, "speed": 110.0, "gate": 1500.0, "id": 1},
	{"x0": 2300.0, "x1": 3900.0, "vents": [2700.0, 3100.0, 3500.0], "quota": 10, "speed": 125.0, "gate": 3900.0, "id": 2},
	{"x0": 4620.0, "x1": 5540.0, "vents": [5100.0], "quota": 0, "speed": 115.0, "gate": 5540.0, "id": 3},
]
const SAC_X: Array[float] = [4850.0, 5100.0, 5350.0]
## Acid pits: [x0, x1].
const PITS: Array = [[1700.0, 1820.0], [1930.0, 2050.0], [2160.0, 2280.0], [4050.0, 4200.0], [4330.0, 4480.0]]
## Low ledges [x, top height above the floor]: places to stand above the swarm.
const LEDGES: Array = [[300.0, 76.0], [750.0, 76.0], [1200.0, 76.0], [2500.0, 76.0], [2900.0, 76.0], [3010.0, 150.0], [3300.0, 76.0], [3700.0, 76.0]]
## Where the three optional cores can appear: [x, height above the floor, sweep]. Over the acid, or high above a ledge.
const CORE_SPOTS: Array = [[700.0, 150.0, 70.0], [1760.0, 110.0, 30.0], [1990.0, 110.0, 30.0], [2220.0, 110.0, 30.0], [3010.0, 250.0, 60.0], [4125.0, 110.0, 40.0], [4405.0, 110.0, 40.0]]

var player: Player = null
var kills: Array[int] = [0, 0, 0]
var sacs_burst: int = 0
var spawned: int = 0
var drones: Array = []
var sacs: Array = []

var _t: float = 0.0
var _vent_clock: Dictionary = {}       # vent x -> seconds
var _opened: Array[bool] = [false, false, false]
var _label: Label = null
var _on_orb: Callable
var _cores: Array = []
var _rng := RandomNumberGenerator.new()


static func hall_of(x: float) -> int:
	for i in HALLS.size():
		if x >= float(HALLS[i]["x0"]) and x <= float(HALLS[i]["x1"]):
			return i
	return -1


static func build_def(legacy: LevelData.LevelDef) -> LevelData.LevelDef:
	var def := LevelData.LevelDef.new()
	def.number = LEVEL
	def.name = "THE HIVE"
	def.theme = legacy.theme
	def.boss_config = LevelData.BossConfig.new()
	def.hive = true
	def.scripted = true
	var theme: LevelData.LevelTheme = def.theme
	var P := LevelData.PlatformDef
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), theme.wall_color, theme.edge_color, 0.0),
		P.new("RightWall", Vector2(LENGTH + 60.0, 200.0), Vector2(40.0, 2200.0), theme.wall_color, theme.edge_color, 0.0),
	]
	# the floor, cut open at every acid pit
	var x := -100.0
	var gi := 0
	for pit in PITS:
		def.platforms.append(P.new("Ground_%d" % gi, Vector2((x + float(pit[0])) * 0.5, FLOOR_Y + 250.0), Vector2(float(pit[0]) - x, 500.0), theme.wall_color, theme.edge_color, 5.0))
		var lava := LevelData.LavaDef.new(Vector2((float(pit[0]) + float(pit[1])) * 0.5, FLOOR_Y + 160.0), Vector2(float(pit[1]) - float(pit[0]), 280.0))
		lava.style = 1      # acid
		def.lava_pits.append(lava)
		x = float(pit[1])
		gi += 1
	def.platforms.append(P.new("Ground_%d" % gi, Vector2((x + LENGTH + 100.0) * 0.5, FLOOR_Y + 250.0), Vector2(LENGTH + 100.0 - x, 500.0), theme.wall_color, theme.edge_color, 5.0))
	for li in LEDGES.size():
		var l: Array = LEDGES[li]
		def.platforms.append(P.new("Ledge_%d" % li, Vector2(float(l[0]), FLOOR_Y - float(l[1]) + 12.0), Vector2(110.0, 24.0), theme.platform_color, theme.edge_color, 5.0))
	for h in HALLS:
		var pg := LevelData.PlateGateDef.new(Vector2(float(h["gate"]), FLOOR_Y + 600.0), Vector2(float(h["gate"]) + 30.0, FLOOR_Y - 200.0), Vector2(26.0, 400.0), 7.0, int(h["id"]))
		pg.use_slash = true
		def.plate_gates.append(pg)
	def.spawn_point = Vector2(160.0, FLOOR_Y - 28.0)
	def.goal_position = Vector2(LENGTH - 200.0, FLOOR_Y - 48.0)
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = FLOOR_Y + 1400.0
	return def


func setup(p_player: Player, on_orb: Callable = Callable()) -> void:
	player = p_player
	_on_orb = on_orb
	_rng.randomize()
	var layer := CanvasLayer.new()
	layer.layer = 6
	_label = Label.new()
	_label.position = Vector2(1560, 128)
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)
	add_child(layer)
	reset()


func reset() -> void:
	for d in drones:
		if is_instance_valid(d):
			d.queue_free()
	drones.clear()
	for s in sacs:
		if is_instance_valid(s):
			s.queue_free()
	sacs.clear()
	kills = [0, 0, 0]
	sacs_burst = 0
	spawned = 0
	_t = 0.0
	_opened = [false, false, false]
	_vent_clock.clear()
	for h in HALLS:
		var k := 0
		for vx in h["vents"]:
			_vent_clock[float(vx)] = float(k) * 0.9      # staggered
			k += 1
	for i in SAC_X.size():
		var sac := Sac.new()
		sac.collision_layer = PlayerAttack.SLASH_LAYER
		sac.collision_mask = 0
		sac.position = Vector2(SAC_X[i], FLOOR_Y - SAC_H)
		sac.phase = _rng.randf_range(0.0, SAC_PERIOD)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 26.0
		shape.shape = circle
		sac.add_child(shape)
		sac.burst.connect(_on_sac_burst)
		add_child(sac)
		sacs.append(sac)
	_roll_cores()
	_refresh_label()
	queue_redraw()


func _roll_cores() -> void:
	for c in _cores:
		if is_instance_valid(c):
			c.queue_free()
	_cores.clear()
	var spots := CORE_SPOTS.duplicate()
	for k in 3:
		var i := _rng.randi_range(0, spots.size() - 1)
		var s: Array = spots[i]
		spots.remove_at(i)
		_cores.append(CoreSpawner.add(self, LEVEL, k, Vector2(float(s[0]), FLOOR_Y - float(s[1])), _on_orb,
			Vector2(float(s[2]), 0.0), _rng.randf_range(2.0, 2.8), _rng.randf_range(0.0, TAU)))


func alive_in(hall: int) -> int:
	var n := 0
	for d in drones:
		if is_instance_valid(d) and d.alive and int(d.get_meta("hall", -1)) == hall:
			n += 1
	return n


func total_kills() -> int:
	return kills[0] + kills[1] + kills[2]


func _refresh_label() -> void:
	if _label == null:
		return
	var h := hall_of(player.global_position.x) if player != null and is_instance_valid(player) else 0
	if h < 0:
		h = 2 if _opened[1] else (1 if _opened[0] else 0)
	if h == 2:
		_label.text = "MOTHER  %d / %d" % [sacs_burst, SAC_X.size()]
	else:
		_label.text = "HIVE  %d / %d" % [mini(kills[h], int(HALLS[h]["quota"])), int(HALLS[h]["quota"])]
	_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.85) if _opened[h] else Color(1.0, 0.75, 0.35))


func _spawn(hall: int, at: Vector2) -> void:
	var d := Drone.new()
	d.position = at
	d.patrol_range = 0.0
	d.drift_speed = float(HALLS[hall]["speed"])
	d.sense_range = 2400.0
	d.windup_time = 0.35
	d.set_meta("hall", hall)
	d.player_hit.connect(func() -> void: chip.emit(d.global_position.x))
	d.killed.connect(func() -> void: _on_kill(hall))
	add_child(d)
	drones.append(d)
	spawned += 1


func _clear_hall(hall: int) -> void:
	for d in drones:
		if is_instance_valid(d) and d.alive and int(d.get_meta("hall", -1)) == hall:
			d.set_meta("hall", -1)      # so its death is not counted again
			d.slash_hit(Vector2.ZERO, null)


func _on_kill(hall: int) -> void:
	if hall < 0 or hall > 2:
		return
	kills[hall] += 1
	if total_kills() % HEAL_EVERY == 0 and player != null and is_instance_valid(player):
		player.heal_full()
	if hall < 2 and kills[hall] >= int(HALLS[hall]["quota"]) and not _opened[hall]:
		_opened[hall] = true
		_clear_hall(hall)
		gate_open.emit(int(HALLS[hall]["id"]))
	_refresh_label()


func _on_sac_burst() -> void:
	sacs_burst += 1
	if player != null and is_instance_valid(player):
		player.heal_full()
	if sacs_burst >= SAC_X.size() and not _opened[2]:
		_opened[2] = true
		_clear_hall(2)
		gate_open.emit(int(HALLS[2]["id"]))
	_refresh_label()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	for s in sacs:
		if is_instance_valid(s):
			s.clock = _t
	var hall := hall_of(player.global_position.x)
	if _t >= GRACE and hall >= 0 and not _opened[hall]:
		var every := SPAWN_EVERY if hall < 2 else MOTHER_SPAWN_EVERY
		var cap := MAX_ALIVE if hall < 2 else MOTHER_MAX_ALIVE
		for vx in HALLS[hall]["vents"]:
			var key := float(vx)
			_vent_clock[key] = float(_vent_clock[key]) + delta
			if float(_vent_clock[key]) >= every:
				_vent_clock[key] = float(_vent_clock[key]) - every
				if alive_in(hall) < cap:
					_spawn(hall, Vector2(key, FLOOR_Y - VENT_H + 30.0))
	_refresh_label()
	queue_redraw()


func _vent_telling(hall: int, vx: float) -> bool:
	if _opened[hall] or player == null or not is_instance_valid(player) or hall_of(player.global_position.x) != hall:
		return false
	var every := SPAWN_EVERY if hall < 2 else MOTHER_SPAWN_EVERY
	return float(_vent_clock.get(vx, 0.0)) >= every - TELL


func _draw() -> void:
	var vy := FLOOR_Y - VENT_H
	for hi in 2:
		for vx in HALLS[hi]["vents"]:
			var x := float(vx)
			draw_rect(Rect2(x - 40.0, vy - 16.0, 80.0, 22.0), Color(0.22, 0.20, 0.28))
			var telling := _vent_telling(hi, x)
			draw_rect(Rect2(x - 26.0, vy + 4.0, 52.0, 8.0), Color(1.0, 0.45, 0.2, 0.85) if telling else Color(0.35, 0.2, 0.22, 0.9))
			if telling:
				draw_rect(Rect2(x - 20.0, vy + 12.0, 40.0, 60.0), Color(1.0, 0.5, 0.2, 0.18))
	# the Mother: a segmented body along the roof, a mouth in the middle, three sacs hanging on stalks
	var mx := 5100.0
	var body := Color(0.34, 0.16, 0.30) if not _opened[2] else Color(0.18, 0.14, 0.18)
	for k in 7:
		var bx := mx - 330.0 + float(k) * 110.0
		draw_rect(Rect2(bx - 52.0, vy - 60.0 - 14.0 * sin(float(k) * 0.9), 104.0, 70.0), body)
		draw_rect(Rect2(bx - 52.0, vy - 60.0 - 14.0 * sin(float(k) * 0.9), 104.0, 6.0), body.lightened(0.18))
	var mouth_tell := _vent_telling(2, mx)
	draw_rect(Rect2(mx - 30.0, vy + 6.0, 60.0, 14.0), Color(1.0, 0.45, 0.2) if mouth_tell else Color(0.12, 0.05, 0.1))
	for i in sacs.size():
		var s: Sac = sacs[i]
		if not is_instance_valid(s):
			continue
		var p := s.position
		draw_rect(Rect2(p.x - 3.0, vy + 6.0, 6.0, p.y - vy - 26.0), body.darkened(0.2))
		if s.dead:
			draw_rect(Rect2(p.x - 10.0, p.y - 26.0, 20.0, 12.0), Color(0.2, 0.14, 0.18))
			continue
		var shell := Color(0.45, 0.25, 0.4)
		var r := 26.0
		if s.is_open():
			shell = Color(1.0, 0.75, 0.3)
			draw_circle(p, r + 8.0, Color(1.0, 0.8, 0.3, 0.2))
		elif s.is_telling():
			shell = Color(0.45, 0.25, 0.4).lerp(Color(1.0, 0.75, 0.3), 0.5 + 0.5 * float(int(_t * 14.0) % 2))
		draw_circle(p, r, shell)
		draw_circle(p + Vector2(-8.0, -8.0), 6.0, shell.lightened(0.3))
		if s.hp < 2:
			draw_line(p + Vector2(-12, -6), p + Vector2(4, 8), Color(0.1, 0.05, 0.08), 3.0)
