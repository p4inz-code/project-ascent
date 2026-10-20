class_name MachineRuntime
extends Node2D
## Builds a rolled machine out of real nodes, and rolls a brand-new one on every death (the whole
## level re-rolls each attempt: nothing can be memorised, and every roll is proven passable by
## MachineGen before it is built). Lives under the level scene like RoadCourse does.
##
## The sim world (MachinePieces.build_world) and these nodes come from the same spec, and
## tests/test_machine_build.gd checks that they agree rect for rect.

signal rolled(spec: Dictionary)

## Tests pin the roll; 0 means draw a fresh random seed each attempt.
static var fixed_seed: int = 0

var level_number: int = 1
var spec: Dictionary = {}
var seed_value: int = 0
var on_kill: Callable
var on_chip: Callable
## Called with (level, index) when the core is collected, so the level can save it.
var on_orb: Callable
var theme: LevelData.LevelTheme = null
var boss_factor: float = 1.0
var rolls: int = 0

var _nodes: Array = []


func setup(p_level: int, p_theme: LevelData.LevelTheme, p_on_kill: Callable, p_on_chip: Callable,
		p_boss_factor: float = 1.0, p_on_orb: Callable = Callable()) -> void:
	on_orb = p_on_orb
	level_number = p_level
	theme = p_theme
	on_kill = p_on_kill
	on_chip = p_on_chip
	boss_factor = p_boss_factor


## A readable 8-character seed for the HUD and for sharing a roll.
static func seed_code(s: int) -> String:
	var alphabet := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
	var out := ""
	var v: int = absi(s)
	for i in 8:
		out += alphabet[v % alphabet.length()]
		v = int(v / alphabet.length()) + (i + 1) * 7
	return out


func roll(force_seed: int = 0) -> void:
	clear()
	if force_seed != 0:
		seed_value = force_seed
	elif fixed_seed != 0:
		seed_value = fixed_seed
	else:
		seed_value = int(Time.get_ticks_usec() % 2147483647) ^ int(randi())
	spec = MachineGen.roll(level_number, seed_value, boss_factor)
	rolls += 1
	_build()
	rolled.emit(spec)


## Build a given spec instead of rolling one (tests replay exact layouts).
func build_spec(p_spec: Dictionary) -> void:
	clear()
	spec = p_spec
	_build()
	rolled.emit(spec)


func clear() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_nodes.clear()
	# Freed nodes leave this frame; remove from the tree now so a fresh roll never overlaps them.
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _add(n: Node) -> void:
	add_child(n)
	_nodes.append(n)


func _build() -> void:
	var platform_scene := preload("res://scenes/platform.tscn")
	var pc := theme.platform_color if theme != null else Color(0.2, 0.22, 0.3)
	var ec := theme.edge_color if theme != null else Color(0.42, 0.58, 0.76)
	var wc := theme.wall_color if theme != null else Color(0.14, 0.16, 0.22)
	for d in MachinePieces.solids_of(spec):
		var r: Rect2 = d["rect"]
		if r.end.x <= MachinePieces.START_X - 1.0 and String(d["kind"]) != "roof":
			continue      # the start hinge is the level's own Ground platform
		if r.position.x < MachinePieces.START_X and String(d["kind"]) != "roof":
			r = Rect2(MachinePieces.START_X, r.position.y, r.end.x - MachinePieces.START_X, r.size.y)
		var node: Node2D
		match String(d["kind"]):
			"belt":
				var belt := ConveyorBelt.new()
				belt.size = r.size
				belt.color = pc
				belt.edge_color = ec
				belt.push_speed = float(d["belt"]["speed"])
				belt.direction = int(d["belt"]["dir"])
				node = belt
			"ice", "slick":
				var surf := SurfacePlatform.new()
				surf.kind = SurfacePlatform.Kind.ICE
				surf.ice_slip = MachinePieces.ICE_SLIP if String(d["kind"]) == "ice" else MachinePieces.SLICK_SLIP
				surf.size = r.size
				surf.color = pc.lerp(Color(0.25, 0.45, 0.6), 0.5) if String(d["kind"]) == "ice" else pc.darkened(0.1)
				surf.edge_color = Color(0.65, 0.9, 1.0) if String(d["kind"]) == "ice" else ec
				node = surf
			"roof":
				var roof = platform_scene.instantiate()
				roof.size = r.size
				roof.color = wc
				roof.edge_color = wc.lightened(0.1)
				roof.edge_thickness = 0.0
				node = roof
			_:
				var plat = platform_scene.instantiate()
				plat.size = r.size
				plat.color = pc
				plat.edge_color = ec
				plat.edge_thickness = 5.0
				node = plat
		node.position = r.get_center()
		_add(node)
		if (String(d["kind"]) == "ice" or String(d["kind"]) == "slick") and TileDecor.has_pattern("ice"):
			var idecor := TileDecor.new()
			idecor.kind = "ice"
			idecor.size = r.size
			node.add_child(idecor)
		if String(d["kind"]) == "belt" and TileDecor.has_pattern("conveyor"):
			var decor := TileDecor.new()
			decor.kind = "conveyor"
			decor.size = r.size
			decor.direction = int(d["belt"]["dir"])
			node.add_child(decor)
	_build_backdrop(pc)
	_build_nook()
	for cell in spec["cells"]:
		for p in MachinePieces.cell_pieces(cell):
			_build_piece(p)


## The inside of the tube: a dark back wall with ribs and pipes, so the machine reads as one long
## piece of machinery rather than platforms floating in the sky.
func _build_backdrop(base: Color) -> void:
	var x0 := MachinePieces.START_X - 200.0
	var x1 := float(spec["end_x"]) + 600.0
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(x0, MachinePieces.CEIL_Y), Vector2(x1, MachinePieces.CEIL_Y),
		Vector2(x1, MachinePieces.FLOOR_Y), Vector2(x0, MachinePieces.FLOOR_Y)])
	wall.color = base.darkened(0.62)
	wall.color.a = 0.93
	wall.z_index = -6
	_add(wall)
	var rib_col := base.darkened(0.45)
	var x := x0
	while x < x1:
		var rib := Polygon2D.new()
		rib.polygon = PackedVector2Array([
			Vector2(x, MachinePieces.CEIL_Y), Vector2(x + 14.0, MachinePieces.CEIL_Y),
			Vector2(x + 14.0, MachinePieces.FLOOR_Y), Vector2(x, MachinePieces.FLOOR_Y)])
		rib.color = rib_col
		rib.z_index = -5
		_add(rib)
		x += 260.0
	for py in [MachinePieces.CEIL_Y + 26.0, MachinePieces.DECK_Y - 60.0, MachinePieces.FLOOR_Y - 70.0]:
		var pipe := Polygon2D.new()
		pipe.polygon = PackedVector2Array([
			Vector2(x0, py), Vector2(x1, py), Vector2(x1, py + 12.0), Vector2(x0, py + 12.0)])
		pipe.color = base.lightened(0.05)
		pipe.color.a = 0.35
		pipe.z_index = -5
		_add(pipe)


## The core in its nook (the ledge itself is one of the solids).
func _build_nook() -> void:
	if not spec.has("nook"):
		return
	var orb := Orb.new()
	orb.kind = Orb.Kind.OPTIONAL
	orb.level_num = level_number
	orb.index = 0
	orb.position = spec["nook"]["orb"]
	if on_orb.is_valid():
		orb.collected.connect(on_orb)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.save_system != null and gm.save_system.has_orb(level_number, 0):
		orb.mark_already_taken()
	_add(orb)


func _build_piece(p: Dictionary) -> void:
	var x: float = float(p["x"]) if p.has("x") else 0.0
	var lane: String = p["lane"]
	var base_y: float = MachinePieces.FLOOR_Y if lane == "L" else MachinePieces.DECK_Y
	match String(p["k"]):
		"spikes":
			var s := SpikeRow.new()
			s.width = float(p["w"])
			s.position = Vector2(x, base_y)
			s.player_hit.connect(on_chip)
			_add(s)
		"rspike_gap":
			var rs := SpikeRow.new()
			rs.width = float(p["sw"])
			rs.hang = true
			rs.tooth_height = float(p["len"])
			rs.position = Vector2(float(p["sx"]), MachinePieces.CEIL_Y)
			rs.player_hit.connect(on_chip)
			_add(rs)
		"flame":
			var f := FlameJet.new()
			f.width = float(p["w"])
			f.period = float(p["period"])
			f.active = float(p["active"])
			f.tell = float(p["tell"])
			f.phase = float(p["phase"])
			f.position = Vector2(x, MachinePieces.FLOOR_Y)
			f.player_hit.connect(on_chip)
			_add(f)
		"jet":
			var j := AirJet.new()
			var top := MachinePieces.DECK_Y + 20.0
			j.size = Vector2(float(p["w"]), MachinePieces.FLOOR_Y - top)
			j.position = Vector2(x, top)
			_add(j)
		"crusher":
			var cr := Crusher.new()
			cr.width = float(p["w"])
			cr.period = float(p["period"])
			cr.active = float(p["active"])
			cr.tell = float(p["tell"])
			cr.phase = float(p["phase"])
			cr.position = Vector2(x, MachinePieces.FLOOR_Y)
			cr.player_hit.connect(on_kill)
			_add(cr)
		"hail":
			var hc := HailColumn.new()
			hc.width = float(p["w"])
			hc.period = float(p["period"])
			hc.active = float(p["active"])
			hc.tell = float(p["tell"])
			hc.phase = float(p["phase"])
			hc.position = Vector2(x, MachinePieces.CEIL_Y)
			hc.player_hit.connect(on_chip)
			_add(hc)
		"pit":
			var lava := Lava.new()
			var depth := 300.0
			lava.size = Vector2(float(p["w"]), depth)
			lava.sensor_depth = MachinePieces.PIT_KILL_DEPTH - MachinePieces.PIT_SURFACE
			lava.position = Vector2(x + float(p["w"]) * 0.5, MachinePieces.FLOOR_Y + MachinePieces.PIT_SURFACE + depth * 0.5)
			lava.player_hit.connect(on_kill)
			_add(lava)
