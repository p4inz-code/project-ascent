class_name MachineLevel
extends RefCounted
## The LevelDef of a machine level. The terrain and hazards are NOT in the def: they are rolled by
## MachineRuntime on every attempt. The def carries only what is fixed per level: the start hinge,
## the door, the kill depth and the theme.

## Levels that are machines. Rebuilt act by act; see docs/ROADMAP_STATUS.md.
const LEVELS: Array[int] = []
## Tests and the --dev-machine flag add levels here without touching the shipped list.
static var forced: Array[int] = []


static func is_machine(number: int) -> bool:
	return number in LEVELS or number in forced


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
	var hinge_w := MachinePieces.START_X + 400.0
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), theme.wall_color, theme.edge_color, 0.0),
		P.new("Ground", Vector2(-400.0 + hinge_w * 0.5, MachinePieces.FLOOR_Y + MachinePieces.FLOOR_THICK * 0.5),
			Vector2(hinge_w, MachinePieces.FLOOR_THICK), theme.wall_color, theme.edge_color, 5.0),
	]
	var end_x := MachinePieces.START_X + float(int(recipe["cells"])) * MachinePieces.CELL_W
	def.spawn_point = Vector2(200.0, MachinePieces.FLOOR_Y - 28.0)
	def.goal_position = Vector2(end_x - 172.0, MachinePieces.DECK_Y - 48.0)
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
