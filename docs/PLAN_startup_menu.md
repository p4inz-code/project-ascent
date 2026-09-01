# Startup Menu — plan

Owner's spec: a menu on startup for people who want one. Play, Settings,
About. About checks for updates, and if one is available it opens the launcher
and updates the game from right there. The pause menu stays exactly as it is.

## The one real design constraint

The launcher already exists and already updates the game. So this menu must
not become a second, competing updater — that is how two code paths for one
job drift apart and one of them silently breaks. The menu's job is to
**detect and hand off**, never to download or install anything itself.

That also settles the awkward case: the game cannot replace its own running
.exe. Only the launcher can. So "update available" in the menu is always
"close the game, open the launcher, let it do the update it already knows how
to do."

## Boot flow

`project.godot` currently boots straight to `game_scene.tscn`. That becomes:

```
main_menu.tscn  ->  game_scene.tscn
```

Two things must survive that change:

- **The launcher's direct-play path.** The owner already noticed the launcher
  drops them straight into the game. A `--skip-menu` command-line flag (which
  the launcher passes) keeps that behaviour, so nobody who uses the launcher
  is made to click through a menu they did not ask for.
- **Level Select and save state.** Both live in autoloads, so they are
  unaffected by an extra scene in front — but the menu's Play button must
  route through the same `GameManager` entry point the launcher uses, not a
  second copy of it.

## Screens

**Main** — the game's title, the current version in small text, and three
items: PLAY, SETTINGS, ABOUT. Keyboard and gamepad first: up/down + confirm,
with the pointer as a secondary. Reuses `ui_theme.gd`, so it picks up the
player's chosen accent automatically and needs no palette of its own.

**Play** — hands off to `GameManager` at the player's furthest level, with
Level Select reachable from the same screen (it already exists; the menu just
becomes a second door to it).

**Settings** — the *existing* settings panel, extracted from `pause_menu.gd`
into a scene both can instance. This is the part with real risk: that panel
is the one the owner already had to hotfix once for unresponsive input, so it
must be lifted as-is, not rewritten, and `test_customization` has to pass
against both hosts.

**About** — credits, version, and the update check. Three states:
- *Idle*: "Check for updates" button.
- *Up to date*: version and a checkmark.
- *Update available*: the new version number and "Open Launcher to update",
  which writes nothing, quits the game, and starts the launcher.

## Update check — how it talks to the launcher

`launcher/updater.py` already has `get_current_version()` and
`check_for_update()`, both hardened this session (HTTPS-only, checksum
required, path-traversal guards). The game must not reimplement that in
GDScript.

Cleanest split:
- The game reads `version.txt` beside its own executable — same file the
  launcher writes.
- The check itself is an `HTTPRequest` to the same releases endpoint, parsing
  only the tag name. **Read-only.** No download, no checksum logic, no
  install path in the game at all.
- If a newer tag exists, the button launches the launcher via `OS.create_process`
  and quits. The launcher then performs the verified update it already does.

Failure is silent and non-blocking: no network, a rate limit, or a malformed
response all fall back to "could not check right now". A menu that blocks on a
network call is a menu that hangs on a plane.

## Tests

- `test_main_menu.gd`: menu boots, all three items focusable by keyboard, Play
  reaches `game_scene`, `--skip-menu` bypasses it entirely.
- Settings-panel suite runs against **both** hosts (menu and pause menu), so
  the extraction cannot silently break the pause path.
- Update check: stub responses for newer / same / malformed / no-network, and
  assert the game never writes to disk in any of them.
- `test_geometry` and the full gate stay green — an added boot scene must not
  disturb level data.

## Cost

Roughly: menu scene and navigation (small), settings extraction (the real
work, because it must not regress), About + update check (small), tests
(moderate). The settings extraction is the only part that can go wrong
quietly, so it goes first and gets its own gate run.
