class_name RoadCourse
extends Node2D
## The runtime of a plain-road level: a long road cut into cells, and in every cell,
## on every attempt, a freshly rolled obstacle. Nothing sits in the same place twice.
##
## Fairness is built in, not hoped for:
##
##  * A cell is 520 px wide and holds at most one obstacle, so two obstacles are never
##    close enough to stack.
##  * Every obstacle type is passable by waiting or timing, with a guaranteed safe
##    window (timing gates), a long calm (vent pipes), a jumpable size (pits, spikes,
##    darts), or no hazard at all (tile patches). tests/test_road_course.gd drives the
##    real controller through every type, many seeds each.
##  * The layout rules never put more than two hard cells in a row, always start and
##    finish on plain road, and never repeat a type back to back.
##
## The road itself is ordinary solid platforms (so the death line, the chasers and all
## the level tests see it); tile patches and pits swap individual pieces in and out.

enum Cell { PLAIN, SPIKES, LASER, CRUSHER, PENDULUM, SHOOTER, PIT, ICE, STICKY, CONVEYOR, CRUMBLE, PIPE, WIND }

const NAMES := ["PLAIN", "SPIKES", "LASER", "CRUSHER", "PENDULUM", "SHOOTER", "PIT", "ICE", "STICKY", "CONVEYOR", "CRUMBLE", "PIPE", "WIND"]

## Cells that can kill: no more than MAX_HARD_RUN of these in a row.
const HARD := [Cell.SPIKES, Cell.LASER, Cell.CRUSHER, Cell.PENDULUM, Cell.SHOOTER, Cell.PIT, Cell.CRUMBLE]
const MAX_HARD_RUN := 2
const MAX_BUSY_RUN := 3          # any non-plain cell

## Which types each difficulty tier may roll, with weights.
const TIERS := {
	1: {Cell.PLAIN: 3, Cell.SPIKES: 3, Cell.PIT: 3, Cell.ICE: 2, Cell.STICKY: 2, Cell.CONVEYOR: 2, Cell.WIND: 2},
	2: {Cell.PLAIN: 2, Cell.SPIKES: 2, Cell.PIT: 2, Cell.LASER: 3, Cell.PENDULUM: 2, Cell.SHOOTER: 2,
		Cell.ICE: 2, Cell.STICKY: 1, Cell.CONVEYOR: 2, Cell.CRUMBLE: 2, Cell.WIND: 1},
	3: {Cell.PLAIN: 1, Cell.SPIKES: 2, Cell.PIT: 2, Cell.LASER: 3, Cell.CRUSHER: 3, Cell.PENDULUM: 3,
		Cell.SHOOTER: 3, Cell.ICE: 2, Cell.CONVEYOR: 2, Cell.CRUMBLE: 3, Cell.PIPE: 2, Cell.WIND: 2},
}

## Test hook: when true, no obstacle is ever built (autopilot suites cannot wait for them).
static var suspended: bool = false

var road: LevelData.RoadDef
var terrain: Node
var hazards: Node
var on_hit: Callable
var on_chip: Callable
var layout: Array[int] = []
var rng := RandomNumberGenerator.new()

var _dynamic: Array[Node] = []
var _swapped: Array = []        # [{base: Node, replacement: Node}]
var _rolls: int = 0


func setup(p_road: LevelData.RoadDef, p_terrain: Node, p_hazards: Node, p_on_hit: Callable,
		p_on_chip: Callable = Callable()) -> void:
	road = p_road
	terrain = p_terrain
	hazards = p_hazards
	on_hit = p_on_hit
	# Chip hazards (spikes, pendulums, shooters) cost a cell; with no chip handler they kill.
	on_chip = p_on_chip if p_on_chip.is_valid() else p_on_hit


## The layout for a road: Array[int] of Cell values, one per cell. Pure (no nodes).
static func choose_layout(p_road: LevelData.RoadDef, random: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var n := p_road.cells.size()
	var weights: Dictionary = TIERS[clampi(p_road.tier, 1, 3)]
	var hard_run := 0
	var busy_run := 0
	for i in n:
		# Open and close on plain road: a breath at the start, the door at the end.
		if i < 1 or i >= n - 1:
			out.append(Cell.PLAIN)
			hard_run = 0
			busy_run = 0
			continue
		var options: Array = []
		for t in weights:
			if t == Cell.PLAIN:
				options.append(t)
				continue
			if int(t) == (out[i - 1] if i > 0 else -1):
				continue                                  # never the same type twice in a row
			if t in HARD and hard_run >= MAX_HARD_RUN:
				continue
			if busy_run >= MAX_BUSY_RUN:
				continue
			options.append(t)
		var total := 0
		for t in options:
			total += int(weights[t])
		var pick := random.randi_range(1, maxi(total, 1))
		var chosen: int = Cell.PLAIN
		for t in options:
			pick -= int(weights[t])
			if pick <= 0:
				chosen = int(t)
				break
		out.append(chosen)
		hard_run = hard_run + 1 if chosen in HARD else 0
		busy_run = busy_run + 1 if chosen != Cell.PLAIN else 0
	return out


## Roll a new layout (a new attempt). seed < 0 means truly random.
func roll(seed_value: int = -1) -> void:
	if suspended or road == null:
		return
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_clear()
	layout = choose_layout(road, rng)
	for i in layout.size():
		if layout[i] != Cell.PLAIN:
			_build_cell(i, layout[i])
	_rolls += 1


## Force a specific layout (tests): types by index, everything else plain.
func force(types: Dictionary, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_clear()
	layout = []
	for i in road.cells.size():
		layout.append(int(types.get(i, Cell.PLAIN)))
	for i in layout.size():
		if layout[i] != Cell.PLAIN:
			_build_cell(i, layout[i])


func rolls() -> int:
	return _rolls


func _clear() -> void:
	for pair in _swapped:
		var base: Node = pair["base"]
		var rep: Node = pair["replacement"]
		if is_instance_valid(base):
			base.visible = true
			if base is CollisionObject2D:
				(base as CollisionObject2D).collision_layer = 3
		if is_instance_valid(rep):
			rep.queue_free()
	_swapped.clear()
	for n in _dynamic:
		if is_instance_valid(n):
			n.queue_free()
	_dynamic.clear()


# ── geometry helpers ────────────────────────────────────────────────

func cell_left(i: int) -> float:
	return float(road.cells[i]["x"])


func cell_y(i: int) -> float:
	return float(road.cells[i]["y"])


func cell_centre_x(i: int) -> float:
	return cell_left(i) + road.cell_w * 0.5


func _piece(i: int, letter: String) -> Node2D:
	return terrain.get_node_or_null("R%d_%s" % [i, letter]) as Node2D


func _add(n: Node, parent: Node = null) -> Node:
	(parent if parent != null else hazards).add_child(n)
	_dynamic.append(n)
	return n


## Hide a base road piece and its collision (a replacement or a hole takes its place).
func _hide_piece(piece: Node2D, replacement: Node = null) -> void:
	if piece == null:
		return
	piece.visible = false
	if piece is CollisionObject2D:
		(piece as CollisionObject2D).collision_layer = 0
	_swapped.append({"base": piece, "replacement": replacement})


func _piece_rect(i: int, letter: String) -> Rect2:
	var x := cell_left(i)
	var w := road.piece_widths
	match letter:
		"A":
			return Rect2(x, cell_y(i), w[0], 60.0)
		"B":
			return Rect2(x + w[0], cell_y(i), w[1], 60.0)
		_:
			return Rect2(x + w[0] + w[1], cell_y(i), w[2], 60.0)


## A replacement floor piece of a special class, flush with the road.
func _special_floor(i: int, letter: String, cls: String) -> Node2D:
	var r := _piece_rect(i, letter)
	var node: Node2D
	match cls:
		"ice":
			var s := SurfacePlatform.new()
			s.kind = SurfacePlatform.Kind.ICE
			node = s
		"sticky":
			var s2 := SurfacePlatform.new()
			s2.kind = SurfacePlatform.Kind.STICKY
			node = s2
		"conveyor":
			var c := ConveyorBelt.new()
			c.push_speed = rng.randf_range(90.0, 150.0)
			c.direction = -1 if rng.randf() < 0.65 else 1      # mostly against you
			node = c
		_:
			node = CrumblePlatform.new()
	node.set("size", r.size)
	node.set("color", road.platform_color)
	node.set("edge_color", road.edge_color)
	node.position = r.position + r.size * 0.5
	var base := _piece(i, letter)
	terrain.add_child(node)
	_hide_piece(base, node)
	if TileDecor.has_pattern(cls):
		var d := TileDecor.new()
		d.kind = cls
		d.size = r.size
		d.direction = int(node.get("direction")) if cls == "conveyor" else 1
		node.add_child(d)
	return node


func _build_cell(i: int, type: int) -> void:
	var cx := cell_centre_x(i)
	var y := cell_y(i)
	match type:
		Cell.SPIKES:
			var group := TrapGroup.new()
			_add(group)
			var pos: Array[Vector2] = [Vector2(cx - 115.0, y), Vector2(cx + 115.0, y)]
			group.setup(pos, rng.randi_range(1, 2))
			group.slot_hit.connect(on_chip)
		Cell.LASER:
			var gate := _gate(i, TimedGate.Kind.LASER)
			_gantry(cx, y, 150.0, TimedGate.ZONE_HEIGHT)
			gate.position = Vector2(cx, y)
		Cell.CRUSHER:
			var gate2 := _gate(i, TimedGate.Kind.CRUSHER)
			# Lowered so it catches a runner, not just a jumper.
			gate2.slam_y = -40.0
			gate2.position = Vector2(cx, y)
			_gantry(cx, y, 150.0, absf(gate2.rest_y) + 40.0)
		Cell.PENDULUM:
			var pend := Pendulum.new()
			pend.arm_length = 200.0
			pend.max_angle_deg = 55.0
			pend.swing_speed = rng.randf_range(1.3, 2.0)
			pend.phase_offset = rng.randf_range(0.0, TAU)
			var pivot_h := rng.randf_range(255.0, 275.0)
			pend.position = Vector2(cx, y - pivot_h)
			pend.player_hit.connect(on_chip)
			_add(pend)
			_gantry(cx, y, 150.0, pivot_h + 14.0)
		Cell.SHOOTER:
			var shooter := ShooterTrap.new()
			shooter.direction = Vector2(-1.0, 0.0)
			shooter.interval = rng.randf_range(2.0, 2.7)
			shooter.range_px = 500.0
			shooter.position = Vector2(cell_left(i) + road.cell_w - 20.0, y - 28.0)
			shooter.player_hit.connect(on_chip)
			_add(shooter)
			var pillar := Gantry.new()
			pillar.style = Gantry.Style.PILLAR
			pillar.height = 28.0
			pillar.position = Vector2(shooter.position.x, y)
			_add(pillar)
		Cell.PIT:
			_pit(i, false)
		Cell.CRUMBLE:
			_pit(i, true)
		Cell.ICE:
			for letter in ["A", "B", "C"]:
				_special_floor(i, letter, "ice")
		Cell.STICKY:
			for letter in ["A", "B", "C"]:
				_special_floor(i, letter, "sticky")
		Cell.CONVEYOR:
			var dir := -1 if rng.randf() < 0.65 else 1
			for letter in ["A", "B", "C"]:
				var belt := _special_floor(i, letter, "conveyor")
				belt.set("direction", dir)
				belt.set("push_speed", 120.0)
		Cell.PIPE:
			var pipe := PipeTube.new()
			pipe.length = road.cell_w
			pipe.rise = 0.0
			pipe.phase_offset = rng.randf_range(0.0, 3.0)
			pipe.idle_time = rng.randf_range(1.6, 2.2)
			pipe.position = Vector2(cell_left(i), y)
			_add(pipe)
		Cell.WIND:
			var zone := WindZone.new()
			zone.size = Vector2(300.0, 220.0)
			zone.force = Vector2(rng.randf_range(110.0, 160.0) * (-1.0 if rng.randf() < 0.7 else 1.0), 0.0)
			zone.position = Vector2(cx, y - 110.0)
			_add(zone)


func _gate(i: int, kind: int) -> TimedGate:
	var gate := TimedGate.new()
	gate.kind = kind as TimedGate.Kind
	# Always a calm of at least MIN_SAFE_WINDOW, with a random length and offset.
	gate.safe_time = rng.randf_range(1.5, 2.3)
	gate.warn_time = 0.6
	gate.active_time = rng.randf_range(0.5, 0.6)
	gate.phase_offset = rng.randf_range(0.0, gate.period())
	gate.player_hit.connect(on_hit)
	_add(gate)
	return gate


func _gantry(x: float, y: float, span: float, height: float) -> void:
	var g := Gantry.new()
	g.span = span
	g.height = height
	g.position = Vector2(x, y)
	_add(g)


## A hole in the road with a pool below (acid, lava or water by biome). `bridged`
## puts a crumbling plate over it instead of leaving it open.
func _pit(i: int, bridged: bool) -> void:
	var rect := _piece_rect(i, "B")
	var y := cell_y(i)
	var base := _piece(i, "B")
	var pool := Lava.new()
	pool.style = road.pool_style
	pool.size = Vector2(rect.size.x, 150.0)
	pool.sensor_depth = 30.0
	# Visible surface 12 px under the road; lethal 30 px below that surface.
	pool.position = Vector2(rect.position.x + rect.size.x * 0.5, y + 12.0 + pool.size.y * 0.5)
	pool.player_hit.connect(on_hit)
	_add(pool)
	if bridged:
		var plate := CrumblePlatform.new()
		plate.size = Vector2(rect.size.x + 16.0, 30.0)
		plate.color = road.platform_color
		plate.edge_color = road.edge_color
		# Long enough to cross at a run; it crumbles if you stop to think.
		plate.crumble_delay = 0.95
		plate.respawn_delay = 2.4
		plate.position = Vector2(rect.position.x + rect.size.x * 0.5, y + 15.0)
		# Drawn over the pool, not under it.
		plate.z_index = 2
		terrain.add_child(plate)
		_hide_piece(base, plate)
		var d := TileDecor.new()
		d.kind = "crumble"
		d.size = plate.size
		plate.add_child(d)
	else:
		_hide_piece(base, null)
