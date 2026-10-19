class_name Platform
extends RefCounted
## One place that knows which platform the game is running on and which features that
## platform offers. Every screen asks here instead of calling OS.has_feature on its own,
## so "the web build has no QUIT" is one rule, not a scatter of checks.
##
## `override` lets a test (or the --platform=web debug flag) pretend to be another
## platform so every menu can be built and checked for each one.

enum Kind { DESKTOP, WEB, DECK }

## Set by tests / debug: "", "desktop", "web" or "deck".
static var override: String = ""


static func kind() -> int:
	match override:
		"web":
			return Kind.WEB
		"deck":
			return Kind.DECK
		"desktop":
			return Kind.DESKTOP
	if OS.has_feature("web"):
		return Kind.WEB
	# Steam sets SteamDeck=1 in the game's environment on a Deck.
	if OS.has_environment("SteamDeck") and OS.get_environment("SteamDeck") == "1":
		return Kind.DECK
	return Kind.DESKTOP


static func is_web() -> bool:
	return kind() == Kind.WEB


static func is_deck() -> bool:
	return kind() == Kind.DECK


static func is_desktop() -> bool:
	return kind() != Kind.WEB


static func name_of(k: int = -1) -> String:
	match (kind() if k < 0 else k):
		Kind.WEB:
			return "web"
		Kind.DECK:
			return "deck"
	return "desktop"


## Features, by name. Unknown names are false so a typo can never expose a control.
static func supports(feature: String) -> bool:
	match feature:
		# A browser tab cannot be closed by the page, so there is nothing to quit to.
		"quit":
			return not is_web()
		# The browser owns the window: only a fullscreen toggle makes sense there.
		"fullscreen":
			return true
		"window_size", "window_mode", "vsync", "fps_cap":
			return not is_web()
		"render_scale":
			return true
		# Settings travel as a file on desktop, as copy/paste text in a browser.
		"file_export":
			return not is_web()
		"text_export":
			return true
		# Browsers refuse audio until the player has clicked or pressed a key.
		"needs_audio_gesture":
			return is_web()
		"launcher_notes":
			return not is_web()
		# Deck: a handheld with a gamepad as the primary input.
		"gamepad_first":
			return is_deck()
	return false


## Where saves live, in words the player can act on.
static func save_location_text() -> String:
	if is_web():
		return "Saved in this browser. Clearing site data erases it."
	return "Saved in your user folder on this computer."
