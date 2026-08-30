# Project Ascent — Audit Report & Level Design v2 (Redesign)

**Author role:** Auditor + Designer (Claude). Implementation is out of scope for
this document — hand this file to **Freebuff** (or whichever agent/dev builds
next) as the spec. No project files were modified to produce this document;
it is a new file only.

**Audit date:** 2026-08-30. **Reconciled against:** commit `4fa01e0` (HEAD,
`main`, matches `origin/main`).

**Companion illustrated version:** see the published Artifact link in chat —
it draws a simple diagram of all 25 levels. This file is the text spec of
record; keep the two in sync if either changes.

---

## PART 0 — TL;DR for whoever implements this

1. **The game does not currently run.** One line of code references a
   Godot class that doesn't exist. Fix that first — nothing else matters
   until this is fixed. See Part 1.
2. Level *geometry* (jump/gap validation) is currently OK — the existing
   route-validation suite passes for all 25 levels. What's actually wrong
   with the levels is **sameness**: the design doc promised 25 distinct
   mechanical identities, but nearly every one of those unique ideas was
   built, found to be unbeatable, and stripped back out — repeatedly. What's
   left is 25 ascending platform chains that mostly differ only in goal
   height and boss timers. See Part 3.
3. Part 4 is the full replacement level-by-level spec — same difficulty
   curve and act structure as before, but every "special" mechanic is one
   that has actually been proven to work in this engine, so it should not
   need a sixth rewrite.
4. Part 5 is the pause menu + launcher redesign.
5. Part 6 is the exact asset list — **nothing new needs to be bought or
   downloaded**, everything needed already sits in this repo's parent folder.

---

## PART 1 — CRITICAL BUG (fix before anything else)

### The game's entry point currently fails to compile

```
SCRIPT ERROR: Parse Error: Identifier "RectangleMesh" not declared in the current scope.
   at: GDScript::reload (res://scripts/floating_particles.gd:54)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
   at: GDScript::reload (res://scripts/game_scene.gd:0)
ERROR: Failed to load script "res://scripts/game_scene.gd" with error "Compilation failed".
```

Verified live with `Godot --headless --path . --quit-after 90` against the
current `HEAD` (`4fa01e0`).

**Root cause:** `scripts/floating_particles.gd:54` calls
`RectangleMesh.new()`. There is no `RectangleMesh` class in Godot 4 — the
correct primitive is `QuadMesh` (or a hand-built `ArrayMesh`, which is what
`scripts/star_field.gd` already does for exactly this reason — see its own
comment: *"built by hand rather than with QuadMesh so..."*). Because the
identifier doesn't exist, the whole script fails to **parse**, not just run.

**Why this breaks the whole game, not just particles:** `floating_particles.gd`
is attached to a node inside `scenes/backdrop.tscn`, which every level's
`main_scene` instances. `scripts/game_scene.gd` — the actual entry point that
loads levels, drives transitions, and owns the pause overlay — depends on
that chain and now fails to **compile at all** (not just error at runtime).
`game_scene.tscn` is the scene launched at boot, so the real game cannot
start.

**Why the test suite (262/262 "PASS") didn't catch it:** none of the five
regression suites instantiate `game_scene.tscn`. They boot a level scene
directly, bypassing the real entry point entirely. This is a genuine coverage
gap, not a false claim — the suites are honestly reporting what they check,
they just don't check the thing that broke.

**This matches the leaked evidence:** `docs/media/audit/failure_L01.png` and
`failure_L02.png` (untracked, produced by `tools/audit_playthrough.py` against
the freshly-built `test_release/game/ProjectAscent.exe`, built *after* the
breaking commit) show the game window rendering as a **solid blank grey box**
for the full timeout on both levels — exactly what you'd expect if the entry
point script can't compile. (Aside: those two screenshots are full-desktop
captures, not just the game window — `tools/audit_playthrough.py` uses
`sct.monitors[1]` which grabs the whole primary display. They currently show
an unrelated coding-agent session's private sidebar/chat text in the
background. Recommend fixing the capture to bound to the game window only,
and deleting/regenerating those two PNGs.)

### The fix (one line)

```gdscript
# scripts/floating_particles.gd:54
var mesh := QuadMesh.new()
mesh.size = Vector2(2, 2)
```

`QuadMesh` is a flat rectangle primitive mesh and is a drop-in replacement
here. After the fix, re-run:

```text
Godot --headless --path . --quit-after 60          # confirm 0 SCRIPT ERROR lines
Godot --headless --path . --script res://tests/test_level.gd
pwsh -File tools/run_all_tests.ps1
```

and then **boot `game_scene.tscn` in a real window** before shipping again —
add this as a permanent smoke test (see Part 3) so this exact failure class
can never silently ship a second time.

---

## PART 2 — FOLDER AUDIT (`F:\PROJECT ASCENT`)

| Item | Size | Status | Recommendation |
|---|---|---|---|
| `project-ascent/` | 513 MB | The actual game project | — |
| `craftpix-net-889507-...vampires-locations...` | 234 MB | **Unused.** Project's own `docs/ART_DIRECTION.md` §15 explicitly lists this as "NOT USED (wrong resolution and style)" | Delete or move out of the project tree |
| `craftpix-net-139108-...graveyard...` | 2.1 MB | **Unused** ("wrong theme" per ART_DIRECTION.md) | Delete/archive |
| `craftpix-net-227064-...cloudscape...` | 1.6 MB | **Unused** ("procedural sky is better" per ART_DIRECTION.md) | Delete/archive |
| `craftpix-net-281031-...sky-and-clouds...` | 3.0 MB | **Unused**, same reason | Delete/archive |
| `craftpix-net-645714-...sky-with-clouds-pack-3...` | 1.6 MB | **Unused**, same reason | Delete/archive |
| `craftpix-net-894687-...cyberpunk-pixel-art...` | 7.1 MB | **Partially used** (font + numeral sprites already imported into `assets/`) | **Keep** — Part 6 uses the rest of this pack for UI |
| `test_release/` | 143 MB | Generated audit artifact (extracted release zip) | Fine to keep locally, already outside git; don't commit |
| `godot-mcp-server/` | 5.9 MB | Separate dev-tooling repo (Node/MCP), distinct from the vendored addon below | Dev-only, not shipped; no action needed |
| `godot-mcp-toolkit/` | 11 MB | Separate dev-tooling repo — appears to be the *source* that `project-ascent/addons/godot_mcp_toolkit` (2.1 MB) was vendored from | Confirm one is the source of truth for the other; having both invites drift |
| `docs/` (outer, next to `project-ascent/`) | ~0 (just `media/boss`) | Orphaned — the real docs live in `project-ascent/docs/`, which also has its own `media/boss` | Looks like a stray/duplicate path from a script that wrote to the wrong working directory; safe to delete once confirmed empty of anything unique |
| Two `Godot_v4.7.2*.exe` at root | — | The engine binaries used to build/test | Fine, expected local tooling |

**Inside `project-ascent/`, untracked (per `git status`):**
- `docs/media/audit/` — the two leaked desktop screenshots (see Part 1).
- `docs/media/boss/*.png.import` (25 files) — Godot-generated import
  metadata for boss screenshots; these normally get committed alongside the
  `.png` they describe, so this looks like an incomplete `git add`.
- `tools/audit_playthrough.py`, `tools/capture_boss_final.py` — new tools not
  yet committed.

None of this is destructive to leave as-is; flagging it so whoever commits
next does it deliberately rather than by accident.

---

## PART 3 — GAME AUDIT (design & process findings)

### 3.1 Design-doc drift is systemic, not a one-off

`docs/LEVEL_DESIGN.md` is the "authoritative" 25-level spec. Comparing it
against the shipped `scripts/level_data.gd` (591 `PlatformDef` entries across
25 levels) shows every single level was renamed and re-scoped:

| # | Doc title (promised) | Code title (shipped) | What was dropped |
|---|---|---|---|
| 3 | The First Walls | Movement Confidence | Wall-jump shaft |
| 4 | The First Dash | Difficulty Begins | (name only) |
| 6 | Longer Paths | Endurance | (name only) |
| 9 | Rising Danger | Pressure | (name only) |
| 10 | Hunted | Master Escape | (name only) |
| 11 | Vertical Maze | Traverse | Non-linear branching |
| 12 | Risk and Reward | Rising | Optional shortcuts |
| 13 | Combination Lock | Depths | (name only) |
| 15 | Trapped | Shadow Chase | Environmental traps |
| 17 | Twisted Paths | Precipice | Visual deception |
| 18 | Speed Trial | Maelstrom | Momentum/crumble hazard |
| 20 | Domination | Tempest | (name only, boss kept) |
| 22 | Crystal Maze | Apex | Multi-room navigation |
| 23 | Apex Speed | Crucible | (name only) |
| 25 | Summit | Dawn | (name only, boss kept) |

The git history explains why: `remove all wall-jump shafts from 16 levels`,
`remove all ShaftWalls and Pit walls from all 25 levels`, `fix 8 broken goal
positions across L16–L24`. **Level 3 alone was rewritten at least six
separate times** (wall shaft → blocked platform removed → "blockhead
platform" removed → confusing S3_1 removed → full geometric rewrite) before
settling on a plain ascending chain.

### 3.2 Root cause of the repeated rewrites

Every "fix: remove/rewrite" commit is downstream of the same mistake: level
geometry was authored from the *prose* design doc first, and checked against
the actual measured movement envelope *after* — sometimes never. The
project's own tooling (`tools/probe_reach.gd`, `tools/probe_envelope.gd`)
already measures exactly what's needed:

- Flat running-jump reach: **~180–187 px** horizontal at ≤80 px rise.
- Dash-assisted reach: **~280–309 px** horizontal.
- Wall-slide fall clamp: 130 px/s; wall-jump launch: 340 px/s away from the
  wall, full jump height.

Any gap wider than the flat-jump number needs to be *explicitly* a dash
gate. Any enclosed wall space narrower than roughly two player-widths risks
being a dead end if the player fumbles a wall-jump timing. This is exactly
the pattern that kept failing. Part 4 below designs to this budget explicitly
so it doesn't happen again.

### 3.3 Metadata that lies

`LevelDef` carries `wall_slide_sections` and `dash_required` booleans set
per-level (e.g. Level 3 sets `wall_slide_sections = true`), but **no code
anywhere reads these fields** (confirmed by project-wide search — they are
write-only). Since the actual wall-jump shaft geometry was stripped from
every level, `wall_slide_sections = true` is now simply false advertising in
the data — harmless today because nothing consumes it, but a trap for
whoever wires up level-specific hints or a "new mechanic" banner later and
trusts the flag. Recommend either deleting the fields or making them
accurate again once Part 4 restores real wall sections to specific levels.

### 3.4 Recommended process fix

Add a `tools/validate_all_levels.gd` (or extend `probe_reach.gd`) that loops
`LevelData.get_level(1..25)` and asserts every gap is `trivial` or `dash`
classified — run it in CI/`run_all_tests.ps1` alongside the existing suites.
This converts "level breaks, someone notices during a manual playthrough,
six rewrites happen" into "level breaks, the test suite fails before it's
committed." This is the single highest-leverage process change available.

---

## PART 4 — LEVEL DESIGN v2 (Levels 1–25)

### Design constraints (read this before building any level)

| Rule | Value | Why |
|---|---|---|
| Max flat-jump gap | 180 px @ ≤80 px rise | Measured envelope; anything past this needs a dash gate, marked as such |
| Max dash-jump gap | 280 px | Measured envelope; this is the hard ceiling, not a target |
| No enclosed wall shaft | narrower than ~2 player-widths (56 px) | Root cause of the Level 3 rewrite cycle — a missed wall-jump inside a narrow corridor is unrecoverable |
| No blind branching | forks must reconverge at the same platform | The design doc's branching/shortcut ideas were never actually built; this makes them buildable |
| No hazard types that don't exist in code | no spikes, movers, conveyors, crumbling platforms, fake/deceptive platforms | These were promised (L15, L17, L18, L22) but never implemented; inventing them now is new-mechanic scope, not level design — flagged explicitly per level below where the doc wanted one |
| Every level must pass `probe_reach` before merge | 0 "unreachable" gaps | See §3.4 |

Where the original `LEVEL_DESIGN.md` promised a mechanic that doesn't exist
in the codebase, this spec gives a **safe substitute** that delivers the same
player feeling using only what's already built, and says so explicitly —
that substitution is the actual "issue solved" for that level.

### Act I — Foundation (Levels 1–5): unchanged in spirit, already working

These five are already implemented close to spec and already pass the
route-validation suite. Keep them; only the notes below apply.

| # | Title | Teaches | Structure | Note |
|---|---|---|---|---|
| 1 | First Steps | Jump, variable height | 5–6 gentle platforms, wide forgiving goal | Working as-is |
| 2 | Gaining Height | Coyote time, buffer | 8–10 platforms, gaps 20–40% wider than L1 | Working as-is |
| 3 | First Walls | Wall-slide + wall-jump | Intro run → **one standalone wall** positioned so a single wall-jump clears a gap 20–40 px past the flat-jump limit → large forgiving landing → goal. Missing the wall-jump drops the player onto a **safe lower catch platform**, not into a kill zone. | Replaces the 6x-rewritten enclosed shaft. This is the concrete fix for §3.1/§3.2 |
| 4 | The First Dash | Air dash | Safe practice dash over a small gap → one required dash over a 240 px gap → wall-jump recovery → goal | Working as-is |
| 5 | Escape ★ Boss 1 | All tools under pressure | Existing boss+4 minion chase (170→320 px/s) | Working as-is, keep exactly |

### Act II — Mastery (Levels 6–10)

| # | Title | Teaches | Structure | Note |
|---|---|---|---|---|
| 6 | Longer Paths | Sustained traversal | 3 sections separated by wide safe rest platforms, no branching | New content, straightforward to build |
| 7 | Precision Gaps | Narrow-platform landing | Platforms shrink to 80–100 px wide; gaps stay within the flat-jump budget — difficulty comes from target size, not gap size | Avoids inventing new hazards |
| 8 | Combo Traversal | Dash→wall-jump chaining | Alternating **standalone** wall bumps and dash gaps, each wall backed by a forgiving catch platform below it (never a bottomless miss) | Same safety pattern as L3, repeated |
| 9 | Rising Danger | Speed + reaction | Same mechanics as L6–8, tighter timing windows, higher goal | No new hazard type invented (ART_DIRECTION already says "no spikes/moving hazards" — this spec applies that rule to every level, not just 1–5) |
| 10 | Hunted ★ Boss 2 | Escape under pressure | Existing boss+5 minion chase (220→400 px/s), tighter route | Working as-is, keep exactly |

### Act III — Challenge (Levels 11–15)

| # | Title | Teaches | Structure | Note |
|---|---|---|---|---|
| 11 | Vertical Maze | **Safe route choice** | A short 3-platform "low route" (easier, slightly longer) and a short 3-platform "high route" (one dash, faster) that split and then **reconverge on the same platform** before the goal | Delivers the doc's "route choice" promise without an unreachable dead-end fork |
| 12 | Risk and Reward | Optional shortcut | One shortcut platform sits **above** the main safe path, reachable only via a dash-jump, and skips two platforms of the main route. Missing it drops the player back onto the main path — never death | This is the doc's original idea, made buildable: risk costs nothing but the skip |
| 13 | Combination Lock | Sequential mastery | Four short zones in a row, each isolated to one skill (jump-only → standalone wall bump → dash-only → combo), safe landing between each | Matches doc intent exactly, no invented mechanics needed |
| 14 | Endurance | Consistency | 5 sections with wide rest platforms between them (doc's own idea, and a good one) | Working as designed |
| 15 | Shadow Chase ★ Boss 3 | Escape + spatial awareness | Existing boss+5 minion chase (230→420 px/s) through **narrower validated-reachable platforms**, not new "environmental trap" hazards | The doc wanted new trap entities that don't exist in code; narrower platforms during the existing chase deliver the same pressure without new scope |

### Act IV — Ordeal (Levels 16–20)

| # | Title | Teaches | Structure | Note |
|---|---|---|---|---|
| 16 | The Gauntlet | Precision endurance | Continuous precision chain, minimal rest, narrow platforms, still inside the jump budget | Straightforward |
| 17 | Precipice | Level reading | Doc wanted "visually deceptive" fake-looking platforms — that needs new visual/collision-mismatch code (scope creep). Substitute: tight precision + occasional standalone wall bump, difficulty from density not trickery | Explicit scope call-out — flag to the user if "fake platforms" is wanted later as its own feature |
| 18 | Maelstrom | Momentum | Doc wanted crumbling/conveyor platforms — don't exist in code. Substitute: a long chain of evenly-spaced platforms tuned so only continuous flat-jump rhythm clears each gap; difficulty from consecutive precise judgment, not a new hazard type | Same call-out as L17 |
| 19 | Threshold | Full moveset | Sequential zones covering jump/wall/dash/combo at Act IV tightness | Buildable now with existing systems |
| 20 | Tempest ★ Boss 4 | Multi-phase adaptation | Existing 2-phase boss (250→450, then 300→500 px/s), 6 minions | Working as-is, keep exactly |

### Act V — Apex (Levels 21–25)

| # | Title | Teaches | Structure | Note |
|---|---|---|---|---|
| 21 | Summit Approach | Endgame endurance | 7 sections, progressively tighter tolerances, still within the jump/dash budget | Longest non-boss level so far |
| 22 | Apex | Tight-space mastery | Doc wanted a "multi-room crystal maze" — needs an interior-room content type that doesn't exist. Substitute: one continuous tight vertical corridor with alternating standalone wall bumps, delivering the enclosed/tense feeling without a new room system | Explicit scope call-out |
| 23 | Crucible | Max speed | Fast flowing chain at the tightest still-safe tolerances (near 180 px flat / 280 px dash ceilings, never past them) | — |
| 24 | The Final Wall | Ultimate endurance | 8 sections, hardest yet, generous rest platforms between each (per doc — this part was always a good idea) | Longest level in the game |
| 25 | Dawn ★ Boss 5 (Final) | Everything, under maximum pressure | Existing 3-phase boss (300→500, 350→550, 400→600 px/s), 6 minions | Working as-is, keep exactly |

### Explicit scope call-outs (don't build these by accident)

Three levels (17, 18, 22) had a "new mechanic" in the original doc that was
never actually implemented anywhere in the codebase: fake/deceptive
platforms, momentum-loss/crumbling platforms, and multi-room interior
navigation. Each is a real feature with its own collision/visual/testing
surface — not a level-design tweak. This spec gives a safe substitute for
each so the campaign is completable today; if the studio wants the original
fantasy later, scope it as its own feature with its own test coverage rather
than folding it into a level PR.

---

## PART 5 — UI REDESIGN

### 5.1 Pause menu (`scripts/pause_menu.gd`, `scenes/*pause*`)

**Current state:** functional but entirely default Godot theme — plain
`Button`/`Label`/`HSlider`/`CheckButton` nodes with no custom `StyleBox`,
despite a full matching pixel-UI kit already sitting in the repo's parent
folder, partially imported, and explicitly pre-approved for this use in
`docs/ART_DIRECTION.md` §9 ("Cyberpunk assets: available for future HUD
upgrades").

**Redesign:**
- **Panel background:** one `Frame_XX.png` from the Cyberpunk pack as a
  9-slice `StyleBoxTexture` behind the whole menu, replacing the flat panel.
- **Buttons** (Resume / Restart / Settings / Progress / Reset / Quit): one
  numbered button set from `6 Buttons/N/` supplies normal/hover/pressed
  frames — wire as a `StyleBoxTexture` per `Button` theme state.
- **Volume sliders:** restyle `HSlider` grabber/fill using an `EnergyBar*.png`
  strip instead of the default thin bar.
- **Section headers** (Audio / Visual / Gameplay in Settings): a small
  `Icon_XX.png` glyph to the left of each header label.
- **Typography:** headings and the title use the already-imported
  `CyberpunkCraftpixPixel.otf`; keep slider values, checkbox labels, and body
  copy in the existing clean default font — pixel fonts read poorly under
  ~14 px, and the settings panel has a lot of small text.
- **Color:** stay exactly on the existing palette — cyan `#6CC4E8` for
  interactive accents, amber `#FFD478` for the title/active state, dark slate
  panel body — so the menu reads as part of the same game, not a reskin.
- **Cursor (optional):** swap to `Cursors/2.png` while any menu is open,
  revert to default on close.

### 5.2 Launcher (`launcher/launcher.py`)

**Current state:** a reasonably well-organized dark-theme Tkinter app
(sidebar with Play/Updates/About, cards, custom color constants) — the
structure is fine, it just doesn't visually match the game at all: plain
system font, a unicode "▶" glyph standing in for a logo, no imagery.

**Redesign (keep the existing Tkinter structure, restyle only):**
- **Wordmark:** Tkinter can't load `.otf` at arbitrary sizes reliably —
  pre-render the "PROJECT ASCENT" wordmark once as a PNG (a small Pillow
  script using the same `CyberpunkCraftpixPixel.otf`), then display it as a
  static `PhotoImage` in the header, replacing the plain text label.
- **Sidebar icons:** add a small `Icon_XX.png` glyph next to each of
  Play/Updates/About (16–20 px), from `3 Icons/Icons/`.
- **Accent color:** change the launcher's `ACCENT` constant to the exact
  in-game cyan `#6CC4E8` (and amber `#FFD478` for the primary Play button),
  so launcher and game feel like one product instead of two.
- **Background texture:** a low-opacity decorative piece from
  `9 Other/1 Decor/` behind the hero Play button, echoing the game's own
  vignette.
- **App icon:** convert `Logo3.png` (the simplest mark) to `.ico` and set it
  as the window/exe icon — worth double-checking this isn't still the
  default Tk icon.

---

## PART 6 — ASSET LIST (hand this to Freebuff — nothing new to source)

Everything below already exists in this repo's parent folder
(`craftpix-net-894687-free-gui-for-cyberpunk-pixel-art/`). No new asset
purchases or downloads are needed.

| Asset | Source path | Use | Work needed |
|---|---|---|---|
| `CyberpunkCraftpixPixel.otf` | already at `project-ascent/assets/fonts/` | Pause menu headings; pre-rendered launcher wordmark | Already imported for Godot; needs a one-time PNG render for the Tkinter launcher |
| A `Frame_XX.png` (e.g. `Frame_07.png`) | `.../1 Frames/` | Pause menu panel background | Import + 9-slice `StyleBoxTexture` |
| One numbered set from `6 Buttons/N/` (e.g. `6 Buttons/3/3_01..08.png`) | `.../6 Buttons/3/` | Pause menu button states (normal/hover/pressed) | Import + `StyleBoxTexture` per state |
| `EnergyBar3.png` or `EnergyBar5.png` | `.../2 Bars/` | Volume slider fill | Import + `HSlider` theme override |
| A few `Icon_XX.png` | `.../3 Icons/Icons/` | Settings section headers + launcher sidebar icons | Direct import |
| `Logo2.png` or `Logo3.png` | `.../5 Logo/` | Launcher app icon (`.ico` conversion), optional splash | PNG → ICO conversion |
| `Cursors/2.png` | `.../8 Cursors/` | Optional custom menu cursor | Optional, low priority |
| (existing) `assets/ui/0-9,B,comma,dot,EnergyBar*.png` | already in `project-ascent/assets/ui/` | Already used by the in-game HUD numeral font | No change |

**License note:** the pack ships only a link
(`https://craftpix.net/file-licenses/`) rather than an inline license text —
CraftPix's free-tier license generally permits commercial use but restricts
reselling the raw assets standalone. Confirm the exact terms directly before
Freebuff bundles these into a distributed build; I haven't verified this
license myself and won't assert compliance.

**Cleanup:** once the above files are copied into `assets/ui/`, the other
five CraftPix packs at the project root (~242 MB total — graveyard, two
cloud/sky packs, cloudscape, vampire-locations) can be deleted; the
project's own `ART_DIRECTION.md` already documents them as out of scope.

---

## Summary checklist for Freebuff, in order

1. Fix `scripts/floating_particles.gd:54` (`RectangleMesh` → `QuadMesh`).
   Confirm `game_scene.tscn` boots in a real window.
2. Add a headless smoke test that instantiates `game_scene.tscn` directly
   (closes the coverage gap that let #1 ship).
3. Add a level-reachability validator that runs across all 25 levels in CI
   (closes the gap that caused the Level 3 rewrite cycle).
4. Build Levels 6–9, 11–14, 16–19, 21–24 per Part 4 (Levels 1–5, 10, 15, 20,
   25 already work — leave them alone).
5. Re-skin the pause menu and launcher per Part 5, using only the asset list
   in Part 6 (no new sourcing needed).
6. Re-export and re-run the full end-to-end audit
   (`tools/audit_playthrough.py`, after fixing its full-desktop screenshot
   capture) before calling the next build a release candidate.
