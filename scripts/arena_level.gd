class_name ArenaLevel
extends RefCounted
## The M1 test arena (launch flag --dev-arena): one flat hall that exercises every part of the
## attack and health systems in a row, so the feel can be tuned before level content builds on it.
## Not part of the campaign, never saved.
##
##   1  a drone to slash            2  two drones, one hovering        3  a dart shooter to deflect
##   4  spikes to pogo over         5  a spinning blade (chip damage)  6  a lava gap (instant death)
##   7  a lever only a slash flips, opening the gate to the door

const Y := 800.0


static func build() -> LevelData.LevelDef:
	var theme := LevelData.LevelTheme.new(
		Color(0.230, 0.245, 0.320), Color(0.46, 0.62, 0.80), Color(0.155, 0.172, 0.230))
	var def := LevelData.LevelDef.new()
	def.number = LevelData.ARENA_LEVEL
	def.name = "M1 ARENA"
	def.theme = theme
	def.boss_config = LevelData.BossConfig.new()
	var pc := theme.platform_color
	var ec := theme.edge_color
	var wc := theme.wall_color
	var P := LevelData.PlatformDef
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), wc, ec, 0.0),
		P.new("Ground", Vector2(850.0, Y + 250.0), Vector2(1800.0, 500.0), wc, ec, 5.0),
		P.new("A_floor", Vector2(2625.0, Y + 30.0), Vector2(1750.0, 60.0), pc, ec),
		# a lava gap between 3500 and 3660
		P.new("B_floor", Vector2(4610.0, Y + 30.0), Vector2(1900.0, 60.0), pc, ec),
		P.new("TopLedge", Vector2(6010.0, Y + 30.0), Vector2(900.0, 60.0), pc, ec, 5.0),
	]
	def.spawn_point = Vector2(200.0, Y - 28.0)
	def.goal_position = Vector2(6300.0, Y - 48.0)
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = Y + 1400.0
	# 1 and 2: drones.
	def.drones = [
		[Vector2(1000.0, Y - 40.0), 110.0],
		[Vector2(1500.0, Y - 40.0), 140.0],
		[Vector2(2000.0, Y - 150.0), 120.0],
	]
	# 3: a shooter on the far side of a lane, firing left.
	def.shooters.append(LevelData.ShooterDef.new(Vector2(2700.0, Y - 28.0), Vector2(-1.0, 0.0), 2.0))
	# 4: spikes (three slots, two armed).
	var slots: Array[Vector2] = [Vector2(2950.0, Y), Vector2(3050.0, Y), Vector2(3150.0, Y)]
	def.trap_groups.append(LevelData.TrapGroupDef.new(slots, 2))
	# 5: a blade over the floor.
	def.spinning_blades.append(LevelData.SpinningBladeDef.new(Vector2(4100.0, Y - 20.0), 70.0, 3.0))
	# 6: lava in the gap.
	def.lava_pits.append(LevelData.LavaDef.new(Vector2(3580.0, Y + 160.0), Vector2(160.0, 280.0)))
	# 7: the lever and the gate in front of the door.
	var pg := LevelData.PlateGateDef.new(Vector2(5300.0, Y - 26.0), Vector2(5650.0, Y - 75.0),
		Vector2(26.0, 150.0), 7.0, 1)
	pg.use_slash = true
	def.plate_gates.append(pg)
	var hints: Array[LevelData.HintDef] = [
		LevelData.HintDef.new(Vector2(350.0, Y - 170.0), "M1 / L / RT: SLASH. HIT THE DRONES"),
		LevelData.HintDef.new(Vector2(2300.0, Y - 170.0), "SLASH A DART TO SEND IT BACK"),
		LevelData.HintDef.new(Vector2(2850.0, Y - 170.0), "AIR + DOWN + SLASH ON SPIKES: BOUNCE"),
		LevelData.HintDef.new(Vector2(5000.0, Y - 170.0), "ONLY A SLASH FLIPS THE LEVER"),
	]
	def.hints = hints
	return def
