# Project Ascent — Final Demo Report

Date: 2026-08-28
Final milestone: S2 → S7 autonomous polish, hardening, audit, and freeze

## Starting State

The run started from the clean, validated Session 1 First Playable checkpoint on
`main`, with the M1/M2 movement kit, procedural star/parallax presentation,
completion HUD, HTML5 export workflow, and regression suites already working.
The baseline route was a compact greybox proving ground with one large dash gate.
The repository was inspected before changes, including the handoff, final report,
architecture notes, README, project configuration, scenes, scripts, tests, tools,
Git history, and Web export settings.

## S2–S7 Work Summary

### Session 2 — Level design and traversal

The route audit found that the original structural Ground extended beneath the
opening platform sequence, allowing the first section to read as a flat bypass.
Ground now ends at x=600, leaving a deliberate 70 px opening gap before P1. This
adds the first teachable jump without adding empty traversal or changing the
route’s speed profile. A level regression assertion protects that contract, and
the full route still completes in 395 physics frames.

### Session 3 — Game feel and movement polish

The real controller and rendered route were replayed and audited. Acceleration,
deceleration, air control, jump timing, coyote time, buffering, variable height,
wall movement, dash, landing, camera relationship, and reset responsiveness were
already consistent and responsive. No controller values or mechanics were
changed. A regression now requires the player to reach 90% of max speed within
eight frames, protecting the intentionally quick pickup requested for the demo.

### Session 4 — Visual presentation

Fresh native captures were inspected across the opening, traversal, goal, and
completion states, and the Web render was inspected separately. The existing
cool indigo/slate palette, star field, parallax ridges, bright platform edges,
cyan player, amber goal, restrained vignette, camera framing, and completion
banner already form a coherent visual identity. No visual redesign, asset
pipeline, particle system, or decorative dependency was added.

### Session 5 — HUD, UX, and player journey

The launch → understand → move → fail → respawn → retry → complete flow was
audited. Controls are visible at launch, the timer waits for first input, the
attempt counter and completion time remain truthful, and Tab/F1 restores the
controls panel after it is hidden. The toggle behavior is now explicitly covered
by presentation tests. No menu, account, save, settings, or other UX system was
added.

### Session 6 — Engineering hardening

Repeated goal entry is now covered for signal emission, attempt advancement, and
current-timer reset. A dependency-free `tools/run_all_tests.ps1` wrapper runs
all five suites consistently for future agents. The native performance probe,
fresh Web export, browser render, and browser console were rechecked.

### Session 7 — Independent audit and freeze

The final audit independently rechecked gameplay mechanics, route completion,
visual presentation, Web export, browser console, performance, documentation,
Git history, and accidental-file state. No feature work was added during the
freeze audit.

## Bugs Discovered and Fixed

- The S2 route audit found a player-visible traversal weakness: the structural
  Ground made the opening platform sequence too easy to bypass. Ground was
  shortened and the 70 px gap is now regression-tested.
- The S5 test audit initially exposed a test timing mistake: a toggle assertion
  checked during the 350 ms fade instead of after it. The test was corrected; no
  game bug was present.
- S6 found missing regression coverage for repeated goal completion state. The
  implementation already used one reset path correctly; the tests now protect
  its attempt and timer behavior.

No critical gameplay, movement, wall, dash, landing, respawn, restart, goal,
HUD-timing, rendering, or HTML5 runtime defect remains.

## Visual Improvements and Final Presentation

The final presentation preserves the established direction:

- cool indigo-to-slate sky with a single-draw star field;
- three seeded parallax ridge layers for depth;
- slate terrain with bright cool top edges;
- cyan player with landing squash, flight stretch, dash tint, and pooled ghosts;
- amber goal and final ledge as the warm visual focus;
- restrained vignette and stable camera framing;
- compact InputMap-driven controls panel, timer, attempts, and completion banner.

The visual audit judged the composition intentional and readable. No change was
kept merely for being different.

## Gameplay and UX State

The current playable includes running with acceleration/deceleration and air
control, derived jump physics, coyote time, jump buffering, variable jump height,
wall slide, wall jump with lockout, one air dash per flight with landing refresh,
dash momentum handling, landing feedback, fall respawn, manual restart, goal
completion, finishing-time preservation, and immediate completion-to-next-attempt
looping.

The route is compact and left-to-right:

`Ground → P1 → P2 → P3 → P4 → LaunchPad → DashPad → TopLedge`

The opening gap is 70 px. `LaunchPad → DashPad` remains the only transition
classified as dash-required by the reachability probe. Wall jump is implemented
and tested but remains an optional movement tool rather than a critical-path
requirement.

## Testing Results

The final project-local wrapper completed all five suites with 85 assertions and
0 failures:

| Suite | Assertions | Result |
|---|---:|---|
| `test_movement.gd` | 28 | pass |
| `test_feel.gd` | 7 | pass |
| `test_loop.gd` | 15 | pass |
| `test_level.gd` | 8 | pass |
| `test_presentation.gd` | 27 | pass |

Coverage includes movement, speed pickup, acceleration/deceleration, jump arc,
coyote, jump buffer, variable jump height, wall slide, wall jump, dash,
landing-impact reporting, dash refresh and expiry, respawn, restart, repeated
respawn, repeated goal completion, attempt state, timer state, controls binding
truthfulness, controls toggling, dash ghosts, camera-adjacent presentation
state, completion feedback, and finishing-time display.

Additional final checks:

- headless boot: exit 0;
- continuous route: goal reached in 395 physics frames;
- rendered route capture: 39 PNG frames, including the completion banner;
- movement envelope: approximately 181 px running-jump distance / 92 px rise;
- dash envelope: approximately 309 px horizontal distance;
- route reachability: all transitions clear, with only LaunchPad → DashPad
  classified as dash-required.

## Browser Playtest and HTML5 Status

The fresh `Web` preset export succeeded with Godot 4.7.2 and exit code 0. The
build was served through `python tools/serve_web.py 8060` and loaded in the
in-app browser. The canvas rendered at the expected viewport, the controls
panel and HUD were visible, and the browser console contained no warning or
error entries during the final load.

The existing browser automation harness could not make its synthetic keyboard
events move the canvas player reliably, so this report does not claim a complete
manual browser clear. The route itself was completed through the real controller
in the native rendered capture, and the browser build’s render/load/console gate
passed. This distinction is a harness limitation, not evidence of a game input
failure.

Export command:

```text
Godot --headless --path . --export-debug "Web" build/web/index.html
```

The export remains single-threaded, uses the Compatibility renderer, excludes
development tooling/tests/docs from the shipped payload, and writes to ignored
`build/web`. The local server supplies the expected WASM MIME type and COOP/COEP
headers.

## Performance Result

The final native performance probe sampled the full route:

- 376 wall-frame samples;
- wall-frame average 16.668 ms, median 16.660 ms, p95 16.942 ms, worst 17.300 ms;
- draw calls average 42.537, median 42, p95 46, worst 52;
- node count stable at 108 at start, peak, and end;
- no node-growth or node-spike failure.

The probe’s process-time outliers are attributable to the managed test
environment and did not correspond to wall-frame, draw-call, or node-growth
regressions.

## Architecture Audit

`player.gd` owns movement state and physics. `main_scene.gd` owns spawn, timer,
attempts, respawn, restart, and goal looping. `platform.gd` keeps reusable
geometry and colliders synchronized. `player_visuals.gd` is non-authoritative.
`hud.gd` presents live InputMap bindings and level state. The backdrop uses a
single-draw star field plus seeded parallax ridges.

The audit found no duplicated runtime gameplay path, dead feature path, fragile
new reference, per-frame node spawning, unnecessary architecture rewrite, broken
scene reference, or stale release-critical documentation. The only new runtime
tooling is the small PowerShell test wrapper.

## Documentation Created or Updated

- `README.md` — current frozen First Playable status and workflow links;
- `docs/ARCHITECTURE.md` — runtime responsibilities, route contract, tests,
  Web workflow, and performance notes;
- `docs/SESSION_HANDOFF.md` — authoritative continuation and freeze handoff;
- `docs/TOOLS.md` — inspected GitHub tool/skill candidates and the decision not
  to install an unnecessary third-party dependency;
- `docs/FINAL_DEMO_REPORT.md` — this complete S2–S7 report;
- `tools/run_all_tests.ps1` — exact local all-suite runner.

## Tool Discovery Result

GitHub candidates for Godot testing, linting, browser automation, and agent
workflow were inspected before S2. GdUnit4, GUT, gdstyle, Godot Stagehand, and
alternative Godot MCP projects were evaluated for relevance, compatibility,
maintenance, dependencies, and security. No candidate provided enough leverage
over the existing custom tests, native capture, in-app browser, and MCP setup to
justify installing it. The evaluation is recorded in `docs/TOOLS.md`.

## Issue Classification

- A — Must fix: none remaining.
- B — Should fix: none remaining that is small and clearly valuable.
- C — Acceptable limitation: one compact greybox route, no authored art/audio,
  browser synthetic-input harness limitation, and managed-environment Godot
  user-directory/MCP permission warnings.
- D — Future work: only a human-led decision about authored art/audio or a
  deliberately designed wall-jump section. No system expansion is recommended
  for this milestone.

## Git Commits

Validated checkpoints pushed to `origin/main` during the run:

- `aabe03d` — docs: record Godot tool evaluation
- `3f84b60` — level: make the opening jump intentional
- `20e1125` — docs: record Session 2 route checkpoint
- `ae36d9a` — feel: protect fast movement pickup
- `b1e6d52` — docs: record Session 4 visual audit
- `a5f282f` — ux: guard controls discovery flow
- `dabc05a` — hardening: cover repeated completion state
- `1e4d003` — prepare public v0.1.0 onboarding, release notes, security policy,
  screenshots, and public project configuration
- `df07f20` — remove machine-local MCP config and make the test wrapper portable
- `584a537` — record final v0.1.0 release metrics and refresh the selected
  presentation captures

The S7 documentation/freeze commit is `59d7538`; public-release preparation
continues from that frozen checkpoint in the release-audit section below.

## Exact Current State

Project Ascent is a small, playable, visually coherent, offline-first First
Playable demo. It passes 85 automated assertions, boots headlessly, completes
the route through the real controller, renders cleanly in native and Web
contexts, exports successfully to HTML5, has stable node/draw performance, and
has an authoritative handoff for future work.

## Recommended Next Milestone

Stop. The S2–S7 objective is complete and the project is frozen at this
milestone. If development resumes later, make a human-led creative decision
before changing stable movement, route, visual, HUD, or Web systems. Do not add
features by default.

## Public Release Audit — v0.1.0

The public-release pass started from the clean S7 freeze at `59d7538`. Gameplay,
level geometry, movement tuning, and presentation were treated as release
content and were not reopened.

### Repository hygiene

- Removed the tracked root `.mcp.json`, which was a per-user development bridge
  configuration capable of invoking a floating `npx` package.
- Added `.mcp.json` to `.gitignore`; the safe template remains under the
  development addon for intentional local use.
- Disabled the optional MCP addon/autoload in the public project configuration.
  The addon remains available as development tooling and is excluded from Web.
- Added four rendered gameplay captures under `docs/media/` for public
  presentation. Generated `build/web/` and `build/shots/` output remains ignored.
- No unnecessary binaries, editor caches, logs, exports, or temporary artifacts
  are tracked.

### Security audit

A repository-wide scan covered current tracked files, reachable Git history,
credential-like patterns, data-risk filenames, URLs, and local filesystem paths.
No embedded API keys, access tokens, passwords, private keys, `.env` files, or
credential values were found. The historical scan matched only intentional
token variable names inside the separately licensed MCP addon; no token values
were present. Current documentation no longer contains the development machine
path.

The root `.mcp.json` was removed as a public-clone hygiene measure. It contained
no credential, but a public game repository should not execute a per-user
development bridge by inheritance.

### Public documentation and onboarding

- `README.md` is now a concise public project page with status, features,
  gameplay, controls, screenshots, local run steps, Web export, testing,
  architecture, validation, limitations, contribution guidance, and license
  status.
- `docs/RELEASE_NOTES_v0.1.0.md` contains the release notes and exact play/build
  instructions.
- `SECURITY.md` documents the small offline threat surface and reporting hygiene.
- `docs/SESSION_HANDOFF.md`, `docs/ARCHITECTURE.md`, and `docs/TOOLS.md` were
  reconciled with the public project configuration and portable paths.
- The test wrapper now discovers `godot` on `PATH` or accepts `-GodotPath`; it no
  longer embeds a machine-specific executable path.
- `project.godot` records `config/version="0.1.0"`.
- The fresh release capture completed the route in 395 physics frames and saved
  40 rendered frames; the release performance probe sampled 384 frames with a
  flat 107-node tree, 42.443 average draw calls, and a 16.667 ms average wall
  frame.

### Presentation

The existing rendered captures were inspected and selected for the README:
opening route, traversal, goal, and completion. No game visual redesign was
needed. The public presentation remains the established cool indigo/slate
palette with cyan player feedback and an amber goal focus.

### CI and GitHub settings

No GitHub Actions workflow was added. The project has no dependency-free,
verified hosted Godot 4.7.2 runner in this repository, and a fragile workflow
would provide less trust than the existing local wrapper plus native/Web checks.
No repository settings, description, topics, Issues, Discussions, or GitHub
Release metadata were changed because the available local Git credentials do
not expose the repository administration API. The remote is configured as
`origin` on `main`.

### Licensing

No root project license existed and none was invented during this pass. The
release is therefore a public source showcase only; Project Ascent source,
original game content, and branding remain reserved until the owner chooses and
publishes an explicit license. The bundled MCP addon carries its own MIT
`LICENSE` and `ATTRIBUTIONS.md`; that license applies to the addon only.

### Release gate and manual owner actions

The source tree is release-prepared, but two actions require the owner:

1. Change `p4inz-code/project-ascent` to Public in GitHub and verify the public
   repository page. An unauthenticated GitHub API request returned 404 during
   this pass, so visibility could not be confirmed from the current environment.
2. Choose the root project licensing policy. Do not label the game MIT/GPL/etc.
   until that decision is explicit.

After those decisions, create the GitHub Release titled
`Project Ascent v0.1.0 — First Playable` from the annotated `v0.1.0` tag and
paste the contents of `docs/RELEASE_NOTES_v0.1.0.md` into the release body. The
source repository remains the canonical reproducible artifact; a Web export
zip can be attached separately if the owner wants a one-click browser download.
The locally generated ignored asset is
`dist/Project-Ascent-v0.1.0-web.zip` (10,374,057 bytes,
SHA-256 `7BF3FF63857C2F224DFAEA90CEB4899F0A697D22EC7DD2D4B4C2360D9D4B2887`)
and is ready for that optional attachment.

### Public-release recommendation

**NOT READY — owner confirmation is still required for repository visibility
and the root project license.** The repository content itself is cleaned,
documented, validated, and prepared for that final GitHub administration step.
