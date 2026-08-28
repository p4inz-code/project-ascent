# Project Ascent

A polished offline-first 2D precision platformer focused on exceptional movement, atmosphere, audiovisual polish, and premium indie-quality game feel.

## Status

Private, offline-first First Playable demo. The finishing pass is complete and
the project is intentionally held at this scope.

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
slide + wall jump, and dash with a short landing-input buffer, on keyboard + controller. It exports to HTML5, loads
in the local browser preview, and the route is regression-tested headlessly and
in a real rendered window. The current presentation includes a procedural
star-field/parallax backdrop, readable platform edges, dash afterimages, a
truthful controls panel, a run clock, attempts, and completion feedback.

The project is intentionally stopping here as a polished First Playable rather
than becoming a larger game. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
for the technical reference, [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)
for continuation instructions, and [docs/FINAL_DEMO_REPORT.md](docs/FINAL_DEMO_REPORT.md)
for the finishing-pass record.
