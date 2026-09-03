# itch.io page copy

Draft. The screenshots and capsule are the owner's to supply — everything
here is the text.

## Tagline

A 25-level precision platformer about getting higher.

## Short description (the card blurb, ~150 chars)

Run, dash, wall-jump and grapple your way up 25 handmade levels. Instant
respawns, no filler, and a chase that speeds up if you take too long.

## About

Project Ascent is a precision platformer built around one idea: the only thing
between you and the top is your own timing.

You get a full moveset from the start — run, jump, wall-jump, dash, slide,
ground pound, wall run, ledge grab, and a grapple. Nothing is locked behind
progress. The levels get harder because they ask more of the same tools, not
because they hand you a new one every ten minutes.

Twenty-five levels across five acts, each with its own sky, weather, and
palette. Spinning blades, swinging pendulums, lava, wind, zero-gravity pockets,
conveyor belts, crumbling ledges, ice you slide across, and sticky ground that
kills your run-up. Five boss chases that hunt you up the level on a visible
countdown — let it run out and the chase gets faster, not lethal.

Death is instant and so is the retry. Past twenty-five attempts on a level the
game starts talking to you. Past fifty it changes its tone.

## What's under the hood (devlog material)

Two things in here were more interesting to build than they were to design:

**The jump envelope.** Rather than assume how far the player can jump, the
project measures it: a probe binary-searches the real controller for the
maximum clearable rise at each gap width. Every level's geometry is then
validated against those measured numbers, so no step can quietly demand more
height than the character actually has.

**The bug that shipped.** A release went out with a Level 1 that would not
compile, and every automated test passed it. Two causes: the engine's script
cache meant the suites were running against an older compile, and the level
loader failed softly enough that loops kept going and reported zero failures.
The fix was a forced rescan before any suite runs, and a rule that every new
gate has to be broken on purpose to prove it can fail.

## Controls

Keyboard, or a controller — Xbox and PlayStation pads both show their own
button prompts (Cross/Circle/Square/Triangle on a DualShock/DualSense, A/B/X/Y
on Xbox). Rebinding and a full settings panel are in the pause menu, along
with level select and a character customiser. Touch controls for mobile are
planned next; this release is desktop and browser only.

## Platforms

Play in the browser — nothing to install — or download for Windows, macOS, or
Linux.

## Price

Free.

## Tags

platformer, precision-platformer, 2d, pixel-art, hard, singleplayer, godot,
speedrun, challenging

## Credits

A solo project by **p4inz** (Atharva Patil) / Northbyte Studios. Same handle
across itch, GitHub, and X — findable as p4inz everywhere.
