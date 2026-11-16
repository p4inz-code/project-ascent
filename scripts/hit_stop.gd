# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name HitStop
extends Node
## The death / hit freeze. Lives under the tree ROOT (never under a level), so a level being freed or reloaded
## inside the freeze can never leave the game slowed down. The first version restored the time scale from a
## coroutine on the level: when the level was freed during the 0.09 s window the coroutine died with it and the
## whole game stayed at 3% speed (the frozen "second Trevor" was the death echo stuck on its first frame).
##
## Restores by real time in _process, which runs whatever the time scale or pause state is.

const SLOW := 0.03

var _until_ms: int = 0
var _active: bool = false


static func freeze(tree: SceneTree, seconds: float) -> void:
	if tree == null or DisplayServer.get_name() == "headless":
		return
	var hs := tree.root.get_node_or_null("HitStop") as HitStop
	if hs == null:
		hs = HitStop.new()
		hs.name = "HitStop"
		tree.root.add_child(hs)
	hs._start(seconds)


## True while a freeze is running (main_scene waits on this before respawning).
static func active(tree: SceneTree) -> bool:
	var hs := tree.root.get_node_or_null("HitStop") as HitStop if tree != null else null
	return hs != null and hs._active


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _start(seconds: float) -> void:
	_until_ms = maxi(_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))
	_active = true
	Engine.time_scale = SLOW


func _process(_delta: float) -> void:
	if _active and Time.get_ticks_msec() >= _until_ms:
		_active = false
		Engine.time_scale = 1.0


## Ends any freeze at once (level loads call this as a safety net).
static func clear(tree: SceneTree) -> void:
	var hs := tree.root.get_node_or_null("HitStop") as HitStop if tree != null else null
	if hs != null and hs._active:
		hs._active = false
		Engine.time_scale = 1.0
