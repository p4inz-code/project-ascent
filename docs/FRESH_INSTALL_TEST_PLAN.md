# Project Ascent — Fresh-Install Test Plan

For testing a GitHub release download on a machine that has never run this
game before (no Godot, no repo, no existing save data). This is the test a
real player's first experience actually looks like — the automated suites
never exercise it.

**Where things live on a truly fresh machine (nothing to clean up beforehand):**
- Save + settings: `%APPDATA%\Godot\app_userdata\Project Ascent\`
- Launcher preferences: wherever `launcher/config.py` writes them (check on
  first run if unsure)

If this is a machine that's run a previous build, delete that folder first
so the test actually reflects a first-time player.

---

## 1. Download & extract

- [ ] Go to the GitHub Releases page for `p4inz-code/project-ascent`, download
      the latest asset.
- [ ] Extract to a normal location (Desktop or Downloads) — **not** inside
      any dev folder, to prove it doesn't need the repo.
- [ ] Confirm the extracted folder contains `ProjectAscent.exe`,
      `ProjectAscent.pck`, and `README.txt` (or `ProjectAscentLauncher.exe`
      if the launcher is included in this release) — nothing else required.

## 2. First boot — no launcher

- [ ] Double-click `ProjectAscent.exe` directly.
- [ ] Windows SmartScreen may warn about an unrecognized publisher — this is
      expected for an unsigned indie build, not a defect. Click "more info" →
      "run anyway".
- [ ] Game window opens within a few seconds, at a reasonable default size.
- [ ] No console/error window appears alongside it.
- [ ] The opening screen/controls panel is legible and the correct keys are
      shown (A/D or arrows, Space/W jump, Shift/J dash, R restart, Tab/F1
      controls toggle).

## 3. Launcher (if this release includes it)

- [ ] Launch `ProjectAscentLauncher.exe` instead.
- [ ] Play page shows the current installed version correctly on first run
      (reads it from the extracted build, not a stale cache).
- [ ] "Check for Updates" reaches GitHub and reports either "up to date" or a
      newer version, without hanging or erroring on a fresh machine with no
      prior config.
- [ ] Update preference radio (ask/auto/never) is selectable and its choice
      survives closing and reopening the launcher.
- [ ] Play button launches the game correctly.
- [ ] About page shows correct developer/attribution info.

## 4. Fresh save behavior

- [ ] Before any input, confirm `%APPDATA%\Godot\app_userdata\Project
      Ascent\save_data.json` does not yet exist (proves this really is a
      clean run).
- [ ] Take one input (move/jump/dash) — the save file should now exist with
      `checkpoint_level: 1`.
- [ ] Kill the game mid-level, relaunch — confirm it resumes from the correct
      checkpoint, not Level 1 again (unless Level 1 was still in progress).

## 5. Full campaign pass

Play start to finish, or at minimum spot-check every Act and every boss.
Note the exact level + what happened for anything under "Watch for."

| Level(s) | What to confirm | Watch for |
|---|---|---|
| 1–4 | Movement teaches itself: jump, wider gaps, wall-slide/jump, dash | Any gap that feels impossible on a clean first attempt |
| 5 | Boss + 4 minions trigger past the marked point, chase feels readable, minions visibly **flank** rather than stack on top of each other | Minions clumping into one spot (this was a real bug, fixed this session — confirm it stays fixed) |
| 6–9 | New crumble platforms (one per level) visibly shake and give way after landing, then reform after a few seconds | Falling through instantly on landing (delay too short) or the level being uncompletable because of it |
| 10 | Second boss, faster, 5 minions | Same flanking check as L5 |
| 11–14 | Longer/vertical levels, no dead ends | Getting stuck with no visible way forward |
| 15 | Third boss chase | Same catch-detection check |
| 16–19 | Precision + speed sections | — |
| 20 | Fourth boss, 2 phases, 6 minions | Phase transition should be noticeable (speed/behavior change) |
| 21–24 | Endgame length; L21–24 include one bounce pad each | Bounce pad should visibly launch the player higher than a normal jump, land solidly afterward |
| 25 | Final boss, 3 phases, 6 minions | Victory/"all levels complete" screen appears on completion |

- [ ] Pause menu (ESC) opens/closes cleanly from every level, including
      mid-boss-chase.
- [ ] Settings panel: audio sliders, visual toggles (screen shake,
      afterimages, particles, background motion, FPS counter), gameplay
      toggles (show controls, death flash, boss warnings, attempt counter,
      run timer) all visibly do what they say.
- [ ] Progress panel shows correct current level / highest unlocked /
      checkpoint / completion count.
- [ ] Reset Progress asks for confirmation and actually resets to Level 1.

## 6. Crash / error triage (only if something breaks)

- [ ] Note the exact level number and what you were doing.
- [ ] Check for a Windows Error Reporting popup — if present, note the
      faulting module.
- [ ] If the window goes blank/grey and stays that way, that's the exact
      symptom of the entry-point compile failure fixed this session
      (`scripts/floating_particles.gd`) — capture a screenshot and check
      whether it's a regression or a new issue.
- [ ] Save the contents of `%APPDATA%\Godot\app_userdata\Project
      Ascent\save_data.json` at the point of failure before touching
      anything else.
- [ ] **Grab the error log**: every run now writes
      `%APPDATA%\Godot\app_userdata\Project Ascent\logs\godot.log` (enabled
      this session specifically so bugs are reportable without reproducing
      them live). It captures every `SCRIPT ERROR`/`ERROR`/`WARNING` the
      engine printed, in order, with the exact file:line — this is the
      single most useful thing to hand over for any bug report. Copy it out
      before relaunching, since a fresh run may rotate/append to it.

## 7. Report format

For each issue found: level number, what you did, what happened, what you
expected. A screenshot or short clip is worth more than a description for
anything visual (boss behavior, platform timing, layout).
