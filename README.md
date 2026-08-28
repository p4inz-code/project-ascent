# Project Ascent

A polished offline-first 2D precision platformer focused on exceptional movement, atmosphere, audiovisual polish, and premium indie-quality game feel.

## Status

Private prototype / active development.

## Core Goals

- Offline-first
- Browser-first
- Lightweight and performant
- Keyboard + controller support
- Precision platforming
- Exceptional game feel
- Atmospheric environments
- Premium UI/UX
- Fast restarts
- Replayability
- No accounts
- No backend
- No ads

## Technology

- Godot 4
- GDScript
- Git / GitHub

## Development Model

AI handles coding and technical implementation.

Human developers handle creative direction, 3D assets, art direction, playtesting, and final decisions.

## Current Milestone

First Playable — the greybox proving ground is completable end to end with the
full movement kit: run, jump (coyote time, jump buffering, variable height), wall
slide + wall jump, and dash, on keyboard + controller. It exports to the browser
at a locked 60 fps, and the whole route is regression-tested headlessly (50
assertions across four suites) and rendered to PNGs for visual inspection. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Next: art direction and a real level-design pass (the wall jump is built and
tested but not yet on the critical path), plus completion feedback and UI.
