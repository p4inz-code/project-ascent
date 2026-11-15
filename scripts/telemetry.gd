# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name Telemetry
extends RefCounted
## Tester mode: a local log of how the game is played, so the next round of testing teaches us the REAL
## difficulty (the odds in the machine levels are a model until people play them).
##
## Off by default. On with the Tester mode setting or the --tester launch flag. It only ever writes to the
## game's own save folder (user://telemetry.json) and only ever leaves the machine when a tester presses
## COPY TESTER REPORT and pastes the text to someone. No name, no path, no account, nothing sent anywhere.
##
## Logged per level: attempts, deaths (cause, progress %, time, roll seed), clears (time, deaths), where the
## session ended (quit point). The report sums it up per level.

const PATH := "user://telemetry.json"
const MAX_EVENTS := 6000
const FLAG := "--tester"

static var events: Array = []
static var forced: int = -1          # tests: 1 forces on, 0 forces off, -1 follows the setting
static var session_start_msec: int = Time.get_ticks_msec()
static var _loaded: bool = false
static var _since_save: int = 0


static func enabled() -> bool:
	if forced >= 0:
		return forced == 1
	if FLAG in OS.get_cmdline_args() or FLAG in OS.get_cmdline_user_args():
		return true
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var gs: Node = (ml as SceneTree).root.get_node_or_null("/root/GameSettings")
	return gs != null and bool(gs.get_reg("tester_mode"))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if forced >= 0:
		return
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Array:
				events = parsed


## Log one event. kind: "level_start", "death", "clear", "quit".
static func record(kind: String, data: Dictionary = {}) -> void:
	if not enabled():
		return
	_ensure_loaded()
	var e := {"k": kind, "t": int((Time.get_ticks_msec() - session_start_msec) / 1000)}
	e.merge(data, true)
	events.append(e)
	while events.size() > MAX_EVENTS:
		events.pop_front()
	_since_save += 1
	if kind in ["clear", "quit"] or _since_save >= 10:
		save()


static func save() -> void:
	if forced >= 0:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(events))
	_since_save = 0


static func clear_log() -> void:
	events.clear()
	_since_save = 0
	if forced < 0 and FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## The report a tester pastes to us: one header, then per level.
static func report_text(version: String = "") -> String:
	_ensure_loaded()
	var ver := version
	if ver == "":
		ver = String(ProjectSettings.get_setting("application/config/version", "?"))
	var lines: PackedStringArray = []
	lines.append("PROJECT ASCENT TESTER REPORT")
	lines.append("version %s  os %s  events %d" % [ver, OS.get_name(), events.size()])
	var levels := {}
	var quit_level := -1
	var play_s := 0
	for e in events:
		var lv := int(e.get("level", -1))
		play_s = maxi(play_s, int(e.get("t", 0)))
		if e["k"] == "quit":
			quit_level = lv
			continue
		if lv < 0:
			continue
		if not levels.has(lv):
			levels[lv] = {"starts": 0, "deaths": 0, "clears": 0, "pct_sum": 0.0, "best_pct": 0.0, "causes": {},
				"clear_times": [], "clear_deaths": [], "seeds": []}
		var d: Dictionary = levels[lv]
		match String(e["k"]):
			"level_start":
				d["starts"] += 1
			"death":
				d["deaths"] += 1
				var pct := float(e.get("pct", 0.0))
				d["pct_sum"] += pct
				d["best_pct"] = maxf(float(d["best_pct"]), pct)
				var cause := String(e.get("cause", "?"))
				if cause == "":
					cause = "?"
				d["causes"][cause] = int(d["causes"].get(cause, 0)) + 1
				if String(e.get("seed", "")) != "" and d["seeds"].size() < 5:
					d["seeds"].append(String(e["seed"]))
			"clear":
				d["clears"] += 1
				d["clear_times"].append(float(e.get("time", 0.0)))
				d["clear_deaths"].append(int(e.get("attempts", 1)) - 1)
	lines.append("session play time about %d s" % play_s)
	if quit_level >= 0:
		lines.append("last quit point: level %d" % quit_level)
	var keys := levels.keys()
	keys.sort()
	lines.append("")
	lines.append("level | deaths | clears | avg death % | best % | clear time (avg s) | deaths before clear | top causes | sample seeds")
	for lv in keys:
		var d: Dictionary = levels[lv]
		var avg_pct := float(d["pct_sum"]) / float(maxi(int(d["deaths"]), 1))
		var avg_t := 0.0
		for t in d["clear_times"]:
			avg_t += float(t)
		avg_t /= float(maxi(d["clear_times"].size(), 1))
		var before := 0.0
		for n in d["clear_deaths"]:
			before += float(n)
		before /= float(maxi(d["clear_deaths"].size(), 1))
		var causes: Array = []
		for c in d["causes"]:
			causes.append([c, d["causes"][c]])
		causes.sort_custom(func(a, b): return a[1] > b[1])
		var cs: PackedStringArray = []
		for i in mini(3, causes.size()):
			cs.append("%s x%d" % [causes[i][0], causes[i][1]])
		lines.append("%d | %d | %d | %.0f | %.0f | %.1f | %.1f | %s | %s" % [lv, d["deaths"], d["clears"], avg_pct, d["best_pct"],
			avg_t, before, ", ".join(cs), ", ".join(PackedStringArray(d["seeds"]))])
	return "\n".join(lines)
