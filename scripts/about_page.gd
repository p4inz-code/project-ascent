# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name AboutPage
extends CanvasLayer
## Full-screen ABOUT page: what the game is, who made it, and the update check.
##
## Updates run through the GameUpdater autoload (scripts/game_updater.gd): this page only shows its state and
## offers the next step (check, update now, restart now). On Windows the launcher swaps the files; on the
## other systems the page opens the release page.

signal closed

## The game is free. These are the only two places it ever points to for donations, and nothing in the
## game is gated behind them (tests/test_support_links.gd keeps it that way).
const SUPPORT_BMC := "https://buymeacoffee.com/p4inz"
const SUPPORT_UPI := "https://p4inz-code.github.io/donate/"
const RELEASES_PAGE := "https://github.com/p4inz-code/project-ascent/releases/latest"

var _version: String = ""
var _status: Label
var _updater: Node = null
var _bar: ProgressBar
var _act: Button
var _check: Button
var _done: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 240
	_version = read_version()
	UITheme.refresh_accent(get_node_or_null("/root/GameSettings"))
	_build()


## res://version.txt is written by build_release.ps1 right before export and is
## bundled into the PCK, so this read works identically on desktop and web.
static func read_version() -> String:
	var path := "res://version.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return ""


func _label(text: String, size: int, colour: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build() -> void:
	add_child(PixelBackdrop.new())
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.theme = UITheme.build()
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	frame.add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(880, 0)
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(PageShell.header(PixelIcons.texture(PixelIcons.INFO, 4), "ABOUT", "Who made this, with what, and what it costs (nothing)."))
	col.add_child(PageShell.rule())

	var logo := TextureRect.new()
	logo.texture = load("res://assets/pixel/logo.png") as Texture2D
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if logo.texture != null:
		logo.custom_minimum_size = Vector2(logo.texture.get_width(), logo.texture.get_height()) * 3
	col.add_child(logo)

	var ver := _label(("VERSION %s" % _version) if _version != "" else "DEV BUILD",
		UITheme.SIZE_SMALL, UITheme.AMBER)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)

	_rule(col)
	col.add_child(_label(
		"You fell out of the sky into THE SPIRE: a tower outside time with no ground below it. "
		+ "One gate waits at the top and needs 100 cores to open. Climb, collect, get out. "
		+ "PIP, the AI in your suit, will keep you company.",
		UITheme.SIZE_BODY, UITheme.TEXT, true))
	_rule(col)

	col.add_child(_label("MADE BY", UITheme.SIZE_SMALL, UITheme.TEXT_DIM))
	col.add_child(_label("Atharva Patil  -  P4inz Interactive Labs", UITheme.SIZE_BODY, UITheme.TEXT))
	col.add_child(_label("BUILT WITH", UITheme.SIZE_SMALL, UITheme.TEXT_DIM))
	col.add_child(_label("Godot Engine 4  -  UI font: Cyberpunk Craftpix Pixel", UITheme.SIZE_BODY, UITheme.TEXT))
	col.add_child(_label(
		"No accounts, no ads, no tracking. The game only ever contacts this game's own GitHub page, "
		+ "to look for updates (once a day, and nothing about you is sent). You can turn that off or "
		+ "make it ask first in Settings.", UITheme.SIZE_SMALL, UITheme.TEXT_DIM, true))

	_rule(col)
	col.add_child(_label("FREE, FOREVER", UITheme.SIZE_SMALL, UITheme.TEXT_DIM))
	col.add_child(_label(
		"Project Ascent is free and open source (GPL-3.0). Nothing is locked behind a donation. If it ate an evening or two of your life "
		+ "and you want more of it, a coffee buys the dev more evenings for the next update.",
		UITheme.SIZE_SMALL, UITheme.TEXT, true))
	var contribute := Button.new()
	contribute.name = "Contribute"
	contribute.text = "CONTRIBUTE TO DEVELOPMENT"
	contribute.icon = PixelHeart.texture(3)
	contribute.custom_minimum_size = Vector2(0, 48)
	contribute.pressed.connect(func() -> void:
		var page := SupportPage.new()
		add_child(page)
		page.closed.connect(func() -> void: contribute.grab_focus()))
	col.add_child(contribute)
	_rule(col)

	_check = Button.new()
	_check.text = "CHECK FOR UPDATES"
	_check.custom_minimum_size = Vector2(0, 44)
	_check.pressed.connect(_on_check_updates)
	col.add_child(_check)
	_status = _label("", UITheme.SIZE_SMALL, UITheme.AMBER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(0, 22)
	col.add_child(_status)
	_bar = ProgressBar.new()
	_bar.name = "UpdateProgress"
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	UpdateNotice.style_bar(_bar)
	_bar.visible = false
	col.add_child(_bar)
	_act = Button.new()
	_act.name = "UpdateAction"
	_act.custom_minimum_size = Vector2(0, 44)
	_act.visible = false
	_act.pressed.connect(_on_update_action)
	col.add_child(_act)
	_updater = get_node_or_null("/root/GameUpdater")
	if _updater != null:
		_updater.state_changed.connect(_refresh_update_ui)
		_updater.progress.connect(func(_r: int, _t: int) -> void: _refresh_update_ui())
		_refresh_update_ui()

	_done = Button.new()
	_done.text = "DONE"
	_done.custom_minimum_size = Vector2(0, 48)
	_done.pressed.connect(close)
	col.add_child(_done)
	_done.call_deferred("grab_focus")
	PageFx.enter.call_deferred(frame, null)


func _rule(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = UITheme.LINE
	r.custom_minimum_size = Vector2(0, UITheme.PX)
	parent.add_child(r)


func _on_check_updates() -> void:
	# The browser build has no launcher and no separate download to update to;
	# the page always serves the latest export.
	if not Platform.supports("launcher_notes"):
		_status.text = "playing in browser - always up to date"
		return
	if _version == "":
		_status.text = "no version file - run from the launcher"
		return
	if _updater == null:
		_status.text = "could not check right now"
		return
	_status.text = "checking..."
	_updater.check_now(true)


## What the page shows for the updater's current state. A failure stays calm: a menu must never alarm because
## a network call did not work.
func _refresh_update_ui() -> void:
	if _updater == null or _status == null:
		return
	var s: int = _updater.state
	_bar.visible = s == GameUpdater_State.DOWNLOADING
	_act.visible = false
	match s:
		GameUpdater_State.CHECKING:
			_status.text = "checking..."
		GameUpdater_State.UP_TO_DATE:
			_status.text = "up to date (v%s)" % _version
		GameUpdater_State.AVAILABLE:
			if _updater.supported_reason() == "" and _updater.can_install():
				_status.text = "v%s is available" % _updater.latest
				_act.text = "UPDATE NOW"
			else:
				_status.text = update_message(_updater.latest, _version)
				_act.text = "OPEN RELEASE PAGE"
			_act.visible = true
		GameUpdater_State.DOWNLOADING:
			var mb := 1048576.0
			_bar.max_value = maxf(1.0, float(_updater.total))
			_bar.value = float(_updater.received)
			_status.text = "downloading v%s: %.1f of %.1f MB" % [_updater.latest, _updater.received / mb, _updater.total / mb]
		GameUpdater_State.READY:
			_status.text = "v%s is ready. Restart to finish." % _updater.latest
			_act.text = "RESTART NOW"
			_act.visible = true
		GameUpdater_State.FAILED:
			_status.text = "could not update: %s" % _updater.error
			_act.text = "TRY AGAIN"
			_act.visible = true
		_:
			pass


func _on_update_action() -> void:
	if _updater == null:
		return
	match int(_updater.state):
		GameUpdater_State.AVAILABLE:
			if _updater.supported_reason() == "" and _updater.can_install():
				_updater.download(false)
			else:
				OS.shell_open(RELEASES_PAGE)
		GameUpdater_State.READY:
			_updater.install_and_quit()
		GameUpdater_State.FAILED:
			_updater.check_now(true)


## The state names of the GameUpdater autoload, so this page does not hard-code its numbers.
class GameUpdater_State:
	const IDLE := 0
	const CHECKING := 1
	const UP_TO_DATE := 2
	const AVAILABLE := 3
	const DOWNLOADING := 4
	const READY := 5
	const FAILED := 6


static func update_message(tag: String, current: String) -> String:
	var latest := tag.lstrip("v")
	if latest == current:
		return "up to date (v%s)" % current
	return "v%s available - see the release page" % latest


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()
