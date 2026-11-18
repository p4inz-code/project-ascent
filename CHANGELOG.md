# Changelog

## 0.18.0 (2026-11-18)
The game now updates itself.
- **Updates inside the game.** It checks this repository's GitHub page once a day, downloads a newer version
  with a progress bar, checks its SHA-256 against the checksum published with the release, and asks "Restart now"
  or "Later". Later keeps the verified file and installs it the next time you start the game. Settings, Gameplay
  has three modes: Automatic (the default), Notify me, and Off. Nothing about you is sent, and the browser build
  never does any of this.
- **Safe by default.** If anything goes wrong (a wrong checksum, a dropped connection, a redirect to another site,
  a file that is not what the release says) the update is thrown away and the old version keeps working. The
  installer keeps one rollback copy and repairs itself after a crash in the middle of an install.
- **New launcher.** It looks like the game now (the 3D logo, an amber Play button, the studio mark), shows what is
  new in an update with a progress bar, and has the right licence text. The logo had been missing since the first
  launcher build because the build bundled no artwork; that is fixed and the build now checks for it.
- **Studio page.** More from P4INZ shows the real descriptions and links for Kanvaz, Kinoz and Glint.
- **About page** now says exactly what the game contacts and how to turn it off.
- Tests: the updater has its own suites, a fake GitHub that exercises 13 failure cases over real HTTP, and a
  security review (`docs/SECURITY_REVIEW_updater.md`).
- If you are on 0.17.0: download this version once from the release page. From here on, the game updates itself.

## 0.16.1 test build (owner round 2 fixes, 2026-11-16)
See `docs/BUGS_round2.md` for root causes and what was seen in the real game.
- Boss no longer stands beside the spawn after a death or restart during its warning.
- Level 36 circuit tiles: no more wall of stripes. Machine levels start on a platform that matches the rolled floor.
- Level card on its own plate in the act's colour (pixel font). Deaths and restarts close and open the act's cover.
- Dev level skip leaves Endless (fixed "level 4 went to level 8"); LEVELS opens on the current level.
- Level 10: enclosed shaft (no wall ending in mid-air), 46 steps instead of 30.
- Level 5: waits for the first press, no lag from the lava lake, says LAVA not ACID.
- ENDLESS: mixed stages of four biomes each, no campaign level numbers or bosses.
- One pixel font everywhere; textured belt and ice floors; Trevor redesigned (helmet, faceplate, scarf).
- Quieter HUD (roll code for testers only, attempts from the first death, cores flash on pickup); pixel
  skylines with a landmark set per act.
- Juice: hit-stop on death and chip hits, jump dust, dash streak, wall-jump scuffs, bigger landing dust.
- Harder machine levels: denser, longer runs, longer from act III. Median-player clear odds per attempt
  now about 0.85 / 0.64 / 0.48 / 0.44 for acts II-V (were 0.93 / 0.84 / 0.68 / 0.56).

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
