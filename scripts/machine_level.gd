class_name MachineLevel
extends RefCounted
## The LevelDef of a machine level. The terrain and hazards are NOT in the def: they are rolled by
## MachineRuntime on every attempt. The def carries only what is fixed per level: the start hinge,
## the door, the kill depth and the theme.

## Levels that are machines. Rebuilt act by act; see docs/ROADMAP_STATUS.md.
const LEVELS: Array[int] = [6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 24, 10, 15, 25]
## Machine boss levels: a harder machine with the chase behind you. number -> [time limit s, chasers, odds factor].
## (Level 5 is the lava runner, level 20 the storm boss. The distinct boss formats of the plan come later.)
const BOSSES := {10: [95.0, 5, 0.8], 15: [100.0, 5, 0.6], 25: [120.0, 6, 0.6]}
## Boss levels built on the machine framework as an auto-run tile runner over lava (the Cinder boss).
const RUNNERS: Array[int] = [5]
## Tests and the --dev-machine flag add levels here without touching the shipped list.
static var forced: Array[int] = []
## Suites that check the classic (hand-authored) layouts set this, the way they suspend gates and roads:
## the levels then load as their classic staircases. Machine levels have their own suites.
static var suspended: bool = false


static func is_machine(number: int) -> bool:
	if suspended:
		return false
	return number in LEVELS or number in forced or number in RUNNERS


## Boss levels are gentler or harder than the curve says: the Borer is a gentle first boss.
static func boss_factor(number: int) -> float:
	if is_runner(number):
		return 0.8
	if BOSSES.has(number) and not suspended:
		return float(BOSSES[number][2])
	return 1.0


static func is_runner(number: int) -> bool:
	return not suspended and number in RUNNERS


static func build(number: int, legacy: LevelData.LevelDef) -> LevelData.LevelDef:
	var recipe := MachineGen.recipe_for(number)
	var def := LevelData.LevelDef.new()
	def.number = number
	def.name = legacy.name
	def.theme = legacy.theme
	def.boss_config = LevelData.BossConfig.new()
	def.machine = true
	var theme: LevelData.LevelTheme = def.theme
	var P := LevelData.PlatformDef
	# The start hinge: from just right of the left wall to a little past the first cell.
	var hinge_w := MachinePieces.START_X + 400.0 + 100.0
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), theme.wall_color, theme.edge_color, 0.0),
		P.new("Ground", Vector2(-100.0 + hinge_w * 0.5, MachinePieces.FLOOR_Y + MachinePieces.FLOOR_THICK * 0.5),
			Vector2(hinge_w, MachinePieces.FLOOR_THICK), theme.wall_color, theme.edge_color, 5.0),
	]
	var end_x := MachinePieces.START_X + float(int(recipe["cells"])) * MachinePieces.CELL_W
	def.spawn_point = Vector2(200.0, MachinePieces.FLOOR_Y - 28.0)
	def.goal_position = Vector2(end_x - 172.0, MachinePieces.DECK_Y - 48.0)
	if BOSSES.has(number):
		var b: Array = BOSSES[number]
		var bc := def.boss_config
		bc.enabled = true
		bc.minion_count = int(b[1])
		bc.boss_speed = 175.0
		bc.minion_speed = 200.0
		bc.trigger_x = 1500.0
		bc.boss_start = Vector2(300.0, MachinePieces.FLOOR_Y - 60.0)
		bc.time_limit = float(b[0])
	if is_runner(number):
		# THE BORER: forced auto-run over floating tiles on a lava lake, the Borer surfacing behind you.
		def.machine_mode = "runner"
		def.auto_run = true
		def.goal_position = Vector2(end_x - 172.0, MachinePieces.FLOOR_Y - 48.0)
		var cfg := def.boss_config
		cfg.enabled = true
		cfg.minion_count = 4
		cfg.boss_speed = 175.0
		cfg.minion_speed = 200.0
		cfg.trigger_x = 1100.0
		cfg.boss_start = Vector2(300.0, MachinePieces.FLOOR_Y - 60.0)
		cfg.time_limit = 85.0
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = MachinePieces.FLOOR_Y + 1000.0
	# Long machines carry checkpoint flags on their calm hinge cells. The machine re-rolls on every
	# death, but a hinge is calm in every roll, so the flag is always on safe ground.
	if bool(recipe["checkpoints"]):
		var every := MachineGen.HINGE_EVERY * 2
		var i := every
		while i < int(recipe["cells"]) - 4:
			var cx := MachinePieces.START_X + float(i) * MachinePieces.CELL_W + 260.0
			def.checkpoints.append(LevelData.CheckpointDef.new(Vector2(cx, MachinePieces.FLOOR_Y - 45.0)))
			i += every
	return def
