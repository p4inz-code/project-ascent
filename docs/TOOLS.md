# Project Ascent — Tool Evaluation

Evaluated for the autonomous S2→S7 run on 2026-08-28. No additional
third-party tool was installed. The project already has a focused Godot 4.7.2
workflow: custom headless behavior suites, deterministic route/reachability
probes, rendered native capture, a performance probe, the local Web preview,
and the existing Godot MCP toolkit.

## Decision

Do not add another test framework, formatter, MCP bridge, or runtime playtest
binary during this run. The likely gains are narrower than the dependency and
maintenance cost for this compact project. The existing MCP toolkit remains
available for intentional local development, but is disabled by default in the
public project configuration.

## Evaluated candidates

### GdUnit4

- Repository: https://github.com/godot-gdunit-labs/gdUnit4
- Purpose: embedded Godot unit/scene testing, mocking, parameterized tests,
  and editor test discovery.
- Compatibility: the repository documents v6.2.x compatibility through Godot
  4.7.1, which is close to the installed 4.7.2 engine.
- License/activity: MIT; the repository shows an active release line and a
  substantial community footprint.
- Why not selected: Ascent’s five existing suites already drive the real scene
  and physics directly, report stable exit codes, and cover player-visible
  behavior. Migrating them would be a broad test rewrite with no current gap.
- Dependencies: a Godot addon and its editor/runtime test framework.
- Removal: if ever adopted, remove its addon directory and test configuration,
  then restore the current `tests/` command workflow.

### GUT

- Repository: https://github.com/bitwes/Gut
- Purpose: mature Godot unit testing, doubles, spies, and editor/CLI test runs.
- Compatibility: the current release notes explicitly include Godot 4.7
  compatibility.
- License/activity: open source with an established release history.
- Why not selected: it overlaps GdUnit4 and Ascent’s existing deterministic
  harness. It would add a second assertion/test lifecycle rather than improve
  the route, browser, or visual validation that matters most here.
- Dependencies: a Godot addon and GUT configuration.
- Removal: delete the addon/configuration and retain the existing suites.

### gdstyle

- Repository: https://github.com/atelico/gdstyle
- Purpose: Rust-based GDScript linting and formatting, with an optional Godot
  editor plugin and CI output.
- Compatibility: targets Godot 4.x source syntax; it is a standalone CLI and
  does not require a Godot installation to run.
- License/activity: MIT; the repository documents CI, releases, tests, and a
  current formatter/linter feature set.
- Why not selected: the codebase is already intentionally formatted and small,
  and an opinionated formatter could create noisy diffs during a finishing and
  audit run. No lint defect or style failure is blocking this project.
- Dependencies: prebuilt Rust binary, or Rust toolchain when built from source;
  the optional editor plugin adds a native extension.
- Removal: delete the binary/plugin and any future `gdstyle.toml` or hooks.

### Godot Stagehand

- Repository: https://github.com/mrf/godot-stagehand
- Purpose: external runtime control, node inspection, input actions, screenshot
  capture/diffing, and declarative scenario/CI reports.
- Compatibility: its documentation lists Godot 4.3 through 4.7.
- License/activity: MIT; the repository is explicitly beta/pre-1.0 and its
  tool schemas may change between minor versions.
- Why not selected: it would help formalize external playtest input and visual
  diffs, but Ascent already has native autopilot/capture and the browser skill
  provides live preview inspection. Introducing a new binary plus project addon
  for one compact route is not justified during the freeze-oriented run.
- Dependencies: a downloaded platform binary, a project addon, and a local
  authenticated control endpoint. The repository warns that it is a dev
  control plane and should remain local.
- Removal: remove the addon and binary, then remove any Stagehand launch/config
  entries; no game architecture should depend on it.

### Alternative Godot MCP servers

- Candidates reviewed: https://github.com/triforge0/godot-mcp and
  https://github.com/OneStepAt4time/open-godot-mcp
- Purpose: editor/runtime scene manipulation, input simulation, screenshots,
  and MCP connectivity.
- Why not selected: Ascent already includes `addons/godot_mcp_toolkit`, and the
  current task does not require more editor automation. Running multiple local
  bridges would add port, permission, and security-boundary complexity.
- Removal: none; the existing addon remains unchanged and web-excluded.

## Current project workflow

Use the installed Godot 4.7.2 binary and the commands in
`docs/SESSION_HANDOFF.md` and `docs/ARCHITECTURE.md`. Keep third-party
development tools local-only, review their source and license before any future
installation, pin versions/commits, and never include them in the shipped Web
payload.

For public-release hygiene, the per-user root `.mcp.json` bridge configuration
is intentionally ignored and is not part of a fresh clone. The tracked
`addons/godot_mcp_toolkit/.mcp.json.template` can be copied locally only when an
owner intentionally enables the MCP development workflow.
