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

## Boss chase state (Level 5 only)
var _boss = null
var _minions: Array = []
var _chase_active: bool = false
var _chase_triggered: bool = false
var _terrain_built: bool = false

## Level completion state — prevents duplicate goal triggers and input
## while the completion banner is displayed.
var _level_complete: bool = false


func _ready() -> void:
	# Level 1 already has correct terrain in the .tscn — only rebuild for
	# levels 2+.  This avoids queue_free timing issues that break headless
	# tests (old platforms linger one frame, causing physics explosions).
	if level_number > 1:
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
		var platform = platform_scene.instantiate()
		platform.name = pdef.name
		platform.position = pdef.position
		platform.size = pdef.size
		platform.color = pdef.color
		platform.edge_color = pdef.edge_color
		platform.edge_thickness = pdef.edge_thickness
		terrain.add_child(platform)
		platform.owner = self

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

	# Boss chase: catch detection (uses entity catch_distance)
	if _chase_triggered and _boss != null and _boss.is_active():
		if _boss.has_caught_player():
			_respawn(RespawnCause.FALL)
			return
		for minion in _minions:
			if minion.is_active() and minion.has_caught_player():
				_respawn(RespawnCause.FALL)
				return

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
		_minions[i].activate(Vector2(spawn_x, spawn_y), _player, cfg.minion_speed)

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
	_player.global_position = _spawn_point
	_player.reset_state()
	var visuals = _player.get_node_or_null("Visuals")
	if visuals != null:
		visuals.reset_state()
	attempts += 1
	run_time = 0.0
	_clock_running = false
	# Reset completion flag so subsequent goals can fire (needed for tests
	# and standalone mode where game_scene transition doesn't happen)
	_level_complete = false

	if _chase_triggered:
		_deactivate_boss_chase()


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
