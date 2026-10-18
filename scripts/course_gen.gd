class_name CourseGen
extends RefCounted
## Builds the plain-road levels: a long, mostly flat road with few jumps, where the
## challenge is the obstacles, and the obstacles are different every attempt.
##
## The road geometry is fixed (and checked by the ordinary level tests); only the
## obstacles are rolled at run time (RoadCourse). A few cells step up so there is the
## occasional jump, never more than STEP_UP (well inside the jump height).

const ROAD_Y := 800.0
const START_W := 700.0
const STEP_UP := 48.0

## Every plain-road level: number -> options.
const ROADS := {
	3:  {"name": "DUSTWAY", "cells": 12, "tier": 1, "pool": 0, "seed": 31},
	5:  {"name": "THE BORER", "cells": 16, "tier": 2, "pool": 1, "seed": 51, "boss": true, "auto_run": true, "limit": 85.0},
	8:  {"name": "SCRAPYARD", "cells": 16, "tier": 2, "pool": 2, "seed": 81},
	13: {"name": "CRYO LANE", "cells": 16, "tier": 3, "pool": 1, "seed": 131},
	15: {"name": "WARDEN'S MILE", "cells": 18, "tier": 3, "pool": 2, "seed": 151, "boss": true, "limit": 90.0},
	18: {"name": "STORM LANE", "cells": 18, "tier": 3, "pool": 0, "seed": 181, "checkpoints": true},
	23: {"name": "APEX RUN", "cells": 20, "tier": 3, "pool": 0, "seed": 231, "checkpoints": true},
}


static func is_road(level_number: int) -> bool:
	return ROADS.has(level_number)


## Build a road level. `legacy` supplies the theme so each level keeps its act's colours.
static func road_level(level_number: int, legacy) -> LevelData.LevelDef:
	var opt: Dictionary = ROADS[level_number]
	var def := LevelData.LevelDef.new()
	def.number = level_number
	def.name = String(opt["name"])
	def.theme = legacy.theme
	def.boss_config = LevelData.BossConfig.new()
	var theme: LevelData.LevelTheme = def.theme
	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	var rng := RandomNumberGenerator.new()
	rng.seed = int(opt["seed"])
	var cell_w := 520.0
	var road := LevelData.RoadDef.new()
	road.cell_w = cell_w
	road.tier = int(opt["tier"])
	road.pool_style = int(opt["pool"])
	road.platform_color = pc
	road.edge_color = ec

	var platforms: Array[LevelData.PlatformDef] = []
	platforms.append(LevelData.PlatformDef.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), wc, ec, 0.0))
	platforms.append(LevelData.PlatformDef.new("Ground", Vector2(START_W * 0.5, ROAD_Y + 250.0),
		Vector2(START_W, 500.0), wc, ec, 5.0))

	var n: int = int(opt["cells"])
	var y := ROAD_Y
	var x := START_W
	var since_step := 99
	for i in n:
		# A step up between cells now and then (never two in a row, never in the first
		# or last two cells): the road's few jumps.
		if i >= 2 and i < n - 2 and since_step >= 3 and rng.randf() < 0.28:
			y -= STEP_UP
			since_step = 0
		else:
			since_step += 1
		road.cells.append({"x": x, "y": y})
		var wA: float = road.piece_widths[0]
		var wB: float = road.piece_widths[1]
		var wC: float = road.piece_widths[2]
		platforms.append(LevelData.PlatformDef.new("R%d_A" % i, Vector2(x + wA * 0.5, y + 30.0), Vector2(wA, 60.0), pc, ec))
		platforms.append(LevelData.PlatformDef.new("R%d_B" % i, Vector2(x + wA + wB * 0.5, y + 30.0), Vector2(wB, 60.0), pc, ec))
		platforms.append(LevelData.PlatformDef.new("R%d_C" % i, Vector2(x + wA + wB + wC * 0.5, y + 30.0), Vector2(wC, 60.0), pc, ec))
		x += cell_w
	# The finish: a ledge and the door.
	platforms.append(LevelData.PlatformDef.new("TopLedge", Vector2(x + 300.0, y + 30.0), Vector2(600.0, 60.0), pc, ec, 5.0))
	def.platforms = platforms
	def.road = road
	def.spawn_point = Vector2(200.0, ROAD_Y - 28.0)
	def.goal_position = Vector2(x + 400.0, y - 48.0)
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = ROAD_Y + 1400.0
	def.auto_run = bool(opt.get("auto_run", false))

	if bool(opt.get("checkpoints", false)):
		var every := 6
		var k := every
		while k < n - 2:
			var c: Dictionary = road.cells[k]
			def.checkpoints.append(LevelData.CheckpointDef.new(Vector2(float(c["x"]) + cell_w * 0.5, float(c["y"]) - 45.0)))
			k += every

	if bool(opt.get("boss", false)):
		var cfg := def.boss_config
		cfg.enabled = true
		cfg.minion_count = 3
		cfg.boss_speed = 175.0
		cfg.minion_speed = 200.0
		cfg.trigger_x = 1100.0
		cfg.boss_start = Vector2(300.0, ROAD_Y - 60.0)
		cfg.time_limit = float(opt.get("limit", 85.0))
		# The floor climbs past road level near the end of the countdown.
		def.rise_end_y = ROAD_Y - 300.0

	def.hints = [] as Array[LevelData.HintDef]
	return def
