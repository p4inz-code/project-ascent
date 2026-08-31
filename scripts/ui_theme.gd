class_name UITheme
extends RefCounted
## The single source of truth for UI chrome — colours, type, and control
## styling for every menu surface in the game.
##
## Built in code rather than hand-authored as a .tres for two reasons: the
## parser type-checks it (a typo in a StyleBox property is a parse error, not
## a silently-ignored line in a text resource), and it matches how the rest of
## this project already builds UI — hud.gd's controls panel and
## pause_menu.gd's level-select grid are both constructed in code.
##
## Replaces 152 scattered per-node `theme_override_*` entries that used to
## live in pause_menu.tscn. A Theme assigned to a Control propagates to every
## descendant, so a single assignment at the menu root restyles the whole
## tree — and one edit here now changes every surface at once, instead of
## needing dozens of nodes touched by hand (which is how a restyle ships
## half-applied).

# ── Palette ─────────────────────────────────────────────────────────
# Derived from what the game already uses, not invented: CYAN is the pause
# title colour, AMBER is the goal/TopLedge edge colour that marks the win
# condition in every one of the 25 levels.
const CYAN := Color(0.20, 0.70, 1.00)
const CYAN_DIM := Color(0.12, 0.42, 0.64)
const CYAN_GLOW := Color(0.20, 0.70, 1.00, 0.18)
const AMBER := Color(1.00, 0.827, 0.471)
const AMBER_DIM := Color(0.54, 0.41, 0.16)

const GROUND := Color(0.035, 0.047, 0.070, 0.97)
const SURFACE := Color(0.075, 0.094, 0.130, 1.0)
const SURFACE_HI := Color(0.110, 0.140, 0.190, 1.0)
const LINE := Color(0.165, 0.205, 0.265, 1.0)

const TEXT := Color(0.902, 0.929, 0.953)
const TEXT_DIM := Color(0.545, 0.580, 0.620)
const DANGER := Color(0.973, 0.318, 0.286)
const GOOD := Color(0.247, 0.725, 0.314)

const FONT_PATH := "res://assets/fonts/CyberpunkCraftpixPixel.otf"

# ── Type scale ──────────────────────────────────────────────────────
const SIZE_TITLE := 44
const SIZE_HEADING := 22
const SIZE_BODY := 18
const SIZE_SMALL := 15


## The live accent, honouring the player's UI Accent choice. Everything that
## used to reference CYAN directly goes through here, so the picker in the
## settings panel recolours the entire menu the instant it's clicked rather
## than on the next launch.
static var accent: Color = CYAN
static var accent_dim: Color = CYAN_DIM


## Re-read the accent from GameSettings. Safe to call when the autoload is
## missing (headless tests instantiate scenes without it), in which case the
## original cyan stands.
static func refresh_accent(settings: Node) -> void:
	if settings == null or not settings.has_method("get_accent_color"):
		accent = CYAN
		accent_dim = CYAN_DIM
		return
	accent = settings.get_accent_color()
	accent_dim = accent.darkened(0.45)


## Build the shared Theme. Call once and assign to a menu root; every
## descendant Control inherits it.
static func build() -> Theme:
	var theme := Theme.new()

	var font: Font = load(FONT_PATH)
	if font != null:
		# Set as the theme-wide default so EVERY control type picks it up,
		# including ones added later. Before this, the font shipped imported
		# but unreferenced — the README and the v0.8.0 release notes both
		# claimed it was integrated across all UI while the game actually
		# rendered in Godot's stock face.
		theme.default_font = font
	theme.default_font_size = SIZE_BODY

	_style_panel(theme)
	_style_button(theme)
	_style_label(theme)
	_style_slider(theme)
	_style_checkbutton(theme)
	_style_scroll(theme)
	_style_variations(theme)
	return theme


## Named type variations, so a control can opt into a distinct look without
## a per-node style override. A settings section must not wear the heavy
## glow of the main menu panel, and a 12px value readout must not inherit
## the 18px body size — but both should still live here rather than being
## re-specified on every node that needs them.
static func _style_variations(theme: Theme) -> void:
	# ── SectionPanel — quiet framing inside the settings list ──
	theme.add_type("SectionPanel")
	theme.set_type_variation("SectionPanel", "PanelContainer")
	var section := StyleBoxFlat.new()
	section.bg_color = Color(0.048, 0.062, 0.088, 0.75)
	section.set_corner_radius_all(5)
	section.border_width_left = 2
	section.border_color = accent_dim
	section.content_margin_left = 14.0
	section.content_margin_right = 14.0
	section.content_margin_top = 10.0
	section.content_margin_bottom = 10.0
	theme.set_stylebox("panel", "SectionPanel", section)

	# ── TitleLabel — the one piece of display type in the menu ──
	theme.add_type("TitleLabel")
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_color("font_color", "TitleLabel", accent)
	theme.set_color("font_shadow_color", "TitleLabel", Color(0.10, 0.40, 0.80, 0.55))
	theme.set_constant("shadow_offset_y", "TitleLabel", 3)
	theme.set_font_size("font_size", "TitleLabel", SIZE_TITLE)

	# ── SectionTitle — the AUDIO / VISUAL / GAMEPLAY headers ──
	theme.add_type("SectionTitle")
	theme.set_type_variation("SectionTitle", "Label")
	theme.set_color("font_color", "SectionTitle", accent)
	theme.set_font_size("font_size", "SectionTitle", SIZE_SMALL)

	# ── SettingLabel / SettingValue — the rows inside a section ──
	theme.add_type("SettingLabel")
	theme.set_type_variation("SettingLabel", "Label")
	theme.set_color("font_color", "SettingLabel", TEXT)
	theme.set_font_size("font_size", "SettingLabel", SIZE_SMALL)

	theme.add_type("SettingValue")
	theme.set_type_variation("SettingValue", "Label")
	theme.set_color("font_color", "SettingValue", AMBER)
	theme.set_font_size("font_size", "SettingValue", SIZE_SMALL)

	# ── DangerButton — Reset Progress and the confirm's Yes ──
	theme.add_type("DangerButton")
	theme.set_type_variation("DangerButton", "Button")
	var danger_hover := StyleBoxFlat.new()
	danger_hover.bg_color = Color(0.22, 0.075, 0.070, 1.0)
	danger_hover.set_corner_radius_all(4)
	danger_hover.set_border_width_all(1)
	danger_hover.border_color = DANGER
	danger_hover.border_width_left = 3
	danger_hover.content_margin_left = 18.0
	danger_hover.content_margin_right = 18.0
	danger_hover.content_margin_top = 10.0
	danger_hover.content_margin_bottom = 10.0
	theme.set_stylebox("hover", "DangerButton", danger_hover)
	theme.set_color("font_hover_color", "DangerButton", DANGER)


## A neon-edged panel: deep translucent ground, a bright top hairline that
## catches the eye the way the lit strip on every platform does, and a soft
## outer glow. Deliberately built from layered StyleBoxes rather than a
## 9-sliced pixel-art frame — the game renders smooth anti-aliased vector
## shapes at 1440p, and 32px pixel chrome scaled up to meet it reads as two
## different games glued together.
static func _style_panel(theme: Theme) -> void:
	theme.add_type("Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = GROUND
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = LINE
	# Brighter top edge — the same readability cue platforms use.
	sb.border_width_top = 2
	sb.set_expand_margin_all(0.0)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", "Panel", sb)

	# PanelContainer shares the look so sub-panels match.
	theme.add_type("PanelContainer")
	theme.set_stylebox("panel", "PanelContainer", sb.duplicate())


static func _style_button(theme: Theme) -> void:
	theme.add_type("Button")

	var normal := StyleBoxFlat.new()
	normal.bg_color = SURFACE
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = LINE
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	theme.set_stylebox("normal", "Button", normal)

	# Hover lifts the surface AND lights the left edge, so the affordance
	# survives for players who can't easily distinguish the fill change.
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = SURFACE_HI
	hover.border_color = accent_dim
	hover.border_width_left = 3
	theme.set_stylebox("hover", "Button", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent_dim
	pressed.border_color = accent
	pressed.border_width_left = 3
	theme.set_stylebox("pressed", "Button", pressed)

	# Focus is a real visible ring, not the stock dotted outline — menus are
	# navigable by keyboard and controller, so this carries actual weight.
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = SURFACE_HI
	focus.border_color = accent
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.055, 0.070, 0.095, 1.0)
	disabled.border_color = Color(0.12, 0.14, 0.18, 1.0)
	theme.set_stylebox("disabled", "Button", disabled)

	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.34, 0.36, 0.40))
	theme.set_font_size("font_size", "Button", SIZE_BODY)
	# Space between a button's icon and its label — the icons added this
	# phase sit left of the text on every pause-menu action.
	theme.set_constant("h_separation", "Button", 12)


static func _style_label(theme: Theme) -> void:
	theme.add_type("Label")
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", SIZE_BODY)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)


static func _style_slider(theme: Theme) -> void:
	theme.add_type("HSlider")

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.055, 0.070, 0.095, 1.0)
	track.set_corner_radius_all(3)
	track.set_border_width_all(1)
	track.border_color = LINE
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	theme.set_stylebox("slider", "HSlider", track)

	# The filled portion glows cyan — the clearest read of "this is the
	# current value" at a glance.
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent_dim
	fill.set_corner_radius_all(3)
	fill.set_border_width_all(1)
	fill.border_color = accent
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hl := fill.duplicate() as StyleBoxFlat
	fill_hl.bg_color = accent
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill_hl)

	theme.set_constant("center_grabber", "HSlider", 1)


static func _style_checkbutton(theme: Theme) -> void:
	theme.add_type("CheckButton")
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", Color.WHITE)
	theme.set_font_size("font_size", "CheckButton", SIZE_BODY)

	# Transparent background so toggles read as list rows, not buttons —
	# they sit inside the settings panel's own framed sections.
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 4.0
	flat.content_margin_right = 4.0
	flat.content_margin_top = 6.0
	flat.content_margin_bottom = 6.0
	theme.set_stylebox("normal", "CheckButton", flat)
	var flat_hover := flat.duplicate() as StyleBoxFlat
	flat_hover.bg_color = Color(1, 1, 1, 0.04)
	theme.set_stylebox("hover", "CheckButton", flat_hover)
	theme.set_stylebox("pressed", "CheckButton", flat_hover.duplicate())


static func _style_scroll(theme: Theme) -> void:
	theme.add_type("VScrollBar")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.25)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 3.0
	bg.content_margin_right = 3.0
	theme.set_stylebox("scroll", "VScrollBar", bg)

	var grab := StyleBoxFlat.new()
	grab.bg_color = accent_dim
	grab.set_corner_radius_all(4)
	theme.set_stylebox("grabber", "VScrollBar", grab)
	var grab_hl := grab.duplicate() as StyleBoxFlat
	grab_hl.bg_color = accent
	theme.set_stylebox("grabber_highlight", "VScrollBar", grab_hl)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grab_hl.duplicate())
