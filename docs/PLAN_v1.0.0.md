# v1.0.0 plan: the last release from our side

Written 2026-11-17, after v0.17.0 went live on itch.io and GitHub. This replaces the older 2026-11-15 draft of
this file, which planned 1.0 as a rushed RC; most of that draft shipped in 0.16 and 0.17.

## Owner decisions (2026-11-17)

| Topic | Decision |
| --- | --- |
| Pace | Quality first, no date. Build in phases; the owner plays each phase in the real game before the next starts. Tag 1.0.0 only after two clean test rounds. |
| Updater | In-game and launcher together: the game checks on start, downloads with a progress bar, asks Restart now / Later, and the launcher swaps the files on the next start with one rollback copy. |
| Deferred items | Boss 30 maze format, storm events for levels 16-19 and the daily seed all stay in 1.1. |
| Trailer | Professional and cinematic, made all three ways: scripted in-engine captures, the owner's own OBS footage, and short GIFs. |

## Rules that carry over

- Nothing is done until it has been seen in the real game. Say what was only tested and what was seen.
- Every change gets a test with a negative control. Every rolled level stays bot-proven.
- One or two Godot processes at a time at idle priority; windowed or GPU runs only when the owner says the PC
  is free. Tests redirect APPDATA.
- Commit and push at each checkpoint. Tag and publish only with the owner's go-ahead.
- Player-facing text goes through the humanizer: plain words, no em dashes.

## The phases

Each phase ends with an owner checkpoint: a build the owner plays, a short list of what to check, and a fix
round before the next phase starts.

### Phase 1: updater, shipped early as 0.18.0

Why first: once players and testers have an updater, every later test build (0.99 RCs, 1.0.0) reaches them
without a manual download, which makes the two test rounds much easier.

What exists: the Windows launcher (`launcher/updater.py`) already downloads, checks SHA-256, backs up and
restores, and can verify a signed manifest once a public key is bundled. The in-game About page only checks
the GitHub releases API for a newer version. No release signing key exists yet.

Build:
1. Release signing: the owner generates the key pair once (`python tools/release_sign.py keygen`). The private
   key stays offline (USB drive plus a printed backup); `assets/release_public.pem` is committed.
2. `tools/build_release.ps1` writes `manifest.json` (version, notes, files with size and SHA-256) and signs it.
   The manifest is attached to every GitHub release.
3. In game: on start (at most once a day, off in Settings if the player wants), fetch the manifest, verify the
   signature, compare versions. A quiet corner notice: "Version 1.0.0 is ready. Update". The update screen
   shows the patch notes and a progress bar, downloads into `updates/`, checks every SHA-256, then asks
   "Restart now" or "Later".
4. Launcher: on start, if a verified update is staged, swap it in, keep one rollback copy, start the game. A
   failed or partial download never replaces a working install.
5. macOS and Linux: the notice plus a button that opens the release page (no self-replace on those builds).
   The web and itch builds update themselves; they never show the notice.

Done when: tests cover a good update, a bad signature, a bad hash, an interrupted download and a rollback,
each with a control; then a real staged update (0.18.0 to a 0.18.1 test build on a GitHub pre-release) is
seen working on the owner's PC.

Owner inputs: the Kinoz repo link (the updater UI is modelled on it), and 10 minutes to create and store the
signing key.

### Phase 2: moves with purpose

Goal: every move is needed somewhere, so none of them is decoration.

| Move | A piece that needs it |
| --- | --- |
| Dash | a gap too wide for any jump |
| Double jump / spin | a ledge too high to reach, with no wall to climb |
| Wall-jump | a shaft with no floor until the top |
| Slide | a crusher or laser too low to pass standing |
| Ground pound | a cracked floor that is the only way down |
| Grapple | a void with an anchor and nothing to land on |
| Slash | a drone or barrier that blocks the only route |

Build: one "required" piece per move in the machine generator, introduced in the act where the move is
taught, then mixed into later acts. The proof is strict: the bot clears each piece with the move and fails it
without the move (that failure is the negative control).

Done when: every act's rolled levels contain at least one required piece for each move taught so far (checked
over many seeds), every piece is proven both ways, and the owner has played one level per act.

### Phase 3: boss wall sections

The owner's drawing: two or three tall walls with obstacles and zig-zag jumping, placed just before and just
after boss levels. Build them as fixed, hand-shaped sections inside the rolled levels, with their obstacles
re-rolled per death, and bot-proven like every other piece.

Owner inputs: the drawing again (the earlier one was a screenshot in chat) and any extra patterns.

### Phase 4: level 15 rework

Longer and harder: a second Warden, fewer hiding spots, the same stealth rules. It gets its own proof suite in
the style of `test_warden`.

### Phase 5: difficulty toward the design targets

Measured today (median player, chance to clear a rolled level): act II 0.85, III 0.64, IV 0.48, V 0.44.
These are easier than the design wants, mostly because the 5-frame minimum timing windows set a floor.
Proposal to confirm with the owner: act II 0.70, III 0.55, IV 0.45, V 0.35. Move toward them with tighter
obstacle spacing and denser hazards, never with unfair windows. Remeasure with `tools/tune_machine.gd`.

### Phase 6: cinematic story film

The opening film gets camera moves, depth layers, effects and layered sound, played back at the same pixel
scale as the game. The owner reviews it as a recording before it goes in.

### Phase 7: studio page

Real pitch lines and links for Kanvaz, Kinoz and Glint in `data/studio_projects.json` (the in-game More from
P4INZ page). Owner inputs: one line and one link per project.

### Phase 8: trailer and GIFs

1. In-engine captures with Godot's Movie Maker mode (`--write-movie`): frame-perfect 60 fps at 1080p and 4K,
   scripted shots (a death and re-roll, each boss, Endless, the clear card, the title).
2. The owner's own OBS footage of real play, for the moments a script cannot fake.
3. Edit with ffmpeg: the studio card, 45 to 60 seconds of play cut to the music, the logo, and "Play free in
   your browser" with the itch link. Exports for itch and YouTube (16:9), X (16:9, under 2:20) and a square
   cut.
4. Six short looping GIFs, one per selling point, for itch, X and the README.

Tools: ffmpeg and OBS are already installed, and Movie Maker is built into Godot. Optional: `gifski` (much
better GIF colours: `winget install gifski`) and DaVinci Resolve (free) if the owner wants to grade or
re-cut by hand.

### Phase 9: release candidates and 1.0.0

1. Bump to 0.99.0 (rc1). Full audit on a snapshot. Build every platform plus the manifest.
2. Owner test round 1 with a checklist; bugs and root causes go in `docs/BUGS_round4.md`.
3. Fix, rerun the touched suites, rc2 (delivered through the updater).
4. Owner test round 2. Fix. Final audit.
5. Bump to 1.0.0 with the release notes. The owner approves, then: tag, GitHub release with the manifest,
   `tools/push_itch.bat 1.0.0`, an itch devlog post, the trailer on the page.

## What the owner needs to send

- The Kinoz repo link (Phase 1).
- 10 minutes to create and store the release signing key (Phase 1).
- The wall-section drawing and any extra patterns (Phase 3).
- A yes or a change to the proposed difficulty targets (Phase 5).
- One line and one link each for Kanvaz, Kinoz and Glint (Phase 7).
- Optional: OBS recordings of real play, any length (Phase 8).

## Still in 1.1 (decided)

Boss 30 maze format, storm events for levels 16-19, daily seed with a local best, an online leaderboard,
Steam page, new music tracks.
