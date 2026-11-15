# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name WardenDirector
extends Node2D
## THE WARDEN'S MILE (level 15): a long ice corridor with one Warden patrolling it, lantern first.
## Stay out of the lantern cone. Shadow pockets (dark alcoves, every 520 px) hide you completely: a
## player standing in one is never seen. Seen for SUSPECT_TIME seconds in the open and the Warden
## hunts you for HUNT_TIME seconds at HUNT_SPEED, which is slower than you run (320), and a catch costs
## one cell (a chip), never a kill. A rising "!" bar over the Warden is the tell.
##
## Passable by construction: a perfect player walks pocket to pocket, sprinting only when the whole
## sprint stays out of the cone. tests/test_warden.gd runs exactly that on 200 rolls.

signal chip(source_x: float)

const LEVEL := 15
const FLOOR_Y := 800.0
const LENGTH := 5400.0
const POCKET_FIRST := 600.0
const POCKET_STEP := 520.0
const POCKET_W := 180.0
const POCKETS := 9
const PATROL_MIN := 900.0
const PATROL_MAX := 4700.0
const PATROL_SPEED := 110.0
const HUNT_SPEED := 240.0
const CONE := 380.0
const HEARING := 60.0
const SUSPECT_TIME := 0.6
const HUNT_TIME := 2.5
const BLIND_AFTER := 1.8
const CATCH_X := 40.0
const SPRINT_SPEED := 320.0
const LEDGE_XS: Array[float] = [600.0 + 520.0 * 1.0 + 260.0, 600.0 + 520.0 * 4.0 + 260.0, 600.0 + 520.0 * 7.0 + 260.0]

var player: Player = null
var wx: float = 2000.0
var wdir: int = 1
var suspicion: float = 0.0
var hunting: float = 0.0
var blind: float = 0.0
var alarms: int = 0
var chips: int = 0
var _got_chip: bool = false
var _t: float = 0.0


static func pocket_x(k: int) -> float:
	return POCKET_FIRST + float(k) * POCKET_STEP


static func in_pocket(px: float) -> bool:
	for k in POCKETS:
		if absf(px - pocket_x(k)) <= POCKET_W * 0.5 - 14.0:
			return true
	return false


## The lantern: ahead of the Warden within CONE, or right beside it (HEARING), and not in a shadow pocket.
static func sees(warden_x: float, warden_dir: int, px: float, pdy: float) -> bool:
	if in_pocket(px) or absf(pdy) > 200.0:
		return false
	var d := (px - warden_x) * float(warden_dir)
	return (d > 0.0 and d <= CONE) or absf(px - warden_x) <= HEARING


## One patrol step (the same function drives the node and the proof).
static func patrol_step(x: float, dir: int, dt: float) -> Array:
	x += float(dir) * PATROL_SPEED * dt
	if x >= PATROL_MAX:
		x = PATROL_MAX
		dir = -1
	elif x <= PATROL_MIN:
		x = PATROL_MIN
		dir = 1
	return [x, dir]


static func build_def(legacy: LevelData.LevelDef) -> LevelData.LevelDef:
	var def := LevelData.LevelDef.new()
	def.number = LEVEL
	def.name = "WARDEN'S MILE"
	def.theme = legacy.theme
	def.boss_config = LevelData.BossConfig.new()
	def.warden = true
	var theme: LevelData.LevelTheme = def.theme
	var P := LevelData.PlatformDef
	def.platforms = [
		P.new("LeftWall", Vector2(-120.0, 200.0), Vector2(40.0, 2200.0), theme.wall_color, theme.edge_color, 0.0),
		P.new("Ground", Vector2(LENGTH * 0.5, FLOOR_Y + 250.0), Vector2(LENGTH + 300.0, 500.0), theme.wall_color, theme.edge_color, 5.0, "ice"),
		P.new("RightWall", Vector2(LENGTH + 100.0, 200.0), Vector2(40.0, 2200.0), theme.wall_color, theme.edge_color, 0.0),
	]
	def.spawn_point = Vector2(160.0, FLOOR_Y - 28.0)
	def.goal_position = Vector2(LENGTH - 200.0, FLOOR_Y - 48.0)
	def.goal_size = Vector2(56.0, 96.0)
	def.kill_depth = FLOOR_Y + 1400.0
	# an optional core on a low ledge between two pockets: a detour out in the open
	for li in LEDGE_XS.size():
		def.platforms.append(P.new("Ledge_%d" % li, Vector2(LEDGE_XS[li], FLOOR_Y - 80.0 + 12.0), Vector2(120.0, 24.0), theme.platform_color, theme.edge_color, 5.0))
	return def


func setup(p_player: Player, on_orb: Callable = Callable()) -> void:
	player = p_player
	reset()
	for li in LEDGE_XS.size():
		CoreSpawner.add(self, LEVEL, li, Vector2(LEDGE_XS[li], FLOOR_Y - 80.0 - 38.0), on_orb)


func reset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	wx = rng.randf_range(1500.0, 4000.0)
	wdir = 1 if rng.randf() < 0.5 else -1
	suspicion = 0.0
	hunting = 0.0
	blind = 0.0
	alarms = 0
	chips = 0
	_got_chip = false
	_t = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	var px := player.global_position.x
	var pdy := player.global_position.y - (FLOOR_Y - 26.0)
	blind = maxf(blind - delta, 0.0)
	if hunting > 0.0:
		hunting -= delta
		wdir = 1 if px >= wx else -1
		wx = clampf(wx + float(wdir) * HUNT_SPEED * delta, 200.0, LENGTH - 200.0)
		if not _got_chip and absf(px - wx) <= CATCH_X and absf(pdy) < 90.0:
			_got_chip = true
			chips += 1
			chip.emit(wx)
			hunting = 0.0
			blind = BLIND_AFTER
		if hunting <= 0.0:
			blind = BLIND_AFTER
			suspicion = 0.0
	else:
		var st := patrol_step(wx, wdir, delta)
		wx = st[0]
		wdir = st[1]
		if blind <= 0.0 and sees(wx, wdir, px, pdy):
			suspicion += delta / SUSPECT_TIME
			if suspicion >= 1.0:
				suspicion = 0.0
				hunting = HUNT_TIME
				_got_chip = false
				alarms += 1
				SfxHub.play(get_tree(), "vent")
		else:
			suspicion = maxf(suspicion - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# shadow pockets
	for k in POCKETS:
		var x := pocket_x(k)
		draw_rect(Rect2(x - POCKET_W * 0.5, FLOOR_Y - 150.0, POCKET_W, 150.0), Color(0.02, 0.03, 0.07, 0.62))
		draw_rect(Rect2(x - POCKET_W * 0.5, FLOOR_Y - 154.0, POCKET_W, 4.0), Color(0.45, 0.6, 0.8, 0.5))
	# lantern cone
	var a := 0.16 + 0.22 * clampf(suspicion, 0.0, 1.0)
	var col := Color(1.0, 0.85, 0.4, a) if hunting <= 0.0 else Color(1.0, 0.3, 0.2, 0.3)
	var d := float(wdir)
	draw_colored_polygon(PackedVector2Array([
		Vector2(wx + d * 20.0, FLOOR_Y - 60.0), Vector2(wx + d * CONE, FLOOR_Y - 140.0),
		Vector2(wx + d * CONE, FLOOR_Y), Vector2(wx + d * 20.0, FLOOR_Y)]), col)
	# the Warden: a tall hooded lamp-bearer
	draw_rect(Rect2(wx - 16.0, FLOOR_Y - 96.0, 32.0, 96.0), Color(0.12, 0.14, 0.22))
	draw_rect(Rect2(wx - 12.0, FLOOR_Y - 112.0, 24.0, 20.0), Color(0.2, 0.22, 0.32))
	draw_circle(Vector2(wx + d * 22.0, FLOOR_Y - 60.0), 8.0, Color(1.0, 0.85, 0.4))
	# the "!" tell bar
	var bw := 48.0
	draw_rect(Rect2(wx - bw * 0.5, FLOOR_Y - 134.0, bw, 8.0), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(wx - bw * 0.5, FLOOR_Y - 134.0, bw * clampf(suspicion, 0.0, 1.0), 8.0), Color(1.0, 0.7, 0.2))
	if hunting > 0.0:
		draw_rect(Rect2(wx - bw * 0.5, FLOOR_Y - 134.0, bw, 8.0), Color(1.0, 0.25, 0.2))
