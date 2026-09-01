extends SceneTree
## Death-feedback tiers, asserted by OBSERVABLE EFFECT.
##
## death_feedback.gd shipped written-but-never-instantiated: the class existed,
## compiled, and did nothing, because main_scene.gd never built one. A suite
## that only checked "the class exists" would have passed that. So every check
## here reads the label the player would actually see.
##
## The invariant that matters most is the last one: nothing in this system may
## delay a retry. A player on their fiftieth death is the single most likely
## person to quit, and a respawn that makes them wait is the exact wrong answer.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_death_feedback.gd

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var df := DeathFeedback.new()
	get_root().add_child(df)
	# _ready() is deferred, so the CanvasLayer and Label do not exist until the
	# tree has processed one frame. Reading them before that yields null.
	await process_frame
	var lbl: Label = df.get_child(0).get_child(0)

	# --- Under the taunt threshold: completely silent ----------------------
	df.on_death(1)
	_check("death 1: no message", lbl.text == "")
	df.on_death(DeathFeedback.TAUNT_THRESHOLD - 1)
	_check("death %d: still silent" % (DeathFeedback.TAUNT_THRESHOLD - 1),
		lbl.text == "")

	# --- Taunt tier --------------------------------------------------------
	df.on_death(DeathFeedback.TAUNT_THRESHOLD)
	var taunt := lbl.text
	_check("death %d: a taunt appears" % DeathFeedback.TAUNT_THRESHOLD,
		taunt != "" and DeathFeedback.TAUNTS.has(taunt))

	# --- Support tier takes over, and does NOT taunt -----------------------
	df.on_death(DeathFeedback.SUPPORT_THRESHOLD)
	var support := lbl.text
	_check("death %d: supportive line, not a taunt" % DeathFeedback.SUPPORT_THRESHOLD,
		DeathFeedback.SUPPORT.has(support) and not DeathFeedback.TAUNTS.has(support))
	_check("support tier is visually distinct from the taunt tier",
		lbl.get_theme_color("font_color") != Color(0.85, 0.80, 0.60))

	# --- clear() wipes it, so a taunt cannot leak into the next level ------
	df.clear()
	_check("clear(): message faded out", is_zero_approx(lbl.modulate.a))

	# --- The non-negotiable: this never blocks -----------------------------
	# on_death must be synchronous and instant at EVERY tier. If it ever grew
	# an await or a wait-for-animation, the respawn would stall behind it.
	var t0 := Time.get_ticks_usec()
	for i in 200:
		df.on_death(DeathFeedback.SUPPORT_THRESHOLD + i)
	var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_check("200 deaths at the highest tier cost %.1fms (must be under one frame's 16ms)"
		% elapsed_ms, elapsed_ms < 16.0)

	df.queue_free()

	# --- The check that would actually have caught the original bug --------
	# Everything above tests the class in isolation, and the class was never
	# the problem: it compiled fine and did nothing, because main_scene.gd
	# never built one. So load a real level and assert the node is there and
	# that a real respawn drives it.
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	var wired = scene.get_node_or_null("DeathFeedback")
	_check("main_scene builds a DeathFeedback", wired != null)
	if wired != null:
		var wired_label: Label = wired.get_child(0).get_child(0)
		# Drive real respawns up past the taunt threshold and require that the
		# player would see something. Attempts increments inside _respawn.
		while scene.get("attempts") <= DeathFeedback.TAUNT_THRESHOLD:
			scene._respawn(0)
			await process_frame
		_check("a real respawn past the threshold shows a message",
			wired_label.text != "")
	scene.queue_free()
	await process_frame

	print("[test_death_feedback] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
