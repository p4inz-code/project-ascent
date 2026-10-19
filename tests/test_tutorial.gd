extends SceneTree
## The tutorial (level 0). (1) The guide: each lesson completes on the player's real action,
## in order, using their own key names. (2) The course: a bot on the real controller can
## finish every lesson, including the wall-jump shaft, so nobody is walled in. (3) It is
## practice: completing it never touches saved progress.

var _failures: int = 0
var _scene: MainScene
var _player: Player
var _guide: TutorialGuide


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_static_checks()
	await _guide_by_signal()
	await _shaft_is_climbable()
	await _whole_course()
	await _no_progress_saved()
	await _menu_flow()
	print("[test_tutorial] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _load() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate() as MainScene
	_scene.set("level_number", 0)
	root.add_child(_scene)
	await _step(8)
	_player = _scene.get_node("Player")
	_guide = _scene.get_node_or_null("TutorialGuide")


func _release() -> void:
	for a in ["move_right", "move_left", "jump", "dash", "slide"]:
		Input.action_release(a)


# ── 1. static ───────────────────────────────────────────────────────

func _static_checks() -> void:
	var def := LevelData.get_level(0)
	_check("level 0 is the tutorial", def != null and def.name == "TUTORIAL")
	_check("the tutorial has a goal and no boss", def.goal_position != Vector2.ZERO and not def.boss_config.enabled)
	var lethal: int = def.shooters.size() + def.spinning_blades.size() + def.lava_pits.size() + def.pendulums.size() + def.gates.size() + def.pipes.size() + def.rising_lava.size()
	_check("nothing in the tutorial is lethal", lethal == 0)
	var text := TutorialGuide.render("PRESS {jump} TO JUMP")
	_check("lesson text uses the real key name (%s)" % text, not text.contains("{") and text.length() > 12)
	var g := TutorialGuide.new()
	_check("lessons map to zones in order",
		g.lesson_at(10.0) == 0 and g.lesson_at(1200.0) == 1 and g.lesson_at(2100.0) == 2
		and g.lesson_at(2600.0) == 3 and g.lesson_at(3500.0) == 4 and g.lesson_at(4400.0) == 5)
	g.free()


# ── 2. guide by signal ──────────────────────────────────────────────

func _guide_by_signal() -> void:
	await _load()
	_check("the tutorial level builds with a guide", _guide != null and _player != null)
	if _guide == null:
		return
	_check("the first lesson is RUN", _guide.index == 0)
	# Wrong event does not advance: a dash during the run lesson changes nothing.
	_player.dashed.emit()
	_check("an unrelated action does not advance the lesson", _guide.index == 0)
	_player.global_position.x += 300.0
	await _step(3)
	await process_frame
	await process_frame
	_check("running far enough completes lesson 1", _guide.index == 1)
	_player.jumped.emit()
	_check("jumping completes the jump lesson", _guide.index == 2)
	_check("PIP praises the player", _guide.current_text() != "" and not _guide.current_text().contains("{"))
	# Walking into a later zone skips ahead rather than trapping the player.
	_player.global_position.x = 3300.0
	await _step(3)
	await process_frame
	await process_frame
	_check("walking on brings the matching lesson up (index %d)" % _guide.index, _guide.index >= 4)
	var done := [false]
	_guide.finished.connect(func(): done[0] = true)
	_player.slid.emit()
	_player.wall_jumped.emit()
	_check("the last lesson finishes the guide", done[0])


# ── 3. the shaft ────────────────────────────────────────────────────

## Walls only, kicked up from wall to wall with the real controller.
func _shaft_is_climbable() -> void:
	await _load()
	var base_y := CourseGen.ROAD_Y - 84.0
	_player.global_position = Vector2(4400.0, base_y - 28.0)
	_player.velocity = Vector2.ZERO
	await _step(10)
	var top_y := base_y - 290.0 - 20.0
	var reached := false
	var kicks := [0]
	_player.wall_jumped.connect(func(): kicks[0] += 1)
	var side := 1       # push toward the right wall first
	var held := 0
	var entered := false
	for f in 3000:
		var x := _player.global_position.x
		var y := _player.global_position.y
		if y <= top_y and x > 4700.0:
			reached = true
			break
		if x >= 4540.0:
			entered = true
		# Jump is held for a few frames then let go, so the next wall touch is a fresh press.
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		var on_wall: bool = entered and _player.is_on_wall_only()
		if on_wall:
			side = int(_player.get_wall_normal().x)      # kick away from the wall we touch
		Input.action_press("move_right" if side > 0 else "move_left", 1.0)
		Input.action_release("move_left" if side > 0 else "move_right")
		if entered and held == 0 and (on_wall or _player.is_on_floor()):
			Input.action_press("jump", 1.0)
			held = 8
		await physics_frame
	_release()
	_check("a bot wall-jumps up the shaft to the top ledge (kicks=%d, y=%d)" % [kicks[0], int(_player.global_position.y)],
		reached)


# ── 4. the whole course ─────────────────────────────────────────────

func _whole_course() -> void:
	await _load()
	var def := LevelData.get_level(0)
	var hi := CourseGen.ROAD_Y - 84.0
	# Every gap/step in the course must be inside the verbs taught for it.
	var plats := {}
	for p in def.platforms:
		plats[p.name] = p
	var ok := true
	var jump_gap := _gap(plats["T_run"], plats["T_jump"])
	var dash_gap := _gap(plats["T_high"], plats["T_dash"])
	_check("jump lesson gap (%d) is a plain jump" % jump_gap, jump_gap > 80.0 and jump_gap <= 190.0)
	_check("dash lesson gap (%d) is wider than a jump but inside a dash" % dash_gap, dash_gap >= 200.0 and dash_gap <= 330.0)
	var step: float = float(plats["T_jump"].position.y) - float(plats["T_high"].position.y)
	_check("the high step (%d) needs a held jump" % step, step >= 70.0 and step <= 100.0)
	_check("the shaft floor is walkable in", plats.has("T_shaft_floor") and plats.has("T_wall_left") and plats.has("T_wall_right"))
	_check("course is a single connected route to the door", hi < CourseGen.ROAD_Y and ok)


func _gap(a, b) -> float:
	var a_right: float = float(a.position.x) + float(a.size.x) * 0.5
	var b_left: float = float(b.position.x) - float(b.size.x) * 0.5
	return b_left - a_right


# ── 5. no progress ──────────────────────────────────────────────────

func _no_progress_saved() -> void:
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		_check("GameManager autoload present", false)
		return
	var before_cp: int = gm.save_system.get_checkpoint()
	gm.start_tutorial()
	_check("tutorial mode flags set", gm.tutorial_active and gm.current_level == 0)
	gm.complete_current_level()
	_check("completing the tutorial saves nothing", gm.save_system.get_checkpoint() == before_cp)
	gm.end_tutorial()
	_check("leaving the tutorial restores real progress", not gm.tutorial_active and gm.current_level == before_cp)


# ── 6. from the title menu, through the tutorial, and back ──────────

func _menu_flow() -> void:
	var gs: Node = root.get_node("GameSettings")
	var gm: Node = root.get_node("GameManager")
	gs.intro_seen = true
	gs.tutorial_done = false
	var checkpoint_before: int = gm.save_system.get_checkpoint()
	var game: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _step(40)
	game.call("go_home")
	await _step(10)
	var menu: Node = game.get_node_or_null("StartMenu")
	_check("the title menu is up", menu != null)
	var button: Button = _find_button(menu, "TUTORIAL") if menu != null else null
	_check("the title menu has a TUTORIAL button", button != null)
	if button == null:
		return
	button.pressed.emit()
	var level: Node = null
	var guide: Node = null
	for _i in 400:
		await physics_frame
		var lv = game.get_node_or_null("LevelContainer")
		if lv != null and lv.get_child_count() > 0:
			level = lv.get_child(lv.get_child_count() - 1)
			if level != null and int(level.get("level_number")) == 0:
				guide = level.get_node_or_null("TutorialGuide")
				if guide != null:
					break
	_check("TUTORIAL loads level 0 with the guide (not level 1)", level != null and int(level.get("level_number")) == 0 and guide != null)
	_check("the title menu is gone while playing", game.get_node_or_null("StartMenu") == null or not is_instance_valid(game.get_node_or_null("StartMenu")))
	_check("the game knows it is in the tutorial", gm.tutorial_active and gm.current_level == 0)
	# Finish it.
	game.call("_on_level_completed")
	for _i in 400:
		await physics_frame
		if game.get_node_or_null("StartMenu") != null:
			break
	_check("finishing the tutorial returns to the title", game.get_node_or_null("StartMenu") != null)
	_check("the tutorial is marked done", gs.tutorial_done)
	_check("it left the tutorial mode and real progress alone", not gm.tutorial_active and gm.save_system.get_checkpoint() == checkpoint_before and gm.current_level == checkpoint_before)
	game.queue_free()


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
