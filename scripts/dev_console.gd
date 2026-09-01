extends Node
## Hidden developer console, unlocked by a secret key sequence.
##
## Purpose (from the owner's brief): a tester who cannot pass a level should be
## able to skip it and keep testing, rather than stopping there. Crucially,
## every skip is LOGGED — so a tester giving up on Level 14 six times becomes
## difficulty data instead of a silent shrug. That log is the most valuable
## thing this feature produces.
##
## SECRECY
## The sequence is intentionally short so it is memorable, and guarded by
## silence rather than length: there is no prompt, no hint, no menu entry, no
## flash on a wrong key, and nothing about it appears in the README, the
## in-game UI, or the itch.io page. Nothing tells a player there is anything to
## find, so nobody stumbles into it by mashing.
##
## The sequence is defined here and NOWHERE else in the repository.

## Silent unlock sequence. Must be entered with no other keys in between.
##
## The owner's handle, chosen because a code they cannot recall is useless to
## them. The digit matters: it makes accidental entry during play effectively
## impossible, unlike an arrow-key sequence which collides with movement.
const SEQUENCE: Array[Key] = [KEY_P, KEY_4, KEY_I, KEY_N, KEY_Z]

## Wipe partial progress if the player pauses mid-sequence, so ordinary play
## cannot slowly accumulate into an accidental unlock.
const SEQUENCE_TIMEOUT: float = 2.0

const LOG_PATH := "user://dev_skips.log"

var _progress: int = 0
var _since_last_key: float = 0.0
var _unlocked: bool = false
var _overlay: CanvasLayer = null
var _flying: bool = false
var _status: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _flying:
		_fly_step(delta)
	if _progress > 0:
		_since_last_key += delta
		if _since_last_key > SEQUENCE_TIMEOUT:
			_progress = 0


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if not _unlocked:
		# Deliberately silent on both success and failure until the whole
		# sequence lands — a wrong key gives no feedback at all, so there is
		# nothing to probe against.
		if key.keycode == SEQUENCE[_progress]:
			_progress += 1
			_since_last_key = 0.0
			if _progress >= SEQUENCE.size():
				_unlock()
		else:
			# Restart cleanly, allowing this key to begin a fresh attempt.
			_progress = 1 if key.keycode == SEQUENCE[0] else 0
			_since_last_key = 0.0
		return

	match key.keycode:
		KEY_PAGEUP:
			_skip_level(1)
		KEY_PAGEDOWN:
			_skip_level(-1)
		KEY_HOME:
			_unlock_all()
		KEY_END:
			_toggle_overlay()
		KEY_INSERT:
			_toggle_fly()


func _unlock() -> void:
	_unlocked = true
	_build_overlay()
	_set_status("DEV MODE  ·  PgUp/PgDn skip  ·  Home unlock all  ·  Ins fly  ·  End hide")


func _build_overlay() -> void:
	if _overlay != null:
		return
	_overlay = CanvasLayer.new()
	# Above the pause menu (200) so it is never buried.
	_overlay.layer = 250
	add_child(_overlay)
	_status = Label.new()
	_status.position = Vector2(16, 8)
	_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.9))
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("shadow_offset_y", 2)
	_status.add_theme_font_size_override("font_size", 14)
	_overlay.add_child(_status)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _toggle_overlay() -> void:
	if _overlay != null:
		_overlay.visible = not _overlay.visible


func _skip_level(delta_levels: int) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var target: int = clampi(gm.current_level + delta_levels, 1, LevelData.TOTAL_LEVELS)
	if target == gm.current_level:
		return
	if delta_levels > 0:
		_log_skip(gm.current_level, target)
	# Mark the skipped level complete so level select stays consistent with
	# where the tester actually is.
	if delta_levels > 0 and gm.save_system != null:
		gm.save_system.complete_level(gm.current_level)
	# Deliberately NOT jump_to_level(): that refuses any level which is neither
	# current nor already completed, which is exactly right for the player-facing
	# level select and exactly wrong for a dev skip, whose whole purpose is to
	# reach a level you have not earned.
	gm.current_level = target
	gm.get_tree().paused = false
	gm.is_paused = false
	if gm.pause_menu != null:
		gm.pause_menu.visible = false
	gm.level_changed.emit(target)
	_set_status("DEV MODE  ·  now on level %d" % target)


func _unlock_all() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.save_system == null:
		return
	for i in range(1, LevelData.TOTAL_LEVELS + 1):
		gm.save_system.complete_level(i)
	_set_status("DEV MODE  ·  all %d levels unlocked" % LevelData.TOTAL_LEVELS)


## Append one line per skip. This is the point of the feature: which level a
## tester bailed on, and when. Plain text so it can be read or pasted without
## tooling, and appended rather than rewritten so a session's history survives.
func _log_skip(from_level: int, to_level: int) -> void:
	var line := "%s\tskipped L%d -> L%d\n" % [
		Time.get_datetime_string_from_system(), from_level, to_level]
	var f: FileAccess
	if FileAccess.file_exists(LOG_PATH):
		f = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(line)
		f.close()


## Exposed for tests only — the suite must be able to assert the console is
## locked by default without knowing the sequence.
func is_unlocked() -> bool:
	return _unlocked


## ── Fly mode ────────────────────────────────────────────────────────
## Free-flight over the whole level, for walking a route end to end without
## playing it. This is a REVIEW tool, not a cheat that makes levels easier:
## flying disables the player's own physics entirely, so there is no way to
## fly partway and then "land" into a normal run with an advantage.
##
## Deliberately gated behind the same unlock as everything else here, and
## deliberately not on a key an ordinary player would ever press mid-game.
func _toggle_fly() -> void:
	var player := _find_player()
	if player == null:
		_set_status("DEV MODE  ·  fly: no player in this scene")
		return
	_flying = not _flying
	player.set_physics_process(not _flying)
	if _flying:
		player.velocity = Vector2.ZERO
	set_process(true)
	_set_status("DEV MODE  ·  FLY %s  ·  WASD/arrows to move, Shift for fast"
		% ("ON" if _flying else "OFF"))


func _find_player() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	for node in tree.get_nodes_in_group("player"):
		return node
	# The player is not in a group, so fall back to the known scene path and
	# then to a recursive search — dev tooling should not break because a
	# scene got reorganised.
	var direct := tree.current_scene.find_child("Player", true, false)
	return direct


const FLY_SPEED: float = 620.0
const FLY_FAST_MULTIPLIER: float = 3.0


func _fly_step(delta: float) -> void:
	var player := _find_player()
	if player == null:
		_flying = false
		return
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if dir == Vector2.ZERO:
		# Also accept the game's own movement bindings, so flying uses the
		# same keys the tester already has their hands on.
		dir = Vector2(Input.get_axis("move_left", "move_right"), 0.0)
		if Input.is_action_pressed("jump"):
			dir.y -= 1.0
		if Input.is_action_pressed("slide"):
			dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	var speed := FLY_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FLY_FAST_MULTIPLIER
	player.global_position += dir.normalized() * speed * delta


func is_flying() -> bool:
	return _flying
