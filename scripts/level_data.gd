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
	## "solid" (default greybox), "crumble" (gives way, reforms),
	## "bounce" (launches the player upward on landing), "moving"
	## (rides between two points), or "conveyor" (pushes a standing player
	## horizontally). Wind push zones and spinning blades are separate
	## concepts — see WindZoneDef/SpinningBladeDef and LevelDef.wind_zones/
	## spinning_blades below — not PlatformDef kinds; main_scene.gd's terrain
	## builder has no "wind" or "blade" case here.
	var kind: String
	## Kind-specific config (e.g. "moving": {travel, speed, pause_at_ends};
	## "conveyor": {push_speed, direction}). Kept as a dictionary rather than
	## more constructor params so the common solid/crumble/bounce call sites
	## stay unchanged.
	var extra: Dictionary

	func _init(n: String, pos: Vector2, sz: Vector2,
			col: Color = Color(0.212, 0.231, 0.302),
			edge_col: Color = Color(0.42, 0.58, 0.76),
			edge_thick: float = 5.0,
			p_kind: String = "solid",
			p_extra: Dictionary = {}) -> void:
		name = n
		position = pos
		size = sz
		color = col
		edge_color = edge_col
		edge_thickness = edge_thick
		kind = p_kind
		extra = p_extra


## A wind push zone (Act IV). Not part of the landable route — built into a
## separate container so route-walking code (terrain builders, reachability
## checks) that iterates Terrain's children in order isn't confused by a
## non-solid, non-sequential hazard.
class WindZoneDef:
	var position: Vector2
	var size: Vector2
	var force: Vector2

	func _init(pos: Vector2, sz: Vector2, p_force: Vector2) -> void:
		position = pos
		size = sz
		force = p_force


## A rotating instant-death hazard bar (Act... TBD by level design). Lives in
## the Hazards container alongside wind zones, for the same reason: it's not
## part of the landable route, so route-walking code that iterates Terrain's
## children in order must never see it.
class SpinningBladeDef:
	var position: Vector2
	var radius: float
	var rotation_speed: float

	func _init(pos: Vector2, p_radius: float = 80.0, p_rotation_speed: float = 3.0) -> void:
		position = pos
		radius = p_radius
		rotation_speed = p_rotation_speed


## A static instant-death pit filling a rectangular zone — see lava.gd.
## Position it inside an existing gap between two platforms (never
## overlapping either), so it adds stakes to a jump/dash the reachability
## sweep has already proven possible, rather than changing what's reachable.
class LavaDef:
	var position: Vector2
	var size: Vector2

	func _init(pos: Vector2, sz: Vector2 = Vector2(160.0, 40.0)) -> void:
		position = pos
		size = sz


## A swinging instant-death hazard on a chain — see pendulum.gd.
class PendulumDef:
	var position: Vector2
	var arm_length: float
	var max_angle_deg: float
	var swing_speed: float
	var phase_offset: float

	func _init(pos: Vector2, p_arm_length: float = 220.0, p_max_angle_deg: float = 55.0,
			p_swing_speed: float = 1.6, p_phase_offset: float = 0.0) -> void:
		position = pos
		arm_length = p_arm_length
		max_angle_deg = p_max_angle_deg
		swing_speed = p_swing_speed
		phase_offset = p_phase_offset


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
	var wind_zones: Array[WindZoneDef] = []
	var spinning_blades: Array[SpinningBladeDef] = []
	var lava_pits: Array[LavaDef] = []
	var pendulums: Array[PendulumDef] = []
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
		# Section 3 — wider platforms, steady climb. First mechanic surprise
		# of the whole campaign: a crumble platform, gently paced (dash gate
		# is still 250px ahead, comfortably inside crumble_delay).
		PlatformDef.new("S3_1", Vector2(2050, 440), Vector2(160, 32),
			theme.platform_color, theme.edge_color, 5.0, "crumble"),
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
		# Top ledge — golden edge signals the goal
		PlatformDef.new("TopLedge", Vector2(3800, 200), Vector2(200, 32),
			theme.platform_color, Color(1.0, 0.827, 0.471)),
		# Right boundary wall
	]
	return def


# ============================================================================
# LEVEL 2 — CINDER TREK
# Act I's obby gauntlet: the campaign's gentlest introduction to the "plain
# trek broken by lava" format that recurs once per Act (see also L7, L12,
# L17, L22). Two long flat stretches over lava, each ending in a short,
# proven ascending-steps climb (identical rhythm to every other level's
# climbs) rather than one continuous staircase — the point is a level that
# reads as "run and jump across gaps," not "ascend."
# ============================================================================
static func level_2() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.220, 0.240, 0.310),
		Color(0.44, 0.60, 0.78),
		Color(0.150, 0.168, 0.224),
	)
	var def := LevelDef.new()
	def.number = 2
	def.name = "CINDER TREK"
	def.spawn_point = Vector2(200, 800)
	def.goal_position = Vector2(4700, 56)
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
		PlatformDef.new("Ground", Vector2(200, 1000), Vector2(500, 500), wc, ec, 5.0),
		PlatformDef.new("LeftWall", Vector2(-200, 400), Vector2(40, 1800), wc, ec, 0.0),
		# Trek 1 — flat, small lava gaps (115-155px), teaching the format gently
		PlatformDef.new("T1_1", Vector2(650, 800), Vector2(170, 32), pc, ec),
		PlatformDef.new("T1_2", Vector2(950, 800), Vector2(160, 32), pc, ec),
		PlatformDef.new("T1_3", Vector2(1260, 800), Vector2(150, 32), pc, ec),
		PlatformDef.new("T1_4", Vector2(1560, 800), Vector2(150, 28), pc, ec),
		# Climb 1 — same proven ~70px-rise, ~220px-run rhythm as every other level
		PlatformDef.new("C1_1", Vector2(1780, 730), Vector2(130, 28), pc, ec),
		PlatformDef.new("C1_2", Vector2(2000, 660), Vector2(120, 28), pc, ec),
		PlatformDef.new("C1_3", Vector2(2220, 590), Vector2(120, 28), pc, ec),
		# Trek 2 — wider gaps (200-215px), finishing with a real dash gate (350px)
		PlatformDef.new("T2_1", Vector2(2560, 590), Vector2(160, 32), pc, ec),
		PlatformDef.new("T2_2", Vector2(2940, 570), Vector2(170, 32), pc, ec),
		PlatformDef.new("T2_3", Vector2(3350, 540), Vector2(150, 28), pc, ec),
		# Climb 2 — final ascent to the goal, same rhythm as Climb 1
		PlatformDef.new("C2_1", Vector2(3580, 470), Vector2(120, 26), pc, ec),
		PlatformDef.new("C2_2", Vector2(3800, 400), Vector2(120, 26), pc, ec),
		PlatformDef.new("C2_3", Vector2(4020, 330), Vector2(120, 26), pc, ec),
		PlatformDef.new("C2_4", Vector2(4240, 260), Vector2(120, 26), pc, ec),
		PlatformDef.new("C2_5", Vector2(4460, 190), Vector2(130, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(4700, 120), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471)),
	]
	def.lava_pits = [
		LavaDef.new(Vector2(508, 860), Vector2(90, 280)),
		LavaDef.new(Vector2(800, 860), Vector2(110, 280)),
		LavaDef.new(Vector2(1105, 860), Vector2(120, 280)),
		LavaDef.new(Vector2(1410, 860), Vector2(120, 280)),
		LavaDef.new(Vector2(2390, 650), Vector2(160, 280)),
		LavaDef.new(Vector2(2750, 630), Vector2(170, 280)),
		LavaDef.new(Vector2(3150, 710), Vector2(240, 300)),
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
		# Section 3 — dash gap. Level 3's first moving platform — this
		# mechanic was Act III-only before; introducing it gently here (small
		# travel, generous pause at each end) so it's a familiar friend by
		# the time it reappears at real stakes later in the campaign.
		PlatformDef.new("S3_1", Vector2(2510, 420), Vector2(160, 32), pc, ec, 5.0, "moving",
			{"travel": Vector2(80.0, -20.0), "speed": 65.0, "pause_at_ends": 0.5}),
		PlatformDef.new("S3_2", Vector2(2870, 390), Vector2(160, 32), pc, ec),
		# Section 4 — precision stepping
		PlatformDef.new("S4_1", Vector2(3130, 340), Vector2(120, 24), pc, ec),
		PlatformDef.new("S4_2", Vector2(3370, 280), Vector2(110, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(3610, 220), Vector2(120, 28), pc, ec),
		# Section 5 — final approach
		PlatformDef.new("S5_1", Vector2(3870, 160), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_2", Vector2(4130, 100), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(4450, 40), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
		# Section 1 — tight intro
		PlatformDef.new("S1_1", Vector2(500, 920), Vector2(120, 24), pc, ec),
		PlatformDef.new("S1_2", Vector2(700, 860), Vector2(110, 24), pc, ec),
		PlatformDef.new("S1_3", Vector2(880, 800), Vector2(100, 24), pc, ec),
		PlatformDef.new("S1_4", Vector2(1050, 740), Vector2(110, 24), pc, ec),
		# Section 2 — ascending climb (no walls blocking)
		PlatformDef.new("S2_1", Vector2(1250, 660), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_2", Vector2(1450, 580), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_3", Vector2(1650, 500), Vector2(100, 24), pc, ec),
		PlatformDef.new("S2_4", Vector2(1850, 420), Vector2(100, 24), pc, ec),
		# Section 3 — precision stepping
		PlatformDef.new("S3_1", Vector2(2050, 360), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(2250, 300), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2450, 240), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_4", Vector2(2650, 180), Vector2(90, 20), pc, ec),
		# Section 4 — dash gap. Level 4's conveyor debut, pushing toward the
		# next platform (helps clear the gap, never hurts reachability) —
		# uses ConveyorBelt's default push_speed, strong enough to actually
		# read as "the belt is doing something" against the player's own
		# 320px/s top speed (a first attempt at 100px/s tested as
		# imperceptible during playtesting).
		PlatformDef.new("S4_1", Vector2(2900, 150), Vector2(140, 28), pc, ec, 5.0, "conveyor",
			{"direction": 1}),
		PlatformDef.new("S4_2", Vector2(3240, 120), Vector2(140, 28), pc, ec),
		# Section 5 — final approach
		PlatformDef.new("S5_1", Vector2(3500, 80), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3700, 40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_3", Vector2(3900, 0), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4120, -40), Vector2(100, 24), pc, ec),
		# Section 6 — recovery + climb
		PlatformDef.new("S6_1", Vector2(4360, -20), Vector2(130, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(4600, 0), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5000, 20), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(5960, -324)
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
		PlatformDef.new("S3_1", Vector2(2160, 480), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_1_C1", Vector2(2270, 410), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_1_C2", Vector2(2380, 340), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_1_C3", Vector2(2490, 270), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_3", Vector2(2600, 200), Vector2(100, 24), pc, ec),
		# Section 4 — dash platforms (minions spread out below). A bounce
		# pad mid-chase reads as a dramatic escape beat, and only ever helps
		# clear the gap faster — never a new way to get caught.
		PlatformDef.new("S4_1", Vector2(2880, 160), Vector2(150, 28), pc, ec, 5.0, "bounce"),
		PlatformDef.new("S4_2", Vector2(3220, 140), Vector2(160, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3540, 120), Vector2(140, 28), pc, ec),
		# Section 5 — increasing pressure, tighter platforms
		PlatformDef.new("S5_1", Vector2(3780, 80), Vector2(110, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(3980, 40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_3", Vector2(4180, 0), Vector2(110, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4380, -40), Vector2(100, 24), pc, ec),
		# Section 6 — wall-jump escape (boss gets faster here)
		PlatformDef.new("S6_1", Vector2(4580, -100), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1_C1", Vector2(4690, -160), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(4800, -220), Vector2(80, 20), pc, ec),
		# Section 7 — final dash escape
		PlatformDef.new("S7_1", Vector2(5060, -200), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5360, -220), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5660, -240), Vector2(140, 28), pc, ec),
		# Top ledge — THE ESCAPE
		PlatformDef.new("TopLedge", Vector2(5960, -260), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
		PlatformDef.new("S2_2", Vector2(1580, 720), Vector2(110, 28), pc, ec, 5.0, "crumble"),
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
		PlatformDef.new("TopLedge", Vector2(5000, 0), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	return def


# ============================================================================
# LEVEL 7 — CINDER RUN
# Act II's obby gauntlet — harder than L2's CINDER TREK: tighter lava gaps,
# a real dash gate over a wide pit, and the campaign's first one-way
# platform (solid from above, pass-through from below).
# ============================================================================
static func level_7() -> LevelDef:
	var theme := LevelTheme.new(
		Color(0.240, 0.240, 0.300),
		Color(0.50, 0.56, 0.73),
		Color(0.160, 0.165, 0.220),
	)
	var def := LevelDef.new()
	def.number = 7
	def.name = "CINDER RUN"
	def.spawn_point = Vector2(200, 900)
	def.goal_position = Vector2(4800, 81)
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
		# Trek 1 — flat, tightening lava gaps (100-145px)
		PlatformDef.new("T1_1", Vector2(580, 900), Vector2(160, 30), pc, ec),
		PlatformDef.new("T1_2", Vector2(860, 900), Vector2(150, 28), pc, ec),
		PlatformDef.new("T1_3", Vector2(1150, 900), Vector2(140, 26), pc, ec),
		PlatformDef.new("T1_4", Vector2(1430, 900), Vector2(140, 26), pc, ec),
		# Climb 1 — proven ~75px-rise, ~90px-run rhythm
		PlatformDef.new("C1_1", Vector2(1650, 825), Vector2(120, 24), pc, ec),
		PlatformDef.new("C1_2", Vector2(1870, 750), Vector2(110, 24), pc, ec),
		PlatformDef.new("C1_3", Vector2(2090, 675), Vector2(110, 24), pc, ec),
		# Trek 2 — includes this campaign's first one-way platform (solid
		# from above, pass-through from below — same forward approach as
		# any platform here, the distinct dashed underside is the tell),
		# then a real dash gate over a wide pit
		PlatformDef.new("T2_1", Vector2(2380, 675), Vector2(160, 28), pc, ec),
		PlatformDef.new("OW_1", Vector2(2650, 650), Vector2(150, 20), pc, ec, 5.0, "one_way"),
		PlatformDef.new("T2_2", Vector2(2950, 630), Vector2(160, 28), pc, ec),
		PlatformDef.new("T2_3", Vector2(3420, 590), Vector2(150, 26), pc, ec),
		# Climb 2 — final ascent to the goal, same rhythm as Climb 1
		PlatformDef.new("C2_1", Vector2(3700, 515), Vector2(110, 22), pc, ec),
		PlatformDef.new("C2_2", Vector2(3920, 440), Vector2(110, 22), pc, ec),
		PlatformDef.new("C2_3", Vector2(4140, 365), Vector2(110, 22), pc, ec),
		PlatformDef.new("C2_4", Vector2(4360, 290), Vector2(120, 24), pc, ec),
		PlatformDef.new("C2_5", Vector2(4560, 215), Vector2(130, 26), pc, ec),
		PlatformDef.new("TopLedge", Vector2(4800, 145), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	def.lava_pits = [
		LavaDef.new(Vector2(450, 960), Vector2(80, 280)),
		LavaDef.new(Vector2(722, 960), Vector2(100, 280)),
		LavaDef.new(Vector2(1007, 960), Vector2(120, 280)),
		LavaDef.new(Vector2(1290, 960), Vector2(115, 280)),
		LavaDef.new(Vector2(2222, 735), Vector2(130, 280)),
		LavaDef.new(Vector2(2517, 710), Vector2(95, 280)),
		LavaDef.new(Vector2(2797, 690), Vector2(120, 280)),
		LavaDef.new(Vector2(3187, 670), Vector2(290, 300)),
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
	def.goal_position = Vector2(5860, -344)
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
		PlatformDef.new("S2_1", Vector2(1080, 800), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1190, 725), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1300, 650), Vector2(80, 20), pc, ec),
		# Dash section
		PlatformDef.new("S3_1", Vector2(1570, 600), Vector2(140, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1920, 560), Vector2(150, 28), pc, ec, 5.0, "crumble"),
		# Wall-jump shaft 2
		PlatformDef.new("S4_1", Vector2(2250, 500), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_1_C1", Vector2(2360, 425), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(2470, 350), Vector2(80, 20), pc, ec),
		# Precision stepping
		PlatformDef.new("S5_1", Vector2(2740, 300), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(2940, 250), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(3140, 200), Vector2(100, 24), pc, ec),
		# Dash over void
		PlatformDef.new("S6_1", Vector2(3390, 180), Vector2(140, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3740, 160), Vector2(150, 28), pc, ec),
		# Wall-jump shaft 3
		PlatformDef.new("S7_1", Vector2(4070, 100), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_1_C1", Vector2(4180, 25), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(4290, -50), Vector2(80, 20), pc, ec),
		# Final approach
		PlatformDef.new("S8_1", Vector2(4560, -80), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_2", Vector2(4810, -140), Vector2(110, 24), pc, ec),
		PlatformDef.new("S8_3", Vector2(5060, -200), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_4", Vector2(5460, -260), Vector2(130, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5860, -280), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(5400, -404)
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
		PlatformDef.new("S4_1", Vector2(2500, 430), Vector2(100, 24), pc, ec, 5.0, "crumble"),
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
		# The final jump onto TopLedge broke this level's own established
		# rhythm — every other step here covers ~250px with a ~60px rise,
		# but S7_4 to the (fixed, goal-tied) TopLedge is 300px with a 142px
		# rise, well over what a flat jump reaches. Playtest feedback (an
		# experienced Godot dev, not the owner) flagged this exact jump as
		# noticeably harder than the rest of the level. Splitting it into two
		# ~65-77px rises matching the established pacing, without moving
		# TopLedge itself (goal_position stays at the proven TopLedge.y - 64
		# offset used by every level).
		PlatformDef.new("S7_5", Vector2(5230, -269), Vector2(70, 20), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5400, -340), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(6260, -544)
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
		PlatformDef.new("S3_1", Vector2(2380, 580), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C1", Vector2(2490, 505), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C2", Vector2(2600, 430), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C3", Vector2(2710, 355), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2820, 280), Vector2(80, 20), pc, ec),
		# Dash platforms
		PlatformDef.new("S4_1", Vector2(3090, 240), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(3390, 210), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3690, 180), Vector2(140, 28), pc, ec),
		# Tighter platforms (boss faster here)
		PlatformDef.new("S5_1", Vector2(3940, 140), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(4140, 100), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(4340, 60), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4540, 20), Vector2(90, 20), pc, ec),
		# Wall-jump escape
		PlatformDef.new("S6_1", Vector2(4820, -60), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1_C1", Vector2(4930, -130), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(5040, -200), Vector2(80, 20), pc, ec),
		# Final dash escape
		PlatformDef.new("S7_1", Vector2(5310, -220), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5610, -260), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5910, -300), Vector2(140, 28), pc, ec),
		# Top ledge — THE ESCAPE
		PlatformDef.new("TopLedge", Vector2(6260, -480), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(5200, -104)
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
		PlatformDef.new("TopLedge", Vector2(5200, -40), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(5440, -464)
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
		PlatformDef.new("S2_1", Vector2(1100, 680), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1210, 605), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1320, 530), Vector2(80, 20), pc, ec),
		# Section 3 — ascending precision
		PlatformDef.new("S3_1", Vector2(1570, 480), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1770, 410), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1970, 340), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_4", Vector2(2170, 270), Vector2(90, 20), pc, ec),
		# Section 4 — dash gate
		PlatformDef.new("S4_1", Vector2(2420, 230), Vector2(140, 28), pc, ec, 5.0, "moving", {"travel": Vector2(90, -20), "speed": 70.0, "pause_at_ends": 0.5}),
		PlatformDef.new("S4_2", Vector2(2780, 190), Vector2(140, 28), pc, ec),
		# Section 5 — wall-jump escape
		PlatformDef.new("S5_1", Vector2(3060, 120), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(3170, 50), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(3280, -20), Vector2(80, 20), pc, ec),
		# Section 6 — final climb
		PlatformDef.new("S6_1", Vector2(3560, -60), Vector2(110, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3800, -120), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_3", Vector2(4040, -180), Vector2(110, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(4300, -240), Vector2(120, 24), pc, ec),
		# Section 7 — final approach
		PlatformDef.new("S7_1", Vector2(4560, -280), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4840, -320), Vector2(110, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(5120, -360), Vector2(120, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(5440, -400), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(6060, -584)
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
		PlatformDef.new("S2_1", Vector2(940, 700), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1050, 625), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1160, 550), Vector2(80, 20), pc, ec),
		# Dash section
		PlatformDef.new("S3_1", Vector2(1420, 500), Vector2(130, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1760, 460), Vector2(140, 28), pc, ec),
		# Wall-jump shaft 2
		PlatformDef.new("S4_1", Vector2(2040, 380), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_1_C1", Vector2(2150, 305), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(2260, 230), Vector2(80, 20), pc, ec),
		# Precision stepping
		PlatformDef.new("S5_1", Vector2(2520, 180), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(2720, 120), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(2920, 60), Vector2(100, 24), pc, ec),
		# Dash over void
		PlatformDef.new("S6_1", Vector2(3180, 30), Vector2(140, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3540, 0), Vector2(140, 28), pc, ec),
		# Wall-jump shaft 3
		PlatformDef.new("S7_1", Vector2(3840, -80), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_1_C1", Vector2(3950, -140), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(4060, -200), Vector2(80, 20), pc, ec),
		# Final approach
		PlatformDef.new("S8_1", Vector2(4360, -240), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_2", Vector2(4660, -300), Vector2(110, 24), pc, ec),
		PlatformDef.new("S8_3", Vector2(4960, -360), Vector2(120, 28), pc, ec),
		PlatformDef.new("S8_4", Vector2(5280, -420), Vector2(130, 28), pc, ec),
		PlatformDef.new("S8_5", Vector2(5620, -480), Vector2(120, 24), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(6060, -520), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(6260, -664)
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
		PlatformDef.new("S2_1", Vector2(1080, 730), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1190, 655), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1300, 580), Vector2(80, 20), pc, ec),
		# Dash gate
		PlatformDef.new("S3_1", Vector2(1560, 530), Vector2(130, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1900, 490), Vector2(140, 28), pc, ec),
		# Precision stepping
		PlatformDef.new("S4_1", Vector2(2160, 440), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(2360, 380), Vector2(100, 24), pc, ec),
		PlatformDef.new("S4_3", Vector2(2560, 320), Vector2(90, 20), pc, ec),
		# Wall-jump shaft 2
		PlatformDef.new("S5_1", Vector2(2840, 240), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(2950, 165), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(3060, 90), Vector2(80, 20), pc, ec),
		# Dash over void
		PlatformDef.new("S6_1", Vector2(3360, 50), Vector2(140, 28), pc, ec, 5.0, "moving", {"travel": Vector2(100, 0), "speed": 75.0, "pause_at_ends": 0.5}),
		PlatformDef.new("S6_2", Vector2(3720, 10), Vector2(140, 28), pc, ec),
		# Precision final
		PlatformDef.new("S7_1", Vector2(3980, -40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S7_2", Vector2(4180, -100), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_3", Vector2(4380, -160), Vector2(100, 24), pc, ec),
		# Wall-jump shaft 3
		PlatformDef.new("S8_1", Vector2(4660, -240), Vector2(80, 20), pc, ec),
		PlatformDef.new("S8_1_C1", Vector2(4770, -310), Vector2(80, 20), pc, ec),
		PlatformDef.new("S8_2", Vector2(4880, -380), Vector2(80, 20), pc, ec),
		# Final approach
		PlatformDef.new("S9_1", Vector2(5160, -420), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(5440, -480), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5720, -540), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_3_G1", Vector2(5990, -570), Vector2(120, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(6260, -600), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(6460, -664)
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
		PlatformDef.new("S3_1", Vector2(2280, 520), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C1", Vector2(2390, 445), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C2", Vector2(2500, 370), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C3", Vector2(2610, 295), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2720, 220), Vector2(80, 20), pc, ec),
		# Dash platforms
		PlatformDef.new("S4_1", Vector2(3000, 180), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(3340, 140), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3680, 100), Vector2(140, 28), pc, ec),
		# Tighter platforms
		PlatformDef.new("S5_1", Vector2(3940, 60), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(4140, 10), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(4340, -40), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4540, -90), Vector2(90, 20), pc, ec),
		# Wall-jump escape
		PlatformDef.new("S6_1", Vector2(4820, -170), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1_C1", Vector2(4930, -240), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(5040, -310), Vector2(80, 20), pc, ec),
		# Final dash escape
		PlatformDef.new("S7_1", Vector2(5320, -340), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5640, -400), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5960, -460), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_3_G1", Vector2(6210, -530), Vector2(140, 28), pc, ec),
		# Top ledge
		PlatformDef.new("TopLedge", Vector2(6460, -600), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
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
	def.goal_position = Vector2(5840, -604)
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
		PlatformDef.new("S2_1", Vector2(1260, 660), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1370, 585), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1480, 510), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1720, 460), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_2", Vector2(1920, 400), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2120, 340), Vector2(100, 24), pc, ec),
		PlatformDef.new("S3_4", Vector2(2320, 280), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2580, 240), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2940, 200), Vector2(140, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3240, 100), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(3350, 30), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(3460, -40), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(3740, -80), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3940, -140), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(4140, -200), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(4360, -260), Vector2(100, 24), pc, ec),
		PlatformDef.new("S7_1", Vector2(4620, -300), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4900, -360), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(5180, -420), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5480, -480), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5840, -540), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# Act IV opens the "every level past 15 carries a distinct lethal hazard"
	# escalation. Blades sit inside existing gaps the reachability sweep has
	# already proven crossable — they add stakes to a jump, never change
	# whether it is possible.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(2760, 320), 80.0, 2.4),
		SpinningBladeDef.new(Vector2(4250, -180), 55.0, -2.8),
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
	def.goal_position = Vector2(5300, -544)
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
		PlatformDef.new("TopLedge", Vector2(5300, -480), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# S4_1 (right edge x=2265) to S4_2 (left edge x=2455) leaves a 190px gap;
	# a 280px-wide zone centered here (as before) spilled 45px onto each
	# platform, pushing a player merely standing near either edge. 180px
	# fits the gap with a 5px margin on both sides.
	def.wind_zones = [LevelData.WindZoneDef.new(Vector2(2360, 200), Vector2(180, 220), Vector2(-90, 0))]
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
	def.goal_position = Vector2(6060, -644)
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
		PlatformDef.new("S2_1", Vector2(920, 800), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1030, 725), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1140, 650), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1420, 600), Vector2(120, 28), pc, ec),
		PlatformDef.new("S3_2", Vector2(1740, 560), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_1", Vector2(2000, 500), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_2", Vector2(2180, 430), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_1", Vector2(2440, 350), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(2550, 275), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(2660, 200), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(2940, 150), Vector2(130, 28), pc, ec),
		PlatformDef.new("S6_2", Vector2(3280, 110), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_1", Vector2(3540, 50), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_2", Vector2(3720, -10), Vector2(90, 20), pc, ec),
		PlatformDef.new("S8_1", Vector2(3980, -90), Vector2(80, 20), pc, ec),
		PlatformDef.new("S8_1_C1", Vector2(4090, -160), Vector2(80, 20), pc, ec),
		PlatformDef.new("S8_2", Vector2(4200, -230), Vector2(80, 20), pc, ec),
		PlatformDef.new("S9_1", Vector2(4480, -280), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(4760, -340), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5040, -400), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_4", Vector2(5340, -460), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_5", Vector2(5640, -520), Vector2(120, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6060, -580), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# L18's signature hazard is the pendulum — a swinging arc with a readable
	# rhythm, distinct from L16's constantly-spinning blades. Pivots hang
	# above gaps; phase offsets keep the two from swinging in lockstep.
	def.pendulums = [
		PendulumDef.new(Vector2(1590, 490), 190.0, 50.0, 1.5, 0.0),
		PendulumDef.new(Vector2(3110, 48), 200.0, 55.0, 1.8, 1.4),
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
	def.goal_position = Vector2(5740, -624)
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
		PlatformDef.new("S2_1", Vector2(1220, 660), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1330, 585), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1440, 510), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1700, 460), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(1880, 390), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2060, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_4", Vector2(2260, 260), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2500, 220), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2820, 180), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3120, 80), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(3230, 10), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(3340, -60), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(3620, -100), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3820, -160), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(4020, -220), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(4240, -280), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_1", Vector2(4500, -320), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4780, -380), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(5060, -440), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5360, -500), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5740, -560), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# Same fix as L17: S4_1 (right edge x=2565) to S4_2 (left edge x=2755)
	# leaves a 190px gap; 180px fits it with a 5px margin on both sides
	# instead of spilling 45px onto each flanking platform.
	def.wind_zones = [LevelData.WindZoneDef.new(Vector2(2660, 150), Vector2(180, 220), Vector2(-90, 0))]
	# L19 combines both lethal hazard types ahead of the L20 boss — a blade
	# early, a pendulum late, on top of the existing wind zone. Placed inside
	# gaps the reachability sweep already proves crossable.
	def.spinning_blades = [SpinningBladeDef.new(Vector2(1570, 415), 70.0, 3.0)]
	def.pendulums = [PendulumDef.new(Vector2(4370, -390), 190.0, 48.0, 1.9, 0.7)]
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
	def.goal_position = Vector2(6860, -684)
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
		PlatformDef.new("S3_1", Vector2(2320, 560), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C1", Vector2(2430, 485), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C2", Vector2(2540, 410), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1_C3", Vector2(2650, 335), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2760, 260), Vector2(80, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(3040, 220), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(3380, 180), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3720, 140), Vector2(140, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3980, 90), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(4180, 30), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(4380, -30), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4580, -90), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(4860, -170), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1_C1", Vector2(4970, -240), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(5080, -310), Vector2(80, 20), pc, ec),
		PlatformDef.new("S7_1", Vector2(5360, -350), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5680, -410), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(6000, -470), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(6320, -530), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4_G1", Vector2(6590, -575), Vector2(130, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6860, -620), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# Boss levels get a lighter hazard touch than the non-boss levels around
	# them: the chase is already the pressure, and stacking dodge-timing on
	# top of "keep moving or get caught" turns escalation into unfairness.
	# Two blades in deep pits, well clear of every landing.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(2190, 790), 70.0, 3.0),
		SpinningBladeDef.new(Vector2(4790, 20), 65.0, -3.2),
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
	def.goal_position = Vector2(5740, -624)
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
		PlatformDef.new("S2_1", Vector2(1220, 660), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1330, 585), Vector2(80, 20), pc, ec),
		PlatformDef.new("S2_2", Vector2(1440, 510), Vector2(80, 20), pc, ec),
		PlatformDef.new("S3_1", Vector2(1700, 460), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(1880, 390), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(2060, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_4", Vector2(2260, 260), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2500, 220), Vector2(130, 28), pc, ec, 5.0, "bounce"),
		PlatformDef.new("S4_2", Vector2(2820, 180), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3120, 80), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(3230, 10), Vector2(80, 20), pc, ec),
		PlatformDef.new("S5_2", Vector2(3340, -60), Vector2(80, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(3620, -100), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_2", Vector2(3820, -160), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_3", Vector2(4020, -220), Vector2(100, 24), pc, ec),
		PlatformDef.new("S6_4", Vector2(4240, -280), Vector2(90, 20), pc, ec),
		PlatformDef.new("S7_1", Vector2(4500, -320), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4780, -380), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(5060, -440), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5360, -500), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(5740, -560), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# Act V opens with the campaign's densest hazard mix — two blades and a
	# pendulum, all inside gaps the reachability sweep already proves crossable.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(1570, 415), 75.0, 3.2),
		SpinningBladeDef.new(Vector2(3480, -175), 70.0, -3.4),
	]
	def.pendulums = [PendulumDef.new(Vector2(4370, -386), 190.0, 50.0, 2.1, 0.5)]
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
	def.goal_position = Vector2(6040, -734)
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
		PlatformDef.new("S2_1", Vector2(1160, 610), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1270, 535), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_2", Vector2(1380, 460), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1640, 410), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_2", Vector2(1800, 340), Vector2(80, 18), pc, ec, 5.0, "bounce"),
		PlatformDef.new("S3_3", Vector2(1960, 270), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_4", Vector2(2140, 200), Vector2(80, 18), pc, ec),
		PlatformDef.new("S4_1", Vector2(2380, 160), Vector2(130, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2700, 120), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3000, 30), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(3110, -40), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_2", Vector2(3220, -110), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(3500, -150), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(3680, -210), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_3", Vector2(3860, -270), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_4", Vector2(4060, -330), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(4320, -370), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4620, -430), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_3", Vector2(4920, -490), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(5240, -550), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_5", Vector2(5560, -610), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_5_G1", Vector2(5800, -640), Vector2(130, 28), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6040, -670), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# L22's hazards sit over this level's already-tiny platforms — the
	# precision level's blades punish the same overshoot its narrow landings
	# already do, rather than adding an unrelated demand.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(1520, 375), 65.0, 3.6),
		SpinningBladeDef.new(Vector2(2860, 75), 70.0, -3.2),
		SpinningBladeDef.new(Vector2(4180, -350), 65.0, 3.8),
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
	def.goal_position = Vector2(6660, -874)
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
		PlatformDef.new("S2_1", Vector2(1060, 730), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1170, 655), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_2", Vector2(1280, 580), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1540, 530), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_2", Vector2(1720, 460), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_3", Vector2(1900, 390), Vector2(90, 20), pc, ec),
		PlatformDef.new("S3_4", Vector2(2100, 320), Vector2(90, 20), pc, ec),
		PlatformDef.new("S4_1", Vector2(2340, 280), Vector2(130, 28), pc, ec, 5.0, "bounce"),
		PlatformDef.new("S4_2", Vector2(2660, 240), Vector2(130, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(2960, 150), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_1_C1", Vector2(3070, 80), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_2", Vector2(3180, 10), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(3460, -30), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_2", Vector2(3640, -90), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_3", Vector2(3820, -150), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_4", Vector2(4020, -210), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(4260, -250), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4580, -310), Vector2(120, 24), pc, ec),
		PlatformDef.new("S8_1", Vector2(4880, -390), Vector2(80, 18), pc, ec),
		PlatformDef.new("S8_1_C1", Vector2(4990, -460), Vector2(80, 18), pc, ec),
		PlatformDef.new("S8_2", Vector2(5100, -530), Vector2(80, 18), pc, ec),
		PlatformDef.new("S9_1", Vector2(5380, -570), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(5660, -630), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5940, -690), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_4", Vector2(6240, -750), Vector2(110, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6660, -810), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# CRUCIBLE earns its name: the campaign's longest level carries every
	# lethal hazard type at once, spread across all three of its acts-worth
	# of sections. All sit inside gaps the reachability sweep already proves.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(1420, 495), 70.0, 3.4),
		SpinningBladeDef.new(Vector2(3350, 55), 70.0, -3.0),
	]
	def.pendulums = [
		PendulumDef.new(Vector2(2500, 175), 190.0, 52.0, 1.7, 0.0),
		PendulumDef.new(Vector2(5250, -642), 200.0, 50.0, 2.0, 1.1),
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
	def.goal_position = Vector2(6560, -874)
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
		PlatformDef.new("S2_1", Vector2(1040, 730), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_1_C1", Vector2(1150, 655), Vector2(80, 18), pc, ec),
		PlatformDef.new("S2_2", Vector2(1260, 580), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1", Vector2(1520, 530), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_2", Vector2(1680, 460), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_3", Vector2(1840, 390), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_4", Vector2(2020, 320), Vector2(80, 18), pc, ec),
		PlatformDef.new("S4_1", Vector2(2260, 280), Vector2(120, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(2560, 240), Vector2(120, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(2860, 150), Vector2(80, 18), pc, ec, 5.0, "bounce"),
		PlatformDef.new("S5_1_C1", Vector2(2970, 80), Vector2(80, 18), pc, ec),
		PlatformDef.new("S5_2", Vector2(3080, 10), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1", Vector2(3360, -30), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_2", Vector2(3520, -90), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_3", Vector2(3680, -150), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_4", Vector2(3860, -210), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(4100, -250), Vector2(120, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(4400, -310), Vector2(110, 24), pc, ec),
		PlatformDef.new("S8_1", Vector2(4700, -390), Vector2(80, 18), pc, ec),
		PlatformDef.new("S8_1_C1", Vector2(4810, -460), Vector2(80, 18), pc, ec),
		PlatformDef.new("S8_2", Vector2(4920, -530), Vector2(80, 18), pc, ec),
		PlatformDef.new("S9_1", Vector2(5200, -570), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_2", Vector2(5500, -630), Vector2(110, 24), pc, ec),
		PlatformDef.new("S9_3", Vector2(5800, -690), Vector2(120, 28), pc, ec),
		PlatformDef.new("S9_4", Vector2(6120, -750), Vector2(110, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(6560, -810), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# The last normal level before the final boss — fastest blades in the
	# campaign, plus a pendulum on the closing stretch.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(1600, 610), 65.0, 4.0),
		SpinningBladeDef.new(Vector2(3200, -60), 65.0, -4.0),
	]
	def.pendulums = [PendulumDef.new(Vector2(5350, -684), 195.0, 50.0, 2.2, 0.9)]
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
	def.goal_position = Vector2(7260, -884)
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
		PlatformDef.new("S3_1", Vector2(2300, 560), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1_C1", Vector2(2410, 485), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1_C2", Vector2(2520, 410), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_1_C3", Vector2(2630, 335), Vector2(80, 18), pc, ec),
		PlatformDef.new("S3_3", Vector2(2740, 260), Vector2(80, 18), pc, ec),
		PlatformDef.new("S4_1", Vector2(3020, 220), Vector2(140, 28), pc, ec),
		PlatformDef.new("S4_2", Vector2(3360, 180), Vector2(150, 28), pc, ec),
		PlatformDef.new("S4_3", Vector2(3700, 140), Vector2(140, 28), pc, ec),
		PlatformDef.new("S5_1", Vector2(3960, 90), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_2", Vector2(4160, 30), Vector2(90, 20), pc, ec),
		PlatformDef.new("S5_3", Vector2(4360, -30), Vector2(100, 24), pc, ec),
		PlatformDef.new("S5_4", Vector2(4560, -90), Vector2(90, 20), pc, ec),
		PlatformDef.new("S6_1", Vector2(4840, -170), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_1_C1", Vector2(4950, -240), Vector2(80, 18), pc, ec),
		PlatformDef.new("S6_2", Vector2(5060, -310), Vector2(80, 18), pc, ec),
		PlatformDef.new("S7_1", Vector2(5340, -350), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_2", Vector2(5660, -410), Vector2(150, 28), pc, ec),
		PlatformDef.new("S7_3", Vector2(5980, -470), Vector2(140, 28), pc, ec),
		PlatformDef.new("S7_4", Vector2(6300, -530), Vector2(130, 28), pc, ec),
		PlatformDef.new("S7_5", Vector2(6620, -590), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_5_G1", Vector2(6833, -667), Vector2(120, 24), pc, ec),
		PlatformDef.new("S7_5_G2", Vector2(7047, -743), Vector2(120, 24), pc, ec),
		PlatformDef.new("TopLedge", Vector2(7260, -820), Vector2(200, 32), pc, Color(1.0, 0.827, 0.471))
	]
	# The summit. Same restraint as L20 — the 3-phase boss and 6 minions are
	# the real threat here; blades mark the drop, they don't gate the route.
	def.spinning_blades = [
		SpinningBladeDef.new(Vector2(2170, 790), 70.0, 3.4),
		SpinningBladeDef.new(Vector2(4770, 20), 65.0, -3.6),
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
