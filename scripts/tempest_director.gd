class_name TempestDirector
extends Node2D
## THE TEMPEST (level 20): a reactor hall with four lightning rods. Ground-pound all four (jump, then
## Down + Jump in the air, onto the cap) and the gate to the door opens.
##
## Lightning strikes where you stood 1.25 s ago. Every STRIKE_EVERY seconds a mark is drawn on the floor
## under the player; the mark pulses for TELL seconds and then a column of lightning drops on that spot.
## So the answer to every strike is to keep moving: it is only ever dangerous to stay put, and the tell
## is a whole 1.25 s. A strike is a chip (one cell), never a kill, and each rod you pound refills them.

signal chip(source_x: float)
signal gate_open

const LEVEL := 20
const FLOOR_Y := 800.0
const ROD_X: Array[float] = [520.0, 900.0, 1280.0, 1660.0]
const ROD_H: Array[float] = [64.0, 80.0, 64.0, 80.0]
const ROD_W := 110.0
const ARENA_W := 2200.0
const TELL := 1.25
const STRIKE_EVERY := 1.1
const STRIKE_ACTIVE := 0.22
const STRIKE_HALF_W := 44.0
const GRACE := 2.5
const PERCH_X := 1090.0
const PERCH_Y := FLOOR_Y - 150.0

var player: Player = null
var pounded: Array[bool] = [false, false, false, false]
var chips: int = 0
var strikes_fired: int = 0

var _t: float = 0.0
var _since_strike: float = 0.0
var _marks: Array = []        # {x, age, hit}
var _rod_nodes: Array = []
var _open: bool = false


static func build_def(legacy: LevelData.LevelDef) -> LevelData.LevelDef:
	var def := LevelData.LevelDef.new()
	def.number = LEVEL
	def.name = "TEMPEST"
	def.theme = legacy.theme
	def.boss_config = LevelData.BossConfig.new()
	def.tempest = true
	var theme: LevelData.LevelTheme = def.theme
	var P := LevelData.PlatformDef
	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), wc, ec, 0.0),
		P.new("Ground", Vector2(ARENA_W * 0.5 - 100.0, FLOOR_Y + 250.0), Vector2(ARENA_W + 200.0, 500.0), wc, ec, 5.0),
		P.new("RightWall", Vector2(ARENA_W + 60.0, 200.0), Vector2(40.0, 2200.0), wc, ec, 0.0),
	]
	for i in ROD_X.size():
		def.platforms.append(P.new("Rod_%d" % i, Vector2(ROD_X[i], FLOOR_Y - ROD_H[i] * 0.5), Vector2(ROD_W, ROD_H[i]), pc, ec, 5.0))
	# the optional core sits on a perch between the middle rods, one rod-cap jump up
	def.platforms.append(P.new("Perch", Vector2(PERCH_X, PERCH_Y + 12.0), Vector2(110.0, 24.0), pc, ec, 5.0))
	def.checkpoints.append(LevelData.CheckpointDef.new(Vector2(1090.0, FLOOR_Y - 45.0)))
	# the gate in front of the door; opened by the rods (its lever sits out of reach below the floor)
	var pg := LevelData.PlateGateDef.new(Vector2(900.0, FLOOR_Y + 600.0), Vector2(1900.0, FLOOR_Y - 75.0), Vector2(26.0, 150.0), 7.0, 1)
	pg.use_slash = true
	def.plate_gates.append(pg)
	def.spawn_point = Vector2(160.0, FLOOR_Y - 28.0)
	def.goal_position = Vector2(2040.0, FLOOR_Y - 48.0)
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = FLOOR_Y + 1400.0
	return def


func setup(p_player: Player, on_orb: Callable = Callable()) -> void:
	player = p_player
	_build_rods()
	var orb := Orb.new()
	orb.kind = Orb.Kind.OPTIONAL
	orb.level_num = LEVEL
	orb.index = 0
	orb.position = Vector2(PERCH_X, PERCH_Y - 38.0)
	if on_orb.is_valid():
		orb.collected.connect(on_orb)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.save_system != null and gm.save_system.has_orb(LEVEL, 0):
		orb.mark_already_taken()
	add_child(orb)


func reset() -> void:
	for i in pounded.size():
		pounded[i] = false
	_t = 0.0
	_since_strike = 0.0
	_marks.clear()
	_open = false
	chips = 0
	strikes_fired = 0
	_refresh_rods()
	queue_redraw()


func _build_rods() -> void:
	for i in ROD_X.size():
		var rod := Area2D.new()
		rod.collision_layer = 0
		rod.collision_mask = 1
		rod.position = Vector2(ROD_X[i], FLOOR_Y - ROD_H[i])
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(ROD_W - 10.0, 46.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -23.0)
		rod.add_child(shape)
		var spire := Polygon2D.new()
		spire.polygon = PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(4, -150), Vector2(-4, -150)])
		spire.color = Color(0.55, 0.62, 0.78)
		rod.add_child(spire)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([Vector2(-9, -150), Vector2(9, -150), Vector2(0, -172)])
		tip.color = Color(0.9, 0.85, 0.4)
		rod.add_child(tip)
		var ring := Polygon2D.new()
		ring.polygon = PackedVector2Array([Vector2(-ROD_W * 0.5 + 6.0, -4), Vector2(ROD_W * 0.5 - 6.0, -4), Vector2(ROD_W * 0.5 - 6.0, 0), Vector2(-ROD_W * 0.5 + 6.0, 0)])
		ring.color = Color(0.95, 0.85, 0.35)
		rod.add_child(ring)
		add_child(rod)
		_rod_nodes.append({"area": rod, "spire": spire, "ring": ring})
	_refresh_rods()


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
	if not _open and rods_done() == pounded.size():
		_open = true
		gate_open.emit()
	# lightning: starts after the grace, one mark every STRIKE_EVERY, until the gate is open
	if _t >= GRACE and not _open:
		_since_strike += delta
		if _since_strike >= STRIKE_EVERY:
			_since_strike = 0.0
			_marks.append({"x": clampf(player.global_position.x, 40.0, ARENA_W - 40.0), "age": 0.0, "hit": false})
	var keep: Array = []
	for m in _marks:
		m["age"] = float(m["age"]) + delta
		var age: float = m["age"]
		if age >= TELL and not m.has("fell"):
			m["fell"] = true
			strikes_fired += 1
		if age >= TELL and age < TELL + STRIKE_ACTIVE and not bool(m["hit"]):
			var px := player.global_position.x
			if absf(px - float(m["x"])) < STRIKE_HALF_W + 14.0:
				m["hit"] = true
				chips += 1
				chip.emit(float(m["x"]))
		if age < TELL + STRIKE_ACTIVE + 0.2:
			keep.append(m)
	_marks = keep
	queue_redraw()


func _draw() -> void:
	for m in _marks:
		var age: float = m["age"]
		var x: float = m["x"]
		if age < TELL:
			var f := age / TELL
			var a := 0.25 + 0.45 * f
			var r := STRIKE_HALF_W * (1.3 - 0.3 * f)
			draw_arc(Vector2(x, FLOOR_Y - 2.0), r, 0.0, TAU, 28, Color(1.0, 0.9, 0.3, a), 4.0)
			draw_rect(Rect2(x - STRIKE_HALF_W, FLOOR_Y - 6.0, STRIKE_HALF_W * 2.0, 6.0), Color(1.0, 0.9, 0.3, a * 0.6))
		elif age < TELL + STRIKE_ACTIVE:
			draw_rect(Rect2(x - STRIKE_HALF_W, FLOOR_Y - 900.0, STRIKE_HALF_W * 2.0, 900.0), Color(0.95, 0.95, 1.0, 0.9))
			draw_rect(Rect2(x - STRIKE_HALF_W * 0.4, FLOOR_Y - 900.0, STRIKE_HALF_W * 0.8, 900.0), Color(1.0, 1.0, 1.0, 1.0))
