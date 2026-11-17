# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name TempestDirector
extends Node2D
## THE TEMPEST (level 20): a long reactor hall in three sealed sections. Ground-pound every lightning rod of a
## section (jump, then Down + Jump in the air, onto the rod's cap) and its gate opens. Eight rods in all.
##
##   A  THE FLOOR      three rods on low pillars. Lightning only.
##   B  THE STACKS     three rods on tall stacks climbed by solid steps, with two ARC PLATES in the floor between
##                     the stacks: they crackle for a second and then go live for 0.9 s of every 3.2 s.
##   C  THE CORE DAIS  two rods on a raised dais reached by floating stones; a SWEEP BEAM runs along the floor
##                     every 6 s (the emitter glows for a second first), so the stones and the dais are safe ground.
##
## Lightning strikes where you stood 1.25 s ago, faster in every section. Everything is a chip (one cell), never
## a kill, every hazard has its tell, at most two kinds are live in a section, and every rod you pound refills
## your cells. The geometry is fixed (no step is more than 84 up); the timings and the cores re-roll per attempt.

signal chip(source_x: float)
signal gate_open(id: int)

const LEVEL := 20
const FLOOR_Y := 800.0
const HALL_W := 5200.0
const ROD_W := 110.0
const STEP_W := 110.0
const TELL := 1.25
const STRIKE_ACTIVE := 0.22
const STRIKE_HALF_W := 44.0
const GRACE := 2.5
## Seconds between lightning marks, by section.
const STRIKE_EVERY: Array[float] = [1.1, 0.95, 0.85]
const MAX_STEP_RISE := 84.0

## Rods: [x, height of the cap above the floor, section]. A cap is the top of a pillar (or the dais).
const RODS: Array = [
	[520.0, 64.0, 0], [900.0, 80.0, 0], [1280.0, 64.0, 0],
	[2000.0, 150.0, 1], [2595.0, 222.0, 1], [3185.0, 150.0, 1],
	[4050.0, 300.0, 2], [4250.0, 300.0, 2],
]
## Section gates: [x, link id]. Section k's gate opens when all its rods are pounded.
const GATES: Array = [[1560.0, 1], [3420.0, 2], [4880.0, 3]]
## Steps: [centre x, top height above the floor, floating]. Solid steps are blocks down to the floor and sit flush
## against their stack; floating stones are 16 thick with room to run underneath.
const STEPS: Array = [
	[1890.0, 76.0, false], [2110.0, 76.0, false],
	[2375.0, 76.0, false], [2485.0, 148.0, false], [2705.0, 148.0, false], [2815.0, 76.0, false],
	[3075.0, 76.0, false], [3295.0, 76.0, false],
	[3650.0, 84.0, true], [3760.0, 160.0, true], [3870.0, 236.0, true],
	[4430.0, 236.0, true], [4540.0, 160.0, true], [4650.0, 84.0, true],
]
const DAIS := Rect2(3950.0, FLOOR_Y - 300.0, 400.0, 24.0)
## Arc plates in the floor of section B, between the stacks: [x0, x1].
const ARC_PLATES: Array = [[2180.0, 2300.0], [2885.0, 3005.0]]
const ARC_PERIOD := 3.2
const ARC_TELL := 1.0
const ARC_ACTIVE := 0.9
## The sweep beam of section C: runs right to left along the floor.
const BEAM_FROM := 4800.0
const BEAM_TO := 3440.0
const BEAM_SPEED := 380.0
const BEAM_PERIOD := 6.0
const BEAM_TELL := 1.0
const BEAM_H := 48.0
const BEAM_HALF_W := 20.0
## Where the three optional cores can appear (three are drawn per attempt): [x, height above the floor].
const CORE_SPOTS: Array = [[1100.0, 150.0], [2240.0, 110.0], [2595.0, 330.0], [2945.0, 110.0], [3510.0, 130.0], [4150.0, 400.0], [4760.0, 150.0]]
const CORE_SWEEP := 70.0

var player: Player = null
var pounded: Array[bool] = []
var chips: int = 0
var strikes_fired: int = 0
## Tests set this false to silence the storm while they check something else.
var storm_enabled: bool = true

var _t: float = 0.0
var _since_strike: float = 0.0
var _marks: Array = []
var _rod_nodes: Array = []
var _opened: Array[bool] = [false, false, false]
var _open: bool = false           # every section done
var _arc_phase: Array[float] = [0.0, 1.6]
var _beam_phase: float = 0.0
var _on_orb: Callable
var _cores: Array = []
var _rng := RandomNumberGenerator.new()


static func section_of(x: float) -> int:
	if x < float(GATES[0][0]):
		return 0
	if x < float(GATES[1][0]):
		return 1
	return 2


## True while an arc plate is live (the last ARC_ACTIVE seconds of its period).
static func arc_active(t: float, phase: float) -> bool:
	return fposmod(t + phase, ARC_PERIOD) >= ARC_PERIOD - ARC_ACTIVE


static func arc_telling(t: float, phase: float) -> bool:
	var ph := fposmod(t + phase, ARC_PERIOD)
	return ph >= ARC_PERIOD - ARC_ACTIVE - ARC_TELL and ph < ARC_PERIOD - ARC_ACTIVE


## The beam's x at time t, or NAN while it is charging (the tell) or resting.
static func beam_x(t: float, phase: float) -> float:
	var ph := fposmod(t + phase, BEAM_PERIOD)
	var travel := (BEAM_FROM - BEAM_TO) / BEAM_SPEED
	if ph < BEAM_TELL or ph > BEAM_TELL + travel:
		return NAN
	return BEAM_FROM - (ph - BEAM_TELL) * BEAM_SPEED


static func beam_telling(t: float, phase: float) -> bool:
	return fposmod(t + phase, BEAM_PERIOD) < BEAM_TELL


static func build_def(legacy: LevelData.LevelDef) -> LevelData.LevelDef:
	var def := LevelData.LevelDef.new()
	def.number = LEVEL
	def.name = "TEMPEST"
	def.theme = legacy.theme
	def.boss_config = LevelData.BossConfig.new()
	def.tempest = true
	def.scripted = true
	var theme: LevelData.LevelTheme = def.theme
	var P := LevelData.PlatformDef
	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), wc, ec, 0.0),
		P.new("Ground", Vector2(HALL_W * 0.5 - 100.0, FLOOR_Y + 250.0), Vector2(HALL_W + 200.0, 500.0), wc, ec, 5.0),
		P.new("RightWall", Vector2(HALL_W + 60.0, 200.0), Vector2(40.0, 2200.0), wc, ec, 0.0),
		P.new("Dais", DAIS.get_center(), DAIS.size, pc, ec, 5.0),
	]
	for i in RODS.size():
		var r: Array = RODS[i]
		if int(r[2]) == 2:
			continue      # the dais carries its rods
		def.platforms.append(P.new("Rod_%d" % i, Vector2(float(r[0]), FLOOR_Y - float(r[1]) * 0.5), Vector2(ROD_W, float(r[1])), pc, ec, 5.0))
	for i in STEPS.size():
		var s: Array = STEPS[i]
		var h: float = float(s[1])
		if bool(s[2]):
			def.platforms.append(P.new("Stone_%d" % i, Vector2(float(s[0]), FLOOR_Y - h + 8.0), Vector2(STEP_W, 16.0), pc, ec, 5.0))
		else:
			def.platforms.append(P.new("Step_%d" % i, Vector2(float(s[0]), FLOOR_Y - h * 0.5), Vector2(STEP_W, h), pc, ec, 5.0))
	for g in GATES:
		var pg := LevelData.PlateGateDef.new(Vector2(float(g[0]), FLOOR_Y + 600.0), Vector2(float(g[0]), FLOOR_Y - 200.0), Vector2(26.0, 400.0), 7.0, int(g[1]))
		pg.use_slash = true
		def.plate_gates.append(pg)
	def.spawn_point = Vector2(160.0, FLOOR_Y - 28.0)
	def.goal_position = Vector2(HALL_W - 180.0, FLOOR_Y - 48.0)
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = FLOOR_Y + 1400.0
	return def


func setup(p_player: Player, on_orb: Callable = Callable()) -> void:
	player = p_player
	_on_orb = on_orb
	_rng.randomize()
	for i in RODS.size():
		pounded.append(false)
	_build_rods()
	reset()


func reset() -> void:
	for i in pounded.size():
		pounded[i] = false
	_t = 0.0
	_since_strike = 0.0
	_marks.clear()
	_opened = [false, false, false]
	_open = false
	chips = 0
	strikes_fired = 0
	_arc_phase = [_rng.randf_range(0.0, ARC_PERIOD), _rng.randf_range(0.0, ARC_PERIOD)]
	_beam_phase = _rng.randf_range(0.0, BEAM_PERIOD)
	_refresh_rods()
	_roll_cores()
	queue_redraw()


## Three cores in three of the spots, each sweeping side to side at jump height: a different three every attempt.
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
			Vector2(CORE_SWEEP, 0.0), _rng.randf_range(2.0, 2.8), _rng.randf_range(0.0, TAU)))


func _build_rods() -> void:
	for i in RODS.size():
		var r: Array = RODS[i]
		var rod := Area2D.new()
		rod.collision_layer = 0
		rod.collision_mask = 1
		rod.position = Vector2(float(r[0]), FLOOR_Y - float(r[1]))
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(ROD_W - 10.0, 46.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -23.0)
		rod.add_child(shape)
		var spire := Polygon2D.new()
		spire.polygon = PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(4, -150), Vector2(-4, -150)])
		rod.add_child(spire)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([Vector2(-9, -150), Vector2(9, -150), Vector2(0, -172)])
		tip.color = Color(0.9, 0.85, 0.4)
		rod.add_child(tip)
		var ring := Polygon2D.new()
		ring.polygon = PackedVector2Array([Vector2(-ROD_W * 0.5 + 6.0, -4), Vector2(ROD_W * 0.5 - 6.0, -4), Vector2(ROD_W * 0.5 - 6.0, 0), Vector2(-ROD_W * 0.5 + 6.0, 0)])
		rod.add_child(ring)
		add_child(rod)
		_rod_nodes.append({"area": rod, "spire": spire, "ring": ring})


func _refresh_rods() -> void:
	for i in _rod_nodes.size():
		var on: bool = pounded[i]
		_rod_nodes[i]["spire"].color = Color(0.3, 0.95, 1.0) if on else Color(0.55, 0.62, 0.78)
		_rod_nodes[i]["ring"].color = Color(0.3, 0.95, 1.0) if on else Color(0.95, 0.85, 0.35)


func rods_done() -> int:
	var n := 0
	for p in pounded:
		if p:
			n += 1
	return n


func section_done(section: int) -> bool:
	for i in RODS.size():
		if int(RODS[i][2]) == section and not pounded[i]:
			return false
	return true


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	for i in _rod_nodes.size():
		if pounded[i]:
			continue
		var area: Area2D = _rod_nodes[i]["area"]
		for b in area.get_overlapping_bodies():
			if b == player and player.is_pounding():
				pounded[i] = true
				player.heal_full()
				_refresh_rods()
				SfxHub.play(get_tree(), "vent")
	for s in 3:
		if not _opened[s] and section_done(s):
			_opened[s] = true
			gate_open.emit(int(GATES[s][1]))
	_open = _opened[0] and _opened[1] and _opened[2]
	var px := player.global_position.x
	var py := player.global_position.y
	var sec := section_of(px)
	if storm_enabled and _t >= GRACE and not _open:
		# lightning: one mark every STRIKE_EVERY (by section), under the player
		_since_strike += delta
		if _since_strike >= STRIKE_EVERY[sec]:
			_since_strike = 0.0
			_marks.append({"x": clampf(px, 40.0, HALL_W - 40.0), "age": 0.0, "hit": false})
		# arc plates (section B): live while you stand on the floor inside one
		for i in ARC_PLATES.size():
			var ap: Array = ARC_PLATES[i]
			if arc_active(_t, _arc_phase[i]) and px > float(ap[0]) - 14.0 and px < float(ap[1]) + 14.0 and py > FLOOR_Y - 40.0:
				chips += 1
				chip.emit((float(ap[0]) + float(ap[1])) * 0.5)
		# the sweep beam (section C): only once the player has reached that section
		if sec == 2:
			var bx := beam_x(_t, _beam_phase)
			if not is_nan(bx) and absf(px - bx) < BEAM_HALF_W + 14.0 and py > FLOOR_Y - BEAM_H - 26.0:
				chips += 1
				chip.emit(bx)
	var keep: Array = []
	for m in _marks:
		m["age"] = float(m["age"]) + delta
		var age: float = m["age"]
		if age >= TELL and not m.has("fell"):
			m["fell"] = true
			strikes_fired += 1
		if age >= TELL and age < TELL + STRIKE_ACTIVE and not bool(m["hit"]):
			if absf(px - float(m["x"])) < STRIKE_HALF_W + 14.0:
				m["hit"] = true
				chips += 1
				chip.emit(float(m["x"]))
		if age < TELL + STRIKE_ACTIVE + 0.2:
			keep.append(m)
	_marks = keep
	queue_redraw()


func _draw() -> void:
	# arc plates
	for i in ARC_PLATES.size():
		var ap: Array = ARC_PLATES[i]
		var r := Rect2(float(ap[0]), FLOOR_Y - 6.0, float(ap[1]) - float(ap[0]), 6.0)
		var c := Color(0.25, 0.3, 0.42)
		if storm_enabled and arc_active(_t, _arc_phase[i]):
			c = Color(0.75, 0.95, 1.0)
			draw_rect(Rect2(r.position.x, FLOOR_Y - 34.0, r.size.x, 28.0), Color(0.6, 0.9, 1.0, 0.35))
		elif storm_enabled and arc_telling(_t, _arc_phase[i]):
			c = Color(0.35, 0.45, 0.6).lerp(Color(0.75, 0.95, 1.0), 0.5 + 0.5 * float(int(_t * 20.0) % 2))
		draw_rect(r, c)
	# the sweep beam and its emitter
	draw_rect(Rect2(BEAM_FROM, FLOOR_Y - BEAM_H - 10.0, 26.0, BEAM_H + 10.0), Color(0.3, 0.32, 0.45))
	if storm_enabled and not _open:
		if beam_telling(_t, _beam_phase):
			draw_rect(Rect2(BEAM_FROM - 8.0, FLOOR_Y - BEAM_H, 8.0, BEAM_H), Color(1.0, 0.9, 0.4, 0.4 + 0.5 * float(int(_t * 16.0) % 2)))
		var bx := beam_x(_t, _beam_phase)
		if not is_nan(bx):
			draw_rect(Rect2(bx - BEAM_HALF_W, FLOOR_Y - BEAM_H, BEAM_HALF_W * 2.0, BEAM_H), Color(0.85, 0.95, 1.0, 0.9))
			draw_rect(Rect2(bx - BEAM_HALF_W * 0.4, FLOOR_Y - BEAM_H, BEAM_HALF_W * 0.8, BEAM_H), Color(1, 1, 1, 1))
	# lightning
	for m in _marks:
		var age: float = m["age"]
		var x: float = m["x"]
		if age < TELL:
			var f := age / TELL
			var a := 0.25 + 0.45 * f
			draw_arc(Vector2(x, FLOOR_Y - 2.0), STRIKE_HALF_W * (1.3 - 0.3 * f), 0.0, TAU, 28, Color(1.0, 0.9, 0.3, a), 4.0)
			draw_rect(Rect2(x - STRIKE_HALF_W, FLOOR_Y - 6.0, STRIKE_HALF_W * 2.0, 6.0), Color(1.0, 0.9, 0.3, a * 0.6))
			draw_rect(Rect2(x - 2.0, FLOOR_Y - 900.0, 4.0, 900.0), Color(1.0, 0.9, 0.3, a * 0.25))
		elif age < TELL + STRIKE_ACTIVE:
			draw_rect(Rect2(x - STRIKE_HALF_W, FLOOR_Y - 900.0, STRIKE_HALF_W * 2.0, 900.0), Color(0.95, 0.95, 1.0, 0.9))
			draw_rect(Rect2(x - STRIKE_HALF_W * 0.4, FLOOR_Y - 900.0, STRIKE_HALF_W * 0.8, 900.0), Color(1.0, 1.0, 1.0, 1.0))
