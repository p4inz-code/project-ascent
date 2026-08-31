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

@onready var _player: Player = $Player

var _spawn_point: Vector2

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
	kill_depth = _level_data.kill_depth
	_spawn_point = _player.global_position


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
		terrain.add_child(platform)
		platform.owner = self

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
		blade.player_hit.connect(_on_hazard_hit)
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
	for i in _level_data.zero_gravity.size():
		var zdef: LevelData.ZeroGravityDef = _level_data.zero_gravity[i]
		var zone := ZeroGravityZone.new()
		zone.name = "ZeroG_%d" % i
		zone.position = zdef.position
		zone.size = zdef.size
		hazards.add_child(zone)
		zone.owner = self
	for i in _level_data.pendulums.size():
		var pdef2: LevelData.PendulumDef = _level_data.pendulums[i]
		var pendulum := Pendulum.new()
		pendulum.name = "Pendulum_%d" % i
		pendulum.position = pdef2.position
		pendulum.arm_length = pdef2.arm_length
		pendulum.max_angle_deg = pdef2.max_angle_deg
		pendulum.swing_speed = pdef2.swing_speed
		pendulum.phase_offset = pdef2.phase_offset
		pendulum.player_hit.connect(_on_hazard_hit)
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


func _physics_process(delta: float) -> void:
	# Block ALL gameplay input while the completion banner is showing
	if _level_complete:
		return

	if not _clock_running and (Input.is_action_pressed("move_left")
			or Input.is_action_pressed("move_right")
			or Input.is_action_pressed("jump") or Input.is_action_pressed("dash")):
		_clock_running = true
		var audio = get_node_or_null("Audio")
		if audio != null:
			audio.unlock_audio()
	if _clock_running:
		run_time += delta

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

	# Trigger boss chase when player passes trigger_x
	if not _chase_triggered and _level_data != null and _level_data.boss_config.enabled:
		if _player.global_position.x >= _level_data.boss_config.trigger_x:
			_trigger_boss_chase()


func _trigger_boss_chase() -> void:
	_chase_triggered = true
	_chase_active = true
	var cfg = _level_data.boss_config

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
	_player.global_position = _spawn_point
	_player.reset_state()
	var visuals = _player.get_node_or_null("Visuals")
	if visuals != null:
		visuals.reset_state()
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


func _on_hazard_hit() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _last_hazard_respawn_frame:
		return
	_last_hazard_respawn_frame = frame
	_respawn(RespawnCause.FALL)


func _deactivate_boss_chase() -> void:
	_chase_triggered = false
	_chase_active = false
	if _boss != null:
		_boss.deactivate()
	for minion in _minions:
		minion.deactivate()
	var audio = get_node_or_null("Audio")
	if audio != null and audio.has_method("on_boss_chase_ended"):
		audio.on_boss_chase_ended()


func _on_goal_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	if _level_complete:
		return  # Prevent duplicate triggers
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
