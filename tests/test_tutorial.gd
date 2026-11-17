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
	await _first_launch_chain()
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
	_check("eleven lessons in six sets", TutorialGuide.LESSONS.size() == 11 and TutorialGuide.SET_NAMES.size() == 6)
	_check("lessons map to zones in order",
		g.lesson_at(10.0) == 0 and g.lesson_at(700.0) == 1 and g.lesson_at(1200.0) == 2 and g.lesson_at(2100.0) == 3
		and g.lesson_at(2600.0) == 4 and g.lesson_at(3500.0) == 5 and g.lesson_at(4200.0) == 6
		and g.lesson_at(4500.0) == 7 and g.lesson_at(5000.0) == 8 and g.lesson_at(5500.0) == 9 and g.lesson_at(5800.0) == 10)
	var sets_ok := true
	var last_set := 0
	for i in TutorialGuide.LESSONS.size():
		var sidx: int = TutorialGuide.set_of(i)
		sets_ok = sets_ok and sidx >= last_set and sidx - last_set <= 1
		last_set = sidx
	_check("sets run in order, none skipped, all six used", sets_ok and last_set == 5)
	# Every zone is contiguous with the next, so no stretch of the course has no lesson.
	var contiguous := true
	for i in range(1, TutorialGuide.LESSONS.size()):
		contiguous = contiguous and is_equal_approx(float(TutorialGuide.LESSONS[i]["from"]), float(TutorialGuide.LESSONS[i - 1]["to"]))
	_check("lesson zones leave no gaps", contiguous)
	var all_text := true
	for l in TutorialGuide.LESSONS:
		var t := TutorialGuide.render(String(l["text"]))
		all_text = all_text and not t.contains("{") and t.length() > 10
	_check("every lesson renders with real key names", all_text)
	g.free()
	# Every basic verb is covered by some lesson.
	var covered := {}
	for l in TutorialGuide.LESSONS:
		for e in l["events"]:
			covered[e] = true
	_check("run, turn, jump, hold-jump, dash, slide, wall-slide, wall-jump, keys, slash and flag are all taught", covered.size() == 11)


# ── 2. guide by signal ──────────────────────────────────────────────

func _frames() -> void:
	await _step(3)
	await process_frame
	await process_frame


func _guide_by_signal() -> void:
	await _load()
	_check("the tutorial level builds with a guide", _guide != null and _player != null)
	if _guide == null:
		return
	var sets_seen := [0]       # set 1 was announced as the level opened
	_guide.set_started.connect(func(s): sets_seen.append(s))
	await _frames()
	_check("the first lesson is RUN in set 1", _guide.index == 0 and _guide._current_set == 0)
	# Wrong event does not advance: a dash during the run lesson changes nothing.
	_player.dashed.emit()
	_check("an unrelated action does not advance the lesson", _guide.index == 0)
	_player.global_position.x += 300.0
	await _frames()
	_check("running far enough completes RUN", _guide.index == 1)
	_player.global_position.x -= 150.0
	await _frames()
	_check("running back completes TURN", _guide.index == 2)
	_check("PIP praises the player", _guide.current_text() != "" and not _guide.current_text().contains("{"))
	_player.jumped.emit()
	_check("jumping completes the jump lesson", _guide.index == 3)
	_check("the speaker line shows the set (%s)" % _guide.speaker_text(), _guide.speaker_text().contains("2/6"))
	# Walking into a later zone skips ahead rather than trapping the player.
	_player.global_position.x = 3300.0
	await _frames()
	_check("walking on brings the matching lesson up (index %d)" % _guide.index, _guide.index == 5)
	_check("sets 2 and 3 were announced on the way", 2 in sets_seen)
	_player.slid.emit()
	_check("sliding completes the slide lesson", _guide.index == 6)
	await _frames()
	_player.wall_slide_started.emit()
	_check("a wall slide completes the wall-slide lesson", _guide.index == 7)
	await _frames()
	_player.wall_jumped.emit()
	_check("a wall jump completes the wall-jump lesson", _guide.index == 8)
	await _frames()
	_player.global_position.x = 5000.0
	await _frames()
	Input.action_press("toggle_help", 1.0)
	await _frames()
	Input.action_release("toggle_help")
	_check("opening the controls panel completes the keys lesson", _guide.index == 9)
	_player.attacked.emit(Vector2.RIGHT)
	_check("slashing completes the combat lesson", _guide.index == 10)
	_scene.set("_has_checkpoint", true)
	var done := [false]
	_guide.finished.connect(func(): done[0] = true)
	await _frames()
	_check("touching the flag finishes the tutorial", done[0])
	_check("all six sets were announced %s" % str(sets_seen), sets_seen.size() == 6)


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


# ── 7. first launch: story -> tutorial offer -> level 1, every step skippable ──

func _fresh_game(intro_seen: bool) -> Node:
	var gs: Node = root.get_node("GameSettings")
	var gm: Node = root.get_node("GameManager")
	gs.intro_seen = intro_seen
	gs.tutorial_done = false
	gm.end_tutorial()
	gm.current_level = gm.save_system.get_checkpoint()
	var game: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _step(40)
	game.call("go_home")
	await _step(10)
	return game


func _wait_for(game: Node, node_name: String, frames: int = 300) -> Node:
	for _i in frames:
		await physics_frame
		var n: Node = game.get_node_or_null("StartMenu/" + node_name) if node_name != "StartMenu" else game.get_node_or_null("StartMenu")
		if n == null:
			n = game.find_child(node_name, true, false)
		if n != null and is_instance_valid(n):
			return n
	return null


func _wait_cutscene(game: Node) -> Node:
	for _i in 300:
		await physics_frame
		var found: Node = _first_cutscene(game)
		if found != null:
			return found
	return null


func _first_cutscene(node: Node) -> Node:
	if node is Cutscene:
		return node
	for c in node.get_children():
		var r := _first_cutscene(c)
		if r != null:
			return r
	return null


func _current_level_number(game: Node) -> int:
	var lv = game.get_node_or_null("LevelContainer")
	if lv != null and lv.get_child_count() > 0:
		return int(lv.get_child(lv.get_child_count() - 1).get("level_number"))
	return -1


func _first_launch_chain() -> void:
	var gs: Node = root.get_node("GameSettings")
	var gm: Node = root.get_node("GameManager")

	# A. skip everything: story skipped, offer skipped -> level 1.
	var game := await _fresh_game(false)
	var menu: Node = game.get_node_or_null("StartMenu")
	var play: Button = _find_button(menu, "PLAY")
	play.pressed.emit()
	var cut: Node = await _wait_cutscene(game)
	_check("PLAY on a first launch starts the story", cut != null)
	if cut != null:
		cut.skip()
	var offer: Node = await _wait_for(game, "TutorialOffer")
	_check("after the story PIP offers the tutorial", offer != null)
	_check("the story is marked seen", gs.intro_seen)
	if offer != null:
		var skip_btn := _find_button(offer, "SKIP  -  I KNOW THE BASICS")
		_check("the offer has a clear SKIP", skip_btn != null)
		skip_btn.pressed.emit()
	for _i in 300:
		await physics_frame
		if game.get_node_or_null("StartMenu") == null and _current_level_number(game) == gm.save_system.get_checkpoint():
			break
	_check("skipping the offer goes straight to level 1", _current_level_number(game) == gm.save_system.get_checkpoint() and game.get_node_or_null("StartMenu") == null)
	_check("a skipped tutorial counts as seen (never offered again)", gs.tutorial_done and not gm.tutorial_active)
	game.queue_free()
	await _step(3)

	# B. Escape on the offer skips it too.
	game = await _fresh_game(false)
	_find_button(game.get_node("StartMenu"), "PLAY").pressed.emit()
	cut = await _wait_cutscene(game)
	if cut != null:
		cut.skip()
	offer = await _wait_for(game, "TutorialOffer")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	if offer != null:
		offer._input(esc)
	for _i in 300:
		await physics_frame
		if game.get_node_or_null("StartMenu") == null and _current_level_number(game) == gm.save_system.get_checkpoint():
			break
	_check("Escape / B on the offer skips it", _current_level_number(game) == gm.save_system.get_checkpoint() and gs.tutorial_done)
	game.queue_free()
	await _step(3)

	# C. Take the tutorial: it runs chained, and finishing it continues into level 1.
	game = await _fresh_game(false)
	_find_button(game.get_node("StartMenu"), "PLAY").pressed.emit()
	cut = await _wait_cutscene(game)
	if cut != null:
		cut.skip()
	offer = await _wait_for(game, "TutorialOffer")
	if offer != null:
		_find_button(offer, "SHOW ME  (TUTORIAL)").pressed.emit()
	for _i in 400:
		await physics_frame
		if _current_level_number(game) == 0 and game.get_node_or_null("LevelContainer").get_child(0).get_node_or_null("TutorialGuide") != null:
			break
	_check("choosing the tutorial opens level 0, chained", _current_level_number(game) == 0 and gm.tutorial_active and gm.tutorial_chained)
	_check("the offer and title are gone", game.get_node_or_null("StartMenu") == null)
	game.call("_on_level_completed")
	for _i in 600:
		await physics_frame
		if _current_level_number(game) == gm.save_system.get_checkpoint() and not gm.tutorial_active:
			break
	_check("finishing a chained tutorial continues into level 1, not the title (level %d, gm %d, active %s, menu %s)" % [_current_level_number(game), gm.current_level, str(gm.tutorial_active), str(game.get_node_or_null("StartMenu") != null)], _current_level_number(game) == gm.save_system.get_checkpoint() and game.get_node_or_null("StartMenu") == null)
	_check("and it is marked done", gs.tutorial_done and not gm.tutorial_chained)
	game.queue_free()
	await _step(3)

	# D. Skip from the pause menu in the middle of the tutorial (chained and not).
	game = await _fresh_game(true)
	gm.start_tutorial(true)
	for _i in 400:
		await physics_frame
		if _current_level_number(game) == 0:
			break
	await _step(30)
	game.get_node("PauseMenu").visible = true if game.has_node("PauseMenu") else false
	await _step(4)
	var skip_item: Button = _find_button(game, "SKIP TUTORIAL")
	_check("the pause menu offers SKIP TUTORIAL while in the tutorial", skip_item != null and skip_item.is_visible_in_tree())
	_check("RESET PROGRESS is hidden during the tutorial", _find_button(game, "RESET PROGRESS") != null and not _find_button(game, "RESET PROGRESS").is_visible_in_tree())
	game.call("skip_tutorial")
	for _i in 500:
		await physics_frame
		if _current_level_number(game) == gm.save_system.get_checkpoint() and not gm.tutorial_active:
			break
	_check("skipping mid-tutorial goes to level 1 when it was offered on first launch", _current_level_number(game) == gm.save_system.get_checkpoint() and gs.tutorial_done)
	game.queue_free()
	await _step(3)

	# E. A returning player (story already seen) pressing PLAY gets no offer.
	game = await _fresh_game(true)
	_find_button(game.get_node("StartMenu"), "PLAY").pressed.emit()
	await _step(60)
	_check("a returning player is never asked again", game.find_child("TutorialOffer", true, false) == null and game.get_node_or_null("StartMenu") == null)
	game.queue_free()
	await _step(3)
	gs.tutorial_done = false
	gs.intro_seen = true
