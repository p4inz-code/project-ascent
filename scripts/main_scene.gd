class_name MainScene
extends Node2D
## Level controller for Project Ascent.
##
## Handles one level at a time: terrain, spawn, kill-depth, restart, goal/completion.
## When loaded via game_scene.gd, `level_number` is set before _ready fires so the
## terrain is built from LevelData. When loaded standalone (tests), defaults to
## Level 1 and preserves the original .tscn terrain (no rebuild needed).

## World-space Y below which the player is considered to have fallen out of the
## level and is respawned. Set generously below the lowest platform.
@export var kill_depth: float = 1400.0

## Set by game_scene.gd before instantiation to select which level to build.
## Default 1 preserves backward compatibility with tests that load main_scene.tscn.
@export var level_number: int = 1

## Change that led to a respawn, so the audio layer can play the right cue.
enum RespawnCause { FALL, MANUAL, COMPLETE }

signal level_completed
## Emitted with the new running total whenever an orb is banked. Drives the HUD.
signal orb_collected(total: int)

@onready var _player: Player = $Player

## How far below the lowest platform the death plane sits. Far enough that a
## player standing on that platform cannot touch it, close enough that a fall
## ends in a fraction of a second instead of the second-plus it used to take to
## reach kill_depth.
const DEATH_PLANE_CLEARANCE: float = 260.0
## The local death line sits this far under the lowest platform surface near the
## player: about two player heights, so a missed jump ends almost at once.
const LOCAL_DEATH_DROP: float = 110.0
## How far sideways (each way) a platform still counts as "near the player".
## Past the longest jump + dash, so nothing the player could still reach is ignored.
const LOCAL_DEATH_WINDOW: float = 650.0
## The line may rise at most this fast; it falls instantly. Rising slowly means a
## player crossing into a higher section is never caught by a line that jumped.
const LOCAL_DEATH_RISE_SPEED: float = 1800.0
## Boss levels: the biome floor (ground, water, ice or lava) climbs as the boss
## countdown runs out, up to this share of the way from the level floor to the goal.
## Under 1 so it never reaches the goal, and linear in the countdown so a player
## who keeps moving is always above it.
const BOSS_RISE_SHARE: float = 0.75
## The floor speeds up as the countdown runs out: position follows elapsed^POWER, so
## it creeps early and surges late and the player has to run faster near the end.
const BOSS_RISE_POWER: float = 1.9

var _death_plane: DeathPlane = null
## Trap groups in this level; each re-arms a fresh random subset on every attempt.
var _trap_groups: Array[TrapGroup] = []
var _storm: StormDirector = null
var _plane_global_y: float = 0.0
## True once the floor has been placed for the current life. The first update after a
## spawn or respawn snaps straight to the local line instead of rising to it.
var _death_line_primed: bool = false
## Highest share (0..1) of the boss countdown that has elapsed this attempt.
var _rise_peak: float = 0.0
var _rise_glow: Control = null
var _chase_indicator: ChaseIndicator = null
var _road_course: RoadCourse = null
## Platform spans for the local death line: x = left, y = right, z = surface (top).
var _platform_spans: Array[Vector3] = []

## Rising lava instances, so they can be reset on death — respawning into lava
## already at the ceiling is dead on arrival.
var _rising_lava: Array = []

var _spawn_point: Vector2
## Last claimed mid-level checkpoint, and whether one has been claimed at all.
var _active_checkpoint: Vector2 = Vector2.ZERO
var _has_checkpoint: bool = false
## The authored speed ceilings, captured before berserk ever scales them.
var _boss_base_max: float = 0.0
## Death taunts/encouragement. Built here rather than autoloaded so it dies
## with the level and cannot leak a taunt across a level change.
var _death_feedback: DeathFeedback = null
var _minion_base_max: float = 0.0

var run_time: float = 0.0
var last_run_time: float = 0.0
var attempts: int = 1

var _clock_running: bool = false
var _level_data = null

## Boss chase state (Levels with boss_config.enabled)
var _boss = null
var _minions: Array = []
var _chase_active: bool = false
var _chase_triggered: bool = false
## Counts down once the chase starts. Drives the HUD readout and the berserk
## escalation; -1 means no chase is running.
var _chase_time_left: float = -1.0
var _berserk: bool = false
var _terrain_built: bool = false

## How far behind the player a fallen chaser is put back into the chase.
## Must stay comfortably above the chasers' catch_distance (36px) so a
## recovery can never register as a catch on the same or next frame.
const RECOVERY_SETBACK: float = 520.0

## Level completion state — prevents duplicate goal triggers and input
## while the completion banner is displayed.
var _level_complete: bool = false


func _ready() -> void:
	# Always rebuild terrain from LevelData (the .tscn has no hardcoded
	# platforms anymore — all terrain is data-driven).
	_build_level_terrain()
	_level_data = LevelData.get_level(level_number)
	# Take the authored kill_depth, then let the death plane push it deeper if
	# it needs to. Assigning it AFTER the terrain build (which is where the
	# plane is created) used to clobber that adjustment, so the old shallow
	# cutoff kept firing first and the plane never triggered at all.
	kill_depth = maxf(kill_depth, _level_data.kill_depth)
	_spawn_point = _player.global_position

	# The boss clock is a deadline for the LEVEL, not for the chase. Arming it
	# only when the chase triggers meant the countdown was invisible for the
	# whole approach, so the only timer on screen was the run timer counting
	# UP — which reads as no deadline at all.
	if _level_data.boss_config.enabled:
		_chase_time_left = _level_data.boss_config.time_limit

	_death_feedback = DeathFeedback.new()
	_death_feedback.name = "DeathFeedback"
	add_child(_death_feedback)

	var pixel_filter := PixelFilter.new()
	pixel_filter.name = "PixelFilter"
	add_child(pixel_filter)


func _build_level_terrain() -> void:
	_level_data = LevelData.get_level(level_number)

	var terrain = get_node_or_null("Terrain")
	if terrain == null:
		terrain = Node2D.new()
		terrain.name = "Terrain"
		add_child(terrain)
		terrain.owner = self

	# Remove existing children IMMEDIATELY (not queue_free)
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.free()

	# Rebuild from data
	var platform_scene = preload("res://scenes/platform.tscn")
	for pdef in _level_data.platforms:
		var platform: Node2D
		match pdef.kind:
			"crumble":
				platform = CrumblePlatform.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
			"bounce":
				platform = BouncePad.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
			"moving":
				platform = MovingPlatform.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
				platform.travel = pdef.extra.get("travel", Vector2(220.0, 0.0))
				platform.speed = pdef.extra.get("speed", 90.0)
				platform.pause_at_ends = pdef.extra.get("pause_at_ends", 0.4)
			"conveyor":
				platform = ConveyorBelt.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
				platform.push_speed = pdef.extra.get("push_speed", 120.0)
				platform.direction = pdef.extra.get("direction", 1)
			"fake":
				platform = FakePlatform.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
			"timed":
				platform = TimedPlatform.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
				platform.on_time = pdef.extra.get("on_time", 2.4)
				platform.off_time = pdef.extra.get("off_time", 1.4)
				platform.phase = pdef.extra.get("phase", 0.0)
			"ice", "sticky":
				platform = SurfacePlatform.new()
				platform.kind = (SurfacePlatform.Kind.ICE if pdef.kind == "ice"
					else SurfacePlatform.Kind.STICKY)
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
			"one_way":
				platform = OneWayPlatform.new()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
			_:
				platform = platform_scene.instantiate()
				platform.size = pdef.size
				platform.color = pdef.color
				platform.edge_color = pdef.edge_color
				platform.edge_thickness = pdef.edge_thickness
		platform.name = pdef.name
		platform.position = pdef.position
		# The left boundary wall is a COLLIDER, not scenery. It is 3200px tall
		# and sits off the route at x=-120 purely to stop the player walking
		# out of the level — but drawn, it appears as a full-height column
		# standing in open sky beside the spawn, which reads as level geometry
		# the player might be able to use. Not drawn; collision unaffected.
		if String(pdef.name).contains("Wall"):
			platform.modulate = Color(1, 1, 1, 0.0)
		terrain.add_child(platform)
		platform.owner = self
		# Special tiles get a pattern as well as a colour, so the rule reads
		# without colour. Added after the platform is in the tree so its own
		# visuals (built in _ready) are drawn first and the pattern sits on top.
		if TileDecor.has_pattern(String(pdef.kind)) and not String(pdef.name).contains("Wall"):
			var decor := TileDecor.new()
			decor.name = "TileDecor"
			decor.kind = String(pdef.kind)
			decor.size = pdef.size
			decor.direction = int(pdef.extra.get("direction", 1))
			platform.add_child(decor)

	# Wind zones live in their own container, never mixed into Terrain — they
	# are non-solid and not part of the sequential route, so route-walking
	# code that iterates Terrain's children in order (reachability checks,
	# the terrain rebuild above) must never see one.
	var hazards = get_node_or_null("Hazards")
	if hazards == null:
		hazards = Node2D.new()
		hazards.name = "Hazards"
		add_child(hazards)
		hazards.owner = self
	for child in hazards.get_children():
		hazards.remove_child(child)
		child.free()
	for i in _level_data.wind_zones.size():
		var wdef: LevelData.WindZoneDef = _level_data.wind_zones[i]
		var zone := WindZone.new()
		zone.name = "WindZone_%d" % i
		zone.position = wdef.position
		zone.size = wdef.size
		zone.force = wdef.force
		hazards.add_child(zone)
		zone.owner = self
	for i in _level_data.spinning_blades.size():
		var bdef: LevelData.SpinningBladeDef = _level_data.spinning_blades[i]
		var blade := SpinningBlade.new()
		blade.name = "SpinningBlade_%d" % i
		blade.position = bdef.position
		blade.radius = bdef.radius
		blade.rotation_speed = bdef.rotation_speed
		blade.player_hit.connect(_on_chip_hit)
		hazards.add_child(blade)
		blade.owner = self
	for i in _level_data.lava_pits.size():
		var ldef: LevelData.LavaDef = _level_data.lava_pits[i]
		var lava := Lava.new()
		lava.name = "Lava_%d" % i
		lava.position = ldef.position
		lava.size = ldef.size
		lava.player_hit.connect(_on_hazard_hit)
		hazards.add_child(lava)
		lava.owner = self
	for i in _level_data.abilities.size():
		var adef: LevelData.AbilityDef = _level_data.abilities[i]
		var pick := AbilityPickup.new()
		pick.name = "Ability_%d" % i
		pick.position = adef.position
		pick.kind = adef.kind
		hazards.add_child(pick)
		pick.owner = self
	_build_death_plane(hazards)
	_build_orbs(hazards)
	_build_shooters(hazards)
	_build_rising_lava(hazards)
	_build_plate_gates(hazards)
	_build_drones(hazards)
	_build_machine()

	for i in _level_data.checkpoints.size():
		var cdef: LevelData.CheckpointDef = _level_data.checkpoints[i]
		var flag := CheckpointFlag.new()
		flag.name = "Checkpoint_%d" % i
		flag.position = cdef.position
		flag.activated.connect(_on_checkpoint_reached)
		hazards.add_child(flag)
		flag.owner = self
	for i in _level_data.hints.size():
		var hdef: LevelData.HintDef = _level_data.hints[i]
		var hint := LevelHint.new()
		hint.name = "Hint_%d" % i
		hint.position = hdef.position
		hint.text = hdef.text
		hint.radius = hdef.radius
		hazards.add_child(hint)
		hint.owner = self
	for i in _level_data.zero_gravity.size():
		var zdef: LevelData.ZeroGravityDef = _level_data.zero_gravity[i]
		var zone := ZeroGravityZone.new()
		zone.name = "ZeroG_%d" % i
		zone.position = zdef.position
		zone.size = zdef.size
		hazards.add_child(zone)
		zone.owner = self
	for i in _level_data.gates.size():
		var g: Array = _level_data.gates[i]
		var gate := TimedGate.new()
		gate.name = "TimedGate_%d" % i
		gate.position = g[0]
		gate.kind = g[1]
		gate.phase_offset = g[2]
		gate.player_hit.connect(_on_hazard_hit)
		hazards.add_child(gate)
		gate.owner = self
	# The storm level: telegraphed lightning (see StormDirector).
	_storm = null
	if _level_data.storm and _player != null:
		var rects: Array[Rect2] = []
		for p in _level_data.platforms:
			if String(p.name).contains("Wall") or not GateRules.is_stationary_solid(String(p.kind)):
				continue
			rects.append(Rect2(p.position - p.size * 0.5, p.size))
		_storm = StormDirector.new()
		_storm.name = "StormDirector"
		hazards.add_child(_storm)
		_storm.setup(rects, _player)
		_storm.player_hit.connect(_on_hazard_hit)
	# Plain-road levels: a fresh random obstacle in every cell, re-rolled each attempt.
	_road_course = null
	if _level_data.road != null and not RoadCourse.suspended:
		var terrain_node := get_node_or_null("Terrain")
		_road_course = RoadCourse.new()
		_road_course.name = "RoadCourse"
		hazards.add_child(_road_course)
		_road_course.setup(_level_data.road, terrain_node, hazards, _on_hazard_hit, _on_chip_hit)
		_road_course.roll()
	if level_number == 0 and _player != null:
		var old_guide := get_node_or_null("TutorialGuide")
		if old_guide != null:
			old_guide.free()
		var guide := TutorialGuide.new()
		guide.name = "TutorialGuide"
		add_child(guide)
		guide.attach(_player)
	if _player != null and _level_data.auto_run:
		_player.auto_run = 1
	elif _player != null:
		_player.auto_run = 0
	# Pipes with pressure vents, bridging suitable gaps. They only add floor and roof.
	if not PipeTube.suspended:
		for i in _level_data.pipes.size():
			var pd: Array = _level_data.pipes[i]
			var pipe := PipeTube.new()
			pipe.name = "PipeTube_%d" % i
			pipe.position = pd[0]
			pipe.length = pd[1]
			pipe.phase_offset = pd[2]
			pipe.rise = pd[3]
			hazards.add_child(pipe)
			pipe.owner = self
	# What holds each hazard up: cables, struts and brackets down to the platforms.
	var rects_for_support: Array[Rect2] = []
	for sp in _level_data.platforms:
		if String(sp.name).contains("Wall"):
			continue
		rects_for_support.append(Rect2(sp.position - sp.size * 0.5, sp.size))
	var support := HazardSupport.build(hazards, _level_data, rects_for_support)
	support.owner = self
	_trap_groups.clear()
	for i in _level_data.trap_groups.size():
		var tdef: LevelData.TrapGroupDef = _level_data.trap_groups[i]
		var group := TrapGroup.new()
		group.name = "TrapGroup_%d" % i
		hazards.add_child(group)
		group.owner = self
		group.setup(tdef.positions, tdef.arm_count)
		group.slot_hit.connect(_on_chip_hit)
		_trap_groups.append(group)
	for i in _level_data.pendulums.size():
		var pdef2: LevelData.PendulumDef = _level_data.pendulums[i]
		var pendulum := Pendulum.new()
		pendulum.name = "Pendulum_%d" % i
		pendulum.position = pdef2.position
		pendulum.arm_length = pdef2.arm_length
		pendulum.max_angle_deg = pdef2.max_angle_deg
		pendulum.swing_speed = pdef2.swing_speed
		pendulum.phase_offset = pdef2.phase_offset
		pendulum.player_hit.connect(_on_chip_hit)
		hazards.add_child(pendulum)
		pendulum.owner = self

	_player.global_position = _level_data.spawn_point

	# Reposition goal
	var goal = get_node_or_null("Goal") as Node2D
	if goal != null:
		goal.position = _level_data.goal_position
		var shape_node = goal.get_node_or_null("GoalShape") as CollisionShape2D
		if shape_node != null and shape_node.shape != null:
			shape_node.shape.size = _level_data.goal_size
		var visual = goal.get_node_or_null("GoalVisual") as Polygon2D
		if visual != null:
			var half = _level_data.goal_size * 0.5
			visual.polygon = PackedVector2Array([
				Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y)
			])
		var core = goal.get_node_or_null("GoalCore") as Polygon2D
		if core != null:
			var half2 = _level_data.goal_size * 0.25
			core.polygon = PackedVector2Array([
				Vector2(-half2.x, -half2.y), Vector2(half2.x, -half2.y),
				Vector2(half2.x, half2.y), Vector2(-half2.x, half2.y)
			])
		# Add pulsing glow effect
		var glow = goal.get_node_or_null("GoalGlow") as Polygon2D
		if glow == null:
			glow = Polygon2D.new()
			glow.name = "GoalGlow"
			goal.add_child(glow)
		var half3 = _level_data.goal_size * 0.8
		glow.polygon = PackedVector2Array([
			Vector2(-half3.x, -half3.y), Vector2(half3.x, -half3.y),
			Vector2(half3.x, half3.y), Vector2(-half3.x, half3.y)
		])
		glow.color = Color(1.0, 0.827, 0.471, 0.0)
		glow.z_index = -1
		# Start pulsing glow
		var pulse = create_tween().set_loops()
		pulse.tween_property(glow, "color:a", 0.12, 0.6)
		pulse.tween_property(glow, "color:a", 0.03, 0.6)

		# The door itself: pillars, core sockets, energy field. The old flat polygons
		# stay in the tree (invisible) because tests and tools address them by name.
		if visual != null:
			visual.visible = false
		if core != null:
			core.visible = false
		glow.visible = false
		var old_gate := goal.get_node_or_null("GoalGate")
		if old_gate != null:
			old_gate.free()
		var gate := GoalGate.new()
		gate.name = "GoalGate"
		gate.door_size = _level_data.goal_size
		gate.is_final = level_number == LevelData.TOTAL_LEVELS
		gate.core_goal = SaveSystem.ORB_GOAL
		var gm_gate := get_node_or_null("/root/GameManager")
		gate.cores = gm_gate.save_system.orb_total() if gm_gate != null and gm_gate.save_system != null else 0
		goal.add_child(gate)
		if not goal.body_entered.is_connected(_on_goal_touched_by_player):
			goal.body_entered.connect(_on_goal_touched_by_player)

	if _level_data.boss_config.enabled:
		_spawn_boss_entities()

	_terrain_built = true


func _spawn_boss_entities() -> void:
	var cfg = _level_data.boss_config
	_boss = BossEntity.new()
	_boss.name = "Boss"
	add_child(_boss)
	_boss.owner = self
	_boss.deactivate()
	_boss_base_max = _boss.max_speed

	_minions = []
	for i in cfg.minion_count:
		var minion = MinionEntity.new()
		minion.name = "Minion_%d" % i
		add_child(minion)
		minion.owner = self
		minion.deactivate()
		# Stagger offsets: spread vertically and horizontally for flanking
		var offset_y = -30.0 - i * 50.0
		var offset_x = -60.0 + i * 30.0
		minion._route_offset = Vector2(offset_x, offset_y)
		_minions.append(minion)
		_minion_base_max = minion.max_speed

	# Chasers wear the colour of their biome: acid green, flood blue, frost, ember.
	var biome_tints := {
		DeathPlane.Kind.ACID: Color(0.7, 1.15, 0.6),
		DeathPlane.Kind.WATER: Color(0.65, 0.85, 1.25),
		DeathPlane.Kind.ICE: Color(0.8, 1.1, 1.3),
		DeathPlane.Kind.LAVA: Color(1.0, 0.95, 0.9),
		DeathPlane.Kind.GROUND: Color(1.0, 1.0, 1.0),
	}
	var tint: Color = biome_tints.get(DeathPlane.kind_for_level(level_number), Color(1, 1, 1))
	if _boss != null and _boss.has_method("set_tint"):
		_boss.call_deferred("set_tint", tint)
	for m in _minions:
		m.call_deferred("set_tint", tint)

	# Edge arrows and a closing-in glow so the player always knows where the pursuers are.
	_chase_indicator = ChaseIndicator.new()
	_chase_indicator.name = "ChaseIndicator"
	add_child(_chase_indicator)
	_chase_indicator.targets = [_boss] as Array[Node2D]
	for m in _minions:
		_chase_indicator.targets.append(m)


func _physics_process(delta: float) -> void:
	# Block ALL gameplay input while the completion banner is showing
	if _level_complete:
		return

	if not _clock_running and not _player.input_locked and (Input.is_action_pressed("move_left")
			or Input.is_action_pressed("move_right")
			or Input.is_action_pressed("jump") or Input.is_action_pressed("dash")):
		_clock_running = true
		var audio = get_node_or_null("Audio")
		if audio != null:
			audio.unlock_audio()
	if _clock_running:
		run_time += delta

	_update_local_death_line(delta)
	# Below the floor means in the void: the sensor only catches a body that
	# crosses it, and the floor can sit above a player who slipped under it.
	if _death_plane != null and is_instance_valid(_death_plane) 			and _player.global_position.y > _death_plane.position.y + 60.0:
		_respawn(RespawnCause.FALL)
		return
	if _player.global_position.y > kill_depth:
		_respawn(RespawnCause.FALL)
		return

	if Input.is_action_just_pressed("restart"):
		_respawn(RespawnCause.MANUAL)

	# Boss chase: catch detection (uses entity catch_distance). Gated on
	# _chase_triggered alone, NOT also _boss.is_active() — boss.gd's
	# activate() holds off setting _active for a 1.5s warning-telegraph
	# delay, but minion.gd's activate() has no such delay, so minions are
	# already actively chasing (and could already need the recovery check
	# below) well before the boss itself is considered "active". Nesting
	# minion checks inside a boss-active gate silently skipped them for
	# that whole window.
	if _chase_triggered:
		if _boss != null and _boss.is_active() and _boss.has_caught_player():
			_respawn(RespawnCause.FALL)
			return
		for minion in _minions:
			if minion.is_active() and minion.has_caught_player():
				_respawn(RespawnCause.FALL)
				return

		# Recovery for chasers that fell out of the level. This is a SEPARATE
		# cause from the collision-layer fix in boss.gd/minion.gd: their
		# chase AI jumps toward the player whenever the player is above it
		# (minion.gd's "no horizontal distance restriction" jump), with zero
		# awareness of whether a platform is actually there to land on. In
		# this ascending game the player is above the chaser for nearly the
		# entire chase, so misjudging a gap the player crossed carefully
		# (with dash/wall-jump the chasers don't have) is a real, frequent
		# way for them to fall — independent of any collision interaction
		# with the player. Rather than a full pathfinding rewrite, catch the
		# result: an entity fallen well behind the player gets repositioned
		# back into the chase instead of visibly vanishing into the void.
		#
		# Recovery must drop the chaser well BEHIND the player, not beside
		# them. The original offsets (-180 for the boss, the minion's own
		# ~60-130px flanking offset) put a recovered chaser inside or barely
		# outside catch_distance, so the recovery itself read as an instant
		# unavoidable death — the player never even saw what killed them.
		# RECOVERY_SETBACK restores the chase from a distance the player can
		# actually run from, which is the whole point of a chase level.
		var cfg = _level_data.boss_config
		if _boss != null and _boss.is_active() and _boss.global_position.y > _player.global_position.y + 400.0:
			_boss.reposition(_player.global_position + Vector2(-RECOVERY_SETBACK, -60.0))
		for minion in _minions:
			if minion.is_active() and minion.global_position.y > _player.global_position.y + 400.0:
				minion.reposition(_player.global_position
					+ Vector2(-RECOVERY_SETBACK, 0.0) + minion._route_offset)

	# Rising lava starts when the player passes its trigger.
	for rl in _rising_lava:
		if is_instance_valid(rl) and not rl.is_rising() 				and _player.global_position.x >= rl.position.x:
			rl.start_rising()

	# Boss countdown. Runs from the moment the level starts.
	if _chase_time_left > 0.0 and not _level_complete:
		_chase_time_left -= delta
		if _chase_time_left <= 0.0 and not _berserk:
			# Running the clock out while still short of the trigger point does
			# not let the player off — it brings the chase to them, already
			# escalated. Otherwise the deadline would only threaten players who
			# had reached the boss anyway.
			if not _chase_triggered:
				_trigger_boss_chase()
			_go_berserk()

	# Trigger boss chase when player passes trigger_x
	if not _chase_triggered and _level_data != null and _level_data.boss_config.enabled:
		if _player.global_position.x >= _level_data.boss_config.trigger_x:
			_trigger_boss_chase()


func _trigger_boss_chase() -> void:
	_chase_triggered = true
	_chase_active = true
	if _chase_indicator != null:
		_chase_indicator.active = true
	var cfg = _level_data.boss_config
	_chase_time_left = cfg.time_limit
	_berserk = false
	# Restore the authored speed ceilings before every chase. _go_berserk()
	# multiplies these in place, and activate() only ever resets base_speed —
	# so without this a player who let the clock expire once would face a boss
	# permanently 1.55x faster, compounding on every further expiry until the
	# level became unwinnable.
	if _boss != null:
		_boss.max_speed = _boss_base_max
	for i in _minions.size():
		_minions[i].base_speed = cfg.minion_speed
		_minions[i].max_speed = _minion_base_max

	if _boss != null:
		_boss.activate(cfg.boss_start, _player, cfg.boss_speed)

	for i in _minions.size():
		var spawn_x = cfg.boss_start.x - 100.0 - i * 80.0
		var spawn_y = cfg.boss_start.y - 50.0 - i * 30.0
		# Pass each minion's own staggered offset back to itself — activate()'s
		# route_offset parameter defaults to ZERO, so omitting it here would
		# silently wipe the flanking spread set in _spawn_boss_entities() on
		# every trigger (including every mid-chase respawn re-trigger).
		_minions[i].activate(Vector2(spawn_x, spawn_y), _player, cfg.minion_speed,
			_minions[i]._route_offset)

	var audio = get_node_or_null("Audio")
	if audio != null and audio.has_method("on_boss_chase_started"):
		audio.on_boss_chase_started()

	print("[Main] Boss chase activated! %d minions" % _minions.size())


func _respawn(cause: RespawnCause = RespawnCause.FALL) -> void:
	# Fly mode is a REVIEW tool: the whole point is to inspect a route without
	# playing it, and a tester who gets killed by the lava they were flying
	# over to look at cannot do that. Gated here rather than in each hazard so
	# no death path can miss it — blades, pendulums, lava, chasers and the kill
	# plane all funnel through this one function.
	#
	# A MANUAL restart still works, so a tester is never trapped in fly mode.
	# Only intercept a HAZARD death (FALL). COMPLETE is not a death - it is
	# the level being won, and _teleport_to_goal() exists specifically so a
	# tester can exercise that path under fly/godmode. The guard used to match
	# "not MANUAL", which caught COMPLETE too and skipped the entire reset
	# block below (spawn position, run timer, rising lava) whenever someone
	# reached the goal with either tool still on.
	if cause == RespawnCause.FALL:
		var dev := get_node_or_null("/root/DevConsole")
		if dev != null:
			if dev.has_method("is_flying") and dev.is_flying():
				return
			# Godmode: still playing normally, just not dying to hazards.
			if dev.has_method("is_invulnerable") and dev.is_invulnerable():
				return

	var audio = get_node_or_null("Audio")
	if audio != null:
		match cause:
			RespawnCause.FALL:
				audio.play_death()
			RespawnCause.MANUAL:
				audio.play_restart()
			RespawnCause.COMPLETE:
				pass
		audio.stop_wall_slide()
	# A death gets a real jolt; a manual restart and a completion do not — the
	# shake is feedback for "you were killed", not for every scene reset.
	if cause == RespawnCause.FALL:
		var shake = _player.get_node_or_null("CameraShake")
		if shake != null:
			shake.add_trauma(0.85)
		_play_death_flash()
	# Respawn to the last claimed checkpoint if there is one. In-memory only —
	# see checkpoint_flag.gd for why a checkpoint is a within-attempt
	# convenience rather than saved progress.
	# The chase resets on death, so its clock resets too. Without this a player
	# who died late would respawn into an already-expired (and instantly
	# berserk) chase, which reads as the game cheating.
	_chase_time_left = (_level_data.boss_config.time_limit
		if _level_data != null and _level_data.boss_config.enabled else -1.0)
	_berserk = false
	for rl in _rising_lava:
		if is_instance_valid(rl):
			rl.reset()
	for d in _drones:
		if is_instance_valid(d):
			d.reset()
	var visuals = _player.get_node_or_null("Visuals")
	# A death leaves an echo playing where he fell, and the new life
	# materialises at the checkpoint. Both are purely visual.
	if cause == RespawnCause.FALL:
		Haptics.death()
	if cause == RespawnCause.FALL and visuals != null and visuals.has_method("play_death_echo"):
		visuals.play_death_echo(_player.global_position, _player.facing())
	_player.global_position = _active_checkpoint if _has_checkpoint else _spawn_point
	_death_line_primed = false
	_rise_peak = 0.0
	_player.reset_state()
	if visuals != null:
		visuals.reset_state()
		if cause != RespawnCause.COMPLETE and visuals.has_method("play_respawn"):
			visuals.play_respawn()
	run_time = 0.0
	_clock_running = false
	if cause != RespawnCause.COMPLETE:
		# A completion isn't a failed attempt, and game_scene.gd's completion
		# handler needs _level_complete to stay true so _physics_process()
		# keeps blocking gameplay input for the duration of the banner —
		# resetting it here (as a COMPLETE respawn) undid that freeze in the
		# very same call chain that had just set it, letting the player move
		# during "LEVEL COMPLETE" and inflating the attempt counter on every
		# clean finish. Only a real fall/manual respawn is a new attempt.
		attempts += 1
		for tg in _trap_groups:
			if is_instance_valid(tg):
				tg.reroll()
		# A restart never begins inside a storm.
		if _storm != null and is_instance_valid(_storm):
			_storm.reset()
		# Machine levels roll a whole new machine for every attempt.
		if _machine != null and is_instance_valid(_machine):
			_machine.roll()
		if _scares != null and is_instance_valid(_scares):
			_scares.on_respawn()
		# Plain-road levels roll a brand-new set of obstacles for every attempt.
		if _road_course != null and is_instance_valid(_road_course):
			_road_course.roll()
		# Reset completion flag so subsequent goals can fire (needed for
		# tests and standalone mode where game_scene transition doesn't
		# happen).
		_level_complete = false
		# SaveSystem.total_attempts is a lifetime counter across the whole
		# save file (unlike `attempts` above, which resets per level). The
		# JSON write below is small (a handful of ints/arrays) and this only
		# runs on a respawn event, not every frame, so saving here on every
		# death keeps the counter accurate through a crash/force-quit at
		# negligible cost.
		var gm = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.save_system.total_attempts += 1
			gm.save_system.save()

		# Escalating personality on repeated deaths. Called AFTER the attempt
		# counter increments so the tier reflects the death that just happened,
		# and it draws only — see death_feedback.gd for why nothing here is
		# allowed to delay the retry.
		if _death_feedback != null:
			_death_feedback.on_death(attempts)

	if _chase_triggered:
		_deactivate_boss_chase()
	# If player respawned past the trigger point, re-activate chase immediately
	if _level_data != null and _level_data.boss_config.enabled:
		if _player.global_position.x >= _level_data.boss_config.trigger_x:
			_trigger_boss_chase()


## Lethal hazards (spinning blades) only need to signal "the run just ended" —
## the same respawn path already used for falling off the level or a boss
## catch handles checkpoint/attempt-counting/audio consistently either way.
## Physics frame on which a hazard last triggered a respawn, so two hazards
## overlapping the player on the same frame count as one death. Unlike the
## boss/minion catch checks — which `return` after the first hit and so are
## naturally single-fire — every hazard emits player_hit independently, and a
## second callback in the same frame would bill the player two attempts and
## write the save file twice for one death.
var _last_hazard_respawn_frame: int = -1
var _drones: Array = []
var _machine: MachineRuntime = null
var _scares: ScareDirector = null



## Brief red screen flash on death, honouring the `death_flash` setting.
##
## That setting shipped with NO consumer anywhere in the project — it saved to
## settings.json and did nothing at all. This gives it real behaviour rather
## than deleting a toggle players had already been offered.
##
## Built on its own CanvasLayer above gameplay but below the pause menu
## (layer 200), and freed as soon as it finishes so nothing accumulates across
## the many deaths a run produces.
func _play_death_flash() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs != null and "death_flash" in gs and not gs.death_flash:
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.15, 0.12, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.34, 0.06)
	tween.tween_property(rect, "color:a", 0.0, 0.22)
	tween.finished.connect(func():
		if is_instance_valid(canvas):
			canvas.queue_free())


## Escalate rather than kill. Applied to the boss and every minion at once so
## the whole chase tightens together, which reads as the level turning on you.
func _go_berserk() -> void:
	_berserk = true
	var cfg = _level_data.boss_config
	if _boss != null:
		_boss.base_speed *= cfg.berserk_multiplier
		_boss.max_speed *= cfg.berserk_multiplier
	for minion in _minions:
		minion.base_speed *= cfg.berserk_multiplier
		minion.max_speed *= cfg.berserk_multiplier


## Seconds left on the boss clock, or -1 when no chase is running. Read by the
## HUD; kept as a method so the HUD never reaches into private state.
func boss_time_left() -> float:
	return _chase_time_left


func is_berserk() -> bool:
	return _berserk


func _on_checkpoint_reached(pos: Vector2) -> void:
	_active_checkpoint = pos
	_has_checkpoint = true


func _build_shooters(hazards: Node) -> void:
	for i in _level_data.shooters.size():
		var sdef: LevelData.ShooterDef = _level_data.shooters[i]
		var trap := ShooterTrap.new()
		trap.name = "Shooter_%d" % i
		trap.position = sdef.position
		trap.direction = sdef.direction
		trap.interval = sdef.interval
		trap.player_hit.connect(_on_chip_hit)
		hazards.add_child(trap)
		trap.owner = self


func _build_rising_lava(hazards: Node) -> void:
	for i in _level_data.rising_lava.size():
		var rdef: LevelData.RisingLavaDef = _level_data.rising_lava[i]
		var rl := RisingLava.new()
		rl.name = "RisingLava_%d" % i
		rl.position = Vector2(rdef.trigger_x, 0.0)
		rl.start_y = rdef.start_y
		rl.rise_speed = rdef.rise_speed
		rl.climb_height = rdef.climb_height
		rl.width = 6000.0
		rl.player_hit.connect(_on_hazard_hit)
		hazards.add_child(rl)
		rl.owner = self
		_rising_lava.append(rl)


func _build_plate_gates(hazards: Node) -> void:
	for i in _level_data.plate_gates.size():
		var gdef: LevelData.PlateGateDef = _level_data.plate_gates[i]
		var gate := PlateGate.new()
		gate.name = "Gate_%d" % i
		gate.position = gdef.gate_position
		gate.size = gdef.gate_size
		gate.link_id = gdef.link_id
		hazards.add_child(gate)
		gate.owner = self

		if gdef.use_slash:
			var lever := SlashSwitch.new()
			lever.name = "Switch_%d" % i
			lever.position = gdef.plate_position
			lever.hold_time = gdef.hold_time
			lever.link_id = gdef.link_id
			lever.activated.connect(func(id: int) -> void: _set_gates(id, true))
			lever.expired.connect(func(id: int) -> void: _set_gates(id, false))
			hazards.add_child(lever)
			lever.owner = self
			continue
		var plate := PressurePlate.new()
		plate.name = "Plate_%d" % i
		plate.position = gdef.plate_position
		plate.hold_time = gdef.hold_time
		plate.link_id = gdef.link_id
		plate.activated.connect(func(id: int) -> void: _set_gates(id, true))
		plate.expired.connect(func(id: int) -> void: _set_gates(id, false))
		hazards.add_child(plate)
		plate.owner = self


## A machine level: the terrain and hazards are rolled by MachineRuntime, and again on every death.
func _build_machine() -> void:
	if _machine != null and is_instance_valid(_machine):
		_machine.free()
	_machine = null
	if _level_data == null or not _level_data.machine:
		return
	_machine = MachineRuntime.new()
	_machine.name = "Machine"
	add_child(_machine)
	_machine.setup(level_number, _level_data.theme, _on_hazard_hit, _on_chip_hit, MachineLevel.boss_factor(level_number), _on_orb_collected)
	_machine.roll()
	if _scares != null and is_instance_valid(_scares):
		_scares.free()
	_scares = ScareDirector.new()
	_scares.name = "Scares"
	add_child(_scares)
	_scares.attach(_machine, _player)


## The HUD line for a machine level: the roll's code and, for the extremes, how lucky it is. The
## tag is computed from the validator's measured odds, so it is honest.
func machine_roll_text() -> String:
	if _machine == null or not is_instance_valid(_machine) or _machine.spec.is_empty():
		return ""
	var text := "ROLL %s" % MachineRuntime.seed_code(_machine.seed_value)
	var odds: Dictionary = _machine.spec.get("odds", {})
	if not odds.is_empty() and float(odds.get("target", 0.0)) > 0.0:
		var ratio := float(odds["median"]) / float(odds["target"])
		if ratio >= 1.4:
			text += "  LUCKY ROLL"
		elif ratio <= 0.7:
			text += "  BRUTAL ROLL"
	return text


## Hovering enemies the player kills with M1. They return on every respawn.
func _build_drones(hazards: Node) -> void:
	_drones.clear()
	for i in _level_data.drones.size():
		var ddef: Array = _level_data.drones[i]
		var drone := Drone.new()
		drone.name = "Drone_%d" % i
		drone.position = ddef[0]
		drone.patrol_range = float(ddef[1])
		drone.player_hit.connect(_on_chip_hit)
		hazards.add_child(drone)
		drone.owner = self
		_drones.append(drone)


func _set_gates(link_id: int, open: bool) -> void:
	var hazards := get_node_or_null("Hazards")
	if hazards == null:
		return
	for child in hazards.get_children():
		if child is PlateGate and child.link_id == link_id:
			if open:
				child.open()
			else:
				child.close()


## Trevor's orbs. Already-collected ones are built but hidden rather than
## skipped, so the indices stay stable between a first run and a replay — the
## save record is keyed by index, and skipping would renumber them.
func _build_orbs(hazards: Node) -> void:
	# A machine level rolls its own core nook (see MachineRuntime), so no fixed orb is built here.
	if _level_data != null and _level_data.machine:
		return
	var gm := get_node_or_null("/root/GameManager")
	var defs: Array = LevelData.orbs_for(level_number)
	for i in defs.size():
		var odef = defs[i]
		var orb := Orb.new()
		orb.name = "Orb_%d" % i
		orb.position = odef.position
		orb.kind = (Orb.Kind.ROUTE if odef.kind == 0 else Orb.Kind.OPTIONAL)
		orb.level_num = level_number
		orb.index = i
		orb.collected.connect(_on_orb_collected)
		hazards.add_child(orb)
		orb.owner = self
		if gm != null and gm.save_system != null 				and gm.save_system.has_orb(level_number, i):
			orb.mark_already_taken()


func _on_orb_collected(lvl: int, index: int) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.save_system == null:
		return
	# Save immediately. An orb picked up and then lost to a crash or a force
	# quit is exactly the kind of thing that makes a collectible feel unfair,
	# and the write is small.
	if gm.save_system.collect_orb(lvl, index):
		gm.save_system.save()
		orb_collected.emit(gm.save_system.orb_total())
		var live_gate := get_node_or_null("Goal/GoalGate") as GoalGate
		if live_gate != null:
			live_gate.cores = gm.save_system.orb_total()


## The floor of the world. Derived from the level rather than authored per
## level: it belongs below whatever geometry exists, so hand-placing it would
## be one more number to keep in sync every time a platform moves.
func _build_death_plane(hazards: Node) -> void:
	var lowest := -INF
	var left := INF
	var right := -INF
	for pdef in _level_data.platforms:
		if String(pdef.name).contains("Wall"):
			continue
		lowest = maxf(lowest, pdef.position.y + pdef.size.y * 0.5)
		left = minf(left, pdef.position.x - pdef.size.x * 0.5)
		right = maxf(right, pdef.position.x + pdef.size.x * 0.5)
	if lowest == -INF:
		return

	_platform_spans.clear()
	for pdef in _level_data.platforms:
		if String(pdef.name).contains("Wall"):
			continue
		# A moving platform can ride below where it is authored, so its lowest
		# point counts: the line must never sit above anything the player can stand on.
		var lowest_top: float = pdef.position.y - pdef.size.y * 0.5
		var x_lo: float = pdef.position.x - pdef.size.x * 0.5
		var x_hi: float = pdef.position.x + pdef.size.x * 0.5
		if pdef.kind == "moving":
			var travel: Vector2 = pdef.extra.get("travel", Vector2(220.0, 0.0))
			lowest_top += maxf(absf(travel.y), 0.0)
			x_lo -= absf(travel.x)
			x_hi += absf(travel.x)
		_platform_spans.append(Vector3(x_lo, x_hi, lowest_top))

	var plane := DeathPlane.new()
	plane.name = "DeathPlane"
	plane.kind = DeathPlane.kind_for_level(level_number)
	# Wide enough to cover the level plus a generous margin either side, so
	# there is no way to fall PAST the floor of the world.
	plane.width = maxf(right - left, 1000.0) + 4000.0
	plane.position = Vector2((left + right) * 0.5, lowest + DEATH_PLANE_CLEARANCE)
	plane.player_hit.connect(_on_hazard_hit)
	hazards.add_child(plane)
	plane.owner = self
	_death_plane = plane
	_plane_global_y = plane.position.y
	_announce_rising_floor(plane.kind)

	# kill_depth has to move BELOW the plane, or it fires first and the plane
	# never does anything. Several levels author a kill_depth shallower than
	# where the plane lands, which made the plane pure decoration. It is now
	# what it was always meant to be — a backstop for anything that somehow
	# gets past the floor — rather than the primary cutoff.
	kill_depth = maxf(kill_depth, plane.position.y + 400.0)


## One line at the start of a boss level, telling the player what the clock does.
func _announce_rising_floor(kind: int) -> void:
	if _level_data == null or not _level_data.boss_config.enabled:
		return
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null and not gs.boss_warnings:
		return
	var words := {
		DeathPlane.Kind.GROUND: "THE GROUND IS RISING",
		DeathPlane.Kind.WATER: "THE WATER IS RISING",
		DeathPlane.Kind.ICE: "THE ICE IS CREEPING UP",
		DeathPlane.Kind.LAVA: "THE LAVA IS RISING",
		DeathPlane.Kind.ACID: "THE ACID IS RISING",
	}
	var layer := CanvasLayer.new()
	layer.layer = 105
	layer.name = "RisingFloorNotice"
	add_child(layer)
	var label := Label.new()
	label.text = String(words.get(kind, "THE FLOOR IS RISING")) + " - KEEP CLIMBING"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 196.0
	label.offset_left = -400.0
	label.offset_right = 400.0
	label.add_theme_font_size_override("font_size", UITheme.sz(24))
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)

	# A glow along the bottom edge of the screen that strengthens as the floor
	# closes in, so the danger is felt before it is seen.
	var glow_layer := CanvasLayer.new()
	glow_layer.layer = 104
	glow_layer.name = "RisingFloorGlow"
	add_child(glow_layer)
	var tint: Color = {
		DeathPlane.Kind.GROUND: Color(0.8, 0.7, 0.5),
		DeathPlane.Kind.WATER: Color(0.3, 0.6, 1.0),
		DeathPlane.Kind.ICE: Color(0.7, 0.95, 1.0),
		DeathPlane.Kind.LAVA: Color(1.0, 0.4, 0.15),
		DeathPlane.Kind.ACID: Color(0.5, 1.0, 0.3),
	}.get(kind, Color(1.0, 0.4, 0.2))
	var grad := Gradient.new()
	grad.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	grad.set_color(1, Color(tint.r, tint.g, tint.b, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rect.offset_top = -260.0
	rect.modulate.a = 0.0
	glow_layer.add_child(rect)
	_rise_glow = rect


## Boss levels only: where the climbing biome floor is right now, driven by the boss
## countdown (full height when it reaches zero). INF on every other level.
func rising_floor_y() -> float:
	if _level_data == null or not _level_data.boss_config.enabled or _plane_global_y == 0.0:
		return INF
	var limit: float = _level_data.boss_config.time_limit
	if limit <= 0.0 or _chase_time_left < 0.0 and not _berserk:
		return INF
	# The floor never falls back inside an attempt: when the countdown runs out before
	# the chase starts, the chase restarts the clock, and the floor must stay where it got to.
	_rise_peak = maxf(_rise_peak, clampf(1.0 - _chase_time_left / limit, 0.0, 1.0))
	var climb: float = _plane_global_y - _level_data.goal_position.y
	var share := BOSS_RISE_SHARE
	if _level_data.rise_end_y != INF:
		# Flat roads: the floor ends above road level, so it genuinely catches the slow.
		climb = _plane_global_y - _level_data.rise_end_y
		share = 1.0
	return _plane_global_y - climb * share * pow(_rise_peak, BOSS_RISE_POWER)


## Where the local death line should be for a player at world x: a short drop
## under the lowest platform surface within LOCAL_DEATH_WINDOW, never below the
## level-wide floor. Falls back to the level-wide floor when nothing is near.
static func local_death_y(spans: Array[Vector3], player_x: float, global_y: float) -> float:
	var lowest_surface := -INF
	for sp in spans:
		if sp.y < player_x - LOCAL_DEATH_WINDOW or sp.x > player_x + LOCAL_DEATH_WINDOW:
			continue
		lowest_surface = maxf(lowest_surface, sp.z)
	if lowest_surface == -INF:
		return global_y
	return minf(global_y, lowest_surface + LOCAL_DEATH_DROP)


## Slide the visible floor to the local death line, so the void under the
## player is short and the surface they die on is the one they can see.
func _update_local_death_line(delta: float) -> void:
	if _death_plane == null or not is_instance_valid(_death_plane) or _player == null:
		return
	var target := local_death_y(_platform_spans, _player.global_position.x, _plane_global_y)
	var rising := rising_floor_y()
	if rising != INF:
		target = minf(target, rising)
		if _rise_glow != null and is_instance_valid(_rise_glow):
			# 0 when the floor is far below the player, 1 when it is at their feet.
			var gap := rising - _player.global_position.y
			_rise_glow.modulate.a = clampf(1.0 - gap / 700.0, 0.0, 1.0)
	var current := _death_plane.position.y
	if not _death_line_primed:
		_death_line_primed = true
		_death_plane.position.y = target
	elif target >= current:
		_death_plane.position.y = target
	else:
		_death_plane.position.y = maxf(target, current - LOCAL_DEATH_RISE_SPEED * delta)


## A chip hazard touched the player: one cell, a second of invulnerability and a knockback. The
## last cell is a death like any other. Instant hazards never come through here.
func _on_chip_hit(source_x: float = NAN) -> void:
	if _player == null or _level_complete:
		return
	var dev := get_node_or_null("/root/DevConsole")
	if dev != null and dev.has_method("is_invulnerable") and dev.is_invulnerable():
		return
	var result := _player.take_chip_hit(source_x)
	if result == "dead":
		_on_hazard_hit()
	elif result == "hurt":
		SfxHub.play(get_tree(), "hurt")
		var shake = _player.get_node_or_null("CameraShake")
		if shake != null:
			shake.add_trauma(0.5)
		Haptics.death()


func _on_hazard_hit() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _last_hazard_respawn_frame:
		return
	_last_hazard_respawn_frame = frame
	_respawn(RespawnCause.FALL)


func _deactivate_boss_chase() -> void:
	_chase_triggered = false
	_chase_active = false
	if _chase_indicator != null:
		_chase_indicator.active = false
	if _boss != null:
		_boss.deactivate()
	for minion in _minions:
		minion.deactivate()
	var audio = get_node_or_null("Audio")
	if audio != null and audio.has_method("on_boss_chase_ended"):
		audio.on_boss_chase_ended()


## The player reached the door: it drains open and flares.
func _on_goal_touched_by_player(body: Node2D) -> void:
	if not (body is Player):
		return
	var gate := get_node_or_null("Goal/GoalGate") as GoalGate
	if gate != null:
		gate.open()
		SfxHub.play(get_tree(), "door")


func _on_goal_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	if _level_complete:
		return  # Prevent duplicate triggers

	# The final door is deliberately NOT gated on orbs yet. The 100-orb target
	# belongs to the finished 100-level game; 25 levels can only produce 25
	# orbs, so checking it today would make the game unfinishable. Orbs are
	# collectibles that persist and count — the door that charges for them is
	# a v2 decision.

	_level_complete = true
	last_run_time = run_time
	_clock_running = false
	# Stop player movement
	_player.velocity = Vector2.ZERO
	# Deactivate boss chase if active
	if _chase_active:
		_deactivate_boss_chase()
	level_completed.emit()
	print("[Main] Level %d complete in %.2fs (attempt %d)" % [level_number, last_run_time, attempts])
	# Respawn player back to spawn so they are in a safe state while the
	# completion banner displays (game_scene.gd handles the transition).
	_respawn(RespawnCause.COMPLETE)


func restart_level() -> void:
	_level_complete = false
	_respawn(RespawnCause.MANUAL)
