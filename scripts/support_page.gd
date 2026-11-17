# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name SupportPage
extends CanvasLayer
## CONTRIBUTE TO DEVELOPMENT: a small page with the pixel heart and the two donation links. The game is
## free and GPL-3.0; nothing is unlocked by donating. Opened from the main page and the About page.

signal closed

var _done: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 245
	UITheme.refresh_accent(get_node_or_null("/root/GameSettings"))
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
		margin.add_theme_constant_override("margin_" + side, 26)
	frame.add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(880, 0)
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var header := PageShell.header(PixelHeart.texture(5), "CONTRIBUTE TO DEVELOPMENT", "Free forever. Nothing is locked behind a donation.")
	header.get_child(0).name = "Heart"
	col.add_child(header)
	col.add_child(PageShell.rule())
	var body := Label.new()
	body.text = "Project Ascent is free and open source (GPL-3.0). Nothing is locked behind a donation. If it ate an evening or two of your life and you want more, a coffee buys the dev more evenings for the next update."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	col.add_child(body)
	col.add_child(_link_button("SupportBmc", "BUY ME A COFFEE", AboutPage.SUPPORT_BMC))
	col.add_child(_link_button("SupportUpi", "UPI (INDIA)", AboutPage.SUPPORT_UPI))
	_done = Button.new()
	_done.text = "BACK"
	_done.custom_minimum_size = Vector2(0, 48)
	_done.pressed.connect(close)
	col.add_child(_done)
	_done.call_deferred("grab_focus")
	PageFx.enter.call_deferred(frame, col)


func _link_button(node_name: String, text: String, url: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.icon = PixelHeart.texture(2)
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func() -> void: OS.shell_open(url))
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	closed.emit()
	queue_free()
