class_name LevelData
extends RefCounted
## Static definitions for all 10 playable levels.
##
## Each level defines its terrain platforms, spawn point, goal position,
## kill depth, visual theme, and optional boss configuration.
## Act I (1-5): Foundation — learn, practice, master, pressure, boss.
## Act II (6-10): Mastery — endurance, precision, combo, pressure, master boss.

const TOTAL_LEVELS: int = 25
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
		# Section 1 — intro (each jump: ~80px up, ~200px right)
		PlatformDef.new("S1_1", Vector2(580, 870), Vector2(150, 32), pc, ec),
		PlatformDef.new("S1_2", Vector2(830, 810), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1060, 750), Vector2(140, 28), pc, ec),
		PlatformDef.new("S1_4", Vector2(1290, 690), Vector2(130, 28), pc, ec),
		# Section 2 — ascending climb (each jump: ~80px up, ~200px right)
		PlatformDef.new("S2_1", Vector2(1520, 630), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1750, 570), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_3", Vector2(1980, 510), Vector2(130, 28), pc, ec),
		PlatformDef.new("S2_4", Vector2(2210, 450), Vector2(120, 28), pc, ec),
		# Section 3 — dash gap
		PlatformDef.new("S3_1", Vector2(2510, 420), Vector2(160, 32), pc, ec),
		PlatformDef.new("S3_2", Vector2(2870, 390), Vector2(160, 32), pc, ec),
		# Section 4 — precision stepping
		PlatformDef.new("S4_1", Vector2(3130, 340), Vector2(120, 24), pc, ec),
		PlatformDef.new("S4_2", Vector2(3370, 280), Vector2(110, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(3610, 220), Vector2(120, 28), pc, ec),
		# Section 5 — final approach
		PlatformDef.new("S5_1", Vector2(3870, 160), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_2", Vector2(4130, 100), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(4450, 40), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
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
# LEVEL 11 — TRAVERSE
# Act III begins. Longer horizontal traversal, moderate vertical.
# Environmental depth increases — darker palette.
# ============================================================================
static func level_11() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.220, 0.210, 0.270),
		Color(0.45, 0.52, 0.70),
		Color(0.150, 0.145, 0.200),
	)
	var def := LevelDef.new()
	def.number = 11
	def.name = "TRAVERSE"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5200, -164)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2400.0
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
		# Section 1 — warm-up
		PlatformDef.new("S1_1", Vector2(600, 960), Vector2(140, 28), pc, ec),
		PlatformDef.new("S1_2", Vector2(830, 900), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1060, 840), Vector2(120, 24), pc, ec),
		PlatformDef.new("S1_4", Vector2(1280, 780), Vector2(130, 28), pc, ec),
		# Section 2 — ascending series
		PlatformDef.new("S2_1", Vector2(1500, 720), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_2", Vector2(1700, 660), Vector2(120, 24), pc, ec),
		PlatformDef.new("S2_3", Vector2(1920, 600), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_4", Vector2(2140, 540), Vector2(120, 24), pc, ec),
		# Section 3 — dash gap
		PlatformDef.new("S3_1", Vector2(2360, 500), Vector2(140, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(2720, 460), Vector2(150, 28), pc, ec),
		# Section 4 — precision stepping
		PlatformDef.new("S4_1", Vector2(2980, 420), Vector2(100, 24), pc, ec),
		PlatformDef.new("S4_2", Vector2(3180, 370), Vector2(110, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(3400, 320), Vector2(100, 24), pc, ec),
		# Section 5 — recovery + climb
		PlatformDef.new("S5_1", Vector2(3620, 280), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_2", Vector2(3860, 230), Vector2(120, 24), pc, ec),
		# Section 6 — final approach
		PlatformDef.new("S6_1", Vector2(4100, 180), Vector2(110, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(4340, 120), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_1", Vector2(4600, 60), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4880, 0), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5200, -40), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5320, 200), Vector2(40, 2400), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 12 — RISING
# More vertical, tighter platforms, steeper ascent.
# ============================================================================
static func level_12() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.210, 0.200, 0.260),
		Color(0.43, 0.50, 0.68),
		Color(0.145, 0.140, 0.195),
	)
	var def := LevelDef.new()
	def.number = 12
	def.name = "RISING"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(5000, -284)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2600.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1050), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2400), wc, ec, 0.0),
		# Section 1 — tight intro
		PlatformDef.new("S1_1", Vector2(500, 910), Vector2(110, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(680, 840), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(860, 770), Vector2(110, 24), pc, ec),
		# Section 2 — wall-jump shaft
		PlatformDef.new("WallL_1", Vector2(1020, 580), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1180, 580), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1100, 680), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1100, 530), Vector2(80, 20), pc, ec),
		# Section 3 — ascending precision
		PlatformDef.new("S3_1", Vector2(1350, 480), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1550, 410), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1750, 340), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_4", Vector2(1950, 270), Vector2(90, 20), pc, ec),
		# Section 4 — dash gate
		PlatformDef.new("S4_1", Vector2(2200, 230), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2560, 190), Vector2(140, 28), pc, ec),
		# Section 5 — wall-jump escape
		PlatformDef.new("WallL_2", Vector2(2760, 40), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2920, 40), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2840, 120), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2840, -20), Vector2(80, 20), pc, ec),
		# Section 6 — final climb
		PlatformDef.new("S6_1", Vector2(3120, -60), Vector2(110, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3360, -120), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_3", Vector2(3600, -180), Vector2(110, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(3860, -240), Vector2(120, 24), pc, ec),
		# Section 7 — final approach
		PlatformDef.new("S7_1", Vector2(4120, -280), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4400, -320), Vector2(110, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4680, -360), Vector2(120, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5000, -400), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5120, -200), Vector2(40, 2400), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 13 — DEPTHS
# Wall-jump heavy, environmental pressure. Player feels deep underground.
# ============================================================================
static func level_13() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.190, 0.185, 0.250),
		Color(0.40, 0.48, 0.65),
		Color(0.130, 0.128, 0.185),
	)
	var def := LevelDef.new()
	def.number = 13
	def.name = "DEPTHS"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(5400, -404)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 2800.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1000), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2600), wc, ec, 0.0),
		# Section 1 — intro
		PlatformDef.new("S1_1", Vector2(500, 860), Vector2(110, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(680, 790), Vector2(100, 24), pc, ec),
		# Wall-jump shaft 1
		PlatformDef.new("WallL_1", Vector2(860, 600), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1020, 600), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(940, 700), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(940, 550), Vector2(80, 20), pc, ec),
		# Dash section
		PlatformDef.new("S3_1", Vector2(1200, 500), Vector2(130, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1540, 460), Vector2(140, 28), pc, ec),
		# Wall-jump shaft 2
		PlatformDef.new("WallL_2", Vector2(1740, 280), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(1900, 280), Vector2(40, 500), wc, ec, 0.0),
		PlatformDef.new("S4_1", Vector2(1820, 380), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(1820, 230), Vector2(80, 20), pc, ec),
		# Precision stepping
		PlatformDef.new("S5_1", Vector2(2080, 180), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(2280, 120), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(2480, 60), Vector2(100, 24), pc, ec),
		# Dash over void
		PlatformDef.new("S6_1", Vector2(2740, 30), Vector2(140, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3100, 0), Vector2(140, 28), pc, ec),
		# Wall-jump shaft 3
		PlatformDef.new("WallL_3", Vector2(3320, -160), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_3", Vector2(3480, -160), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S7_1", Vector2(3400, -80), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(3400, -200), Vector2(80, 20), pc, ec),
		# Final approach
		PlatformDef.new("S8_1", Vector2(3700, -240), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_2", Vector2(4000, -300), Vector2(110, 24), pc, ec),
		PlatformDef.new("S8_3", Vector2(4300, -360), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_4", Vector2(4620, -420), Vector2(130, 28), pc, ec),
		PlatformDef.new("S8_5", Vector2(4960, -480), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5400, -520), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5520, -300), Vector2(40, 2600), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 14 — GAUNTLET
# Combines everything. Multiple wall-jump shafts, dash gates, precision.
# ============================================================================
static func level_14() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.200, 0.190, 0.255),
		Color(0.42, 0.47, 0.66),
		Color(0.138, 0.132, 0.190),
	)
	var def := LevelDef.new()
	def.number = 14
	def.name = "GAUNTLET"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5600, -484)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3000.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2800), wc, ec, 0.0),
		# Section 1 — tight intro
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(670, 890), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(840, 820), Vector2(100, 24), pc, ec),
		# Wall-jump shaft 1
		PlatformDef.new("WallL_1", Vector2(1000, 640), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1160, 640), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1080, 730), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1080, 580), Vector2(80, 20), pc, ec),
		# Dash gate
		PlatformDef.new("S3_1", Vector2(1340, 530), Vector2(130, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1680, 490), Vector2(140, 28), pc, ec),
		# Precision stepping
		PlatformDef.new("S4_1", Vector2(1940, 440), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(2140, 380), Vector2(100, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(2340, 320), Vector2(90, 20), pc, ec),
		# Wall-jump shaft 2
		PlatformDef.new("WallL_2", Vector2(2540, 140), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2700, 140), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2620, 240), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2620, 90), Vector2(80, 20), pc, ec),
		# Dash over void
		PlatformDef.new("S6_1", Vector2(2920, 50), Vector2(140, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3280, 10), Vector2(140, 28), pc, ec),
		# Precision final
		PlatformDef.new("S7_1", Vector2(3540, -40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S7_2", Vector2(3740, -100), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_3", Vector2(3940, -160), Vector2(100, 24), pc, ec),
		# Wall-jump shaft 3
		PlatformDef.new("WallL_3", Vector2(4140, -320), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_3", Vector2(4300, -320), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S8_1", Vector2(4220, -240), Vector2(80, 20), pc, ec),
		PlatformDef.new("S8_2", Vector2(4220, -380), Vector2(80, 20), pc, ec),
		# Final approach
		PlatformDef.new("S9_1", Vector2(4500, -420), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(4780, -480), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5060, -540), Vector2(120, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5600, -600), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5720, -400), Vector2(40, 2800), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 15 — SHADOW CHASE
# Act III climax. Boss + 5 minions. Dark, hostile atmosphere.
# ============================================================================
static func level_15() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.230, 0.170, 0.200),
		Color(0.50, 0.42, 0.58),
		Color(0.160, 0.120, 0.145),
	)
	var def := LevelDef.new()
	def.number = 15
	def.name = "SHADOW CHASE"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5800, -564)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3000.0
	def.theme = theme
	def.wall_slide_sections = true
	def.dash_required = true

	def.boss_config = BossConfig.new()
	def.boss_config.enabled = true
	def.boss_config.minion_count = 5
	def.boss_config.boss_speed = 200.0
	def.boss_config.minion_speed = 225.0
	def.boss_config.trigger_x = 1300.0
	def.boss_config.boss_start = Vector2(400, 950)

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(600, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2800), wc, ec, 0.0),
		# Section 1 — pre-chase
		PlatformDef.new("S1_1", Vector2(620, 960), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_2", Vector2(870, 900), Vector2(120, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1120, 840), Vector2(120, 28), pc, ec),
		# Section 2 — chase begins
		PlatformDef.new("S2_1", Vector2(1340, 780), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1560, 720), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_3", Vector2(1780, 660), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_4", Vector2(2000, 600), Vector2(110, 24), pc, ec),
		# Wall-jump corridor
		PlatformDef.new("WallL_1", Vector2(2200, 420), Vector2(40, 480), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(2360, 420), Vector2(40, 480), wc, ec, 0.0),
		PlatformDef.new("S3_1", Vector2(2280, 520), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(2280, 370), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2280, 220), Vector2(80, 20), pc, ec),
		# Dash platforms
		PlatformDef.new("S4_1", Vector2(2560, 180), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2900, 140), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3240, 100), Vector2(140, 28), pc, ec),
		# Tighter platforms
		PlatformDef.new("S5_1", Vector2(3500, 60), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3700, 10), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(3900, -40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4100, -90), Vector2(90, 20), pc, ec),
		# Wall-jump escape
		PlatformDef.new("WallL_2", Vector2(4300, -250), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(4460, -250), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S6_1", Vector2(4380, -170), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(4380, -310), Vector2(80, 20), pc, ec),
		# Final dash escape
		PlatformDef.new("S7_1", Vector2(4660, -340), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4980, -400), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5300, -460), Vector2(140, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5800, -600), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5920, -400), Vector2(40, 2800), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 16 — STORMFRONT
# Act IV begins. Night → Storm. Longer, harder, more hostile.
# ============================================================================
static func level_16() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.195, 0.185, 0.245),
		Color(0.40, 0.44, 0.62),
		Color(0.135, 0.128, 0.180),
	)
	var def := LevelDef.new()
	def.number = 16
	def.name = "STORMFRONT"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5400, -524)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3200.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2800), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(670, 890), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(840, 820), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_4", Vector2(1010, 750), Vector2(100, 24), pc, ec),
		PlatformDef.new("WallL_1", Vector2(1180, 570), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1340, 570), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1260, 660), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1260, 510), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1500, 460), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1700, 400), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1900, 340), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_4", Vector2(2100, 280), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2360, 240), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2720, 200), Vector2(140, 28), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2940, 20), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(3100, 20), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(3020, 100), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(3020, -40), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(3300, -80), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3500, -140), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(3700, -200), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(3920, -260), Vector2(100, 24), pc, ec),
		PlatformDef.new("S7_1", Vector2(4180, -300), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4460, -360), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4740, -420), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5040, -480), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5400, -540), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5520, -350), Vector2(40, 2800), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 17 — PRECIPICE
# Extreme precision. Tiny platforms. No room for error.
# ============================================================================
static func level_17() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.185, 0.178, 0.240),
		Color(0.38, 0.42, 0.60),
		Color(0.128, 0.122, 0.175),
	)
	var def := LevelDef.new()
	def.number = 17
	def.name = "PRECIPICE"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(5300, -564)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3200.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = false
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1050), Vector2(350, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 2800), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(480, 910), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_2", Vector2(640, 840), Vector2(80, 18), pc, ec),
		PlatformDef.new("S1_3", Vector2(790, 770), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_4", Vector2(950, 700), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_1", Vector2(1110, 640), Vector2(90, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1280, 570), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_3", Vector2(1440, 500), Vector2(90, 20), pc, ec),
		PlatformDef.new("S2_4", Vector2(1600, 430), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1780, 380), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1960, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2200, 270), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2520, 220), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(2780, 170), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2960, 110), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_3", Vector2(3140, 50), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_4", Vector2(3340, -10), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(3580, -60), Vector2(130, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3900, -120), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_1", Vector2(4160, -180), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(4340, -240), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_3", Vector2(4520, -300), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_4", Vector2(4720, -360), Vector2(100, 24), pc, ec),
		PlatformDef.new("S7_5", Vector2(4960, -420), Vector2(110, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5300, -480), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5420, -300), Vector2(40, 2800), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 18 — MAELSTROM
# Chaotic combinations. Wall-jumps + dashes + precision in rapid sequence.
# ============================================================================
static func level_18() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.180, 0.172, 0.235),
		Color(0.37, 0.41, 0.58),
		Color(0.125, 0.118, 0.170),
	)
	var def := LevelDef.new()
	def.number = 18
	def.name = "MAELSTROM"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5400, -644)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3400.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3000), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(670, 890), Vector2(100, 24), pc, ec),
		PlatformDef.new("WallL_1", Vector2(840, 710), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1000, 710), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(920, 800), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(920, 650), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1200, 600), Vector2(120, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1520, 560), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_1", Vector2(1780, 500), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(1960, 430), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2140, 250), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2300, 250), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2220, 350), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2220, 200), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(2500, 150), Vector2(130, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(2840, 110), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_1", Vector2(3100, 50), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(3280, -10), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_3", Vector2(3460, -170), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_3", Vector2(3620, -170), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S8_1", Vector2(3540, -90), Vector2(80, 20), pc, ec),
		PlatformDef.new("S8_2", Vector2(3540, -230), Vector2(80, 20), pc, ec),
		PlatformDef.new("S9_1", Vector2(3820, -280), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(4100, -340), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(4380, -400), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_4", Vector2(4680, -460), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_5", Vector2(4980, -520), Vector2(120, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5400, -580), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5520, -400), Vector2(40, 3000), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 19 — THRESHOLD
# Preparation for L20 boss. High difficulty, demanding mastery.
# ============================================================================
static func level_19() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.175, 0.165, 0.230),
		Color(0.36, 0.40, 0.56),
		Color(0.122, 0.115, 0.165),
	)
	var def := LevelDef.new()
	def.number = 19
	def.name = "THRESHOLD"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5300, -604)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3400.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3000), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_2", Vector2(660, 890), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_3", Vector2(820, 820), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_4", Vector2(980, 750), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_1", Vector2(1140, 570), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1300, 570), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1220, 660), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1220, 510), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1480, 460), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(1660, 390), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1840, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_4", Vector2(2040, 260), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2280, 220), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2600, 180), Vector2(130, 28), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2820, 0), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2980, 0), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2900, 80), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2900, -60), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(3180, -100), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3380, -160), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(3580, -220), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(3800, -280), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_1", Vector2(4060, -320), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4340, -380), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4620, -440), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(4920, -500), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5300, -560), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5420, -380), Vector2(40, 3000), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 20 — TEMPEST
# Act IV climax. 2-phase boss, 6 minions. Boss 250→500 px/s.
# ============================================================================
static func level_20() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.200, 0.155, 0.190),
		Color(0.48, 0.38, 0.52),
		Color(0.140, 0.108, 0.135),
	)
	var def := LevelDef.new()
	def.number = 20
	def.name = "TEMPEST"
	def.spawn_point = Vector2(200, 1000)
	def.goal_position = Vector2(6200, -684)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3600.0
	def.theme = theme
	def.wall_slide_sections = true
	def.dash_required = true

	def.boss_config = BossConfig.new()
	def.boss_config.enabled = true
	def.boss_config.minion_count = 6
	def.boss_config.boss_speed = 250.0
	def.boss_config.minion_speed = 270.0
	def.boss_config.trigger_x = 1400.0
	def.boss_config.boss_start = Vector2(400, 1000)

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1150), Vector2(600, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3200), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(620, 1010), Vector2(130, 28), pc, ec),
		PlatformDef.new("S1_2", Vector2(870, 950), Vector2(120, 28), pc, ec),
		PlatformDef.new("S1_3", Vector2(1120, 890), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_1", Vector2(1380, 830), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_2", Vector2(1600, 770), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_3", Vector2(1820, 710), Vector2(120, 28), pc, ec),
		PlatformDef.new("S2_4", Vector2(2040, 650), Vector2(110, 24), pc, ec),
		PlatformDef.new("WallL_1", Vector2(2240, 470), Vector2(40, 480), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(2400, 470), Vector2(40, 480), wc, ec, 0.0),
		PlatformDef.new("S3_1", Vector2(2320, 560), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(2320, 410), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2320, 260), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2600, 220), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2940, 180), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3280, 140), Vector2(140, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3540, 90), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3740, 30), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(3940, -30), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4140, -90), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_2", Vector2(4340, -250), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(4500, -250), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S6_1", Vector2(4420, -170), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(4420, -310), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_1", Vector2(4700, -350), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5020, -410), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5340, -470), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5660, -530), Vector2(130, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6200, -620), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(6320, -400), Vector2(40, 3200), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 21 — SUMMIT APPROACH
# Act V begins. Storm → Dawn. The final ascent begins.
# ============================================================================
static func level_21() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.190, 0.175, 0.235),
		Color(0.42, 0.42, 0.58),
		Color(0.130, 0.122, 0.175),
	)
	var def := LevelDef.new()
	def.number = 21
	def.name = "SUMMIT APPROACH"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5300, -644)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3600.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3000), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_2", Vector2(660, 890), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_3", Vector2(820, 820), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_4", Vector2(980, 750), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_1", Vector2(1140, 570), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1300, 570), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1220, 660), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1220, 510), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1480, 460), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(1660, 390), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1840, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_4", Vector2(2040, 260), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2280, 220), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2600, 180), Vector2(130, 28), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2820, 0), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2980, 0), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2900, 80), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2900, -60), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(3180, -100), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3380, -160), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(3580, -220), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(3800, -280), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_1", Vector2(4060, -320), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4340, -380), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4620, -440), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(4920, -500), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5300, -560), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5420, -380), Vector2(40, 3000), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 22 — APEX
# Maximum precision difficulty. Tiny platforms, huge consequences.
# ============================================================================
static func level_22() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.185, 0.170, 0.230),
		Color(0.40, 0.40, 0.56),
		Color(0.128, 0.118, 0.170),
	)
	var def := LevelDef.new()
	def.number = 22
	def.name = "APEX"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(5600, -724)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 3800.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1050), Vector2(350, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3200), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(470, 910), Vector2(80, 18), pc, ec),
		PlatformDef.new("S1_2", Vector2(620, 840), Vector2(80, 18), pc, ec),
		PlatformDef.new("S1_3", Vector2(770, 770), Vector2(80, 18), pc, ec),
		PlatformDef.new("S1_4", Vector2(920, 700), Vector2(80, 18), pc, ec),
		PlatformDef.new("WallL_1", Vector2(1080, 520), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1240, 520), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1160, 610), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_2", Vector2(1160, 460), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1420, 410), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_2", Vector2(1580, 340), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_3", Vector2(1740, 270), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_4", Vector2(1920, 200), Vector2(80, 18), pc, ec),
		PlatformDef.new("S4_1", Vector2(2160, 160), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2480, 120), Vector2(130, 28), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2700, -60), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2860, -60), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2780, 30), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_2", Vector2(2780, -110), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(3060, -150), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(3240, -210), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_3", Vector2(3420, -270), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_4", Vector2(3620, -330), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(3880, -370), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4180, -430), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4480, -490), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(4800, -550), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_5", Vector2(5120, -610), Vector2(130, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5600, -670), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(5720, -480), Vector2(40, 3200), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 23 — CRUCIBLE
# Endurance test. Longest level. Every mechanic required.
# ============================================================================
static func level_23() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.180, 0.168, 0.225),
		Color(0.39, 0.39, 0.54),
		Color(0.125, 0.115, 0.165),
	)
	var def := LevelDef.new()
	def.number = 23
	def.name = "CRUCIBLE"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(6000, -804)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 4000.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3400), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_2", Vector2(660, 890), Vector2(90, 20), pc, ec),
		PlatformDef.new("S1_3", Vector2(820, 820), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_1", Vector2(980, 640), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1140, 640), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1060, 730), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_2", Vector2(1060, 580), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1320, 530), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(1500, 460), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1680, 390), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_4", Vector2(1880, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2120, 280), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2440, 240), Vector2(130, 28), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2660, 60), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2820, 60), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2740, 150), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_2", Vector2(2740, 10), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(3020, -30), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(3200, -90), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_3", Vector2(3380, -150), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_4", Vector2(3580, -210), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(3820, -250), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4140, -310), Vector2(120, 24), pc, ec),
		PlatformDef.new("WallL_3", Vector2(4360, -470), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_3", Vector2(4520, -470), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S8_1", Vector2(4440, -390), Vector2(80, 18), pc, ec),
		PlatformDef.new("S8_2", Vector2(4440, -530), Vector2(80, 18), pc, ec),
		PlatformDef.new("S9_1", Vector2(4720, -570), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(5000, -630), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5280, -690), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_4", Vector2(5580, -750), Vector2(110, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6000, -810), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(6120, -580), Vector2(40, 3400), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 24 — FINAL PUSH
# Last normal level. Maximum skill required.
# ============================================================================
static func level_24() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.175, 0.165, 0.220),
		Color(0.38, 0.38, 0.52),
		Color(0.122, 0.112, 0.160),
	)
	var def := LevelDef.new()
	def.number = 24
	def.name = "FINAL PUSH"
	def.spawn_point = Vector2(200, 950)
	def.goal_position = Vector2(5900, -764)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 4000.0
	def.theme = theme
	def.boss_config = BossConfig.new()
	def.wall_slide_sections = true
	def.dash_required = true

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1100), Vector2(400, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3400), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(500, 960), Vector2(80, 18), pc, ec),
		PlatformDef.new("S1_2", Vector2(650, 890), Vector2(80, 18), pc, ec),
		PlatformDef.new("S1_3", Vector2(800, 820), Vector2(80, 18), pc, ec),
		PlatformDef.new("WallL_1", Vector2(960, 640), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(1120, 640), Vector2(40, 460), wc, ec, 0.0),
		PlatformDef.new("S2_1", Vector2(1040, 730), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_2", Vector2(1040, 580), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1300, 530), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_2", Vector2(1460, 460), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_3", Vector2(1620, 390), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_4", Vector2(1800, 320), Vector2(80, 18), pc, ec),
		PlatformDef.new("S4_1", Vector2(2040, 280), Vector2(120, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2340, 240), Vector2(120, 28), pc, ec),
		PlatformDef.new("WallL_2", Vector2(2560, 60), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(2720, 60), Vector2(40, 440), wc, ec, 0.0),
		PlatformDef.new("S5_1", Vector2(2640, 150), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_2", Vector2(2640, 10), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(2920, -30), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_2", Vector2(3080, -90), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_3", Vector2(3240, -150), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_4", Vector2(3420, -210), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(3660, -250), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(3960, -310), Vector2(110, 24), pc, ec),
		PlatformDef.new("WallL_3", Vector2(4180, -470), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_3", Vector2(4340, -470), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S8_1", Vector2(4260, -390), Vector2(80, 18), pc, ec),
		PlatformDef.new("S8_2", Vector2(4260, -530), Vector2(80, 18), pc, ec),
		PlatformDef.new("S9_1", Vector2(4540, -570), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(4840, -630), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5140, -690), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_4", Vector2(5460, -750), Vector2(110, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5900, -810), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(6020, -600), Vector2(40, 3400), wc, ec, 0.0),
	]
	return def


# ============================================================================
# LEVEL 25 — DAWN
# Final boss. 3 phases, 6 minions, 300→600 px/s. The summit.
# ============================================================================
static func level_25() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.195, 0.160, 0.185),
		Color(0.50, 0.40, 0.50),
		Color(0.140, 0.110, 0.130),
	)
	var def := LevelDef.new()
	def.number = 25
	def.name = "DAWN"
	def.spawn_point = Vector2(200, 1000)
	def.goal_position = Vector2(6600, -884)
	def.goal_size = Vector2(56, 96)
	def.kill_depth = 4200.0
	def.theme = theme
	def.wall_slide_sections = true
	def.dash_required = true

	def.boss_config = BossConfig.new()
	def.boss_config.enabled = true
	def.boss_config.minion_count = 6
	def.boss_config.boss_speed = 300.0
	def.boss_config.minion_speed = 320.0
	def.boss_config.trigger_x = 1500.0
	def.boss_config.boss_start = Vector2(400, 1000)

	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color

	def.platforms = [
		PlatformDef.new("Ground", Vector2(200, 1150), Vector2(600, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-120, 200), Vector2(40, 3600), wc, ec, 0.0),
		PlatformDef.new("S1_1", Vector2(620, 1010), Vector2(120, 28), pc, ec),
		PlatformDef.new("S1_2", Vector2(860, 950), Vector2(110, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(1100, 890), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_1", Vector2(1360, 830), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_2", Vector2(1580, 770), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_3", Vector2(1800, 710), Vector2(110, 24), pc, ec),
		PlatformDef.new("S2_4", Vector2(2020, 650), Vector2(100, 24), pc, ec),
		PlatformDef.new("WallL_1", Vector2(2220, 470), Vector2(40, 480), wc, ec, 0.0),
		PlatformDef.new("WallR_1", Vector2(2380, 470), Vector2(40, 480), wc, ec, 0.0),
		PlatformDef.new("S3_1", Vector2(2300, 560), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_2", Vector2(2300, 410), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_3", Vector2(2300, 260), Vector2(80, 18), pc, ec),
		PlatformDef.new("S4_1", Vector2(2580, 220), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2920, 180), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3260, 140), Vector2(140, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3520, 90), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3720, 30), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(3920, -30), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4120, -90), Vector2(90, 20), pc, ec),
		PlatformDef.new("WallL_2", Vector2(4320, -250), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("WallR_2", Vector2(4480, -250), Vector2(40, 400), wc, ec, 0.0),
		PlatformDef.new("S6_1", Vector2(4400, -170), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_2", Vector2(4400, -310), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(4680, -350), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5000, -410), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5320, -470), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5640, -530), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_5", Vector2(5960, -590), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6600, -820), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
		PlatformDef.new("ShaftWall", Vector2(6720, -550), Vector2(40, 3600), wc, ec, 0.0),
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
		11: return level_11()
		12: return level_12()
		13: return level_13()
		14: return level_14()
		15: return level_15()
		16: return level_16()
		17: return level_17()
		18: return level_18()
		19: return level_19()
		20: return level_20()
		21: return level_21()
		22: return level_22()
		23: return level_23()
		24: return level_24()
		25: return level_25()
		_: return level_1()
