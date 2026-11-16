# Changelog

## 0.16.1 test build (owner round 2 fixes, 2026-11-16)
See `docs/BUGS_round2.md` for root causes and what was seen in the real game.
- Boss no longer stands beside the spawn after a death or restart during its warning.
- Level 36 circuit tiles: no more wall of stripes. Machine levels start on a platform that matches the rolled floor.
- Level card on its own plate in the act's colour (pixel font). Deaths and restarts close and open the act's cover.
- Dev level skip leaves Endless (fixed "level 4 went to level 8"); LEVELS opens on the current level.
- Level 10: enclosed shaft (no wall ending in mid-air), 46 steps instead of 30.
- Level 5: waits for the first press, no lag from the lava lake, says LAVA not ACID.
- ENDLESS: mixed stages of four biomes each, no campaign level numbers or bosses.

## Unreleased (heading to v1.0.0 release candidate 1)
Built on branch `v2-redesign` since the 0.15.1 test build:
- 40 levels in 8 acts; levels 6-40 are machine levels that re-roll on every death (proven passable per roll); each level has its own jump/dash rhythm.
- Bosses: Borer runner (5), Compactor flood tower (10), Warden stealth hunt (15), Tempest rods and lightning (20), Dawn collapse with heat vents (25), the Hive (30, machine + chase for now), Rift Warden black hole (35), Echo exam (40).
- Slash attack, 3 health cells, three optional cores per level (100 of 108 open the true ending).
- Taunts and ending text for 40 levels, PIP lines per act and boss, 14 pixel reaction cards, music pitch per act, landing dust and death burst, biome tile art.
- Roll codes (`--roll=CODE`, `--daily`), opt-in tester mode with a copyable report.
- GPL-3.0-only with additional credit/naming terms; no paywall and no key system; pixel-heart CONTRIBUTE TO DEVELOPMENT on the main page and About (Buy Me a Coffee, UPI).
- Release signing: signed manifest, integrity notice in the game, launcher verifies the signed manifest before installing.
- Many test suites added (each with a negative control); see `docs/ROADMAP_STATUS.md`.

## 0.15.1 (test build, 2026-10-26)
Machine levels 6-24, M1 slash and health, taunts and briefing, tutorial combat set.

## 0.14.1
Last published release (Trevor, Orbs, and the Death Plane).
