# Project Ascent v0.1.0 — First Playable

## What this release is

Project Ascent v0.1.0 is a compact, offline-first 2D precision-platforming
demo. It is the public release checkpoint for the frozen First Playable, not a
finished commercial game.

## Included

- One complete greybox route from spawn to the amber goal
- Running with acceleration, deceleration, and air control
- Jumping with coyote time, jump buffering, and variable jump height
- Wall slide and wall jump with launch lockout
- One air dash per flight with landing refresh and a short landing buffer
- Fast respawn, manual restart, run timer, attempts, and completion feedback
- Procedural stars, parallax ridges, readable platform edges, player feedback,
  and pooled dash afterimages
- Keyboard and controller input through Godot's `InputMap`
- A single-threaded HTML5 export preset
- A Windows Desktop export preset producing a self-contained `ProjectAscent.exe`
  and `ProjectAscent.pck` standalone program (no Godot or repository required)

## Visual and demo state

The release keeps the established cool indigo/slate visual direction. Cyan
player feedback and an amber goal provide the main gameplay accents, while the
star field and parallax ridges add depth without a large art pipeline.

## Validation

Validated with Godot 4.7.2 stable:

- 85 assertions passed across five regression suites
- headless boot passed
- the native route completed in 395 physics frames
- a rendered native capture produced 40 frames, including completion
- the Web export completed successfully
- the Web build loaded and rendered in the local browser preview with no
  meaningful console entries
- the native performance probe measured a flat 107-node tree and a 16.667 ms
  average wall-frame time in the managed test environment
- the Windows Desktop export completed successfully and the standalone EXE
  launched directly from a clean extracted folder (outside the repository) with
  no errors and no dependency on the Godot editor or any development tooling

The deterministic route run is native. The browser preview was used to verify
the exported build's loading, rendering, HUD, and console behavior; the browser
automation harness did not reliably inject movement keys for a complete browser
route run.

## How to play

Use A/D or Left/Right to move, Space or W to jump, and Shift or J to dash. R
restarts the current attempt. Tab or F1 shows and hides the controls panel.
Controller equivalents are shown in the in-game controls panel and in the
repository README.

To run from source, use Godot 4.7.2 and open the project. To build the Web
version locally:

```text
godot --headless --path . --export-debug "Web" build/web/index.html
python tools/serve_web.py 8060
```

Then open <http://127.0.0.1:8060/>.

To build the Windows standalone and its distribution ZIP:

```text
powershell -ExecutionPolicy Bypass -File tools/build_release.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_console.exe"
```

This exports the `Windows Desktop` preset to `build/windows/ProjectAscent.exe`
plus `ProjectAscent.pck`, exports the HTML5 preset, and packages
`dist/Project-Ascent-v0.1.0-Windows.zip` containing only the EXE, the PCK, and a
player `README.txt`. See `tools/build_release.ps1` for how the Godot binary is
located (never hard-coded).

## Known limitations

- This is one compact greybox route with one goal.
- It has no authored audio, final production art, save system, settings,
  accounts, multiplayer, or online services.
- Wall jump is implemented and tested but is optional on the current route.
- Browser frame timing was not measured in this release audit.
- The Windows standalone ships x86_64 only and is unsigned; Windows SmartScreen
  may warn that the publisher is unknown (the file is a standard Godot export).
- No root project license has been selected yet; reuse rights remain reserved
  until the owner publishes an explicit license.

## What comes next

The First Playable is intentionally frozen. If development resumes, the next
milestone should be a deliberate human-led decision about authored art/audio or
an authored wall-jump section. New mechanics and services are out of scope for
this release.
