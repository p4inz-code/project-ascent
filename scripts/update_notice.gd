# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name UpdateNotice
extends PanelContainer
## A small card in the title screen's bottom-right corner that follows the GameUpdater autoload: an update is
## ready (Notify mode), it is downloading, it is ready to install ("Restart now / Later"), or the launcher
## reports how the last update went. Hidden the rest of the time, and never shown during play.

const WIDTH := 440.0

var _updater: Node = null
var _title: Label
var _body: Label
var _bar: ProgressBar
var _row: HBoxContainer
var _shown_result: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "UpdateNotice"
	visible = false
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -28.0
	offset_right = -28.0
	offset_top = -28.0
	offset_bottom = -28.0
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.12, 0.94)
	box.border_color = UITheme.AMBER
	box.set_border_width_all(UITheme.PX)
	box.set_content_margin_all(16)
	add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	_title.add_theme_color_override("font_color", UITheme.AMBER)
	v.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_body.add_theme_color_override("font_color", UITheme.TEXT)
	v.add_child(_body)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.show_percentage = false
	v.add_child(_bar)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	v.add_child(_row)
	_updater = get_node_or_null("/root/GameUpdater")
	if _updater != null:
		_updater.state_changed.connect(refresh)
		_updater.progress.connect(func(_r: int, _t: int) -> void: refresh())
	refresh()


func _button(text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(on_press)
	_row.add_child(b)
	PageFx.hoverable(b)


## What the card shows now. Public so a test can drive it.
func refresh() -> void:
	if _updater == null:
		visible = false
		return
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_bar.visible = false
	# the launcher's verdict on the last update comes first, once
	if not _updater.last_result.is_empty() and not _shown_result:
		var ok := bool(_updater.last_result.get("ok", false))
		_title.text = ("UPDATED TO v%s" % String(_updater.last_result.get("version", ""))) if ok else "THE UPDATE DID NOT WORK"
		_body.text = "Project Ascent is up to date." if ok else String(_updater.last_result.get("message",
			"Your old version was put back, so nothing is lost."))
		_button("OK", func() -> void:
			_shown_result = true
			_updater.last_result = {}
			refresh())
		visible = true
		return
	var s: int = _updater.state
	match s:
		3:  # AVAILABLE
			if _updater.mode == 0 and _updater.supported_reason() == "":
				visible = false   # Automatic mode downloads by itself; the card appears when it is ready
				return
			_title.text = "VERSION %s IS READY" % _updater.latest
			if _updater.supported_reason() == "" and _updater.can_install():
				_body.text = "Download it now? The game restarts when it is done."
				_button("UPDATE", func() -> void: _updater.download(false))
			else:
				_body.text = "A new version is out. Open the release page to get it."
				_button("OPEN PAGE", func() -> void: OS.shell_open(AboutPage.RELEASES_PAGE))
			_button("SKIP THIS VERSION", func() -> void: _updater.skip_latest())
			visible = true
		4:  # DOWNLOADING
			_title.text = "DOWNLOADING UPDATE"
			var mb := 1048576.0
			_body.text = "%.1f of %.1f MB" % [_updater.received / mb, _updater.total / mb]
			_bar.max_value = maxf(1.0, float(_updater.total))
			_bar.value = float(_updater.received)
			_bar.visible = true
			visible = true
		5:  # READY
			_title.text = "UPDATE READY"
			_body.text = "Version %s is downloaded and checked. Restart now, or it is installed the next time you start the game." % _updater.latest
			_button("RESTART NOW", func() -> void: _updater.install_and_quit())
			_button("LATER", func() -> void: visible = false)
			visible = true
		_:
			visible = false
