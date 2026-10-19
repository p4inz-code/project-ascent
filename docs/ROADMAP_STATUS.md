# Roadmap status (v2 redesign branch)

Last updated: 2026-10-20. Branch `v2-redesign`. Nothing from v2 is tagged or published; `main` is v0.14.1.
A teaser build exists locally (`dist/Project-Ascent-v2-Teaser-*.zip`) for showing friends.

How to read this: **LIVE** = checked in a real window or real Chrome with real input. **TESTED** = automated suite in `tools/run_all_tests.ps1` passes, not yet seen live. **OPEN** = not done.
The full gate has NOT been run on the current code. Until it is, "TESTED" means the individual suite passed on its own.

## Done

| Area | What | State |
|------|------|-------|
| Tutorial | Level 0, five sets (MOVE, JUMP, DASH AND SLIDE, WALLS, THE WORLD), ten lessons, set cards, PIP voice, never saved as progress | LIVE (played start to finish with real keys) |
| First launch | PLAY, story (skippable), PIP offer (skippable), tutorial, level 1. Returning players are never asked again. Skip from the pause menu | LIVE |
| Controls | Pause is its own action: pad B (Slide) no longer pauses; START pauses; D-pad Up opens the controls panel; explicit menu accept/back on a pad | LIVE |
| Controls | Ground dash re-arms after a cooldown (was one dash until you jumped) | LIVE |
| Controls | Controls matrix test: every action, key and pad binding table, rebinding, dead zone | TESTED |
| Transitions | Five per-act covers (airlock, heat flash, frost wipe, warp streak, dawn ascent) | LIVE for airlock, frost, dawn; heat and warp captured, not reviewed |
| Transitions | Real input lock from goal touch until the next level is clear (old code let you run under the banner) | LIVE |
| Cutscene audit | Held key from PLAY no longer skips the film; back and pause also skip; flashes and shake respect Reduce Motion | TESTED (skip path seen live) |
| Story | PIP intro line on the first level of each act; ending callback line | TESTED, not seen live |
| Camera | Zoom presets (close, default, wide), hold-to-peek look (keys and right stick), follow speed. Wide and peek are off in boss chases | TESTED |
| Settings framework | Declarative registry: defaults, limits, per-page reset, search, platform filtering; one generic test covers all | TESTED |
| Accessibility | Text size, high-contrast platforms, colour-blind correction (3 types), extra ledge grace, extra jump buffer, hazard speed, fixed jump height | TESTED (text size LIVE) |
| Graphics | Quality presets (low, medium, high), AUTO measured from frame times, one-time offer to lower on sustained low fps | TESTED |
| Display | Window mode, window size, vsync, frame cap (desktop); fullscreen toggle only on web | window size LIVE; rest TESTED |
| Gamepad | Vibration strength, button-prompt style (auto, keyboard, Xbox, PlayStation, Switch), glyph families, last-device tracking | TESTED |
| Backup | Copy and paste all settings (works on web) | TESTED |
| Fonts | Nine choices; four open-licence pixel fonts bundled with licences and credits, so web matches desktop | LIVE (rendered) |
| Platform rules | One `Platform` helper; web hides quit, window options, file export | TESTED; web title and menu seen in real Chrome |
| Roads | Road levels got hints and the right boss minion counts (fixed two failing suites) | TESTED |
| Tooling | `tools/live_verify.gd` (real-input window run), `tools/cdp.mjs` (real Chrome driver), gate now imports assets first | working |

## Open

| Item | Notes |
|------|-------|
| Full gate on current code | Not run since these changes. Run it first. |
| Live failures to re-check by hand | Frame-cap click, BORDERLESS click and LOW-preset click did not take effect in the live script (unit tests pass; the script probably mis-clicks after the window resizes). Level 2 release after a transition passed when traced by hand. |
| Reachability sweep | Levels 16, 19, 20, 21, 25 fail it. Never compared to main in detail. |
| `test_level` | "course can be completed" fails; it also fails on `main` v0.14.1, so it is an old harness or level issue. |
| No-wall / climbability audit | Not written. Tutorial shaft is proven climbable; the 25 levels are not audited. |
| Boss formats | L20 lightning storm and L25 collapsing dawn gate not built. L5 and L15 are road bosses; L10 flood climb exists. |
| Per-attempt randomness for non-road levels | Only the road levels re-roll their obstacles each attempt. |
| Bug bounty and fuzz suite | `docs/BUG_BOUNTY` not started; no random-input fuzz test yet. |
| Ship gate script | `tools/ship_gate.ps1` not written. |
| Sounds | Door, vent hiss, boss siren, ending cues not generated. |
| Docs and copy | Design bible status, itch page, README and ART docs not updated for the new features. |
| 120 Hz physics | Not evaluated. |
| Render-scale slider | Not built: there is no clean render-scale path for a 2D game in Godot. Decide: drop it or restructure rendering into a sub-viewport. |
| Per-platform menu test | Platform rules are tested individually; no test builds every menu under every platform yet. |
| Web re-check | Re-export and play-test in real Chrome after the latest changes (the Chrome window stopped drawing frames today). |
| Gamepad-only play | Title to goal on a pad has not been run; no pad was available. |
| Settings still on the wish list | More audio options, more gameplay options, more character options, settings presets. |
| Release | Version label still says 0.14.1; no tag, itch upload or GitHub release until you approve. |

## Next, in order

1. Run the full gate; fix what it finds.
2. Re-check the live failures by hand; re-export and test web in real Chrome.
3. Climbability audit and the reachability failures; decide about `test_level`.
4. Boss formats L20 and L25; per-attempt jitter.
5. Bug bounty pass and fuzz suite.
6. Sounds, docs and itch copy.
7. `ship_gate.ps1`, then a real release only when you approve.
