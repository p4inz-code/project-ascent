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

## Platform, edge and wall colours per biome (the machine's tile set): basalt, rust, ice, slate, ember.
const BIOME_TILE := {"cinder": "basalt", "scrapyard": "rust", "freezer": "frost", "storm": "slate", "forge": "ember",
	"underworks": "rust", "rift": "frost", "core": "ember"}
const BIOME_PALETTE := {
	"cinder": [Color(0.22, 0.14, 0.12), Color(0.95, 0.45, 0.20), Color(0.12, 0.08, 0.07)],
	"scrapyard": [Color(0.30, 0.22, 0.20), Color(0.80, 0.55, 0.30), Color(0.17, 0.13, 0.12)],
	"freezer": [Color(0.20, 0.30, 0.38), Color(0.65, 0.90, 1.00), Color(0.10, 0.15, 0.20)],
	"storm": [Color(0.18, 0.21, 0.28), Color(0.55, 0.65, 0.85), Color(0.10, 0.12, 0.17)],
	"forge": [Color(0.28, 0.15, 0.10), Color(1.00, 0.70, 0.25), Color(0.14, 0.08, 0.06)],
	"underworks": [Color(0.17, 0.24, 0.26), Color(0.45, 0.80, 0.82), Color(0.09, 0.13, 0.15)],
	"rift": [Color(0.22, 0.17, 0.32), Color(0.78, 0.62, 1.00), Color(0.11, 0.09, 0.19)],
	"core": [Color(0.30, 0.14, 0.14), Color(1.00, 0.48, 0.38), Color(0.15, 0.07, 0.07)],
}


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
	if TowerGen.is_tower(level_number):
		spec = TowerGen.roll(level_number, seed_value, boss_factor)
	else:
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
	if String(spec.get("mode", "")) == "tower":
		_build_tower()
		return
	var platform_scene := preload("res://scenes/platform.tscn")
	var pal: Array = BIOME_PALETTE.get(String(spec.get("recipe", {}).get("biome", "")), [])
	var pc: Color = pal[0] if not pal.is_empty() else (theme.platform_color if theme != null else Color(0.2, 0.22, 0.3))
	var ec: Color = pal[1] if not pal.is_empty() else (theme.edge_color if theme != null else Color(0.42, 0.58, 0.76))
	var wc: Color = pal[2] if not pal.is_empty() else (theme.wall_color if theme != null else Color(0.14, 0.16, 0.22))
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
		if String(d["kind"]) in ["floor", "deck", "hump", "ledge", "nook", "tile"] or String(d["kind"]) == "":
			_dress_tile(node, r)
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
	if _is_runner():
		_build_lake()
	else:
		_build_backdrop(pc)
		_build_nook()
	for cell in spec["cells"]:
		for p in MachinePieces.cell_pieces(cell):
			_build_piece(p)
	for vd in spec.get("vents", []):
		var hv := HeatVent.new()
		hv.width = float(vd["w"])
		hv.period = float(vd["period"])
		hv.tell = float(vd["tell"])
		hv.active = float(vd["active"])
		hv.phase = float(vd["phase"])
		hv.position = Vector2(float(vd["x"]), MachinePieces.FLOOR_Y)
		_add(hv)
	if spec.has("front"):
		var cf := CollapseFront.new()
		cf.start_x = float(spec["front"]["start_x"])
		cf.speed = float(spec["front"]["speed"])
		cf.player_hit.connect(on_kill)
		_add(cf)
	if spec.has("fake_goal"):
		var fg := FakeGoal.new()
		fg.position = spec["fake_goal"]
		fg.touched.connect(func() -> void:
			var sc := get_parent().get_node_or_null("Scares") if get_parent() != null else null
			if sc != null and sc.has_method("fire") and sc.rules != null:
				sc.fire("forced", "roar"))
		_add(fg)


## THE COMPACTOR: a vertical shaft of scrap platforms, junk dropping from the ceiling and a flood that
## rises once the grace period is over. See TowerGen for what makes every roll passable.
var _flood: RisingLava = null
var _flood_t: float = 0.0
var _gauge: ColorRect = null
var _gauge_label: Label = null
var _hiss_t: float = 0.0
const GAUGE_RANGE := 700.0


func _build_tower() -> void:
	var platform_scene := preload("res://scenes/platform.tscn")
	var pal: Array = BIOME_PALETTE["scrapyard"]
	var t: Dictionary = spec["tower"]
	var solids := TowerGen.solids_of(spec)
	for i in solids.size():
		var r: Rect2 = solids[i]
		if i == 0:
			continue      # the level's own Ground platform is the base
		var plat = platform_scene.instantiate()
		plat.size = r.size
		plat.color = pal[2] if i < 3 else pal[0]
		plat.edge_color = pal[1]
		plat.edge_thickness = 0.0 if i < 3 else 5.0
		plat.position = r.get_center()
		_add(plat)
		if i >= 3:
			_dress_tile(plat, r)
	var back := Polygon2D.new()
	var top_y := float(t["goal"].position.y) - 500.0
	back.polygon = PackedVector2Array([Vector2(0, top_y), Vector2(TowerGen.W, top_y), Vector2(TowerGen.W, TowerGen.FLOOR_Y), Vector2(0, TowerGen.FLOOR_Y)])
	back.color = Color(pal[2]).darkened(0.5)
	back.z_index = -6
	_add(back)
	for jd in t["junk"]:
		var jn := JunkDrop.new()
		jn.width = float(jd["w"])
		jn.period = float(jd["period"])
		jn.tell = float(jd["tell"])
		jn.active = float(jd["active"])
		jn.phase = float(jd["phase"])
		jn.position = Vector2(float(jd["x"]), float(jd["y"]))
		jn.player_hit.connect(on_chip)
		_add(jn)
	for fr in t["fakes"]:
		var fk := FakePlatform.new()
		var fr2: Rect2 = fr
		fk.size = fr2.size
		fk.color = pal[0]
		fk.edge_color = pal[1]
		fk.position = fr2.get_center()
		_add(fk)
	_flood = RisingLava.new()
	_flood.position = Vector2(TowerGen.W * 0.5, 0.0)
	_flood.width = TowerGen.W + 400.0
	_flood.start_y = float(t["flood_start"])
	_flood.rise_speed = float(t["flood_speed"])
	_flood.climb_height = 6000.0
	_flood.color = Color(0.42, 0.30, 0.14, 0.92)
	_flood.crest_color = Color(0.85, 0.65, 0.25, 1.0)
	_flood.player_hit.connect(on_kill)
	_add(_flood)
	_flood_t = 0.0
	var layer := CanvasLayer.new()
	layer.layer = 5
	_gauge_label = Label.new()
	_gauge_label.text = "FLOOD"
	_gauge_label.position = Vector2(1696, 128)
	_gauge_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_gauge_label)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.5)
	track.position = Vector2(1696, 152)
	track.size = Vector2(160, 10)
	layer.add_child(track)
	_gauge = ColorRect.new()
	_gauge.color = Color(0.4, 0.9, 0.5)
	_gauge.position = Vector2(1696, 152)
	_gauge.size = Vector2(160, 10)
	layer.add_child(_gauge)
	_add(layer)


func _tower_process(delta: float) -> void:
	_flood_t += delta
	if _flood != null and is_instance_valid(_flood) and _flood_t >= float(spec["tower"]["grace"]) and not _flood.is_rising():
		_flood.start_rising()
	var pl := get_tree().get_first_node_in_group("player") if get_tree() != null else null
	if pl == null or _gauge == null or _flood == null or not is_instance_valid(_flood):
		return
	var dist := _flood.surface_y() - (pl as Node2D).global_position.y
	var f := clampf(dist / GAUGE_RANGE, 0.0, 1.0)
	_gauge.size.x = 160.0 * f
	_gauge.color = Color(1.0, 0.25, 0.2).lerp(Color(0.4, 0.9, 0.5), f)
	_gauge_label.text = "FLOOD  %d" % int(maxf(dist, 0.0) / 10.0)
	_hiss_t -= delta
	if dist < 260.0 and _hiss_t <= 0.0:
		_hiss_t = 1.4
		SfxHub.play(get_tree(), "vent")


## The biome surface pattern on a plain tile.
func _dress_tile(node: Node2D, r: Rect2) -> void:
	var kind: String = String(BIOME_TILE.get(String(spec.get("recipe", {}).get("biome", "")), ""))
	if kind == "" or not TileDecor.has_pattern(kind):
		return
	var deco := TileDecor.new()
	deco.kind = kind
	deco.size = r.size
	node.add_child(deco)


func _is_runner() -> bool:
	return String(spec.get("mode", "machine")) == "runner"


## The lava lake under the floating tiles. It kills on touch and beats once a second (a heartbeat:
## the surface swells and glows) like a volcano about to erupt.
var _lake: Lava = null
var _beat: float = 0.0


func _build_lake() -> void:
	_lake = Lava.new()
	var x0 := -400.0
	var x1 := float(spec["end_x"]) + 1000.0
	var top := MachinePieces.FLOOR_Y + MachinePieces.RUNNER_THICK + 20.0
	_lake.size = Vector2(x1 - x0, 420.0)
	_lake.sensor_depth = 0.0
	_lake.position = Vector2((x0 + x1) * 0.5, top + 210.0)
	_lake.player_hit.connect(on_kill)
	_add(_lake)


func _process(delta: float) -> void:
	if String(spec.get("mode", "")) == "tower":
		_tower_process(delta)
		return
	if _lake == null or not is_instance_valid(_lake):
		return
	_beat += delta
	# a swell and glow every second
	var ph := fposmod(_beat, 1.0)
	var swell := exp(-pow((ph - 0.12) / 0.10, 2.0))
	_lake.modulate = Color(1.0 + 0.35 * swell, 1.0 + 0.15 * swell, 1.0, 1.0)


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
		"gpit":
			var gc := GeyserColumn.new()
			gc.width = float(p["w"])
			gc.period = float(p["period"])
			gc.active = float(p["active"])
			gc.tell = float(p["tell"])
			gc.phase = float(p["phase"])
			gc.position = Vector2(x, MachinePieces.FLOOR_Y)
			gc.player_hit.connect(on_chip)
			_add(gc)
		"pit":
			if _is_runner():
				return      # the lake under the tiles is the lava
			var lava := Lava.new()
			var depth := 300.0
			lava.size = Vector2(float(p["w"]), depth)
			lava.sensor_depth = MachinePieces.PIT_KILL_DEPTH - MachinePieces.PIT_SURFACE
			lava.position = Vector2(x + float(p["w"]) * 0.5, MachinePieces.FLOOR_Y + MachinePieces.PIT_SURFACE + depth * 0.5)
			lava.player_hit.connect(on_kill)
			_add(lava)
			if bool(p.get("fake", false)):
				# a tile that looks like the way across and drops the moment you land on it
				var fk := FakePlatform.new()
				fk.size = Vector2(float(p["w"]) * 0.4, 28.0)
				fk.color = theme.platform_color if theme != null else Color(0.2, 0.22, 0.3)
				fk.edge_color = theme.edge_color if theme != null else Color(0.42, 0.58, 0.76)
				fk.position = Vector2(x + float(p["w"]) * 0.5, MachinePieces.FLOOR_Y + 14.0)
				_add(fk)
