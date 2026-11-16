# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
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
var _launch: Dictionary = launch_request()
## Back walls draw just above the sky (GameScene.BACKDROP_Z) and below the level's own ground and platforms (z 0).
const WALL_Z := -2

var _nodes: Array = []

## Platform, edge and wall colours per biome (the machine's tile set): basalt, rust, ice, slate, ember.
const BIOME_TILE := {"cinder": "basalt", "scrapyard": "rust", "freezer": "frost", "storm": "slate", "forge": "ember",
	"underworks": "rust", "rift": "crystal", "core": "circuit"}
## Each of the four levels of an act wears its own surface, tint and back wall, so no two levels of an act look alike.
const BIOME_TILE_SET := {
	"cinder": ["basalt", "ember", "basalt", "slate"],
	"scrapyard": ["rust", "slate", "basalt", "rust"],
	"freezer": ["frost", "slate", "frost", "basalt"],
	"storm": ["slate", "basalt", "rust", "slate"],
	"forge": ["ember", "basalt", "rust", "ember"],
	"underworks": ["rust", "slate", "circuit", "basalt"],
	"rift": ["crystal", "slate", "frost", "crystal"],
	"core": ["circuit", "ember", "crystal", "basalt"],
}
## Hue shift (turns), value scale and the back-wall kind for the four level slots of an act (the boss uses slot 0).
const SLOT_LOOK := [
	{"hue": 0.0, "value": 1.0, "wall": "ribs"},
	{"hue": 0.045, "value": 1.12, "wall": "girders"},
	{"hue": -0.05, "value": 0.9, "wall": "chains"},
	{"hue": 0.09, "value": 1.05, "wall": "fans"},
]


static func slot_of(level: int) -> int:
	var s := (level - 1) % 5
	return s if s < 4 else 0


## The tile surface a level wears (boss levels and unknown biomes fall back to the act's main surface).
static func tile_for(biome: String, level: int) -> String:
	var set: Array = BIOME_TILE_SET.get(biome, [])
	if set.is_empty() or (level - 1) % 5 == 4:
		return String(BIOME_TILE.get(biome, ""))
	return String(set[slot_of(level)])


static func tinted(c: Color, level: int) -> Color:
	var look: Dictionary = SLOT_LOOK[slot_of(level)]
	var out := Color.from_hsv(fposmod(c.h + float(look["hue"]), 1.0), c.s, clampf(c.v * float(look["value"]), 0.0, 1.0), c.a)
	return out
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


const CODE_ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const CODE_LEN := 8
const MAX_SEED := 2147483647


## A readable 8-character seed for the HUD and for sharing a roll. It is plain base 31, so it can be read
## back with seed_from_code: type it in with --roll=CODE and the same machine is built.
static func seed_code(s: int) -> String:
	var base := CODE_ALPHABET.length()
	var out := ""
	var v: int = absi(s)
	for i in CODE_LEN:
		out = CODE_ALPHABET[v % base] + out
		v = int(v / base)
	return out


## The seed a code stands for, or 0 when the code is not a code (wrong length, a letter outside the
## alphabet, or too large). Spaces, dashes and lower case are forgiven.
static func seed_from_code(code: String) -> int:
	var c := code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if c.length() != CODE_LEN:
		return 0
	var base := CODE_ALPHABET.length()
	var v := 0
	for i in CODE_LEN:
		var d := CODE_ALPHABET.find(c[i])
		if d < 0:
			return 0
		v = v * base + d
		if v > MAX_SEED:
			return 0
	return v


## The day's seed for a level attempt: the same for everyone on the same UTC date, a different roll for
## every attempt, so the daily cannot be memorised. date_key is YYYYMMDD.
static func daily_seed(date_key: int, level: int, attempt: int) -> int:
	var h := hash([date_key, level, attempt, 8675309])
	return int(absi(h) % MAX_SEED) + 1


static func today_key() -> int:
	var d := Time.get_date_dict_from_system(true)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## What the command line asks for: {"mode": "roll"|"daily"|"", "seed": int}. --roll=CODE replays one roll
## (the same machine on every attempt, for practising or sharing); --daily plays the day's seeds.
static func launch_request(args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var a := args
	if a.is_empty():
		a = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in a:
		if arg.begins_with("--roll="):
			var s := seed_from_code(arg.get_slice("=", 1))
			if s != 0:
				return {"mode": "roll", "seed": s}
		elif arg == "--daily":
			return {"mode": "daily", "seed": 0}
	return {"mode": "", "seed": 0}


func roll(force_seed: int = 0) -> void:
	clear()
	if force_seed != 0:
		seed_value = force_seed
	elif fixed_seed != 0:
		seed_value = fixed_seed
	elif String(_launch.get("mode", "")) == "roll":
		seed_value = int(_launch["seed"])
	elif String(_launch.get("mode", "")) == "daily":
		seed_value = daily_seed(today_key(), level_number, rolls)
	else:
		# masked to 31 bits so every code shown on the HUD can be replayed with --roll
		seed_value = (int(Time.get_ticks_usec() % 2147483647) ^ int(randi())) & MAX_SEED
		if seed_value == 0:
			seed_value = 1
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
	pc = tinted(pc, level_number)
	ec = tinted(ec, level_number)
	wc = tinted(wc, level_number)
	_dress_hinge(pc, ec)
	var base_pc := pc
	var base_ec := ec
	var mixed: bool = spec.get("recipe", {}).has("segments")
	for d in MachinePieces.solids_of(spec):
		var r: Rect2 = d["rect"]
		# a mixed machine (the Echo exam, ENDLESS): every section wears its own biome's colours
		var seg_pal: Array = BIOME_PALETTE.get(_segment_biome(r.position.x), []) if mixed else []
		pc = seg_pal[0] if not seg_pal.is_empty() else base_pc
		ec = seg_pal[1] if not seg_pal.is_empty() else base_ec
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
	pc = base_pc
	ec = base_ec
	if _is_runner():
		_build_lake()
	else:
		_build_backdrop(pc)
		_build_nook()
	for cell in spec["cells"]:
		for p in MachinePieces.cell_pieces(cell):
			_build_piece(p)
	if StormEvents.applies_to(level_number):
		var se := StormEvents.new()
		se.calm_ranges = StormEvents.calm_ranges_of(spec)
		se.player = get_tree().get_first_node_in_group("player") as Player if get_tree() != null else null
		se.chip.connect(on_chip)
		_add(se)
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
		cf.style = String(spec["front"].get("style", "collapse"))
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
	# the shaft floor wears the scrapyard look too (it kept the old act's dusk purple)
	_dress_hinge(pal[0], pal[1])
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
	# The inside of the shaft. The back wall runs the full height of the side walls and the masonry carries on
	# far past both of them, so the camera never shows the dark panel ending in mid-air or a lone column of wall
	# standing in open sky (both were visible in the owner's round-2 screenshot).
	var top_y := TowerGen.FLOOR_Y - 5000.0
	# well past the bottom of any view: the flood rises from below the floor, and the sky must never show there
	var bot_y := TowerGen.FLOOR_Y + 1600.0
	var first_wall_node := _nodes.size()
	var back := Polygon2D.new()
	back.polygon = PackedVector2Array([Vector2(0, top_y), Vector2(TowerGen.W, top_y), Vector2(TowerGen.W, bot_y), Vector2(0, bot_y)])
	back.color = Color(pal[2]).darkened(0.5)
	back.z_index = -6
	_add(back)
	var stone := Color(pal[2]).darkened(0.18)
	for side in [[-2200.0, -60.0], [TowerGen.W + 60.0, TowerGen.W + 2200.0]]:
		_wall_rect(Rect2(float(side[0]), top_y, float(side[1]) - float(side[0]), bot_y - top_y + 1400.0), stone)
	# courses of masonry outside, girders and rivet plates inside: a sense of height while climbing
	var gy := TowerGen.FLOOR_Y - 180.0
	var gi := 0
	while gy > top_y:
		_wall_rect(Rect2(0.0, gy, TowerGen.W, 12.0), Color(Color(pal[0]).darkened(0.25), 0.55))
		_wall_rect(Rect2(120.0 + 340.0 * float(gi % 4), gy - 84.0, 54.0, 36.0), Color(Color(pal[1]).darkened(0.45), 0.28))
		for side2 in [[-2200.0, -60.0], [TowerGen.W + 60.0, TowerGen.W + 2200.0]]:
			_wall_rect(Rect2(float(side2[0]), gy + 60.0, float(side2[1]) - float(side2[0]), 6.0), Color(stone.darkened(0.35), 0.9))
		gy -= 240.0
		gi += 1
	# In front of the sky's parallax ridges (z 0, earlier in the tree), behind the platforms: the walls are put at
	# z 0 and moved to the front of this node's children, so they draw after the backdrop and before every platform.
	# The shaft is an enclosed space; the open sky must not show through it.
	var walls: Array = _nodes.slice(first_wall_node)
	for k in walls.size():
		var w: CanvasItem = walls[walls.size() - 1 - k]
		w.z_index = WALL_Z
		move_child(w, 0)
	back.z_index = WALL_Z
	move_child(back, 0)
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
	_flood.width = TowerGen.W + 120.0      # wall to wall: the flood stays inside the shaft
	_flood.start_y = float(t["flood_start"])
	_flood.rise_speed = float(t["flood_speed"])
	_flood.climb_height = 6000.0
	_flood.color = Color(0.42, 0.30, 0.14, 0.92)
	_flood.crest_color = Color(0.85, 0.65, 0.25, 1.0)
	_flood.player_hit.connect(on_kill)
	for cd in t["cores"]:
		_nodes.append(CoreSpawner.add(self, level_number, int(cd["index"]), cd["pos"], on_orb,
			cd.get("drift", Vector2.ZERO), float(cd.get("period", 2.6)), float(cd.get("phase", 0.0))))
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


## The biome of the section a world x falls in (the level's one biome when it is not a mixed machine).
func _segment_biome(x: float) -> String:
	var rec: Dictionary = spec.get("recipe", {})
	if not rec.has("segments"):
		return String(rec.get("biome", ""))
	var segs: Array = rec["segments"]
	var cells := maxi(spec["cells"].size(), 1)
	var ci := clampi(int((x - MachinePieces.START_X) / MachinePieces.CELL_W), 0, cells - 1)
	return String(segs[mini(segs.size() - 1, ci * segs.size() / cells)])


## The level's own start platform ("Ground", built by the level scene from the def) wears the machine's colours
## and surface. It used to keep the old act theme, so every machine level opened on a dark, bare slab with a
## hard seam where the rolled floor began.
func _dress_hinge(pc: Color, ec: Color) -> void:
	var ground := get_parent().get_node_or_null("Terrain/Ground") if get_parent() != null else null
	if ground == null or not ("color" in ground) or not ("size" in ground):
		return
	var seg_pal: Array = BIOME_PALETTE.get(_segment_biome(MachinePieces.START_X), []) if spec.get("recipe", {}).has("segments") else []
	ground.color = seg_pal[0] if not seg_pal.is_empty() else pc
	ground.edge_color = seg_pal[1] if not seg_pal.is_empty() else ec
	var old := ground.get_node_or_null("HingeDecor")
	if old != null:
		ground.remove_child(old)
		old.queue_free()
	var size: Vector2 = ground.size
	var holder := Node2D.new()
	holder.name = "HingeDecor"
	ground.add_child(holder)
	_dress_tile(holder, Rect2(MachinePieces.START_X - size.x, 0.0, size.x, size.y))


## The biome surface pattern on a plain tile.
func _dress_tile(node: Node2D, r: Rect2) -> void:
	var rec: Dictionary = spec.get("recipe", {})
	var biome := _segment_biome(r.position.x)
	var kind: String = tile_for(biome, level_number) if not rec.has("segments") else String(BIOME_TILE.get(biome, ""))
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
	var first_wall_node := _nodes.size()
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(x0, MachinePieces.CEIL_Y), Vector2(x1, MachinePieces.CEIL_Y),
		Vector2(x1, MachinePieces.FLOOR_Y), Vector2(x0, MachinePieces.FLOOR_Y)])
	wall.color = base.darkened(0.62)
	wall.color.a = 0.93
	wall.z_index = -6
	_add(wall)
	var rib_col := base.darkened(0.45)
	var kind: String = String(SLOT_LOOK[slot_of(level_number)]["wall"])
	var top := MachinePieces.CEIL_Y
	var bot := MachinePieces.FLOOR_Y
	match kind:
		"girders":
			# tall X-braced girders and lit windows between them
			var gx := x0
			var gi := 0
			while gx < x1:
				_wall_rect(Rect2(gx, top, 22.0, bot - top), rib_col)
				_wall_poly(PackedVector2Array([Vector2(gx + 22.0, top + 30.0), Vector2(gx + 30.0, top + 30.0), Vector2(gx + 360.0, bot - 40.0), Vector2(gx + 352.0, bot - 40.0)]), Color(rib_col, 0.55))
				if gi % 2 == 0:
					_wall_rect(Rect2(gx + 150.0, top + 70.0, 46.0, 30.0), Color(base.lightened(0.45), 0.22))
				gx += 380.0
				gi += 1
		"chains":
			# chains hanging from the roof with hooks, different lengths
			var cx2 := x0 + 90.0
			var ci := 0
			while cx2 < x1:
				var ln := 90.0 + 55.0 * float((ci * 7) % 4)
				var y := top
				while y < top + ln:
					_wall_rect(Rect2(cx2, y, 6.0, 10.0), Color(base.lightened(0.12), 0.5))
					y += 16.0
				_wall_rect(Rect2(cx2 - 8.0, top + ln, 22.0, 8.0), Color(base.lightened(0.2), 0.55))
				cx2 += 210.0
				ci += 1
			_wall_rect(Rect2(x0, bot - 150.0, x1 - x0, 10.0), Color(base.lightened(0.05), 0.3))
		"fans":
			# big slow vents (octagons) with a hub, and thick pipes
			var fx := x0 + 200.0
			while fx < x1:
				var pts := PackedVector2Array()
				for k in 8:
					var a := TAU * float(k) / 8.0 + 0.39
					pts.append(Vector2(fx + cos(a) * 78.0, (top + bot) * 0.5 - 30.0 + sin(a) * 78.0))
				_wall_poly(pts, Color(rib_col, 0.8))
				var hub := PackedVector2Array()
				for k in 8:
					var a2 := TAU * float(k) / 8.0
					hub.append(Vector2(fx + cos(a2) * 22.0, (top + bot) * 0.5 - 30.0 + sin(a2) * 22.0))
				_wall_poly(hub, Color(base.lightened(0.15), 0.6))
				fx += 520.0
			for py2 in [top + 18.0, bot - 46.0]:
				_wall_rect(Rect2(x0, py2, x1 - x0, 20.0), Color(base.lightened(0.05), 0.35))
		_:
			var x := x0
			while x < x1:
				_wall_rect(Rect2(x, top, 14.0, bot - top), rib_col)
				x += 260.0
			for py in [top + 26.0, MachinePieces.DECK_Y - 60.0, bot - 70.0]:
				_wall_rect(Rect2(x0, py, x1 - x0, 12.0), Color(base.lightened(0.05), 0.35))
	# The tube is an enclosed space: its back wall draws in front of the sky's parallax ridges (z 0, earlier in
	# the tree) and behind everything else here. At z -6 the ridge lines cut straight across the inside of the tube.
	wall.color.a = 1.0
	var walls: Array = _nodes.slice(first_wall_node)
	for k in walls.size():
		var w: CanvasItem = walls[walls.size() - 1 - k]
		w.z_index = WALL_Z
		move_child(w, 0)


func _wall_rect(r: Rect2, c: Color) -> void:
	_wall_poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), c)


func _wall_poly(pts: PackedVector2Array, c: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	p.z_index = -5
	_add(p)


## The core in its nook (the ledge itself is one of the solids).
func _build_nook() -> void:
	for nk in spec.get("nooks", []):
		_nodes.append(CoreSpawner.add(self, level_number, int(nk["index"]), nk["orb"], on_orb,
			nk.get("drift", Vector2.ZERO), float(nk.get("period", 2.6)), float(nk.get("phase", 0.0))))


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
