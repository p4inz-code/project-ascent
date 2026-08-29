class_name LevelData
extends RefCounted
## Static definitions for all 10 playable levels.
##
## Each level defines its terrain platforms, spawn point, goal position,
## kill depth, visual theme, and optional boss configuration.
## Act I (1-5): Foundation — learn, practice, master, pressure, boss.
## Act II (6-10): Mastery — endurance, precision, combo, pressure, master boss.

const TOTAL_LEVELS: int = 10
const CHECKPOINT_LEVELS: Array[int] = [5, 10, 15, 20]

## Visual theme for each level: base platform color, edge color, background tint.
class LevelTheme:
	var platform_color: Color
	var edge_color: Color
	var wall_color: Color
	var bg_tint: Color

	func _init(p_color: Color = Color(0.212, 0.231, 0.302),
			e_color: Color = Color(0.42, 0.58, 0.76),
			w_color: Color = Color(0.145, 0.161, 0.216),
			b_tint: Color = Color.WHITE) -> void:
		platform_color = p_color
		edge_color = e_color
		wall_color = w_color
		bg_tint = b_tint


## A single platform definition.
class PlatformDef:
	var name: String
	var position: Vector2
	var size: Vector2
	var color: Color
	var edge_color: Color
	var edge_thickness: float

	func _init(n: String, pos: Vector2, sz: Vector2,
			col: Color = Color(0.212, 0.231, 0.302),
			edge_col: Color = Color(0.42, 0.58, 0.76),
			edge_thick: float = 5.0) -> void:
		name = n
		position = pos
		size = sz
		color = col
		edge_color = edge_col
		edge_thickness = edge_thick


## Boss configuration for Level 5.
class BossConfig:
	var enabled: bool = false
	var minion_count: int = 4
	var boss_speed: float = 180.0
	var minion_speed: float = 200.0
	var trigger_x: float = 0.0  # X position that triggers the chase
	var boss_start: Vector2 = Vector2.ZERO


## Complete level definition.
class LevelDef:
	var number: int
	var name: String
	var spawn_point: Vector2
	var goal_position: Vector2
	var goal_size: Vector2
	var kill_depth: float
	var platforms: Array[PlatformDef]
	var theme: LevelTheme
	var boss_config: BossConfig
	var wall_slide_sections: bool
	var dash_required: bool


# ============================================================================
# LEVEL 1 — INTRODUCTION
# The existing designed ascent. Clean, forgiving, teaches basic movement.
# ============================================================================
static func level_1() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.212, 0.231, 0.302),   # platform
		Color(0.42, 0.58, 0.76),      # edge
		Color(0.145, 0.161, 0.216),   # wall
	)
	var def := LevelDef.new()
	def.number = 1
	def.name = "INTRODUCTION"
	def.spawn_point = Vector2(350, 680)
	def.goal_position = Vector2(3800, 136)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 1400.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = false
	def.dash_required = true

	def.platforms = [
		# Ground — wide starting area
		PlatformDef.new("Ground", Vector2(280, 1050), Vector2(660, 620),
			theme.wall_color, theme.edge_color, 5.0),
		# Left boundary wall
		PlatformDef.new("LeftWall", Vector2(-260, 480), Vector2(40, 1760),
			theme.wall_color, theme.edge_color, 0.0),
		# Section 1 — gentle intro jumps
		PlatformDef.new("S1_1", Vector2(780, 710), Vector2(180, 36),
			theme.platform_color, theme.edge_color),
		PlatformDef.new("S1_2", Vector2(1060, 640), Vector2(170, 32),
			theme.platform_color, theme.edge_color),
		# Section 2 — ascending steps
		PlatformDef.new("S2_1", Vector2(1330, 590), Vector2(140, 28),
			theme.platform_color, theme.edge_color),
		PlatformDef.new("S2_2", Vector2(1580, 530), Vector2(130, 28),
			theme.platform_color, theme.edge_color),
		PlatformDef.new("S2_3", Vector2(1810, 480), Vector2(140, 32),
			theme.platform_color, theme.edge_color),
		# Section 3 — wider platforms, steady climb
		PlatformDef.new("S3_1", Vector2(2050, 440), Vector2(160, 32),
			theme.platform_color, theme.edge_color),
		# Section 4 — the dash gate
		PlatformDef.new("S4_A", Vector2(2300, 430), Vector2(200, 32),
			theme.platform_color, theme.edge_color),
		PlatformDef.new("S4_B", Vector2(2750, 430), Vector2(220, 32),
			theme.platform_color, theme.edge_color),
		# Section 5 — narrow platform
		PlatformDef.new("S5_1", Vector2(3050, 380), Vector2(140, 32),
			theme.platform_color, theme.edge_color),
		# Section 6 — final ascent
		PlatformDef.new("S6_1", Vector2(3300, 300), Vector2(120, 28),
			theme.platform_color, theme.edge_color),
		PlatformDef.new("S6_2", Vector2(3550, 240), Vector2(130, 32),
			theme.platform_color, theme.edge_color),
		# Pit decoration walls
		PlatformDef.new("PitA_Left", Vector2(1660, 800), Vector2(40, 400),
			theme.wall_color, theme.edge_color, 0.0),
		PlatformDef.new("PitA_Right", Vector2(1760, 800), Vector2(40, 400),
			theme.wall_color, theme.edge_color, 0.0),
		PlatformDef.new("PitB_Left", Vector2(2140, 750), Vector2(40, 400),
			theme.wall_color, theme.edge_color, 0.0),
		PlatformDef.new("PitB_Right", Vector2(2220, 750), Vector2(40, 400),
			theme.wall_color, theme.edge_color, 0.0),
		PlatformDef.new("PitC_Left", Vector2(3380, 650), Vector2(40, 400),
			theme.wall_color, theme.edge_color, 0.0),
		PlatformDef.new("PitC_Right", Vector2(3460, 650), Vector2(40, 400),
			theme.wall_color, theme.edge_color, 0.0),
		# Top ledge — golden edge signals the goal
		PlatformDef.new("TopLedge", Vector2(3800, 200), Vector2(200, 32),
			theme.platform_color, Color(1.0, 0.827, 0.471)),
		# Right boundary wall
		PlatformDef.new("ShaftWall", Vector2(3920, 480), Vector2(40, 1760),
			theme.wall_color, theme.edge_color, 0.0),
	]
	return def


# ============================================================================
# LEVEL 2 — BASIC ASCENT
# Longer, more variation, slightly harder gaps. Still forgiving.
# Introduces narrower platforms and moderate vertical sections.
# ============================================================================
static func level_2() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.220, 0.240, 0.310),
		Color(0.44, 0.60, 0.78),
		Color(0.150, 0.168, 0.224),
	)
	var def := LevelDef.new()
	def.number = 2
	def.name = "BASIC ASCENT"
	def.spawn_point = Vector2(200, 800)
	def.goal_position = Vector2(4000, 66)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 1600.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = false
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		# Ground — wide start
		PlatformDef.new("Ground", Vector2(200, 1000), Vector2(500, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-200, 400), Vector2(40, 1800), wc, ec, 0.0),
		# Section 1 — intro (slightly harder than Level 1)
		PlatformDef.new("S1_1", Vector2(630, 810), Vector2(150, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(900, 740), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1140, 680), Vector2(140, 28), pc, ec),
		# Section 2 — ascending series (tighter gaps)
		PlatformDef.new("S2_1", Vector2(1380, 620), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1600, 560), Vector2(110, 28), pc, ec),
		PlatformDef.new("S2_3", Vector2(1810, 500), Vector2(130, 32), pc, ec),
		PlatformDef.new("S2_4", Vector2(2020, 450), Vector2(120, 28), pc, ec),
		# Section 3 — wider gap, needs dash
		PlatformDef.new("S3_1", Vector2(2260, 440), Vector2(180, 32), pc, ec),
		PlatformDef.new("S3_2", Vector2(2620, 420), Vector2(200, 32), pc, ec),
		# Section 4 — tight stepping
		PlatformDef.new("S4_1", Vector2(2880, 380), Vector2(110, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(3080, 330), Vector2(110, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3280, 280), Vector2(120, 28), pc, ec),
		# Section 5 — final climb
		PlatformDef.new("S5_1", Vector2(3500, 230), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_2", Vector2(3720, 180), Vector2(140, 32), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(4000, 130), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(4120, 400), Vector2(40, 1800), wc, ec, 0.0),
	# No decorative pit walls — they must not overlap playable platforms
	]
	return def


# ============================================================================
# LEVEL 3 — MOVEMENT CONFIDENCE
# Proper level. Longer traversal, vertical sections, precision jumps,
# wall interaction introduced. Last relatively safe level.
# ============================================================================
static func level_3() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.230, 0.245, 0.320),
		Color(0.46, 0.62, 0.80),
		Color(0.155, 0.172, 0.230),
	)
	var def := LevelDef.new()
	def.number = 3
	def.name = "MOVEMENT CONFIDENCE"
	def.spawn_point = Vector2(200, 850)
	def.goal_position = Vector2(4450, -24)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 1800.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		# Ground
		PlatformDef.new("Ground", Vector2(200, 1050), Vector2(500, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-160, 300), Vector2(40, 2000), wc, ec, 0.0),
		# Section 1 — intro with moderate gaps
		PlatformDef.new("S1_1", Vector2(580, 870), Vector2(150, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(810, 810), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1020, 750), Vector2(140, 28), pc, ec),
		PlatformDef.new("S1_4", Vector2(1230, 700), Vector2(120, 28), pc, ec),
		# Section 2 — vertical climb
		PlatformDef.new("S2_1", Vector2(1350, 620), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1480, 540), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_3", Vector2(1350, 460), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_4", Vector2(1480, 380), Vector2(120, 28), pc, ec),
		# Section 3 — wider platforms with bigger jumps (no wall-jump needed)
		PlatformDef.new("S3_1", Vector2(1620, 440), Vector2(130, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1780, 380), Vector2(130, 24), pc, ec),
		# Section 4 — precision stepping
		PlatformDef.new("S4_1", Vector2(1850, 300), Vector2(120, 24), pc, ec),
		PlatformDef.new("S4_2", Vector2(2030, 250), Vector2(110, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(2210, 200), Vector2(110, 24), pc, ec),
		PlatformDef.new("S4_4", Vector2(2390, 150), Vector2(120, 28), pc, ec),
		# Section 5 — dash gap
		PlatformDef.new("S5_1", Vector2(2730, 140), Vector2(180, 32), pc, ec),
		PlatformDef.new("S5_2", Vector2(3130, 130), Vector2(180, 32), pc, ec),
		# Section 6 — mixed terrain
		PlatformDef.new("S6_1", Vector2(3370, 100), Vector2(120, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3570, 60), Vector2(110, 24), pc, ec),
		PlatformDef.new("S6_3", Vector2(3770, 20), Vector2(120, 28), pc, ec),
		# Section 7 — final approach
		PlatformDef.new("S7_1", Vector2(4000, 0), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4230, -20), Vector2(130, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(4450, -40), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(4570, 300), Vector2(40, 2000), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 4 — DIFFICULTY BEGINS
# Now demanding skill. Narrow platforms, larger gaps, wall-jump requirements,
# more meaningful fall punishment, complex mechanic combinations.
# ============================================================================
static func level_4() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.240, 0.220, 0.280),   # slightly warmer/darker
		Color(0.50, 0.55, 0.72),
		Color(0.165, 0.155, 0.210),
	)
	var def := LevelDef.new()
	def.number = 4
	def.name = "THE CLIMB"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(5000, -44)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2000.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		# Ground
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2200), wc, ec, 0.0),
		# Section 1 — tight intro, no room for error
		PlatformDef.new("S1_1", Vector2(500, 920), Vector2(120, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(700, 860), Vector2(110, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(880, 800), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_4", Vector2(1050, 740), Vector2(110, 24), pc, ec),
		# Section 2 — wall-jump shaft
		PlatformDef.new("WallL_1", Vector2(1180, 500), Vector2(40, 600), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1340, 500), Vector2(40, 600), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1260, 620), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1260, 460), Vector2(80, 20), pc, ec),
		# Section 3 — precision stepping with bigger gaps
		PlatformDef.new("S3_1", Vector2(1480, 410), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1680, 360), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1870, 310), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_4", Vector2(2060, 260), Vector2(90, 20), pc, ec),
		# Section 4 — dash over void
		PlatformDef.new("S4_1", Vector2(2300, 250), Vector2(160, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2720, 240), Vector2(160, 28), pc, ec),
		# Section 5 — alternating wall jumps
		PlatformDef.new("WallL_2", Vector2(2880, 100), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(3040, 100), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2960, 180), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2960, 60), Vector2(80, 20), pc, ec),
		# Section 6 — final gauntlet
		PlatformDef.new("S6_1", Vector2(3200, 100), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3400, 60), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(3600, 30), Vector2(100, 24), pc, ec),
		# Section 7 — dash to recovery
		PlatformDef.new("S7_1", Vector2(3850, 50), Vector2(160, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4180, 80), Vector2(140, 28), pc, ec),
		# Section 8 — final climb
		PlatformDef.new("S8_1", Vector2(4400, 60), Vector2(120, 24), pc, ec),
		PlatformDef.new("S8_2", Vector2(4600, 40), Vector2(110, 24), pc, ec),
		PlatformDef.new("S8_3", Vector2(4800, 30), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5000, 20), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5120, 200), Vector2(40, 2200), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 5 — FIRST BOSS CHASE
# The vertical-slice finale. A long climb with boss + 4 minions pursuing.
# The player must keep moving upward while enemies close in from behind.
# ============================================================================
static func level_5() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.260, 0.200, 0.220),   # danger-tinted
		Color(0.55, 0.50, 0.65),
		Color(0.180, 0.140, 0.160),
	)
	var def := LevelDef.new()
	def.number = 5
	def.name = "ESCAPE"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(5300, -324)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2200.0
	def.theme = theme
	def.wall_slide_sections = true
	def.dash_required = true

	# Boss chase configuration
	def.boss_config = BossConfig.new()
	def.boss_config.enabled = true
	def.boss_config.minion_count = 4
	def.boss_config.boss_speed = 170.0
	def.boss_config.minion_speed = 195.0
	def.boss_config.trigger_x = 1200.0  # Chase starts when player passes x=1200
	def.boss_config.boss_start = Vector2(400, 900)

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		# Ground — wider than usual, safe intro area
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(600, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2200), wc, ec, 0.0),
		# Section 1 — platforms before the trigger (build tension)
		PlatformDef.new("S1_1", Vector2(620, 910), Vector2(140, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(880, 850), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1120, 790), Vector2(130, 28), pc, ec),
		# Section 2 — chase begins here (after trigger_x)
		PlatformDef.new("S2_1", Vector2(1300, 740), Vector2(140, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1520, 680), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_3", Vector2(1740, 620), Vector2(140, 28), pc, ec),
		PlatformDef.new("S2_4", Vector2(1960, 560), Vector2(130, 28), pc, ec),
		# Section 3 — wall-jump corridor (escape route)
		PlatformDef.new("WallL_1", Vector2(2080, 380), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(2240, 380), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S3_1", Vector2(2160, 480), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(2160, 340), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_3", Vector2(2160, 200), Vector2(100, 24), pc, ec),
		# Section 4 — dash platforms (minions spread out below)
		PlatformDef.new("S4_1", Vector2(2440, 160), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2780, 140), Vector2(160, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3100, 120), Vector2(140, 28), pc, ec),
		# Section 5 — increasing pressure, tighter platforms
		PlatformDef.new("S5_1", Vector2(3340, 80), Vector2(110, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3540, 40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_3", Vector2(3740, 0), Vector2(110, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(3940, -40), Vector2(100, 24), pc, ec),
		# Section 6 — wall-jump escape (boss gets faster here)
		PlatformDef.new("WallL_2", Vector2(4060, -180), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(4220, -180), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S6_1", Vector2(4140, -100), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(4140, -220), Vector2(80, 20), pc, ec),
		# Section 7 — final dash escape
		PlatformDef.new("S7_1", Vector2(4400, -200), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4700, -220), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5000, -240), Vector2(140, 28), pc, ec),
		# Top ledge — THE ESCAPE
		PlatformDef.new("TopLedge", Vector2(5300, -260), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5420, -100), Vector2(40, 2200), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 6 — ENDURANCE
# First Act II level. Noticeably longer, sustained platforming.
# Tests stamina and consistency across many sections.
# ============================================================================
static func level_6() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.230, 0.250, 0.310),
		Color(0.48, 0.58, 0.75),
		Color(0.155, 0.175, 0.225),
	)
	var def := LevelDef.new()
	def.number = 6
	def.name = "ENDURANCE"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5000, -64)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2200.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = false
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(500, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2400), wc, ec, 0.0),
		# Section 1 — warm-up (moderate gaps)
		PlatformDef.new("S1_1", Vector2(600, 960), Vector2(150, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(850, 900), Vector2(140, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1100, 840), Vector2(130, 28), pc, ec),
		# Section 2 — ascending series (tighter gaps)
		PlatformDef.new("S2_1", Vector2(1350, 780), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1580, 720), Vector2(110, 28), pc, ec),
		PlatformDef.new("S2_3", Vector2(1800, 660), Vector2(130, 32), pc, ec),
		PlatformDef.new("S2_4", Vector2(2020, 600), Vector2(120, 28), pc, ec),
		# Section 3 — wider dash gap
		PlatformDef.new("S3_1", Vector2(2220, 560), Vector2(160, 32), pc, ec),
		PlatformDef.new("S3_2", Vector2(2580, 520), Vector2(180, 32), pc, ec),
		# Section 4 — precision stepping
		PlatformDef.new("S4_1", Vector2(2850, 480), Vector2(110, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(3060, 430), Vector2(100, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(3250, 380), Vector2(110, 28), pc, ec),
		PlatformDef.new("S4_4", Vector2(3460, 330), Vector2(100, 24), pc, ec),
		# Section 5 — recovery + climb
		PlatformDef.new("S5_1", Vector2(3700, 300), Vector2(140, 32), pc, ec),
		PlatformDef.new("S5_2", Vector2(4000, 260), Vector2(130, 28), pc, ec),
		# Section 6 — final approach
		PlatformDef.new("S6_1", Vector2(4250, 200), Vector2(120, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(4480, 140), Vector2(130, 32), pc, ec),
		PlatformDef.new("S7_1", Vector2(4720, 80), Vector2(140, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5000, 0), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5120, 300), Vector2(40, 2400), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 7 — PRECISION
# Smaller landing zones, carefully timed jumps, control over speed.
# Tests precision rather than raw movement.
# ============================================================================
static func level_7() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.240, 0.240, 0.300),
		Color(0.50, 0.56, 0.73),
		Color(0.160, 0.165, 0.220),
	)
	var def := LevelDef.new()
	def.number = 7
	def.name = "PRECISION"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(4800, -164)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2000.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = false
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1050), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2200), wc, ec, 0.0),
		# Section 1 — narrow platforms, small gaps
		PlatformDef.new("S1_1", Vector2(550, 910), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(730, 850), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_3", Vector2(900, 790), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_4", Vector2(1080, 730), Vector2(90, 20), pc, ec),
		# Section 2 — ascending precision
		PlatformDef.new("S2_1", Vector2(1250, 680), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_2", Vector2(1430, 620), Vector2(90, 20), pc, ec),
		PlatformDef.new("S2_3", Vector2(1600, 560), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_4", Vector2(1780, 500), Vector2(90, 20), pc, ec),
		# Section 3 — recovery platform + dash gap
		PlatformDef.new("S3_1", Vector2(1960, 450), Vector2(110, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(2180, 400), Vector2(100, 24), pc, ec),
		# Section 4 — wider platforms (breather)
		PlatformDef.new("S4_1", Vector2(2400, 350), Vector2(120, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2650, 310), Vector2(110, 24), pc, ec),
		# Section 5 — dash gate
		PlatformDef.new("S5_1", Vector2(2900, 260), Vector2(140, 32), pc, ec),
		PlatformDef.new("S5_2", Vector2(3200, 220), Vector2(130, 28), pc, ec),
		# Section 6 — narrow final approach
		PlatformDef.new("S6_1", Vector2(3450, 170), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3640, 120), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(3830, 70), Vector2(100, 24), pc, ec),
		# Section 7 — final climb
		PlatformDef.new("S7_1", Vector2(4050, 20), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4300, -40), Vector2(110, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4550, -100), Vector2(120, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(4800, -120), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(4920, 100), Vector2(40, 2200), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 8 — COMBO
# Combines wall-jump, dash, precision in flowing sequences.
# Tests mastery of the full movement system.
# ============================================================================
static func level_8() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.250, 0.230, 0.290),
		Color(0.52, 0.54, 0.71),
		Color(0.170, 0.160, 0.215),
	)
	var def := LevelDef.new()
	def.number = 8
	def.name = "COMBO"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5200, -324)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2400.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2400), wc, ec, 0.0),
		# Section 1 — intro
		PlatformDef.new("S1_1", Vector2(550, 960), Vector2(140, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(780, 900), Vector2(130, 28), pc, ec),
		# Wall-jump shaft 1
		PlatformDef.new("WallL_1", Vector2(1000, 700), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1160, 700), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1080, 800), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1080, 650), Vector2(80, 20), pc, ec),
		# Dash section
		PlatformDef.new("S3_1", Vector2(1350, 600), Vector2(140, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1700, 560), Vector2(150, 28), pc, ec),
		# Wall-jump shaft 2
		PlatformDef.new("WallL_2", Vector2(1950, 400), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2110, 400), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S4_1", Vector2(2030, 500), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(2030, 350), Vector2(80, 20), pc, ec),
		# Precision stepping
		PlatformDef.new("S5_1", Vector2(2300, 300), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(2500, 250), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(2700, 200), Vector2(100, 24), pc, ec),
		# Dash over void
		PlatformDef.new("S6_1", Vector2(2950, 180), Vector2(140, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3300, 160), Vector2(150, 28), pc, ec),
		# Wall-jump shaft 3
		PlatformDef.new("WallL_3", Vector2(3550, 0), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_3", Vector2(3710, 0), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S7_1", Vector2(3630, 100), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(3630, -50), Vector2(80, 20), pc, ec),
		# Final approach
		PlatformDef.new("S8_1", Vector2(3900, -80), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_2", Vector2(4150, -140), Vector2(110, 24), pc, ec),
		PlatformDef.new("S8_3", Vector2(4400, -200), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_4", Vector2(4800, -260), Vector2(130, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5200, -280), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5320, -50), Vector2(40, 2400), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 9 — PRESSURE
# High-pressure level preparing for the Level 10 boss.
# Long sequences, tight platforms, visual warning systems.
# ============================================================================
static func level_9() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.255, 0.215, 0.265),
		Color(0.54, 0.50, 0.68),
		Color(0.175, 0.150, 0.200),
	)
	var def := LevelDef.new()
	def.number = 9
	def.name = "PRESSURE"
	def.spawn_point = Vector2(200, 1000)
	def.goal_position = Vector2(5400, -384)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2600.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = false
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1150), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2600), wc, ec, 0.0),
		# Section 1 — tight intro
		PlatformDef.new("S1_1", Vector2(530, 1010), Vector2(110, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(720, 950), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(900, 890), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_4", Vector2(1080, 830), Vector2(100, 24), pc, ec),
		# Section 2 — ascending precision
		PlatformDef.new("S2_1", Vector2(1260, 770), Vector2(90, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1440, 710), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_3", Vector2(1620, 650), Vector2(90, 20), pc, ec),
		PlatformDef.new("S2_4", Vector2(1800, 590), Vector2(100, 24), pc, ec),
		# Section 3 — wider gap + recovery
		PlatformDef.new("S3_1", Vector2(2000, 540), Vector2(130, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(2250, 490), Vector2(120, 28), pc, ec),
		# Section 4 — precision stepping
		PlatformDef.new("S4_1", Vector2(2500, 430), Vector2(100, 24), pc, ec),
		PlatformDef.new("S4_2", Vector2(2700, 370), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_3", Vector2(2900, 310), Vector2(100, 24), pc, ec),
		# Section 5 — dash gate
		PlatformDef.new("S5_1", Vector2(3150, 260), Vector2(140, 32), pc, ec),
		PlatformDef.new("S5_2", Vector2(3450, 210), Vector2(130, 28), pc, ec),
		# Section 6 — narrow final approach
		PlatformDef.new("S6_1", Vector2(3700, 160), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3900, 100), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(4100, 40), Vector2(100, 24), pc, ec),
		# Section 7 — final climb
		PlatformDef.new("S7_1", Vector2(4350, -20), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4600, -80), Vector2(110, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4850, -140), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5100, -200), Vector2(130, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5400, -340), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5520, -100), Vector2(40, 2600), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 10 — MASTER ESCAPE
# Act II climax. Faster boss, 5 minions, longer chase.
# Tests everything learned in Levels 6-9.
# ============================================================================
static func level_10() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.270, 0.190, 0.210),
		Color(0.58, 0.48, 0.62),
		Color(0.185, 0.135, 0.155),
	)
	var def := LevelDef.new()
	def.number = 10
	def.name = "MASTER ESCAPE"
	def.spawn_point = Vector2(200, 1000)
	def.goal_position = Vector2(5600, -524)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2800.0
	def.theme = theme
	def.wall_slide_sections = true
	def.dash_required = true

	# Boss: faster than Level 5, 5 minions
	def.boss_config = BossConfig.new()
	def.boss_config.enabled = true
	def.boss_config.minion_count = 5
	def.boss_config.boss_speed = 220.0
	def.boss_config.minion_speed = 240.0
	def.boss_config.trigger_x = 1400.0
	def.boss_config.boss_start = Vector2(500, 1000)

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		# Ground — wider intro area
		PlatformDef.new("Ground", Vector2(200, 1150), Vector2(600, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2800), wc, ec, 0.0),
		# Section 1 — pre-chase (3 platforms)
		PlatformDef.new("S1_1", Vector2(650, 1010), Vector2(140, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(920, 950), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1180, 890), Vector2(130, 28), pc, ec),
		# Section 2 — chase begins (after trigger_x=1400)
		PlatformDef.new("S2_1", Vector2(1420, 830), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1650, 770), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_3", Vector2(1880, 710), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_4", Vector2(2100, 650), Vector2(120, 28), pc, ec),
		# Wall-jump corridor
		PlatformDef.new("WallL_1", Vector2(2300, 480), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(2460, 480), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S3_1", Vector2(2380, 580), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(2380, 430), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2380, 280), Vector2(80, 20), pc, ec),
		# Dash platforms
		PlatformDef.new("S4_1", Vector2(2650, 240), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2950, 210), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3250, 180), Vector2(140, 28), pc, ec),
		# Tighter platforms (boss faster here)
		PlatformDef.new("S5_1", Vector2(3500, 140), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3700, 100), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(3900, 60), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4100, 20), Vector2(90, 20), pc, ec),
		# Wall-jump escape
		PlatformDef.new("WallL_2", Vector2(4300, -140), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(4460, -140), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S6_1", Vector2(4380, -60), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(4380, -200), Vector2(80, 20), pc, ec),
		# Final dash escape
		PlatformDef.new("S7_1", Vector2(4650, -220), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4950, -260), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5250, -300), Vector2(140, 28), pc, ec),
		# Top ledge — THE ESCAPE
		PlatformDef.new("TopLedge", Vector2(5600, -480), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5720, -200), Vector2(40, 2800), wc, ec, 0.0),
	]
	return def


# ============================================================================
# Public API
# ============================================================================

static func get_level(number: int) -> LevelDef:
	match number:
		1: return level_1()
		2: return level_2()
		3: return level_3()
		4: return level_4()
		5: return level_5()
		6: return level_6()
		7: return level_7()
		8: return level_8()
		9: return level_9()
		10: return level_10()
		_: return level_1()
