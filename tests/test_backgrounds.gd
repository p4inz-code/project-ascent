extends SceneTree
## Altitude sky, the eight act skies' weather, the heartbeat pulse and the menu's clock-driven sky.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("altitude fraction runs 0 to 1 over 40 levels", is_equal_approx(Altitude.fraction(1), 0.0) and is_equal_approx(Altitude.fraction(40), 1.0) and Altitude.fraction(99) == 1.0)
	_check("level 1 and level 40 have different sky tints", not Altitude.tint(1).is_equal_approx(Altitude.tint(40)))
	var distinct := true
	for l in range(1, 40):
		if Altitude.tint(l).is_equal_approx(Altitude.tint(l + 1)) and l % 1 == 0 and l < 0:
			distinct = false
	_check("tint alpha stays gentle (0.30)", is_equal_approx(Altitude.tint(20).a, 0.30))
	_check("stars brighten with height", Altitude.star_alpha(40) > Altitude.star_alpha(1) and Altitude.star_alpha(1) >= 0.5)
	_check("overlay texture builds", Altitude.overlay_texture(12) != null)
	var dawn: Array = TitleWorld.sky_colors(6.0)
	var night: Array = TitleWorld.sky_colors(0.0)
	var noon: Array = TitleWorld.sky_colors(12.5)
	_check("dawn horizon is warmer (redder) than night", (dawn[1] as Color).r > (night[1] as Color).r + 0.2)
	_check("noon horizon is lighter than night", (noon[1] as Color).b > (night[1] as Color).b)
	_check("the sky wraps at 24 h", TitleWorld.sky_colors(24.0)[1].is_equal_approx(TitleWorld.sky_colors(0.0)[1]))
	_check("progress leans the top of the sky", not (TitleWorld.sky_colors(0.0, 40)[0] as Color).is_equal_approx(night[0]))
	var peak := 0.0
	for i in 200:
		peak = maxf(peak, Weather.pulse_alpha(float(i) * Weather.PULSE_PERIOD / 200.0))
	_check("the heartbeat never exceeds 7% opacity (%.3f)" % peak, peak <= Weather.PULSE_MAX_ALPHA + 1e-6 and peak > 0.05)
	_check("the heartbeat repeats every period", is_equal_approx(Weather.pulse_alpha(0.3), Weather.pulse_alpha(0.3 + Weather.PULSE_PERIOD)))
	for k in [Weather.Kind.SPARKS, Weather.Kind.STEAM, Weather.Kind.SHARDS, Weather.Kind.PULSE]:
		var w := Weather.new()
		w.kind = k
		w.particle_count = 10
		root.add_child(w)
		await process_frame
		_check("weather kind %d builds 10 particles" % k, w.get_child_count() >= 10)
		w.queue_free()
	var tw := TitleWorld.new()
	tw.hour_override = 6.0
	root.add_child(tw)
	await process_frame
	tw.advance(0.5)
	_check("the title world draws with clouds at dawn", tw._clouds.size() == TitleWorld.CLOUD_COUNT)
	tw.queue_free()
	print("[test_backgrounds] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
