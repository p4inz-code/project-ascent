extends SceneTree
## Tester telemetry: off by default, log format, sums in the report, no personal data, clear works.

var _failures: int = 0


func _check(name: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_failures += 1


func _initialize() -> void:
	Telemetry.forced = 0
	Telemetry.events.clear()
	Telemetry.record("death", {"level": 6, "cause": "spikes", "pct": 40})
	_check("off: nothing is logged (negative control)", Telemetry.events.size() == 0)

	Telemetry.forced = 1
	Telemetry.record("level_start", {"level": 6})
	Telemetry.record("death", {"level": 6, "cause": "spikes", "pct": 40, "seed": "AB12"})
	Telemetry.record("death", {"level": 6, "cause": "spikes", "pct": 60, "seed": "CD34"})
	Telemetry.record("death", {"level": 6, "cause": "flame", "pct": 20, "seed": "EF56"})
	Telemetry.record("clear", {"level": 6, "attempts": 4, "time": 31.5, "seed": "GH78"})
	Telemetry.record("quit", {"level": 7})
	_check("on: six events logged", Telemetry.events.size() == 6)
	var r := Telemetry.report_text("9.9.9")
	_check("report header and version", r.begins_with("PROJECT ASCENT TESTER REPORT") and r.contains("version 9.9.9"))
	_check("report sums deaths and clears", r.contains("6 | 3 | 1 | 40 | 60 | 31.5 | 3.0 | spikes x2, flame x1"))
	_check("report shows the quit point", r.contains("last quit point: level 7"))
	_check("report lists roll seeds", r.contains("AB12"))
	var bad := false
	for needle in ["C:\\", "/Users/", "@", "Admin", "F:/"]:
		if r.contains(needle):
			bad = true
	_check("no path, account or personal data in the report", not bad)
	_check("log is capped", _capped())
	Telemetry.clear_log()
	_check("clear empties the log", Telemetry.events.size() == 0 and not Telemetry.report_text("x").contains("6 |"))
	Telemetry.forced = -1
	print("TELEMETRY: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _capped() -> bool:
	Telemetry.forced = 1
	for i in Telemetry.MAX_EVENTS + 50:
		Telemetry.record("death", {"level": 1})
	var ok := Telemetry.events.size() == Telemetry.MAX_EVENTS
	Telemetry.events.clear()
	return ok
