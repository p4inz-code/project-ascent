# v1.0.0: the one version (written 2026-11-15, updated after the owner decisions)

Goal: everything planned ships as ONE version, v1.0.0, free with donations. Target: code-complete (feature freeze, called 1.0.0-rc1) by tomorrow, then the owner's manual test, a bug list, fixes, the gate, and the tag. Testing and fixing will take longer than building, so the build list below is cut hard: anything that does not make the game finishable, fair and shippable moves to 1.1.

Rules that stay: torture but never impossible (every roll proven), no hints, taunts mock the play and boost the ego, no tag or release without the owner's approval, every item gets a test with a negative control.

## Owner decisions (2026-11-15)
GPL-3.0 (done). No paywall and no key system (done). Pixel-heart CONTRIBUTE TO DEVELOPMENT on the main page and About (done). Every level needs its own jump/dash rhythm with a randomised go-through (built, see level rhythm). Build everything discussed first, then RC1; the owner then tests by hand and refines each level; two rounds (before fixes and after fixes); then the official publish to GitHub, itch.io and the rest. Strict: never heat up the PC (one headless process at a time at idle priority, no GPU captures, the full gate only when the owner says the PC is free).

## Next actions (in order)
1. Rerun the machine suites after the rhythm change, one at a time: `test_machine_gen`, `test_machine_routes`, `test_machine_build`, `test_new_levels`, `test_machine_front`, `test_machine_replay`, `test_machine_runner`, `test_tile_biomes`, `test_scares`. Fix anything the new floor-lane pattern breaks (proof floors must hold).
2. Endless mode: `ENDLESS` on the main page and `--endless`; random machine levels with a rising difficulty by streak; never touches the campaign save; best streak saved separately; tested.
3. Owner call: should RC1 wait for the boss 30 maze and the storm events (levels 16-19), or ship them in 1.0.1? Default: ship RC1 now, because manual testing is the long pole.
4. Version bump to 0.99.0 (rc1) in one commit; full gate once on a snapshot (when the PC is free); fix only real failures; build Windows, Linux, macOS and web zips with hashes; write `RELEASE_NOTES_rc1.md`.
5. Owner round 1: manual test, bug list (the tester report helps). I fix, re-test only the touched suites, build rc2.
6. Owner round 2 on rc2: a smaller list, fix, final gate, bump to 1.0.0.
7. Owner approves the tag; publish: git tag and GitHub release (zips + sha256 + signed manifest if the key exists), itch.io page (name your own price, donation links), web build.

## Already in (0.16.0 build, all tested)
Attack + health, machine levels 6-9/11-14/16-19/21-24/26-29/31-34/36-39, bosses: 5 Borer runner, 10 Compactor flood tower, 15 Warden stealth, 20 Tempest rods and lightning, 25 Dawn (collapse front + heat vents), 30 Hive (machine + chase, placeholder), 35 Rift Warden black hole, 40 Core echo exam; biome tile art; taunts, scares, briefing, tutorial; tester telemetry; roll codes (`--roll`, `--daily`); support links; signed-key and manifest tooling.

## P0: must be in v1.0.0-rc1 (build tonight and tomorrow morning)
| # | Item | Done when |
|---|---|---|
| 1 | **DONE 2026-11-15** **Core count so the true ending is reachable** (default: 3 cores per level, 108 available, 100 needed) | every level 5-40 carries 3 optional cores, each proven reachable; ending OPEN at 100; tests updated |
| 2 | **MOVED TO 1.0.1** (needs a backward-travel proof the bot does not have; boss 30 ships as machine + chase for 1.0.0) **Boss 30 THE MAZE/HIVE own format** (fixed topology: visible wrong forks, one right route, content re-rolled per death) | bot-proven route on every roll; real-scene run |
| 3 | **MOVED TO 1.0.1** (gust and lightning add new hazard physics that need their own probe table; levels 16-19 keep hail and slick surfaces) **Storm events for levels 16-19** (gust lanes, lightning marks, flicker) | at most 2 at once, every tell, proven by the sim or by a safe-window test |
| 4 | **DONE** **Legal and credit**: GPL-3.0 LICENSE, ADDITIONAL_TERMS, SPDX GPL-3.0-only headers on every script, THIRD_PARTY_NOTICES, DMCA template | files present, a test scans for headers |
| 5 | **DONE** (coffee button on the ending, 100 text matches the 108-core goal) **Ending polish**: final-screen support line, "100" text matches the real goal, PIP lines for 26-40 beats | ending test passes |
| 6 | **DONE except Authenticode/PCK encryption** **Integrity + authenticity**: SHA-256 list, signed manifest, in-game "modified copy" notice, signed release notes with hashes | verify tool + test; Authenticode and PCK encryption need the owner's certificate and a custom export template (P1) |
| 7 | **DONE** (the launcher already had download, SHA-256, backup and restore; it now verifies the signed manifest before installing, skipped until a public key is bundled) **Updater** in the launcher (signed manifest, delta by file, rollback) and the About-page check | download/verify/swap tested against a local manifest |
| 8 | **Full gate on the final head** | only the owner-signed allowlist line remains |

## P1: in v1.0.0 if time allows, otherwise 1.0.1
DONE: reaction cards (14 original pixel faces, `tests/test_reaction_cards.gd`), music pitch per act (`tests/test_music_flavor.gd`). Still open: launcher visual polish and the wordmark bundling bug, visual polish pass (hit stop, landing dust, death burst), Authenticode signing and PCK encryption (needs certificate and custom template), web demo packaging.

## Cut to 1.1 (decided now so they do not block)
Endless mode, daily-seed leaderboard, late-game difficulty retune (needs real telemetry), boss 40 and 35 further variants, new music tracks, Steam page.

## Order, with owner touchpoints
1. Tonight: P0 items 1-3, then 4-5 (mostly files and text).
2. Tomorrow morning: items 6-7, full gate on a snapshot, build rc1 zips.
3. Owner: play rc1, send the bug list (telemetry copy-report helps); decisions needed: license type, certificate, itch/Steam.
4. Fix, re-gate, build v1.0.0, owner approves tag and release.

Version number: project files stay at 0.16.0 until rc1; the final bump to 1.0.0 happens in one commit with the release notes.
