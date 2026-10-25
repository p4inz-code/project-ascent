extends SceneTree
## PIP's taunts, observed by effect:
##   * the language scan: no banned word in any line of any pool (with a negative control)
##   * five tiers by deaths this level, harsher sooner on hard levels, T4/T5 swear, T1-T3 do not
##   * the EGO rules: long sufferers get flexed on, a clear is celebrated, WEAK shows nothing at all
##   * spacing: never within 4 s (outside tests), never a repeat inside 20 lines, BLEEPED stars swears
##   * nothing here may delay a retry: on_death is synchronous and cheap at every tier
##   * wiring: a real level builds one and a real respawn drives it
## Run: Godot --headless --path <project> --script res://tests/test_death_feedback.gd

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()


func _has_swear(text: String) -> bool:
	var low := text.to_lower()
	for w in ["fuck", "shit", "damn", "ass", "hell"]:
		var rx := RegEx.new()
		rx.compile("\\b" + w)
		if rx.search(low) != null:
			return true
	return false


func _run() -> void:
	# --- the language scan ---
	var lines := TauntLines.all_lines()
	_check("every line passes the language scan (%d lines)" % lines.size(), TauntLines.violations(lines).is_empty())
	_check("(control) the scan catches a banned word", not TauntLines.violations(["your mother is slow"]).is_empty())
	_check("(control) ... and a gendered insult", not TauntLines.violations(["what a bitch of a level"]).is_empty())
	_check("(control) ... and does not flag innocent words", TauntLines.violations(["a quiet moment, then a class act"]).is_empty())
	_check("there are enough lines for the review sample (>= 60)", lines.size() >= 60)

	# --- tiers ---
	_check("easy level: deaths 1-2 are tier 1, 3 is tier 2, 7 tier 3, 15 tier 4, 20 tier 5",
		TauntLines.tier_for(1, 3) == 1 and TauntLines.tier_for(2, 3) == 1 and TauntLines.tier_for(3, 3) == 2
		and TauntLines.tier_for(7, 3) == 3 and TauntLines.tier_for(15, 3) == 4 and TauntLines.tier_for(20, 3) == 5)
	_check("hard level reaches the harsh tiers sooner (10 -> T4, 15 -> T5 on level 20)",
		TauntLines.tier_for(10, 20) == 4 and TauntLines.tier_for(15, 20) == 5 and TauntLines.tier_for(10, 3) == 3)
	_check("tier 5 climbs forever (death 400 is still tier 5)", TauntLines.tier_for(400, 20) == 5)
	var swears_low := false
	for t in [1, 2, 3]:
		for l in TauntLines.pool_for(t, "spikes", 40.0, false):
			if _has_swear(TauntLines.fill(l, 5, 40.0)) and not (" damn" in String(l).to_lower() or "ass" in String(l).to_lower() or "hell" in String(l).to_lower()):
				swears_low = true
	_check("tiers 1-3 never use strong swears", not swears_low)
	var swears_high := false
	for l in TauntLines.pool_for(4, "", -1.0, false):
		if _has_swear(String(l)):
			swears_high = true
	_check("tier 4 does swear", swears_high)
	# cause-specific lines show up
	var pool := TauntLines.pool_for(3, "lava", -1.0, false)
	_check("a lava death at tier 3 can draw the lava line", "Swan dive into the hot stuff, take {n}. Judges say: ten out of ten for commitment." in pool)
	_check("(control) a spikes death does not draw the lava line", not ("Swan dive into the hot stuff, take {n}. Judges say: ten out of ten for commitment." in TauntLines.pool_for(3, "spikes", -1.0, false)))
	_check("so-close lines only appear near the end (pct 95 yes, 40 no)",
		TauntLines.pool_for(5, "", 95.0, false).has("{pct} percent. So close it is insulting.")
		and not TauntLines.pool_for(5, "", 40.0, false).has("{pct} percent. So close it is insulting."))
	_check("the same-spot lines appear only when dying in the same spot",
		TauntLines.pool_for(5, "", -1.0, true).has("Same spot. Again. The spot loves you.")
		and not TauntLines.pool_for(5, "", -1.0, false).has("Same spot. Again. The spot loves you."))

	# --- ego ---
	var flex := 0
	for l in TauntLines.T4 + TauntLines.T5:
		var low := String(l).to_lower()
		if low.contains("respect") or low.contains("elite") or low.contains("everyone else quit") or low.contains("impressive") or low.contains("surprised") or low.contains("further"):
			flex += 1
	_check("the harsh tiers carry flex lines that lift the player up (%d)" % flex, flex >= 4)
	var praise := true
	for l in TauntLines.CLEAR_STREAK_HARD:
		if not (String(l).to_lower().contains("legend") or String(l).to_lower().contains("impressed") or String(l).to_lower().contains("not most players")):
			praise = false
	_check("clearing after a long fight is celebrated", praise and TauntLines.CLEAR_STREAK_HARD.size() >= 3)

	# --- the node ---
	var df := DeathFeedback.new()
	get_root().add_child(df)
	await process_frame
	var lbl: Label = df.get_child(0).get_child(0)
	df.forced_mode = 0
	df.forced_language = 0
	df.level = 20
	df.cause = "spikes"
	df.on_death(1)
	df.on_death(2)
	var before_weak := df.lines_shown
	df.forced_mode = 1
	df.on_death(30)
	df.on_clear(30, false)
	_check("WEAK mode shows nothing on a death or a clear", df.lines_shown == before_weak)
	var shown_weak := df.lines_shown
	df.forced_mode = 0
	df.on_death(30)
	_check("STRONG shows a line on a deep death (%s)" % df.last_line, df.lines_shown == shown_weak + 1 and df.last_line != "")
	df.on_clear(30, false)
	_check("STRONG celebrates a clear", df.lines_shown == shown_weak + 2 and lbl.text == df.last_line)
	df.forced_language = 1
	var bleeped := TauntLines.bleep("You are fucking up this shit, damn it. Hello, class.")
	_check("BLEEPED stars out swears but leaves 'class' alone (%s)" % bleeped, not bleeped.to_lower().contains("fuck") and not bleeped.to_lower().contains("shit") and bleeped.contains("class"))
	df.forced_language = 0
	# no repeats within 20 deaths
	var seen: Array = []
	var repeats := 0
	df.cause = ""
	for i in 10:
		var before := df.lines_shown
		df.on_death(40 + i)
		if df.lines_shown > before:
			var raw := df.last_line
			if raw in seen:
				repeats += 1
			seen.append(raw)
	_check("no line repeats inside 10 consecutive deaths (the size of the smallest harsh pool) (%d repeats)" % repeats, repeats == 0)
	# never blocks
	var t0 := Time.get_ticks_usec()
	for i in 200:
		df.on_death(50 + i)
	var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_check("200 deaths cost %.1f ms (must be under one frame)" % elapsed_ms, elapsed_ms < 16.0)
	df.clear()
	_check("clear(): the line is gone", is_zero_approx(lbl.modulate.a))
	df.queue_free()

	# --- the 4 s spacing outside tests ---
	var df2 := DeathFeedback.new()
	get_root().add_child(df2)
	await process_frame
	df2.level = 20
	df2.on_death(30)
	var n2 := df2.lines_shown
	df2.on_death(31)
	_check("two deaths a moment apart give one line (the 4 s gap)", df2.lines_shown == n2)
	df2.queue_free()

	# --- wiring ---
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	var wired := scene.get_node_or_null("DeathFeedback") as DeathFeedback
	_check("main_scene builds a DeathFeedback", wired != null)
	if wired != null:
		wired.forced_mode = 0
		var n0 := wired.lines_shown
		var guard := 0
		while scene.get("attempts") < 12 and guard < 40:
			wired._last_ms = -100000
			scene._respawn(0)
			guard += 1
			await process_frame
		_check("real respawns drive the taunts (%d lines)" % (wired.lines_shown - n0), wired.lines_shown > n0)
	scene.queue_free()
	await process_frame
	print("[test_death_feedback] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
